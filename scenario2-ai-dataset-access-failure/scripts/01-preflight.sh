#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

validate_lab_dir

printf 'Scenario 2 preflight\n'
printf 'UTC time:        %s\n' "$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
printf 'OS:              %s\n' "$(. /etc/os-release && printf '%s %s' "$NAME" "$VERSION_ID")"
printf 'Kernel:          %s\n' "$(uname -r)"
printf 'Architecture:    %s\n' "$(uname -m)"
printf 'CPU count:       %s\n' "$(nproc)"
printf 'Memory:          %s\n' "$(free -h | awk '/^Mem:/ {print $2}')"
printf 'Lab directory:   %s\n' "$LAB_DIR"
printf 'Filesystem path: %s\n' "$(df -T "$(dirname "$LAB_DIR")" | tail -n 1)"

for tool in bash python3 jq vmstat iostat find stat du; do
  if command -v "$tool" >/dev/null 2>&1; then
    printf 'Tool %-10s OK (%s)\n' "$tool" "$(command -v "$tool")"
  else
    printf 'Tool %-10s MISSING\n' "$tool"
  fi
done

printf '\nScenario identity/path matrix:\n'
printf '  %-12s UID %-5s -> %s\n' "$CURRENT_CLIENT_NAME" "$CURRENT_CLIENT_UID" "$CURRENT_SHARD"
printf '  %-12s UID %-5s -> %s\n' "$STALE_CLIENT_NAME" "$STALE_CLIENT_UID" "$LEGACY_SHARD"
printf '\nPreflight completed.\n'
