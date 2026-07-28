#!/usr/bin/env bash

set -Eeuo pipefail

if [[ "$(id -u)" -eq 0 ]]; then
  SUDO=()
else
  command -v sudo >/dev/null 2>&1 || {
    printf 'sudo is required to install packages.\n' >&2
    exit 1
  }
  SUDO=(sudo)
fi

"${SUDO[@]}" apt-get update
"${SUDO[@]}" apt-get install -y \
  fio jq sysstat stress-ng tcpdump iproute2 iputils-ping \
  ethtool nfs-common smbclient curl tar gzip

printf '\nInstalled workshop tools. MinIO client (mc) is optional and is not installed by this script.\n'

