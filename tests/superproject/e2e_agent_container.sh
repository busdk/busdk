#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT_DIR"

if ! command -v docker >/dev/null 2>&1; then
  printf 'SKIP superproject agent container e2e: docker not installed\n'
  exit 0
fi

TOPIC="agent-e2e-$$"
trap './scripts/remove-worktree.sh "$TOPIC" >/dev/null 2>&1 || true' EXIT

GO_VERSION_OUTPUT="$(./scripts/start-shell.sh "$TOPIC" go version)"
printf '%s\n' "$GO_VERSION_OUTPUT" | grep -E '^go version go1\.[0-9]+\.[0-9]+ '

TOOLS_OUTPUT="$(./scripts/start-shell.sh "$TOPIC" bash -lc 'command -v gopls goimports govulncheck dlv staticcheck codex')"
printf '%s\n' "$TOOLS_OUTPUT" | grep -Fx '/usr/local/bin/gopls'
printf '%s\n' "$TOOLS_OUTPUT" | grep -Fx '/usr/local/bin/goimports'
printf '%s\n' "$TOOLS_OUTPUT" | grep -Fx '/usr/local/bin/govulncheck'
printf '%s\n' "$TOOLS_OUTPUT" | grep -Fx '/usr/local/bin/dlv'
printf '%s\n' "$TOOLS_OUTPUT" | grep -Fx '/usr/local/bin/staticcheck'
printf '%s\n' "$TOOLS_OUTPUT" | grep -Fx '/usr/local/bin/codex'

CODEX_VERSION_OUTPUT="$(./scripts/start-agent.sh "$TOPIC" --version)"
printf '%s\n' "$CODEX_VERSION_OUTPUT" | grep -i 'codex'

printf 'superproject agent container e2e OK\n'
