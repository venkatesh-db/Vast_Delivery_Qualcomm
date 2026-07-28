#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ ! -f "$PROJECT_DIR/config.env" ]]; then
  cp "$PROJECT_DIR/config.env.example" "$PROJECT_DIR/config.env"
  printf '[INFO] Created config.env from the safe classroom defaults.\n'
fi

"$PROJECT_DIR/scripts/01-preflight.sh"
"$PROJECT_DIR/scripts/02-prepare-lab.sh"
"$PROJECT_DIR/scripts/03-run-baseline.sh"
"$PROJECT_DIR/scripts/04-run-incident.sh"
"$PROJECT_DIR/scripts/05-recover-and-retest.sh"
"$PROJECT_DIR/scripts/06-build-report.sh"
