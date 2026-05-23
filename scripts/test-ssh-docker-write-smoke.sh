#!/bin/sh
set -eu

# Proves the SSH-Docker image-backed worker substrate can write through an
# isolated task worktree, create a bridge commit, and promote it. This uses a
# deterministic container command so worker Git/promotion can be debugged
# independently from live Codex/model authentication.

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

STAMP=$(date +%Y%m%d%H%M%S)
BRANCH=${BUS_SSH_DOCKER_WRITE_SMOKE_BRANCH:-codex/ssh-docker-substrate-smoke-${STAMP}}
BASE_BRANCH=${BUS_SSH_DOCKER_WRITE_SMOKE_BASE_BRANCH:-}
SMOKE_FILE=${BUS_SSH_DOCKER_WRITE_SMOKE_FILE:-testdata/ssh-docker-write-smoke.txt}
TIMEOUT=${BUS_SSH_DOCKER_WRITE_SMOKE_WAIT_TIMEOUT:-10m}
COMMIT_MESSAGE=${BUS_SSH_DOCKER_WRITE_SMOKE_COMMIT_MESSAGE:-test: ssh-docker substrate write smoke}
COMMAND_JSON=${BUS_SSH_DOCKER_WRITE_SMOKE_COMMAND_JSON:-'["sh","-lc","mkdir -p testdata && { echo ssh-docker writable smoke; echo branch: substrate; } > testdata/ssh-docker-write-smoke.txt"]'}
POST_COMMAND_JSON=${BUS_SSH_DOCKER_WRITE_SMOKE_POST_COMMAND_JSON:-'["sh","-lc","grep -q ssh-docker testdata/ssh-docker-write-smoke.txt"]'}
PROMPT=${BUS_SSH_DOCKER_WRITE_SMOKE_PROMPT:-"SSH-Docker substrate write smoke: run the configured deterministic command, then preserve the changed ${SMOKE_FILE} through the bridge commit/promotion path."}

BUS_SSH_DOCKER_SMOKE_AGENT_BACKEND=container \
BUS_SSH_DOCKER_SMOKE_WORKTREE=true \
BUS_SSH_DOCKER_SMOKE_COMMIT=true \
BUS_SSH_DOCKER_SMOKE_NEW_BRANCH="$BRANCH" \
BUS_SSH_DOCKER_SMOKE_BASE_BRANCH="$BASE_BRANCH" \
BUS_SSH_DOCKER_SMOKE_WRITE_SCOPE="$SMOKE_FILE" \
BUS_SSH_DOCKER_SMOKE_COMMAND_JSON="$COMMAND_JSON" \
BUS_SSH_DOCKER_SMOKE_POST_COMMAND_JSON="$POST_COMMAND_JSON" \
BUS_SSH_DOCKER_SMOKE_COMMIT_MESSAGE="$COMMIT_MESSAGE" \
BUS_SSH_DOCKER_SMOKE_WAIT_TIMEOUT="$TIMEOUT" \
BUS_SSH_DOCKER_SMOKE_PROMPT="$PROMPT" \
"$ROOT/scripts/test-ssh-docker-image-smoke.sh"
