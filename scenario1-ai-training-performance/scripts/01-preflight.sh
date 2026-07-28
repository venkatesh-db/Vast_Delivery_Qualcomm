#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

validate_lab_dir

printf 'Scenario 1 preflight\n'
printf 'UTC time:        %s\n' "$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
printf 'OS:              %s\n' "$(. /etc/os-release && printf '%s %s' "$NAME" "$VERSION_ID")"
printf 'Kernel:          %s\n' "$(uname -r)"
printf 'Architecture:    %s\n' "$(uname -m)"
printf 'CPU count:       %s\n' "$(nproc)"
printf 'Memory:          %s\n' "$(free -h | awk '/^Mem:/ {print $2}')"
printf 'Lab directory:   %s\n' "$LAB_DIR"
printf 'Filesystem path: %s\n' "$(df -T "$(dirname "$LAB_DIR")" | tail -n 1)"

for tool in bash python3 fio jq vmstat iostat sar; do
  if command -v "$tool" >/dev/null 2>&1; then
    printf 'Tool %-10s OK (%s)\n' "$tool" "$(command -v "$tool")"
  else
    printf 'Tool %-10s MISSING\n' "$tool"
  fi
done

if command -v nvidia-smi >/dev/null 2>&1; then
  printf '\nPhysical GPU telemetry available:\n'
  nvidia-smi --query-gpu=name,driver_version --format=csv,noheader
else
  printf '\nNo nvidia-smi detected. The lab will use the labelled simulated GPU metric.\n'
fi

printf '\nPreflight completed.\n'
