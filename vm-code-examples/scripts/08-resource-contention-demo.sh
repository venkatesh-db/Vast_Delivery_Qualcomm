#!/usr/bin/env bash

set -Eeuo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

require_controlled_lab
require_cmd stress-ng
for tool in vmstat iostat pidstat sar; do
  require_cmd "$tool"
done

duration="${DURATION:-60}"
cpu_workers="${CPU_WORKERS:-2}"
vm_workers="${VM_WORKERS:-1}"
vm_bytes="${VM_BYTES:-25%}"
stress_pid=""

cleanup() {
  if [[ -n "$stress_pid" ]] && kill -0 "$stress_pid" 2>/dev/null; then
    kill -INT "$stress_pid" 2>/dev/null || true
    wait "$stress_pid" 2>/dev/null || true
  fi
}
trap cleanup EXIT INT TERM

info "Starting bounded client contention for $duration seconds"
printf 'CPU workers=%s, VM workers=%s, VM bytes=%s\n' \
  "$cpu_workers" "$vm_workers" "$vm_bytes"

DURATION="$duration" "$SCRIPT_DIR/06-capture-client-metrics.sh" &
metrics_pid=$!

stress-ng \
  --cpu "$cpu_workers" \
  --vm "$vm_workers" \
  --vm-bytes "$vm_bytes" \
  --timeout "${duration}s" \
  --metrics-brief &
stress_pid=$!

wait "$stress_pid"
stress_pid=""
wait "$metrics_pid"

info "Contention stopped. Re-run the original fio workload to prove recovery."
