#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

require_cmd python3

if pgrep -f 'fio.*competing-small-block' >/dev/null 2>&1; then
  die "A competing-small-block fio process is still running. Stop it before recovery."
fi

run_training_phase recovered "$BASELINE_LOADER_DELAY_MS"
