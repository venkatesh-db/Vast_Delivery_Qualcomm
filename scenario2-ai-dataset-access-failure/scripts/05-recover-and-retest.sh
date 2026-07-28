#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

require_cmd python3
require_prepared
ensure_current_run

if pgrep -f 'publisher.py.*legacy-shard' >/dev/null 2>&1; then
  die "Publisher is still running. Preserve evidence and stop it before recovery."
fi

preserved_legacy="$DATASETS_DIR/v7-stale-preserved-$RUN_ID"
[[ ! -e "$preserved_legacy" ]] || die "Recovery target already exists: $preserved_legacy"

info "Preserving the stale legacy namespace"
mv "$LEGACY_DIR" "$preserved_legacy"

info "Correcting v7 mapping to the canonical current dataset"
ln -s current "$LEGACY_DIR"

start_monitors recovered
trap stop_monitors EXIT INT TERM
run_two_clients recovered "$RECOVERY_DURATION_SECONDS"
stop_monitors
trap - EXIT INT TERM

info "Recovery evidence written to $RUN_DIR"
