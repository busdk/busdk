#!/bin/sh
set -eu

# Proves the image-backed SSH-Docker path with the real Codex App Server
# backend on the remote host. This is the no-edit readiness smoke before
# trusting remote workers with writable task branches.

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

PROMPT=${BUS_SSH_DOCKER_CODEX_SMOKE_PROMPT:-SSH-Docker real Codex smoke: do not edit files. Inspect /workspace/bus-dev/go.mod, report the module path in one sentence, and mark the task done with evidence.}
TIMEOUT=${BUS_SSH_DOCKER_CODEX_SMOKE_WAIT_TIMEOUT:-15m}

BUS_SSH_DOCKER_SMOKE_AGENT_BACKEND=codex-appserver \
BUS_SSH_DOCKER_SMOKE_WORKTREE=false \
BUS_SSH_DOCKER_SMOKE_COMMIT=false \
BUS_SSH_DOCKER_SMOKE_WAIT_TIMEOUT="$TIMEOUT" \
BUS_SSH_DOCKER_SMOKE_PROMPT="$PROMPT" \
"$ROOT/scripts/test-ssh-docker-image-smoke.sh"
