#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONFIG_FILE="${SCENARIO_CONFIG:-$PROJECT_DIR/config.env}"

if [[ -f "$CONFIG_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$CONFIG_FILE"
fi

LAB_DIR="${LAB_DIR:-/var/tmp/vast-ai-dataset-access-lab}"
SHARD_SIZE_BYTES="${SHARD_SIZE_BYTES:-1048576}"
INITIAL_METADATA_FILES="${INITIAL_METADATA_FILES:-100}"
METADATA_FILE_BYTES="${METADATA_FILE_BYTES:-4096}"
GROWTH_FILES_PER_CYCLE="${GROWTH_FILES_PER_CYCLE:-50}"
BASELINE_DURATION_SECONDS="${BASELINE_DURATION_SECONDS:-2}"
INCIDENT_DURATION_SECONDS="${INCIDENT_DURATION_SECONDS:-5}"
RECOVERY_DURATION_SECONDS="${RECOVERY_DURATION_SECONDS:-2}"
CLIENT_READ_INTERVAL_MS="${CLIENT_READ_INTERVAL_MS:-20}"
PUBLISH_INTERVAL_MS="${PUBLISH_INTERVAL_MS:-100}"
LEGACY_DELETE_GAP_MS="${LEGACY_DELETE_GAP_MS:-60}"
CURRENT_CLIENT_NAME="${CURRENT_CLIENT_NAME:-trainer-b}"
CURRENT_CLIENT_UID="${CURRENT_CLIENT_UID:-2002}"
STALE_CLIENT_NAME="${STALE_CLIENT_NAME:-trainer-a}"
STALE_CLIENT_UID="${STALE_CLIENT_UID:-2001}"

DATASETS_DIR="$LAB_DIR/datasets"
RELEASES_DIR="$DATASETS_DIR/releases"
CURRENT_DIR="$DATASETS_DIR/current"
LEGACY_DIR="$DATASETS_DIR/v7"
GROWTH_DIR="$DATASETS_DIR/metadata-growth"
CURRENT_SHARD="$CURRENT_DIR/shard-042.bin"
LEGACY_SHARD="$LEGACY_DIR/shard-042.bin"
ARTIFACT_ROOT="$LAB_DIR/artifacts"
SENTINEL="$LAB_DIR/.vast-ai-dataset-access-lab"
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
  command -v "$1" >/dev/null 2>&1 ||
    die "Missing command '$1'. Run ./scripts/00-install-tools.sh"
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
  [[ -e "$CURRENT_SHARD" ]] || die "Canonical shard is missing: $CURRENT_SHARD"
  [[ -e "$LEGACY_SHARD" ]] || die "Legacy shard is missing: $LEGACY_SHARD"
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

MONITOR_PIDS=()

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
}

stop_monitors() {
  local pid
  for pid in "${MONITOR_PIDS[@]:-}"; do
    terminate_pid "$pid"
  done
  MONITOR_PIDS=()
}

capture_capacity() {
  local phase="$1"
  ensure_current_run
  python3 "$PROJECT_DIR/src/capture_capacity.py" \
    --lab-dir "$LAB_DIR" \
    --growth-dir "$GROWTH_DIR" \
    --phase "$phase" \
    --output "$RUN_DIR/capacity-${phase}.json"
}

run_two_clients() {
  local phase="$1"
  local duration="$2"
  local current_output="$RUN_DIR/${phase}-current.json"
  local stale_output="$RUN_DIR/${phase}-stale.json"
  local current_pid stale_pid

  python3 "$PROJECT_DIR/src/client_reader.py" \
    --path "$CURRENT_SHARD" \
    --browse-dir "$GROWTH_DIR" \
    --phase "$phase" \
    --client "$CURRENT_CLIENT_NAME" \
    --uid-label "$CURRENT_CLIENT_UID" \
    --duration "$duration" \
    --interval-ms "$CLIENT_READ_INTERVAL_MS" \
    --output "$current_output" &
  current_pid="$!"

  python3 "$PROJECT_DIR/src/client_reader.py" \
    --path "$LEGACY_SHARD" \
    --browse-dir "$GROWTH_DIR" \
    --phase "$phase" \
    --client "$STALE_CLIENT_NAME" \
    --uid-label "$STALE_CLIENT_UID" \
    --duration "$duration" \
    --interval-ms "$CLIENT_READ_INTERVAL_MS" \
    --output "$stale_output" &
  stale_pid="$!"

  wait "$current_pid"
  wait "$stale_pid"
}
