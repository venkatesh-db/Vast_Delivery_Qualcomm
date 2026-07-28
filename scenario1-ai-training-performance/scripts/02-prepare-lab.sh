#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

require_cmd fio
validate_lab_dir
require_confirmation

mkdir -p "$LAB_DIR" "$ARTIFACT_ROOT"
touch "$SENTINEL"

info "Preparing disposable dataset: $DATASET_FILE ($DATASET_SIZE)"
fio \
  --name=prepare-dataset \
  --filename="$DATASET_FILE" \
  --rw=write \
  --bs=1M \
  --size="$DATASET_SIZE" \
  --ioengine=libaio \
  --iodepth=8 \
  --direct="$FIO_DIRECT" \
  --end_fsync=1 \
  --group_reporting \
  --output="$LAB_DIR/prepare-dataset.txt"

info "Preparing disposable contention file: $CONTENTION_FILE ($CONTENTION_FILE_SIZE)"
fio \
  --name=prepare-contention \
  --filename="$CONTENTION_FILE" \
  --rw=write \
  --bs=1M \
  --size="$CONTENTION_FILE_SIZE" \
  --ioengine=libaio \
  --iodepth=8 \
  --direct="$FIO_DIRECT" \
  --end_fsync=1 \
  --group_reporting \
  --output="$LAB_DIR/prepare-contention.txt"

reset_current_run
info "Prepared run $RUN_ID"
ls -lh "$DATASET_FILE" "$CONTENTION_FILE"
