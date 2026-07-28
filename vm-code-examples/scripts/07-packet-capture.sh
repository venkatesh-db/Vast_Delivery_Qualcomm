#!/usr/bin/env bash

set -Eeuo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

require_cmd tcpdump
require_cmd ip
[[ -n "${LAB_IF:-}" ]] || die "Set LAB_IF in lab.env."
[[ -n "${TARGET_HOST:-}" ]] || die "Set TARGET_HOST in lab.env."
ip link show dev "$LAB_IF" >/dev/null 2>&1 || die "Interface not found: $LAB_IF"

duration="${DURATION:-30}"
capture="$ARTIFACT_DIR/capture-$(timestamp).pcap"
filter="${BPF_FILTER:-host $TARGET_HOST and (port 2049 or port 445 or port 9000)}"

info "Capturing on $LAB_IF for $duration seconds"
printf 'Filter: %s\n' "$filter"
printf 'CAUTION: packet captures may contain sensitive data.\n'

sudo timeout "$duration" tcpdump \
  -i "$LAB_IF" \
  -nn \
  -s 0 \
  -w "$capture" \
  "$filter" || status=$?

status="${status:-0}"
if [[ "$status" -ne 0 && "$status" -ne 124 ]]; then
  die "tcpdump exited with status $status"
fi

sudo chown "$(id -u):$(id -g)" "$capture" 2>/dev/null || true
show_file "Packet capture:" "$capture"

