#!/usr/bin/env bash

set -Eeuo pipefail

COMMON_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
PROJECT_DIR="$(cd -- "$COMMON_DIR/../.." >/dev/null 2>&1 && pwd)"
ENV_FILE="${VAST_TRAINING_ENV:-$PROJECT_DIR/lab.env}"

if [[ -f "$ENV_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$ENV_FILE"
fi

ARTIFACT_DIR="${ARTIFACT_DIR:-$PROJECT_DIR/artifacts}"
mkdir -p "$ARTIFACT_DIR"

timestamp() {
  date -u +%Y%m%dT%H%M%SZ
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

info() {
  printf '\n[%s] %s\n' "$(date -u +%FT%TZ)" "$*"
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"
}

require_controlled_lab() {
  [[ "${CONFIRM_CONTROLLED_LAB:-NO}" == "YES" ]] ||
    die "Set CONFIRM_CONTROLLED_LAB=YES only on an isolated training VM."
}

require_safe_write_target() {
  local target="${TARGET_DIR:-}"
  [[ "${ALLOW_WRITE_TESTS:-NO}" == "YES" ]] ||
    die "Set ALLOW_WRITE_TESTS=YES after approving the disposable target."
  [[ -n "$target" && -d "$target" ]] || die "TARGET_DIR must be an existing directory."
  case "$target" in
    /|/bin|/boot|/dev|/etc|/home|/lib|/lib64|/opt|/proc|/root|/run|/sbin|/srv|/sys|/usr|/var)
      die "Refusing unsafe TARGET_DIR: $target"
      ;;
  esac
  [[ -f "$target/.vast-training-lab-approved" ]] ||
    die "Missing sentinel: $target/.vast-training-lab-approved"
  [[ -w "$target" ]] || die "TARGET_DIR is not writable: $target"
}

show_file() {
  local label="$1"
  local file="$2"
  printf '%-24s %s\n' "$label" "$file"
}

