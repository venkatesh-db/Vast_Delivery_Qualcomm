#!/usr/bin/env bash

set -Eeuo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

run_id="$(timestamp)"
bundle_dir="$ARTIFACT_DIR/evidence-$run_id"
archive="$ARTIFACT_DIR/evidence-$run_id.tar.gz"
mkdir -p "$bundle_dir"

date -u > "$bundle_dir/date-utc.txt"
uname -a > "$bundle_dir/uname.txt"
free -h > "$bundle_dir/free.txt"
df -hT > "$bundle_dir/df.txt"
ip -br address > "$bundle_dir/ip-address.txt"
ip route > "$bundle_dir/ip-route.txt"
ip -s link > "$bundle_dir/ip-link.txt"
ss -s > "$bundle_dir/ss-summary.txt"
ss -tanp > "$bundle_dir/ss-tcp.txt" 2>&1 || true
vmstat 1 5 > "$bundle_dir/vmstat.txt"
iostat -xz 1 5 > "$bundle_dir/iostat.txt"
journalctl --since '-15 min' --utc > "$bundle_dir/journal.txt" 2>&1 || true
dmesg --ctime | tail -n 300 > "$bundle_dir/dmesg.txt" 2>&1 || true

if [[ -n "${TARGET_DIR:-}" && -d "$TARGET_DIR" ]]; then
  findmnt -T "$TARGET_DIR" > "$bundle_dir/findmnt-target.txt" 2>&1 || true
  stat "$TARGET_DIR" > "$bundle_dir/stat-target.txt" 2>&1 || true
fi

tar -czf "$archive" -C "$ARTIFACT_DIR" "$(basename "$bundle_dir")"
sha256sum "$archive" | tee "$archive.sha256"

printf '\nReview the archive for secrets, credentials, personal data, internal addresses,\n'
printf 'and capture scope before sharing it.\n'
show_file "Evidence directory:" "$bundle_dir"
show_file "Evidence archive:" "$archive"

