#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

require_cmd python3
validate_lab_dir
require_confirmation

if [[ -d "$LAB_DIR" && ! -f "$SENTINEL" ]] &&
  [[ -n "$(find "$LAB_DIR" -mindepth 1 -maxdepth 1 -print -quit)" ]]; then
  die "LAB_DIR is non-empty and has no scenario sentinel: $LAB_DIR"
fi

mkdir -p "$LAB_DIR"
touch "$SENTINEL"

python3 "$PROJECT_DIR/src/prepare_lab.py" \
  --lab-dir "$LAB_DIR" \
  --shard-size "$SHARD_SIZE_BYTES" \
  --initial-metadata-files "$INITIAL_METADATA_FILES" \
  --metadata-file-bytes "$METADATA_FILE_BYTES"

reset_current_run
capture_capacity before

info "Prepared run $RUN_ID"
info "Canonical path: $CURRENT_SHARD"
info "Stale path:     $LEGACY_SHARD"
