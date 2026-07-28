#!/usr/bin/env bash

set -Eeuo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

require_cmd fio
require_cmd jq
require_safe_write_target

run_id="$(timestamp)"
result_dir="$ARTIFACT_DIR/queue-depth-$run_id"
mkdir -p "$result_dir"
test_file="$TARGET_DIR/vast-training-qd.bin"
size="${FIO_SIZE:-1G}"
duration="${DURATION:-30}"

info "Preparing the dedicated queue-depth data file"
fio \
  --name=prepare \
  --filename="$test_file" \
  --rw=write \
  --bs=1M \
  --size="$size" \
  --ioengine=libaio \
  --direct=1 \
  --iodepth=16 \
  --group_reporting \
  --output="$result_dir/prepare.txt"

printf 'queue_depth,iops,MBps,mean_latency_ms,p99_latency_ms,error\n' \
  > "$result_dir/summary.csv"

for qd in 1 4 8 16 32; do
  result="$result_dir/qd-$qd.json"
  info "Testing 4 KiB random read at queue depth $qd"
  fio \
    --name="qd-$qd" \
    --filename="$test_file" \
    --rw=randread \
    --bs=4k \
    --size="$size" \
    --runtime="$duration" \
    --time_based \
    --ioengine=libaio \
    --direct=1 \
    --iodepth="$qd" \
    --numjobs=1 \
    --group_reporting \
    --output-format=json \
    --output="$result"

  jq -r --arg qd "$qd" '
    [
      $qd,
      .jobs[0].read.iops,
      (.jobs[0].read.bw_bytes / 1048576),
      (.jobs[0].read.clat_ns.mean / 1000000),
      ((.jobs[0].read.clat_ns.percentile["99.000000"] // 0) / 1000000),
      .jobs[0].error
    ] | @csv
  ' "$result" >> "$result_dir/summary.csv"
done

column -s, -t "$result_dir/summary.csv" 2>/dev/null ||
  sed -n '1,20p' "$result_dir/summary.csv"

if [[ "${KEEP_TEST_DATA:-NO}" != "YES" ]]; then
  rm -f -- "$test_file"
fi

show_file "Sweep results:" "$result_dir"
