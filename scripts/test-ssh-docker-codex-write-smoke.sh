#!/bin/sh
set -eu

# Proves the image-backed SSH-Docker path can run a real Codex App Server task
# in an isolated writable worktree, create a bridge commit, and promote it back
# to the remote module checkout. The default target is a disposable bus-dev
# branch with one small smoke fixture file.

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

STAMP=$(date +%Y%m%d%H%M%S)
BRANCH=${BUS_SSH_DOCKER_CODEX_WRITE_SMOKE_BRANCH:-codex/ssh-docker-write-smoke-${STAMP}}
BASE_BRANCH=${BUS_SSH_DOCKER_CODEX_WRITE_SMOKE_BASE_BRANCH:-}
SMOKE_FILE=${BUS_SSH_DOCKER_CODEX_WRITE_SMOKE_FILE:-testdata/ssh-docker-write-smoke.txt}
TIMEOUT=${BUS_SSH_DOCKER_CODEX_WRITE_SMOKE_WAIT_TIMEOUT:-20m}
COMMIT_MESSAGE=${BUS_SSH_DOCKER_CODEX_WRITE_SMOKE_COMMIT_MESSAGE:-test: ssh-docker writable smoke}
POST_COMMAND_JSON=${BUS_SSH_DOCKER_CODEX_WRITE_SMOKE_POST_COMMAND_JSON:-'["sh","-lc","test -s testdata/ssh-docker-write-smoke.txt"]'}

PROMPT=${BUS_SSH_DOCKER_CODEX_WRITE_SMOKE_PROMPT:-"SSH-Docker writable Codex smoke: create or update only ${SMOKE_FILE}. Create parent directories if needed. File content must include exactly these facts on separate lines: ssh-docker writable smoke; branch: ${BRANCH}. Do not edit any other file, do not run broad tests, then mark the task done with the changed path."}

BUS_SSH_DOCKER_SMOKE_AGENT_BACKEND=codex-appserver \
BUS_SSH_DOCKER_SMOKE_WORKTREE=true \
BUS_SSH_DOCKER_SMOKE_COMMIT=true \
BUS_SSH_DOCKER_SMOKE_NEW_BRANCH="$BRANCH" \
BUS_SSH_DOCKER_SMOKE_BASE_BRANCH="$BASE_BRANCH" \
BUS_SSH_DOCKER_SMOKE_WRITE_SCOPE="$SMOKE_FILE" \
BUS_SSH_DOCKER_SMOKE_COMMIT_MESSAGE="$COMMIT_MESSAGE" \
BUS_SSH_DOCKER_SMOKE_POST_COMMAND_JSON="$POST_COMMAND_JSON" \
BUS_SSH_DOCKER_SMOKE_WAIT_TIMEOUT="$TIMEOUT" \
BUS_SSH_DOCKER_SMOKE_PROMPT="$PROMPT" \
"$ROOT/scripts/test-ssh-docker-image-smoke.sh"
