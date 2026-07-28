#!/usr/bin/env bash

set -Eeuo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

require_cmd fio
require_safe_write_target

run_id="$(timestamp)"
test_file="$TARGET_DIR/vast-training-smoke.bin"
result="$ARTIFACT_DIR/fio-smoke-$run_id.json"

cleanup() {
  if [[ "${KEEP_TEST_DATA:-NO}" != "YES" ]]; then
    rm -f -- "$test_file"
  fi
}
trap cleanup EXIT

info "Running a 20-second, 128 MiB mixed-I/O smoke test"
fio \
  --name=smoke \
  --filename="$test_file" \
  --rw=randrw \
  --rwmixread=70 \
  --bs=4k \
  --size=128M \
  --runtime=20 \
  --time_based \
  --ioengine=libaio \
  --direct=1 \
  --iodepth=8 \
  --group_reporting \
  --output-format=json \
  --output="$result"

show_file "fio JSON:" "$result"
if command -v jq >/dev/null 2>&1; then
  jq '.jobs[0] | {
    read_iops: .read.iops,
    read_bw_bytes: .read.bw_bytes,
    read_mean_ns: .read.clat_ns.mean,
    write_iops: .write.iops,
    write_bw_bytes: .write.bw_bytes,
    write_mean_ns: .write.clat_ns.mean,
    errors: .error
  }' "$result"
fi
