#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

require_cmd python3
require_prepared
ensure_current_run

info "Running baseline reads for both client path mappings"
start_monitors baseline
trap stop_monitors EXIT INT TERM
run_two_clients baseline "$BASELINE_DURATION_SECONDS"
stop_monitors
trap - EXIT INT TERM
info "Baseline evidence written to $RUN_DIR"
