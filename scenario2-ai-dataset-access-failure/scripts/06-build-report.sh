#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

require_cmd python3
require_prepared
ensure_current_run

python3 "$PROJECT_DIR/src/build_report.py" --run-dir "$RUN_DIR"

printf '\n'
cat "$RUN_DIR/scenario-summary.md"
printf '\n[INFO] Full report: %s\n' "$RUN_DIR/scenario-summary.md"
