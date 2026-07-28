#!/usr/bin/env bash

set -Eeuo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

for tool in vmstat iostat pidstat sar; do
  require_cmd "$tool"
done

duration="${DURATION:-30}"
[[ "$duration" =~ ^[0-9]+$ ]] || die "DURATION must be an integer number of seconds."
result_dir="$ARTIFACT_DIR/client-metrics-$(timestamp)"
mkdir -p "$result_dir"

date -u +%FT%TZ > "$result_dir/start-utc.txt"
vmstat 1 "$duration" > "$result_dir/vmstat.txt" &
p1=$!
iostat -xz 1 "$duration" > "$result_dir/iostat.txt" &
p2=$!
pidstat -dur 1 "$duration" > "$result_dir/pidstat.txt" &
p3=$!
sar -n DEV 1 "$duration" > "$result_dir/sar-network.txt" &
p4=$!

wait "$p1" "$p2" "$p3" "$p4"
date -u +%FT%TZ > "$result_dir/end-utc.txt"

show_file "Metric files:" "$result_dir"

