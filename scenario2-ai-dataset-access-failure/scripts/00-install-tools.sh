#!/usr/bin/env bash
set -Eeuo pipefail

if [[ "$(id -u)" -eq 0 ]]; then
  SUDO=()
else
  command -v sudo >/dev/null 2>&1 || {
    printf '[ERROR] sudo is required for package installation.\n' >&2
    exit 1
  }
  SUDO=(sudo)
fi

"${SUDO[@]}" apt-get update
"${SUDO[@]}" env DEBIAN_FRONTEND=noninteractive apt-get install -y \
  python3 jq sysstat procps util-linux findutils

printf '\nInstalled versions:\n'
python3 --version
jq --version
