#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
source "$PROJECT_DIR/scripts/lib/common.sh"

validate_lab_dir
[[ -f "$SENTINEL" ]] || die "Sentinel is absent; refusing to remove $LAB_DIR"

printf 'Cleanup will remove only this generated lab directory:\n  %s\n' "$LAB_DIR"

if [[ "${CONFIRM_CLEANUP:-NO}" != "YES" ]]; then
  read -r -p 'Type DELETE to continue: ' answer
  [[ "$answer" == "DELETE" ]] || die "Cleanup cancelled."
fi

find "$LAB_DIR" -depth -delete
printf '[INFO] Removed %s\n' "$LAB_DIR"
