#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

require_cmd python3
require_prepared
ensure_current_run

publisher_pid=''

stop_all() {
  stop_monitors
  terminate_pid "$publisher_pid"
}

trap stop_all EXIT INT TERM

info "Starting controlled publishing fault and metadata growth"
python3 "$PROJECT_DIR/src/publisher.py" \
  --current-shard "$CURRENT_SHARD" \
  --legacy-shard "$LEGACY_SHARD" \
  --growth-dir "$GROWTH_DIR" \
  --duration "$INCIDENT_DURATION_SECONDS" \
  --publish-interval-ms "$PUBLISH_INTERVAL_MS" \
  --legacy-delete-gap-ms "$LEGACY_DELETE_GAP_MS" \
  --growth-files-per-cycle "$GROWTH_FILES_PER_CYCLE" \
  --metadata-file-bytes "$METADATA_FILE_BYTES" \
  --event-log "$RUN_DIR/publisher-events.jsonl" &
publisher_pid="$!"

sleep 0.2
start_monitors incident
run_two_clients incident "$INCIDENT_DURATION_SECONDS"
terminate_pid "$publisher_pid"
publisher_pid=''
stop_monitors
trap - EXIT INT TERM

capture_capacity after
info "Incident evidence written to $RUN_DIR"
