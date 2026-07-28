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
  fio jq sysstat python3 procps util-linux pciutils

printf '\nInstalled versions:\n'
fio --version
python3 --version
jq --version
