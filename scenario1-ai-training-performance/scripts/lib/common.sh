#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONFIG_FILE="${SCENARIO_CONFIG:-$PROJECT_DIR/config.env}"

if [[ -f "$CONFIG_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$CONFIG_FILE"
fi

LAB_DIR="${LAB_DIR:-/var/tmp/vast-ai-training-lab}"
DATASET_SIZE="${DATASET_SIZE:-128M}"
CONTENTION_FILE_SIZE="${CONTENTION_FILE_SIZE:-128M}"
BATCH_COUNT="${BATCH_COUNT:-80}"
BATCH_BYTES="${BATCH_BYTES:-1048576}"
COMPUTE_MS="${COMPUTE_MS:-40}"
BASELINE_LOADER_DELAY_MS="${BASELINE_LOADER_DELAY_MS:-2}"
DEGRADED_LOADER_DELAY_MS="${DEGRADED_LOADER_DELAY_MS:-46}"
BASELINE_TRAINING_HOURS="${BASELINE_TRAINING_HOURS:-3}"
COMPETITOR_BS="${COMPETITOR_BS:-4k}"
COMPETITOR_IODEPTH="${COMPETITOR_IODEPTH:-32}"
COMPETITOR_JOBS="${COMPETITOR_JOBS:-2}"
FIO_DIRECT="${FIO_DIRECT:-1}"
DROP_FILE_CACHE_HINT="${DROP_FILE_CACHE_HINT:-1}"

DATASET_FILE="$LAB_DIR/dataset.bin"
CONTENTION_FILE="$LAB_DIR/contention.bin"
ARTIFACT_ROOT="$LAB_DIR/artifacts"
SENTINEL="$LAB_DIR/.vast-ai-training-lab"
CURRENT_RUN_FILE="$LAB_DIR/.current-run"

info() {
  printf '[INFO] %s\n' "$*"
}

warn() {
  printf '[WARN] %s\n' "$*" >&2
}

die() {
  printf '[ERROR] %s\n' "$*" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Missing command '$1'. Run ./scripts/00-install-tools.sh"
}

validate_lab_dir() {
  [[ "$LAB_DIR" == /* ]] || die "LAB_DIR must be an absolute path."
  case "$LAB_DIR" in
    /|/home|/home/*|/root|/root/*|/usr|/usr/*|/etc|/etc/*|/var|/var/tmp)
      die "Unsafe LAB_DIR refused: $LAB_DIR"
      ;;
  esac

  local slashless="${LAB_DIR#/}"
  [[ "$slashless" == */* ]] || die "LAB_DIR is too shallow: $LAB_DIR"
}

require_confirmation() {
  [[ "${CONFIRM_DISPOSABLE_LAB:-NO}" == "YES" ]] ||
    die "Set CONFIRM_DISPOSABLE_LAB=YES only for an isolated disposable lab."
}

require_prepared() {
  validate_lab_dir
  [[ -f "$SENTINEL" ]] || die "Lab is not prepared. Run ./scripts/02-prepare-lab.sh"
  [[ -f "$DATASET_FILE" ]] || die "Dataset file is missing: $DATASET_FILE"
  [[ -f "$CONTENTION_FILE" ]] || die "Contention file is missing: $CONTENTION_FILE"
}

new_run_id() {
  date -u +'%Y%m%dT%H%M%SZ'
}

ensure_current_run() {
  mkdir -p "$ARTIFACT_ROOT"
  if [[ ! -s "$CURRENT_RUN_FILE" ]]; then
    new_run_id > "$CURRENT_RUN_FILE"
  fi
  RUN_ID="$(<"$CURRENT_RUN_FILE")"
  RUN_DIR="$ARTIFACT_ROOT/$RUN_ID"
  mkdir -p "$RUN_DIR"
  export RUN_ID RUN_DIR
}

reset_current_run() {
  mkdir -p "$ARTIFACT_ROOT"
  new_run_id > "$CURRENT_RUN_FILE"
  ensure_current_run
}

MONITOR_PIDS=()

terminate_pid() {
  local pid="$1"
  local attempt

  [[ -n "$pid" ]] || return 0
  if ! kill -0 "$pid" 2>/dev/null; then
    wait "$pid" 2>/dev/null || true
    return 0
  fi

  kill -TERM "$pid" 2>/dev/null || true
  for attempt in {1..20}; do
    if ! kill -0 "$pid" 2>/dev/null; then
      wait "$pid" 2>/dev/null || true
      return 0
    fi
    sleep 0.1
  done

  warn "PID $pid did not stop after SIGTERM; sending SIGKILL."
  kill -KILL "$pid" 2>/dev/null || true
  wait "$pid" 2>/dev/null || true
}

start_monitors() {
  local phase="$1"
  local prefix="$RUN_DIR/${phase}"

  if command -v vmstat >/dev/null 2>&1; then
    vmstat 1 > "${prefix}-vmstat.txt" 2>&1 &
    MONITOR_PIDS+=("$!")
  fi

  if command -v iostat >/dev/null 2>&1; then
    iostat -xz 1 > "${prefix}-iostat.txt" 2>&1 &
    MONITOR_PIDS+=("$!")
  fi

  if command -v sar >/dev/null 2>&1; then
    sar -n DEV 1 > "${prefix}-network.txt" 2>&1 &
    MONITOR_PIDS+=("$!")
  fi

  if command -v nvidia-smi >/dev/null 2>&1; then
    nvidia-smi \
      --query-gpu=timestamp,index,name,utilization.gpu,memory.used,memory.total \
      --format=csv -l 1 > "${prefix}-nvidia-smi.csv" 2>&1 &
    MONITOR_PIDS+=("$!")
  else
    printf 'nvidia-smi not available; using simulated GPU teaching metric.\n' \
      > "${prefix}-nvidia-smi.txt"
  fi
}

stop_monitors() {
  local pid
  for pid in "${MONITOR_PIDS[@]:-}"; do
    terminate_pid "$pid"
  done
  MONITOR_PIDS=()
}

run_training_phase() {
  local phase="$1"
  local delay_ms="$2"
  require_prepared
  ensure_current_run

  info "Running $phase training workload"
  start_monitors "$phase"
  trap stop_monitors EXIT INT TERM

  python3 "$PROJECT_DIR/src/training_simulator.py" \
    --dataset "$DATASET_FILE" \
    --phase "$phase" \
    --batches "$BATCH_COUNT" \
    --batch-bytes "$BATCH_BYTES" \
    --compute-ms "$COMPUTE_MS" \
    --loader-delay-ms "$delay_ms" \
    --drop-cache-hint "$DROP_FILE_CACHE_HINT" \
    --output "$RUN_DIR/${phase}.json"

  stop_monitors
  trap - EXIT INT TERM
  info "Evidence: $RUN_DIR/${phase}.json"
}
