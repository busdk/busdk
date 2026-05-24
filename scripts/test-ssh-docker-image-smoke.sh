#!/bin/sh
set -eu

# Proves the Bus-managed SSH-Docker image path against a real SSH host.
# Required remote-side shape: SSH access, Docker, a reachable bus-events
# container on the selected Docker network, and the worker image installed. Set
# BUS_SSH_DOCKER_SMOKE_INSTALL_IMAGE=true to install the selected local image
# first through scripts/install-ssh-docker-worker-image.sh.

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

REMOTE_ID=${BUS_SSH_DOCKER_SMOKE_REMOTE_ID:-dev-hg}
SMOKE_DIR=${BUS_SSH_DOCKER_SMOKE_DIR:-${TMPDIR:-/tmp}/bus-ssh-docker-smoke}
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
WORKER_DOCKER_SOCKET=${BUS_SSH_DOCKER_SMOKE_DOCKER_SOCKET:-}
WORKER_KEEP_CONTAINER=${BUS_SSH_DOCKER_SMOKE_KEEP_CONTAINER:-false}
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
USE_TUNNEL=${BUS_SSH_DOCKER_SMOKE_TUNNEL:-true}
WAIT_TIMEOUT=${BUS_SSH_DOCKER_SMOKE_WAIT_TIMEOUT:-8m}
RECIPIENT=${BUS_SSH_DOCKER_SMOKE_RECIPIENT:-bus-dev}
WRITE_SCOPE=${BUS_SSH_DOCKER_SMOKE_WRITE_SCOPE:-}
BRANCH=${BUS_SSH_DOCKER_SMOKE_BRANCH:-}
NEW_BRANCH=${BUS_SSH_DOCKER_SMOKE_NEW_BRANCH:-}
BASE_BRANCH=${BUS_SSH_DOCKER_SMOKE_BASE_BRANCH:-}
PROMPT=${BUS_SSH_DOCKER_SMOKE_PROMPT:-SSH-Docker image smoke: do not edit files; verify the worker can claim this task, send a short progress message, and mark it done.}
LOCAL_SECRET=${BUS_AUTH_HS256_SECRET:-not-a-secret-local-development-hs256-key}
ACCOUNT_ID=${BUS_LOCAL_ACCOUNT_ID:-00000000-0000-4000-8000-000000000001}
CONTROLLER_URL=${BUS_SSH_DOCKER_SMOKE_CONTROLLER_URL:-http://127.0.0.1:${TUNNEL_PORT}}
RUNNER_LOG=${BUS_SSH_DOCKER_SMOKE_RUNNER_LOG:-${TMPDIR:-/tmp}/bus-ssh-runner-smoke.log}

usage() {
	cat >&2 <<'USAGE'
usage: test-ssh-docker-image-smoke.sh [options]

Options override the compatibility BUS_SSH_DOCKER_SMOKE_* environment
variables. Use flags for normal test variations so the script can run through
a stable approved command prefix.

  --remote-id ID                 Bus remote id
  --smoke-dir DIR               Local smoke project directory
  --ssh-target USER@HOST         SSH target used by the runner/tunnel
  --ssh-host HOST                Remote host recorded in bus-remote
  --ssh-user USER                Remote user recorded in bus-remote
  --ssh-port PORT                Remote SSH port
  --remote-workdir DIR           Remote checkout/workdir
  --compose-file FILE            Remote Compose file
  --controller-url URL           Controller Events URL
  --worker-events-url URL        Worker Events URL
  --image IMAGE                  Worker launcher image
  --network NETWORK              Worker Docker network
  --codex-home DIR               Codex home mounted in worker containers
  --docker-socket PATH           Docker socket mounted in worker containers
  --keep-container[=BOOL]        Keep worker container after the smoke
  --agent-backend BACKEND        dev-task agent backend
  --container-image IMAGE        container backend image
  --container-profile PROFILE    container backend profile
  --command-json JSON            command JSON for container backend
  --pre-command-json JSON        pre-command JSON for container backend
  --post-command-json JSON       post-command JSON for container backend
  --worktree[=BOOL]              request a task worktree
  --commit[=BOOL]                request worker commit
  --commit-message TEXT          worker commit message
  --install-image[=BOOL]         install local image to remote first
  --build-image[=BOOL]           build local worker image first
  --tunnel[=BOOL]                use local SSH tunnel to Events
  --remote-events-host HOST      tunnel target host on remote side
  --remote-events-port PORT      tunnel target port on remote side
  --wait-timeout DURATION        bus-dev work wait timeout
  --runner-log FILE             local runner log path
  --recipient NAME               task recipient
  --write-scope PATH             task write scope
  --branch BRANCH                task branch
  --new-branch BRANCH            task new branch
  --base-branch BRANCH           task base branch
  --prompt TEXT                  task prompt
USAGE
}

need_arg() {
	if [ "$#" -lt 2 ]; then
		printf 'missing value for %s\n' "$1" >&2
		usage
		exit 2
	fi
}

while [ "$#" -gt 0 ]; do
	case "$1" in
		--remote-id) need_arg "$@"; REMOTE_ID=$2; shift 2 ;;
		--smoke-dir) need_arg "$@"; SMOKE_DIR=$2; shift 2 ;;
		--tunnel-port) need_arg "$@"; TUNNEL_PORT=$2; shift 2 ;;
		--ssh-target) need_arg "$@"; SSH_TARGET=$2; shift 2 ;;
		--ssh-host) need_arg "$@"; SSH_HOST=$2; shift 2 ;;
		--ssh-user) need_arg "$@"; SSH_USER=$2; shift 2 ;;
		--ssh-port) need_arg "$@"; SSH_PORT=$2; shift 2 ;;
		--remote-workdir) need_arg "$@"; REMOTE_WORKDIR=$2; shift 2 ;;
		--compose-file) need_arg "$@"; COMPOSE_FILE=$2; shift 2 ;;
		--remote-events-host) need_arg "$@"; REMOTE_EVENTS_HOST=$2; shift 2 ;;
		--remote-events-port) need_arg "$@"; REMOTE_EVENTS_PORT=$2; shift 2 ;;
		--controller-url) need_arg "$@"; CONTROLLER_URL=$2; shift 2 ;;
		--worker-events-url) need_arg "$@"; WORKER_EVENTS_URL=$2; shift 2 ;;
		--image|--worker-image) need_arg "$@"; WORKER_IMAGE=$2; shift 2 ;;
		--network) need_arg "$@"; WORKER_NETWORK=$2; shift 2 ;;
		--codex-home) need_arg "$@"; WORKER_CODEX_HOME=$2; shift 2 ;;
		--docker-socket) need_arg "$@"; WORKER_DOCKER_SOCKET=$2; shift 2 ;;
		--keep-container) WORKER_KEEP_CONTAINER=true; shift ;;
		--keep-container=*) WORKER_KEEP_CONTAINER=${1#*=}; shift ;;
		--no-keep-container) WORKER_KEEP_CONTAINER=false; shift ;;
		--agent-backend) need_arg "$@"; WORKER_AGENT_BACKEND=$2; shift 2 ;;
		--container-image) need_arg "$@"; WORKER_CONTAINER_IMAGE=$2; shift 2 ;;
		--container-profile) need_arg "$@"; WORKER_CONTAINER_PROFILE=$2; shift 2 ;;
		--command-json) need_arg "$@"; WORKER_COMMAND_JSON=$2; shift 2 ;;
		--pre-command-json) need_arg "$@"; WORKER_PRE_COMMAND_JSON=$2; shift 2 ;;
		--post-command-json) need_arg "$@"; WORKER_POST_COMMAND_JSON=$2; shift 2 ;;
		--worktree) WORKER_WORKTREE=true; shift ;;
		--worktree=*) WORKER_WORKTREE=${1#*=}; shift ;;
		--no-worktree) WORKER_WORKTREE=false; shift ;;
		--commit) WORKER_COMMIT=true; shift ;;
		--commit=*) WORKER_COMMIT=${1#*=}; shift ;;
		--no-commit) WORKER_COMMIT=false; shift ;;
		--commit-message) need_arg "$@"; WORKER_COMMIT_MESSAGE=$2; shift 2 ;;
		--install-image) INSTALL_IMAGE=true; shift ;;
		--install-image=*) INSTALL_IMAGE=${1#*=}; shift ;;
		--build-image) BUILD_IMAGE=true; shift ;;
		--build-image=*) BUILD_IMAGE=${1#*=}; shift ;;
		--tunnel) USE_TUNNEL=true; shift ;;
		--tunnel=*) USE_TUNNEL=${1#*=}; shift ;;
		--no-tunnel) USE_TUNNEL=false; shift ;;
		--wait-timeout) need_arg "$@"; WAIT_TIMEOUT=$2; shift 2 ;;
		--runner-log) need_arg "$@"; RUNNER_LOG=$2; shift 2 ;;
		--recipient) need_arg "$@"; RECIPIENT=$2; shift 2 ;;
		--write-scope) need_arg "$@"; WRITE_SCOPE=$2; shift 2 ;;
		--branch) need_arg "$@"; BRANCH=$2; shift 2 ;;
		--new-branch) need_arg "$@"; NEW_BRANCH=$2; shift 2 ;;
		--base-branch) need_arg "$@"; BASE_BRANCH=$2; shift 2 ;;
		--prompt) need_arg "$@"; PROMPT=$2; shift 2 ;;
		--help|-h) usage; exit 0 ;;
		*)
			printf 'unknown option: %s\n' "$1" >&2
			usage
			exit 2
			;;
	esac
done

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
tunnel=0
cleanup() {
	if [ "$runner" != 0 ]; then
		kill "$runner" 2>/dev/null || true
	fi
	if [ "$tunnel" != 0 ]; then
		kill "$tunnel" 2>/dev/null || true
	fi
}
trap cleanup EXIT INT TERM

task_event_row_present() {
	event_name=$1
	file_name=$2
	awk -F '	' -v event_name="$event_name" '
		$1 == event_name { found = 1 }
		END {
			if (found) {
				exit 0
			}
			exit 1
		}
	' "$file_name"
}

case "$USE_TUNNEL" in
	true|1|yes|on)
		ssh -A -N -o ExitOnForwardFailure=yes -L "127.0.0.1:${TUNNEL_PORT}:${REMOTE_EVENTS_HOST}:${REMOTE_EVENTS_PORT}" "$SSH_TARGET" &
		tunnel=$!
		;;
	false|0|no|off|'')
		;;
	*)
		printf 'invalid BUS_SSH_DOCKER_SMOKE_TUNNEL=%s\n' "$USE_TUNNEL" >&2
		exit 2
		;;
esac

if command -v curl >/dev/null 2>&1; then
	i=0
	while [ "$i" -lt 20 ]; do
		if curl -s -o /dev/null --max-time 1 "$CONTROLLER_URL/api/v1/events/capabilities"; then
			break
		fi
		if [ "$tunnel" != 0 ] && ! kill -0 "$tunnel" 2>/dev/null; then
			printf 'ssh tunnel to %s failed before Events became reachable; local port forwarding may be disabled by the gateway\n' "$SSH_TARGET" >&2
			wait "$tunnel" 2>/dev/null || true
			exit 2
		fi
		i=$((i + 1))
		sleep 1
	done
	if [ "$i" -ge 20 ]; then
		printf 'timed out waiting for tunneled Events API at %s; verify %s can forward to %s:%s\n' "$CONTROLLER_URL" "$SSH_TARGET" "$REMOTE_EVENTS_HOST" "$REMOTE_EVENTS_PORT" >&2
		exit 2
	fi
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
BUS_DEV_SSH_DOCKER_WORKER_DOCKER_SOCKET="$WORKER_DOCKER_SOCKET" \
BUS_DEV_SSH_DOCKER_WORKER_KEEP_CONTAINER="$WORKER_KEEP_CONTAINER" \
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

wait_output=$(mktemp "${TMPDIR:-/tmp}/bus-ssh-docker-smoke-wait.XXXXXX")
set +e
BUS_API_TOKEN="$TOKEN" "$ROOT/bus-dev/bin/bus-dev" -C "$SMOKE_DIR" work --remote "$REMOTE_ID" wait --timeout "$WAIT_TIMEOUT" >"$wait_output" 2>&1
wait_status=$?
set -e
cat "$wait_output"
if task_event_row_present 'bus.dev.task.failed' "$wait_output"; then
	rm -f "$wait_output"
	exit 1
fi
if ! task_event_row_present 'bus.dev.task.done' "$wait_output"; then
	rm -f "$wait_output"
	exit 1
fi
rm -f "$wait_output"
exit "$wait_status"
