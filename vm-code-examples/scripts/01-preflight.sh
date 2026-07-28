#!/usr/bin/env bash

set -Eeuo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

out="$ARTIFACT_DIR/preflight-$(timestamp).txt"

{
  printf 'VAST workshop VM preflight\n'
  printf 'UTC: '; date -u
  printf '\nKernel\n'; uname -a
  printf '\nCPU\n'; lscpu
  printf '\nMemory\n'; free -h
  printf '\nBlock devices\n'; lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS
  printf '\nFilesystems\n'; df -hT
  printf '\nAddresses\n'; ip -br address
  printf '\nRoutes\n'; ip route
  printf '\nSocket summary\n'; ss -s

  printf '\nTool availability\n'
  for tool in fio jq vmstat iostat pidstat sar stress-ng tcpdump tc ping \
    nfsstat smbclient mc curl; do
    if command -v "$tool" >/dev/null 2>&1; then
      printf 'OK      %s\n' "$tool"
    else
      printf 'MISSING %s\n' "$tool"
    fi
  done

  if [[ -n "${TARGET_DIR:-}" ]]; then
    printf '\nConfigured target\n'
    printf 'TARGET_DIR=%s\n' "$TARGET_DIR"
    if [[ -d "$TARGET_DIR" ]]; then
      df -hT "$TARGET_DIR"
      findmnt -T "$TARGET_DIR" || true
      [[ -f "$TARGET_DIR/.vast-training-lab-approved" ]] &&
        printf 'Write sentinel: present\n' ||
        printf 'Write sentinel: absent\n'
    else
      printf 'Target directory does not exist.\n'
    fi
  fi
} | tee "$out"

show_file "Saved preflight:" "$out"

