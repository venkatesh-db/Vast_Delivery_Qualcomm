#!/usr/bin/env bash

set -Eeuo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

require_controlled_lab
require_cmd systemctl
service="nfs-kernel-server"
result_dir="$ARTIFACT_DIR/nfs-recovery-$(timestamp)"
mkdir -p "$result_dir"
stopped="NO"

restore_service() {
  if [[ "$stopped" == "YES" ]]; then
    sudo systemctl start "$service" || true
    stopped="NO"
  fi
}
trap restore_service EXIT INT TERM

info "Preserving local Ubuntu NFS service state"
date -u > "$result_dir/date-before.txt"
systemctl --no-pager --full status "$service" > "$result_dir/status-before.txt" || true
journalctl -u "$service" --since '-10 min' --utc > "$result_dir/journal-before.txt" || true
ss -ltnp > "$result_dir/listeners-before.txt" || true

info "Stopping only the local Ubuntu NFS service"
sudo systemctl stop "$service"
stopped="YES"
systemctl is-active "$service" || true
ss -ltnp | grep ':2049' || true
if [[ -n "${NFS_TEST_PATH:-}" ]]; then
  timeout 10 stat "$NFS_TEST_PATH" > "$result_dir/access-during-stop.txt" 2>&1 || true
fi

info "Restoring service"
sudo systemctl start "$service"
stopped="NO"
systemctl is-active "$service"
ss -ltnp | grep ':2049' || true
if [[ -n "${NFS_TEST_PATH:-}" ]]; then
  timeout 10 stat "$NFS_TEST_PATH" > "$result_dir/access-after-restore.txt" 2>&1
fi
date -u > "$result_dir/date-after.txt"
systemctl --no-pager --full status "$service" > "$result_dir/status-after.txt" || true

show_file "Recovery evidence:" "$result_dir"
