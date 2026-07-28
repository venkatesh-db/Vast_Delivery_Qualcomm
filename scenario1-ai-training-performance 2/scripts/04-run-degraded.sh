#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

require_cmd fio
require_cmd python3
require_prepared
ensure_current_run

competitor_pid=''

stop_competitor() {
  stop_monitors
  terminate_pid "$competitor_pid"
}

trap stop_competitor EXIT INT TERM

info "Starting competing small-block workload on disposable contention.bin"
fio \
  --name=competing-small-block \
  --filename="$CONTENTION_FILE" \
  --rw=randrw \
  --rwmixread=70 \
  --bs="$COMPETITOR_BS" \
  --ioengine=libaio \
  --iodepth="$COMPETITOR_IODEPTH" \
  --numjobs="$COMPETITOR_JOBS" \
  --direct="$FIO_DIRECT" \
  --time_based=1 \
  --runtime=300 \
  --group_reporting \
  --output-format=json \
  --output="$RUN_DIR/competing-fio.json" &
competitor_pid="$!"

sleep 1
info "Competing fio PID: $competitor_pid"
info "Injecting ${DEGRADED_LOADER_DELAY_MS} ms repeatable loader wait per batch"

start_monitors degraded
python3 "$PROJECT_DIR/src/training_simulator.py" \
  --dataset "$DATASET_FILE" \
  --phase degraded \
  --batches "$BATCH_COUNT" \
  --batch-bytes "$BATCH_BYTES" \
  --compute-ms "$COMPUTE_MS" \
  --loader-delay-ms "$DEGRADED_LOADER_DELAY_MS" \
  --drop-cache-hint "$DROP_FILE_CACHE_HINT" \
  --output "$RUN_DIR/degraded.json"

stop_competitor
trap - EXIT INT TERM
info "Fault removed. Evidence: $RUN_DIR/degraded.json"
