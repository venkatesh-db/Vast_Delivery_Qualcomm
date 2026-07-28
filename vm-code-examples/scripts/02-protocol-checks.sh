#!/usr/bin/env bash

set -Eeuo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

out="$ARTIFACT_DIR/protocol-checks-$(timestamp).txt"

{
  printf 'Protocol validation — %s\n' "$(date -u +%FT%TZ)"

  if [[ -n "${TARGET_HOST:-}" ]]; then
    printf '\nConnectivity to %s\n' "$TARGET_HOST"
    getent hosts "$TARGET_HOST" || true
    ip route get "$TARGET_HOST" || true
    ping -c 3 -W 2 "$TARGET_HOST" || true
  fi

  if [[ -n "${NFS_TEST_PATH:-}" ]]; then
    printf '\nNFS path: %s\n' "$NFS_TEST_PATH"
    findmnt -T "$NFS_TEST_PATH" || true
    nfsstat -m || true
    namei -l "$NFS_TEST_PATH" || true
    stat "$NFS_TEST_PATH"
  fi

  if [[ -n "${SMB_SERVER:-}" ]]; then
    printf '\nSMB server: %s\n' "$SMB_SERVER"
    if [[ -n "${SMB_AUTH_FILE:-}" ]]; then
      smbclient -L "//$SMB_SERVER" -A "$SMB_AUTH_FILE"
    else
      printf 'No SMB_AUTH_FILE set; attempting guest listing.\n'
      smbclient -L "//$SMB_SERVER" -N || true
    fi
    if [[ -n "${SMB_SHARE:-}" ]]; then
      printf 'Configured share: //%s/%s\n' "$SMB_SERVER" "$SMB_SHARE"
    fi
  fi

  if [[ -n "${S3_OBJECT:-}" ]]; then
    if command -v mc >/dev/null 2>&1; then
      printf '\nS3 object: %s\n' "$S3_OBJECT"
      mc stat "$S3_OBJECT"
    else
      printf '\nS3_OBJECT is set, but mc is not installed.\n'
    fi
  fi

  if [[ -n "${MINIO_HEALTH_URL:-}" ]]; then
    printf '\nMinIO health URL: %s\n' "$MINIO_HEALTH_URL"
    curl --fail --silent --show-error --max-time 5 "$MINIO_HEALTH_URL"
    printf '\n'
  fi
} | tee "$out"

show_file "Saved checks:" "$out"

