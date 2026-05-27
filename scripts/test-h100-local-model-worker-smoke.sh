#!/bin/sh
set -eu

# Replays the current H100 proof with deterministic setup steps. The host may
# be disposable: this hydrates required submodules, applies local smoke patches,
# rebuilds the worker image/tool binaries on the H100 host, starts the minimal
# control plane, and runs the no-tunnel local-model smoke there.

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

SSH_TARGET=${BUS_H100_SMOKE_SSH_TARGET:-dev@ai.hg.fi}
REMOTE_ROOT=${BUS_H100_SMOKE_REMOTE_ROOT:-/home/dev/workspace/busdk/busdk}
REMOTE_NAME=${BUS_H100_SMOKE_REMOTE_NAME:-origin}
REPO_URL=${BUS_H100_SMOKE_REPO_URL:-}
BRANCH=${BUS_H100_SMOKE_BRANCH:-}
IMAGE=${BUS_H100_SMOKE_IMAGE:-bus-integration-dev-task:h100-smoke}
PLATFORM=${BUS_H100_SMOKE_PLATFORM:-linux/amd64}
GO_VERSION=${BUS_H100_SMOKE_GO_VERSION:-1.26.3}
MODEL=${BUS_H100_SMOKE_MODEL:-gemma4:31b}
MODEL_ENDPOINT=${BUS_H100_SMOKE_MODEL_ENDPOINT:-http://127.0.0.1:11434}
NETWORK=${BUS_H100_SMOKE_NETWORK:-host}
CODEX_HOME=${BUS_H100_SMOKE_CODEX_HOME:-/home/dev/.codex}
REMOTE_ID=${BUS_H100_SMOKE_REMOTE_ID:-h100-local-model}
REMOTE_SSH_TARGET=${BUS_H100_SMOKE_REMOTE_SSH_TARGET:-localhost}
REMOTE_SSH_HOST=${BUS_H100_SMOKE_REMOTE_SSH_HOST:-localhost}
REMOTE_SSH_USER=${BUS_H100_SMOKE_REMOTE_SSH_USER:-dev}
DOCKER_SOCKET=${BUS_H100_SMOKE_DOCKER_SOCKET:-auto}
KEEP_CONTAINER=${BUS_H100_SMOKE_KEEP_CONTAINER:-false}
SMOKE_DIR=${BUS_H100_SMOKE_DIR:-/tmp/bus-ssh-docker-model-smoke}
RUNNER_LOG=${BUS_H100_SMOKE_RUNNER_LOG:-/tmp/bus-ssh-runner-model-smoke.log}
WAIT_TIMEOUT=${BUS_H100_SMOKE_WAIT_TIMEOUT:-8m}
SSH_WAIT_TIMEOUT=${BUS_H100_SMOKE_SSH_WAIT_TIMEOUT:-300}
RUN_SSH_WAIT_TIMEOUT=${BUS_H100_SMOKE_RUN_SSH_WAIT_TIMEOUT:-900}
COMPOSE_FILE=${BUS_H100_SMOKE_COMPOSE_FILE:-compose.yaml}
SERVICES=${BUS_H100_SMOKE_SERVICES:-bus-events bus-integration-docker bus-integration-containers}
SUBMODULES=${BUS_H100_SMOKE_SUBMODULES:-"bus bus-agent bus-api-provider-auth bus-api-provider-events bus-dev bus-events bus-help bus-integration bus-integration-dev-task bus-integration-docker bus-integration-containers bus-integration-ssh-runner bus-lint bus-notes bus-operator-token bus-preferences bus-remote bus-secrets bus-update"}
EXTRA_SCRIPT=${BUS_H100_SMOKE_EXTRA_SCRIPT:-}
MODEL_COMMAND_JSON=${BUS_H100_SMOKE_MODEL_COMMAND_JSON:-}
MODEL_POST_COMMAND_JSON=${BUS_H100_SMOKE_MODEL_POST_COMMAND_JSON:-}
MODEL_WORKTREE=${BUS_H100_SMOKE_MODEL_WORKTREE:-}
MODEL_COMMIT=${BUS_H100_SMOKE_MODEL_COMMIT:-}
MODEL_WRITE_SCOPE=${BUS_H100_SMOKE_MODEL_WRITE_SCOPE:-}
MODEL_NEW_BRANCH=${BUS_H100_SMOKE_MODEL_NEW_BRANCH:-}
MODEL_BASE_BRANCH=${BUS_H100_SMOKE_MODEL_BASE_BRANCH:-}
MODEL_COMMIT_MESSAGE=${BUS_H100_SMOKE_MODEL_COMMIT_MESSAGE:-}

usage() {
	cat >&2 <<'USAGE'
usage: test-h100-local-model-worker-smoke.sh [options]

Options override compatibility BUS_H100_SMOKE_* environment variables.

  --ssh-target USER@HOST         H100 SSH target
  --remote-root DIR             H100 BusDK checkout path
  --remote-name NAME            Git remote name
  --repo-url URL                Repository URL
  --branch BRANCH               Repository branch to hydrate
  --image IMAGE                 Worker image tag to build/run
  --platform PLATFORM           Docker build platform
  --go-version VERSION          Go version build arg
  --model MODEL                 local model name
  --model-endpoint URL          Ollama-compatible endpoint
  --network NETWORK             worker Docker network
  --codex-home DIR              Codex home mounted in worker containers
  --remote-id ID                bus-remote id for the smoke
  --remote-ssh-target TARGET    target recorded for the inner SSH run
  --remote-ssh-host HOST        host recorded for the inner SSH run
  --remote-ssh-user USER        user recorded for the inner SSH run
  --docker-socket PATH|auto     Docker socket mounted into worker containers
  --keep-container[=BOOL]       keep worker container after the smoke
  --smoke-dir DIR               remote smoke project directory
  --runner-log FILE             remote runner log path
  --wait-timeout DURATION       work wait timeout
  --ssh-wait-timeout SECONDS    normal SSH command timeout
  --run-ssh-wait-timeout SEC    long SSH command timeout
  --compose-file FILE           remote Compose file
  --services "A B ..."          services to start
  --submodules "A B ..."        submodules to hydrate
  --extra-script PATH           extra local script to copy to remote
  --model-command-json JSON     model command JSON for inner smoke
  --model-post-command-json JSON
  --model-worktree[=BOOL]
  --model-commit[=BOOL]
  --model-write-scope PATH
  --model-new-branch BRANCH
  --model-base-branch BRANCH
  --model-commit-message TEXT
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
		--ssh-target) need_arg "$@"; SSH_TARGET=$2; shift 2 ;;
		--remote-root) need_arg "$@"; REMOTE_ROOT=$2; shift 2 ;;
		--remote-name) need_arg "$@"; REMOTE_NAME=$2; shift 2 ;;
		--repo-url) need_arg "$@"; REPO_URL=$2; shift 2 ;;
		--branch) need_arg "$@"; BRANCH=$2; shift 2 ;;
		--image) need_arg "$@"; IMAGE=$2; shift 2 ;;
		--platform) need_arg "$@"; PLATFORM=$2; shift 2 ;;
		--go-version) need_arg "$@"; GO_VERSION=$2; shift 2 ;;
		--model) need_arg "$@"; MODEL=$2; shift 2 ;;
		--model-endpoint|--endpoint) need_arg "$@"; MODEL_ENDPOINT=$2; shift 2 ;;
		--network) need_arg "$@"; NETWORK=$2; shift 2 ;;
		--codex-home) need_arg "$@"; CODEX_HOME=$2; shift 2 ;;
		--remote-id) need_arg "$@"; REMOTE_ID=$2; shift 2 ;;
		--remote-ssh-target) need_arg "$@"; REMOTE_SSH_TARGET=$2; shift 2 ;;
		--remote-ssh-host) need_arg "$@"; REMOTE_SSH_HOST=$2; shift 2 ;;
		--remote-ssh-user) need_arg "$@"; REMOTE_SSH_USER=$2; shift 2 ;;
		--docker-socket) need_arg "$@"; DOCKER_SOCKET=$2; shift 2 ;;
		--keep-container) KEEP_CONTAINER=true; shift ;;
		--keep-container=*) KEEP_CONTAINER=${1#*=}; shift ;;
		--no-keep-container) KEEP_CONTAINER=false; shift ;;
		--smoke-dir) need_arg "$@"; SMOKE_DIR=$2; shift 2 ;;
		--runner-log) need_arg "$@"; RUNNER_LOG=$2; shift 2 ;;
		--wait-timeout) need_arg "$@"; WAIT_TIMEOUT=$2; shift 2 ;;
		--ssh-wait-timeout) need_arg "$@"; SSH_WAIT_TIMEOUT=$2; shift 2 ;;
		--run-ssh-wait-timeout) need_arg "$@"; RUN_SSH_WAIT_TIMEOUT=$2; shift 2 ;;
		--compose-file) need_arg "$@"; COMPOSE_FILE=$2; shift 2 ;;
		--services) need_arg "$@"; SERVICES=$2; shift 2 ;;
		--submodules) need_arg "$@"; SUBMODULES=$2; shift 2 ;;
		--extra-script) need_arg "$@"; EXTRA_SCRIPT=$2; shift 2 ;;
		--model-command-json) need_arg "$@"; MODEL_COMMAND_JSON=$2; shift 2 ;;
		--model-post-command-json) need_arg "$@"; MODEL_POST_COMMAND_JSON=$2; shift 2 ;;
		--model-worktree) MODEL_WORKTREE=true; shift ;;
		--model-worktree=*) MODEL_WORKTREE=${1#*=}; shift ;;
		--no-model-worktree) MODEL_WORKTREE=false; shift ;;
		--model-commit) MODEL_COMMIT=true; shift ;;
		--model-commit=*) MODEL_COMMIT=${1#*=}; shift ;;
		--no-model-commit) MODEL_COMMIT=false; shift ;;
		--model-write-scope) need_arg "$@"; MODEL_WRITE_SCOPE=$2; shift 2 ;;
		--model-new-branch) need_arg "$@"; MODEL_NEW_BRANCH=$2; shift 2 ;;
		--model-base-branch) need_arg "$@"; MODEL_BASE_BRANCH=$2; shift 2 ;;
		--model-commit-message) need_arg "$@"; MODEL_COMMIT_MESSAGE=$2; shift 2 ;;
		--help|-h) usage; exit 0 ;;
		*)
			printf 'unknown option: %s\n' "$1" >&2
			usage
			exit 2
			;;
	esac
done

if [ -z "$REPO_URL" ]; then
	REPO_URL=$(git -C "$ROOT" remote get-url "$REMOTE_NAME")
fi

if [ -z "$BRANCH" ]; then
	BRANCH=$(git -C "$ROOT" rev-parse --abbrev-ref HEAD)
	if [ "$BRANCH" = HEAD ]; then
		BRANCH=main
	fi
fi

shell_quote() {
	printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"
}

run_ssh_with_input() {
	wait_timeout=$1
	input_file=$2
	shift 2
	out=$(mktemp "${TMPDIR:-/tmp}/bus-h100-ssh-out.XXXXXX")
	err=$(mktemp "${TMPDIR:-/tmp}/bus-h100-ssh-err.XXXXXX")
	ssh -A -o BatchMode=yes -o ConnectTimeout=20 "$SSH_TARGET" "$@" < "$input_file" >"$out" 2>"$err" &
	pid=$!
	elapsed=0
	while kill -0 "$pid" 2>/dev/null; do
		if [ "$elapsed" -ge "$wait_timeout" ]; then
			kill "$pid" 2>/dev/null || true
			sleep 1
			kill -9 "$pid" 2>/dev/null || true
			cat "$out"
			cat "$err" >&2
			rm -f "$out" "$err"
			printf 'timed out after %s seconds waiting for ssh target %s\n' "$wait_timeout" "$SSH_TARGET" >&2
			return 124
		fi
		sleep 1
		elapsed=$((elapsed + 1))
	done
	set +e
	wait "$pid"
	status=$?
	set -e
	cat "$out"
	cat "$err" >&2
	rm -f "$out" "$err"
	return "$status"
}

run_ssh() {
	run_ssh_with_input "$SSH_WAIT_TIMEOUT" /dev/null "$@"
}

run_ssh_stdin_timeout() {
	wait_timeout=$1
	shift
	in=$(mktemp "${TMPDIR:-/tmp}/bus-h100-ssh-in.XXXXXX")
	cat > "$in"
	set +e
	run_ssh_with_input "$wait_timeout" "$in" "$@"
	status=$?
	set -e
	rm -f "$in"
	return "$status"
}

run_ssh_stdin() {
	run_ssh_stdin_timeout "$SSH_WAIT_TIMEOUT" "$@"
}

run_ssh_stdin_long() {
	run_ssh_stdin_timeout "$RUN_SSH_WAIT_TIMEOUT" "$@"
}

copy_file() {
	local_path=$1
	remote_path=$2
	remote_path_q=$(shell_quote "$remote_path")
	run_ssh_stdin "cat > $remote_path_q" < "$local_path"
}

remote_root_q=$(shell_quote "$REMOTE_ROOT")
remote_name_q=$(shell_quote "$REMOTE_NAME")
repo_url_q=$(shell_quote "$REPO_URL")
branch_q=$(shell_quote "$BRANCH")
submodules_q=
for module in $SUBMODULES; do
	submodules_q="$submodules_q $(shell_quote "$module")"
done

printf 'Preparing H100 checkout at %s on %s\n' "$REMOTE_ROOT" "$SSH_TARGET" >&2
printf '%s\n' "
set -eu
if [ \"\$(id -u)\" = 0 ]; then
	printf 'refusing to run H100 smoke setup as root\n' >&2
	exit 2
fi
remote_root=$remote_root_q
if [ ! -d \"\$remote_root/.git\" ]; then
	if [ -e \"\$remote_root\" ] && [ \"\$(find \"\$remote_root\" -mindepth 1 -maxdepth 1 2>/dev/null | sed -n '1p')\" ]; then
		printf 'remote path exists but is not a Git checkout: %s\n' \"\$remote_root\" >&2
		exit 2
	fi
	parent=\${remote_root%/*}
	if [ \"\$parent\" = \"\$remote_root\" ]; then
		parent=.
	fi
	mkdir -p \"\$parent\"
	git clone --origin $remote_name_q --recurse-submodules=no $repo_url_q \"\$remote_root\"
fi
cd $remote_root_q
git fetch --recurse-submodules=no $remote_name_q $branch_q
git checkout $branch_q
git pull --ff-only $remote_name_q $branch_q
git submodule update --init --recursive$submodules_q
" | run_ssh_stdin sh -s

printf 'Copying local smoke patches to H100 host\n' >&2
copy_file "$ROOT/bus-dev/run/task.go" "$REMOTE_ROOT/bus-dev/run/task.go"
copy_file "$ROOT/bus-dev/run/worker.go" "$REMOTE_ROOT/bus-dev/run/worker.go"
copy_file "$ROOT/compose.yaml" "$REMOTE_ROOT/compose.yaml"
copy_file "$ROOT/scripts/test-ssh-docker-image-smoke.sh" "$REMOTE_ROOT/scripts/test-ssh-docker-image-smoke.sh"
copy_file "$ROOT/scripts/test-ssh-docker-local-model-smoke.sh" "$REMOTE_ROOT/scripts/test-ssh-docker-local-model-smoke.sh"
if [ -n "$EXTRA_SCRIPT" ]; then
	copy_file "$ROOT/$EXTRA_SCRIPT" "$REMOTE_ROOT/$EXTRA_SCRIPT"
	run_ssh "chmod +x $(shell_quote "$REMOTE_ROOT/$EXTRA_SCRIPT")"
fi
run_ssh "chmod +x $(shell_quote "$REMOTE_ROOT/scripts/test-ssh-docker-image-smoke.sh") $(shell_quote "$REMOTE_ROOT/scripts/test-ssh-docker-local-model-smoke.sh")"

image_q=$(shell_quote "$IMAGE")
platform_q=$(shell_quote "$PLATFORM")
go_version_q=$(shell_quote "$GO_VERSION")
model_q=$(shell_quote "$MODEL")
model_endpoint_q=$(shell_quote "$MODEL_ENDPOINT")
network_q=$(shell_quote "$NETWORK")
codex_home_q=$(shell_quote "$CODEX_HOME")
remote_id_q=$(shell_quote "$REMOTE_ID")
remote_ssh_target_q=$(shell_quote "$REMOTE_SSH_TARGET")
remote_ssh_host_q=$(shell_quote "$REMOTE_SSH_HOST")
remote_ssh_user_q=$(shell_quote "$REMOTE_SSH_USER")
docker_socket_q=$(shell_quote "$DOCKER_SOCKET")
keep_container_q=$(shell_quote "$KEEP_CONTAINER")
smoke_dir_q=$(shell_quote "$SMOKE_DIR")
runner_log_q=$(shell_quote "$RUNNER_LOG")
wait_timeout_q=$(shell_quote "$WAIT_TIMEOUT")
compose_file_q=$(shell_quote "$COMPOSE_FILE")
model_command_json_q=$(shell_quote "$MODEL_COMMAND_JSON")
model_post_command_json_q=$(shell_quote "$MODEL_POST_COMMAND_JSON")
model_worktree_q=$(shell_quote "$MODEL_WORKTREE")
model_commit_q=$(shell_quote "$MODEL_COMMIT")
model_write_scope_q=$(shell_quote "$MODEL_WRITE_SCOPE")
model_new_branch_q=$(shell_quote "$MODEL_NEW_BRANCH")
model_base_branch_q=$(shell_quote "$MODEL_BASE_BRANCH")
model_commit_message_q=$(shell_quote "$MODEL_COMMIT_MESSAGE")
services_q=
for service in $SERVICES; do
	services_q="$services_q $(shell_quote "$service")"
done

printf 'Building H100 worker image and running local-model smoke\n' >&2
printf '%s\n' "
set -eu
if [ \"\$(id -u)\" = 0 ]; then
	printf 'refusing to run H100 smoke as root\n' >&2
	exit 2
fi
cd $remote_root_q
docker_socket=$docker_socket_q
if [ \"\$docker_socket\" = auto ]; then
	case \"\${DOCKER_HOST:-}\" in
		unix://*)
			docker_socket=\${DOCKER_HOST#unix://}
			;;
	esac
fi
if [ \"\$docker_socket\" = auto ] || [ -z \"\$docker_socket\" ]; then
	uid=\$(id -u)
	if [ -S \"/run/user/\$uid/docker.sock\" ]; then
		docker_socket=/run/user/\$uid/docker.sock
	elif [ -S /var/run/docker.sock ]; then
		docker_socket=/var/run/docker.sock
	else
		printf 'could not locate a Docker socket for nested worker container access\n' >&2
		exit 2
	fi
fi
printf 'Using Docker socket for trusted nested worker access: %s\n' \"\$docker_socket\" >&2
BUS_SSH_DOCKER_BUILD_IMAGE=$image_q \\
BUS_SSH_DOCKER_BUILD_PLATFORM=$platform_q \\
BUS_SSH_DOCKER_BUILD_GO_VERSION=$go_version_q \\
./scripts/build-ssh-docker-worker-image.sh
git -C bus-dev checkout -- run/task.go
git -C bus-dev checkout -- run/worker.go
BUS_DOCKER_SOCKET_HOST=\"\$docker_socket\" docker compose -f $compose_file_q up -d --no-deps$services_q
scripts/test-ssh-docker-local-model-smoke.sh \\
	--image $image_q \\
	--model $model_q \\
	--model-endpoint $model_endpoint_q \\
	--command-json $model_command_json_q \\
	--post-command-json $model_post_command_json_q \\
	--worktree=$model_worktree_q \\
	--commit=$model_commit_q \\
	--write-scope $model_write_scope_q \\
	--new-branch $model_new_branch_q \\
	--base-branch $model_base_branch_q \\
	--commit-message $model_commit_message_q \\
	-- \\
	--no-tunnel \\
	--controller-url http://127.0.0.1:8081 \\
	--remote-id $remote_id_q \\
	--ssh-target $remote_ssh_target_q \\
	--ssh-host $remote_ssh_host_q \\
	--ssh-user $remote_ssh_user_q \\
	--remote-workdir $remote_root_q \\
	--worker-events-url http://127.0.0.1:8081 \\
	--network $network_q \\
	--docker-socket \"\$docker_socket\" \\
	--keep-container=$keep_container_q \\
	--codex-home $codex_home_q \\
	--smoke-dir $smoke_dir_q \\
	--runner-log $runner_log_q \\
	--wait-timeout $wait_timeout_q
" | run_ssh_stdin_long sh -s
