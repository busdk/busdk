#!/bin/sh
set -eu

# Proves the Bus-managed SSH-Docker image path against a real SSH host.
# Required remote-side shape: SSH access, Docker, a reachable bus-events
# container on the selected Docker network, and the worker image installed. Set
# BUS_SSH_DOCKER_SMOKE_INSTALL_IMAGE=true to install the selected local image
# first through scripts/install-ssh-docker-worker-image.sh.

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

REMOTE_ID=${BUS_SSH_DOCKER_SMOKE_REMOTE_ID:-dev-hg}
SMOKE_DIR=${BUS_SSH_DOCKER_SMOKE_DIR:-/private/tmp/bus-ssh-docker-smoke}
TUNNEL_PORT=${BUS_SSH_DOCKER_SMOKE_TUNNEL_PORT:-18086}
SSH_TARGET=${BUS_SSH_DOCKER_SMOKE_SSH_TARGET:-coding-agent@dev.hg.fi}
SSH_HOST=${BUS_SSH_DOCKER_SMOKE_SSH_HOST:-dev.hg.fi}
SSH_USER=${BUS_SSH_DOCKER_SMOKE_SSH_USER:-coding-agent}
SSH_PORT=${BUS_SSH_DOCKER_SMOKE_SSH_PORT:-22}
REMOTE_WORKDIR=${BUS_SSH_DOCKER_SMOKE_REMOTE_WORKDIR:-/home/coding-agent/coding-agent/git/busdk/busdk}
COMPOSE_FILE=${BUS_SSH_DOCKER_SMOKE_COMPOSE_FILE:-compose.dev-task-docker.yaml}
REMOTE_EVENTS_HOST=${BUS_SSH_DOCKER_SMOKE_REMOTE_EVENTS_HOST:-127.0.0.1}
REMOTE_EVENTS_PORT=${BUS_SSH_DOCKER_SMOKE_REMOTE_EVENTS_PORT:-8081}
WORKER_EVENTS_URL=${BUS_SSH_DOCKER_SMOKE_WORKER_EVENTS_URL:-http://bus-events:8081}
WORKER_IMAGE=${BUS_SSH_DOCKER_SMOKE_IMAGE:-bus-integration-dev-task:local-image-smoke}
WORKER_NETWORK=${BUS_SSH_DOCKER_SMOKE_NETWORK:-busdk_default}
WORKER_CODEX_HOME=${BUS_SSH_DOCKER_SMOKE_CODEX_HOME:-/home/coding-agent/coding-agent/.codex}
WORKER_AGENT_BACKEND=${BUS_SSH_DOCKER_SMOKE_AGENT_BACKEND:-self-test}
WORKER_CONTAINER_IMAGE=${BUS_SSH_DOCKER_SMOKE_CONTAINER_IMAGE:-}
WORKER_CONTAINER_PROFILE=${BUS_SSH_DOCKER_SMOKE_CONTAINER_PROFILE:-}
WORKER_COMMAND_JSON=${BUS_SSH_DOCKER_SMOKE_COMMAND_JSON:-}
WORKER_PRE_COMMAND_JSON=${BUS_SSH_DOCKER_SMOKE_PRE_COMMAND_JSON:-}
WORKER_POST_COMMAND_JSON=${BUS_SSH_DOCKER_SMOKE_POST_COMMAND_JSON:-}
WORKER_WORKTREE=${BUS_SSH_DOCKER_SMOKE_WORKTREE:-}
WORKER_COMMIT=${BUS_SSH_DOCKER_SMOKE_COMMIT:-false}
WORKER_COMMIT_MESSAGE=${BUS_SSH_DOCKER_SMOKE_COMMIT_MESSAGE:-}
INSTALL_IMAGE=${BUS_SSH_DOCKER_SMOKE_INSTALL_IMAGE:-false}
BUILD_IMAGE=${BUS_SSH_DOCKER_SMOKE_BUILD_IMAGE:-false}
WAIT_TIMEOUT=${BUS_SSH_DOCKER_SMOKE_WAIT_TIMEOUT:-8m}
RECIPIENT=${BUS_SSH_DOCKER_SMOKE_RECIPIENT:-bus-dev}
WRITE_SCOPE=${BUS_SSH_DOCKER_SMOKE_WRITE_SCOPE:-}
BRANCH=${BUS_SSH_DOCKER_SMOKE_BRANCH:-}
NEW_BRANCH=${BUS_SSH_DOCKER_SMOKE_NEW_BRANCH:-}
BASE_BRANCH=${BUS_SSH_DOCKER_SMOKE_BASE_BRANCH:-}
PROMPT=${BUS_SSH_DOCKER_SMOKE_PROMPT:-SSH-Docker image smoke: do not edit files; verify the worker can claim this task, send a short progress message, and mark it done.}
LOCAL_SECRET=${BUS_AUTH_HS256_SECRET:-not-a-secret-local-development-hs256-key}
ACCOUNT_ID=${BUS_LOCAL_ACCOUNT_ID:-00000000-0000-4000-8000-000000000001}
CONTROLLER_URL="http://127.0.0.1:${TUNNEL_PORT}"
RUNNER_LOG=${BUS_SSH_DOCKER_SMOKE_RUNNER_LOG:-/private/tmp/bus-ssh-runner-smoke.log}

case "$BUILD_IMAGE" in
	true|1|yes|on)
		BUS_SSH_DOCKER_BUILD_IMAGE="$WORKER_IMAGE" "$ROOT/scripts/build-ssh-docker-worker-image.sh" >/dev/null
		;;
	false|0|no|off|'')
		;;
	*)
		printf 'invalid BUS_SSH_DOCKER_SMOKE_BUILD_IMAGE=%s\n' "$BUILD_IMAGE" >&2
		exit 2
		;;
esac

case "$INSTALL_IMAGE" in
	true|1|yes|on)
		BUS_SSH_DOCKER_INSTALL_REMOTE_ID="$REMOTE_ID" \
		BUS_SSH_DOCKER_INSTALL_SSH_TARGET="$SSH_TARGET" \
		BUS_SSH_DOCKER_INSTALL_LOCAL_TAG="$WORKER_IMAGE" \
		BUS_SSH_DOCKER_INSTALL_IMAGE="$WORKER_IMAGE" \
		"$ROOT/scripts/install-ssh-docker-worker-image.sh" >/dev/null
		;;
	false|0|no|off|'')
		;;
	*)
		printf 'invalid BUS_SSH_DOCKER_SMOKE_INSTALL_IMAGE=%s\n' "$INSTALL_IMAGE" >&2
		exit 2
		;;
esac

mkdir -p "$SMOKE_DIR"
if [ ! -d "$SMOKE_DIR/.git" ]; then
	git -C "$SMOKE_DIR" init >/dev/null
fi

"$ROOT/bus-remote/bin/bus-remote" -C "$SMOKE_DIR" --format json add \
	--id "$REMOTE_ID" \
	--kind ssh-docker \
	--ssh-host "$SSH_HOST" \
	--ssh-user "$SSH_USER" \
	--ssh-port "$SSH_PORT" \
	--remote-workdir "$REMOTE_WORKDIR" \
	--compose-file "$COMPOSE_FILE" \
	--controller-events-url "$CONTROLLER_URL" \
	--worker-events-url "$WORKER_EVENTS_URL" \
	--description "SSH-Docker smoke host; controller uses local SSH tunnel to remote Events, worker containers use remote Docker networking" >/dev/null

TOKEN=$(BUS_AUTH_HS256_SECRET="$LOCAL_SECRET" "$ROOT/bus-operator-token/bin/bus-operator-token" \
	--format token issue --local \
	--subject "$ACCOUNT_ID" \
	--audience ai.hg.fi/api \
	--scope 'events:send events:listen dev:task:send dev:task:read dev:task:reply dev:task:claim ssh:run container:read container:run container:delete notes.write notes.read notes.search notes.import.memo_file notes.import.task_summary notes.import.session_summary' \
	--ttl 2h)

runner=0
ssh -A -N -o ExitOnForwardFailure=yes -L "127.0.0.1:${TUNNEL_PORT}:${REMOTE_EVENTS_HOST}:${REMOTE_EVENTS_PORT}" "$SSH_TARGET" &
tunnel=$!
cleanup() {
	kill "$runner" "$tunnel" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

if command -v curl >/dev/null 2>&1; then
	i=0
	while [ "$i" -lt 20 ]; do
		if curl -s -o /dev/null --max-time 1 "$CONTROLLER_URL/"; then
			break
		fi
		i=$((i + 1))
		sleep 1
	done
fi

BUS_API_TOKEN="$TOKEN" BUS_EVENTS_LISTENER_RETRY=true "$ROOT/bus-integration-ssh-runner/bin/bus-integration-ssh-runner" \
	--events-url "$CONTROLLER_URL" >"$RUNNER_LOG" 2>&1 &
runner=$!

sleep 2

set -- "$ROOT/bus-dev/bin/bus-dev" -C "$SMOKE_DIR" work --remote "$REMOTE_ID" start
if [ -n "$BRANCH" ]; then
	set -- "$@" --branch "$BRANCH"
fi
if [ -n "$NEW_BRANCH" ]; then
	set -- "$@" --new-branch "$NEW_BRANCH"
fi
if [ -n "$BASE_BRANCH" ]; then
	set -- "$@" --base-branch "$BASE_BRANCH"
fi
if [ -n "$WRITE_SCOPE" ]; then
	set -- "$@" --write-scope "$WRITE_SCOPE"
fi
set -- "$@" "@${RECIPIENT}" "$PROMPT"
BUS_API_TOKEN="$TOKEN" \
BUS_DEV_SSH_DOCKER_LAUNCH_MODE=image \
BUS_DEV_SSH_DOCKER_WORKER_IMAGE="$WORKER_IMAGE" \
BUS_DEV_SSH_DOCKER_WORKER_NETWORK="$WORKER_NETWORK" \
BUS_DEV_SSH_DOCKER_WORKER_CODEX_HOME="$WORKER_CODEX_HOME" \
BUS_DEV_TASK_AGENT_BACKEND="$WORKER_AGENT_BACKEND" \
BUS_DEV_TASK_CONTAINER_IMAGE="$WORKER_CONTAINER_IMAGE" \
BUS_DEV_TASK_CONTAINER_PROFILE="$WORKER_CONTAINER_PROFILE" \
BUS_DEV_TASK_COMMAND_JSON="$WORKER_COMMAND_JSON" \
BUS_DEV_TASK_PRE_COMMAND_JSON="$WORKER_PRE_COMMAND_JSON" \
BUS_DEV_TASK_POST_COMMAND_JSON="$WORKER_POST_COMMAND_JSON" \
BUS_DEV_TASK_WORKTREE="$WORKER_WORKTREE" \
BUS_DEV_TASK_COMMIT="$WORKER_COMMIT" \
BUS_DEV_TASK_COMMIT_MESSAGE="$WORKER_COMMIT_MESSAGE" \
"$@"

BUS_API_TOKEN="$TOKEN" "$ROOT/bus-dev/bin/bus-dev" -C "$SMOKE_DIR" work --remote "$REMOTE_ID" wait --timeout "$WAIT_TIMEOUT"
