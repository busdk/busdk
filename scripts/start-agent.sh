#!/bin/bash
cd "$(dirname "${BASH_SOURCE[0]}")/.."
set -euo pipefail
#set -x

TOPIC="${1:-}"
shift || true

if [ -z "$TOPIC" ]; then
  echo "Usage: ./scripts/start-agent.sh <topic> [codex args...]" >&2
  exit 1
fi

exec ./scripts/start-shell.sh "$TOPIC" codex "$@"
