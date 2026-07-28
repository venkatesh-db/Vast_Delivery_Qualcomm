#!/usr/bin/env bash

set -Eeuo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

require_cmd fio
require_safe_write_target

run_id="$(timestamp)"
profile_dir="$ARTIFACT_DIR/fio-profiles-$run_id"
mkdir -p "$profile_dir"
test_file="$TARGET_DIR/vast-training-profile.bin"
size="${FIO_SIZE:-1G}"
duration="${DURATION:-30}"

run_profile() {
  local name="$1"
  local rw="$2"
  local bs="$3"
  local qd="$4"
  local jobs="$5"

  info "Profile $name: rw=$rw bs=$bs iodepth=$qd numjobs=$jobs"
  fio \
    --name="$name" \
    --filename="$test_file" \
    --rw="$rw" \
    --bs="$bs" \
    --size="$size" \
    --runtime="$duration" \
    --time_based \
    --ioengine=libaio \
    --direct=1 \
    --iodepth="$qd" \
    --numjobs="$jobs" \
    --group_reporting \
    --output-format=json \
    --output="$profile_dir/$name.json"
}

run_profile seq-write write 1M 16 1
run_profile seq-read read 1M 16 1
run_profile rand-write randwrite 4k 32 4
run_profile rand-read randread 4k 32 4

if command -v jq >/dev/null 2>&1; then
  printf 'profile,read_iops,read_MBps,write_iops,write_MBps,error\n' \
    > "$profile_dir/summary.csv"
  for file in "$profile_dir"/*.json; do
    jq -r --arg profile "$(basename "$file" .json)" '
      [
        $profile,
        .jobs[0].read.iops,
        (.jobs[0].read.bw_bytes / 1048576),
        .jobs[0].write.iops,
        (.jobs[0].write.bw_bytes / 1048576),
        .jobs[0].error
      ] | @csv
    ' "$file" >> "$profile_dir/summary.csv"
  done
fi

if [[ "${KEEP_TEST_DATA:-NO}" != "YES" ]]; then
  rm -f -- "$test_file"
fi

show_file "Profile results:" "$profile_dir"
