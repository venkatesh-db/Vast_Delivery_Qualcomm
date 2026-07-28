#!/usr/bin/env bash

set -Eeuo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

require_controlled_lab
require_cmd tc
require_cmd ip
[[ -n "${LAB_IF:-}" ]] || die "Set LAB_IF in lab.env."
ip link show dev "$LAB_IF" >/dev/null 2>&1 || die "Interface not found: $LAB_IF"

action="${1:-demo}"
applied="NO"

rollback() {
  if [[ "$applied" == "YES" ]] &&
    tc qdisc show dev "$LAB_IF" | grep -q ' netem '; then
    sudo tc qdisc del dev "$LAB_IF" root
    applied="NO"
    info "netem removed from $LAB_IF"
  fi
}
trap rollback EXIT INT TERM

if [[ "$action" == "rollback" ]]; then
  if tc qdisc show dev "$LAB_IF" | grep -q ' netem '; then
    sudo tc qdisc del dev "$LAB_IF" root
    info "Removed netem from $LAB_IF"
  else
    info "No netem qdisc is active on $LAB_IF"
  fi
  exit 0
fi

[[ "$action" == "demo" ]] || die "Usage: $0 demo|rollback"
[[ -n "${TARGET_HOST:-}" ]] || die "Set TARGET_HOST in lab.env."

default_if="$(ip route show default | awk 'NR==1 {for (i=1; i<=NF; i++) if ($i=="dev") print $(i+1)}')"
if [[ "$LAB_IF" == "$default_if" &&
  "${ALLOW_DEFAULT_ROUTE_NETEM:-NO}" != "YES" ]]; then
  die "Refusing default-route interface $LAB_IF. Use a secondary interface or explicitly approve it."
fi

if tc qdisc show dev "$LAB_IF" | grep -Eq ' netem | tbf | htb '; then
  die "A managed qdisc already exists on $LAB_IF; refusing to replace it."
fi

info "Baseline RTT"
ping -c 5 -W 2 "$TARGET_HOST" || true

info "Applying 20 ms delay and 0.5% loss for ${DURATION:-30} seconds"
sudo tc qdisc add dev "$LAB_IF" root netem delay 20ms loss 0.5%
applied="YES"
tc qdisc show dev "$LAB_IF"
ping -c 10 -W 2 "$TARGET_HOST" || true
sleep "${DURATION:-30}"

rollback
info "Post-rollback verification"
tc qdisc show dev "$LAB_IF"
ping -c 5 -W 2 "$TARGET_HOST" || true

