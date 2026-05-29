#!/bin/sh
set -eu

# Minimal manual Spark worker launcher.
# This intentionally does not use bus-task, Bus Events, or any worker provider.

REMOTE=${BUS_MANUAL_SPARK_REMOTE:-coding-agent@dev.hg.fi}
REMOTE_REPO=${BUS_MANUAL_SPARK_REMOTE_REPO:-/home/coding-agent/coding-agent/git/busdk/busdk}
REMOTE_ROOT=${BUS_MANUAL_SPARK_REMOTE_ROOT:-/home/coding-agent/coding-agent/git/busdk/tmp/workers}
IMAGE=${BUS_MANUAL_SPARK_IMAGE:-bus-integration-task:local-image-smoke}
MODEL=${BUS_MANUAL_SPARK_MODEL:-gpt-5.3-codex-spark}
SANDBOX=${BUS_MANUAL_SPARK_SANDBOX:-danger-full-access}
AUTH_HOME=${BUS_MANUAL_SPARK_AUTH_HOME:-/home/coding-agent/coding-agent/.codex}
PORT_START=${BUS_MANUAL_SPARK_PORT_START:-19100}

usage() {
	cat >&2 <<'USAGE'
usage:
  manual-dev-hg-spark-worker.sh start NAME MODULE BRANCH PROMPT_FILE
  manual-dev-hg-spark-worker.sh prompt NAME [PROMPT_FILE]
  manual-dev-hg-spark-worker.sh attach NAME
  manual-dev-hg-spark-worker.sh logs NAME
  manual-dev-hg-spark-worker.sh status [NAME]
  manual-dev-hg-spark-worker.sh stop NAME

Starts plain Docker-hosted Codex App Server workers on coding-agent@dev.hg.fi.
No Bus task/event/provider implementation is involved. Each worker gets a
remote Git worktree, a module branch, a worker-specific AGENTS.md,
worker-specific logs, a worker-specific CODEX_HOME copy, and a Spark-model
app-server container. The checkout is mounted at /workspace/projects/busdk
inside the container.

Environment overrides:
  BUS_MANUAL_SPARK_REMOTE       default coding-agent@dev.hg.fi
  BUS_MANUAL_SPARK_REMOTE_REPO  default /home/coding-agent/coding-agent/git/busdk/busdk
  BUS_MANUAL_SPARK_REMOTE_ROOT  default /home/coding-agent/coding-agent/git/busdk/tmp/workers
  BUS_MANUAL_SPARK_IMAGE        default bus-integration-task:local-image-smoke
  BUS_MANUAL_SPARK_MODEL        default gpt-5.3-codex-spark
  BUS_MANUAL_SPARK_SANDBOX      default danger-full-access
  BUS_MANUAL_SPARK_AUTH_HOME    default /home/coding-agent/coding-agent/.codex
  BUS_MANUAL_SPARK_PORT_START   default 19100
USAGE
	exit 2
}

shell_quote() {
	printf "'%s'" "$(printf "%s" "$1" | sed "s/'/'\\\\''/g")"
}

worker_dir() {
	printf '%s/%s\n' "$REMOTE_ROOT" "$1"
}

remote_meta() {
	name=$1
	key=$2
	ssh "$REMOTE" "test -f $(shell_quote "$(worker_dir "$name")/meta.env") && sed -n 's/^$key=//p' $(shell_quote "$(worker_dir "$name")/meta.env") | tail -1"
}

cmd=${1:-}
[ -n "$cmd" ] || usage
shift

case "$cmd" in
start)
	name=${1:-}
	module=${2:-}
	branch=${3:-}
	prompt_file=${4:-}
	[ -n "$name" ] && [ -n "$module" ] && [ -n "$branch" ] && [ -n "$prompt_file" ] || usage
	if [ ! -f "$prompt_file" ]; then
		printf 'prompt file not found: %s\n' "$prompt_file" >&2
		exit 2
	fi

	case "$name" in
		*[!A-Za-z0-9_.-]*|'')
			printf 'worker NAME must contain only letters, numbers, dot, underscore, or dash: %s\n' "$name" >&2
			exit 2
			;;
	esac

	dir=$(worker_dir "$name")
	prompt_remote="$dir/prompt.md"
	ssh "$REMOTE" "mkdir -p $(shell_quote "$dir")"
	scp "$prompt_file" "$REMOTE:$prompt_remote" >/dev/null

	remote_script=$(mktemp "${TMPDIR:-/tmp}/manual-spark-start.XXXXXX")
	trap 'rm -f "$remote_script"' EXIT
	cat >"$remote_script" <<'REMOTE_SCRIPT'
set -eu
name=$1
module=$2
branch=$3
remote_repo=$4
remote_root=$5
image=$6
model=$7
sandbox=$8
auth_home=$9
port_start=${10}

dir="$remote_root/$name"
worktree="$dir/worktree"
codex_home="$dir/codex-home"
workspace="$dir/workspace"
worker_agents="$workspace/AGENTS.md"
worker_logs="$workspace/logs"
token_file="$dir/ws-token"
meta_file="$dir/meta.env"
prompt_file="$dir/prompt.md"
container_prompt="/workspace/task.md"
container="bus-manual-spark-$name"
lockdir="$remote_root/.manual-spark.lock"

mkdir -p "$dir" "$codex_home" "$workspace" "$worker_logs"
if [ ! -d "$remote_repo/.git" ]; then
	printf 'remote repo not found: %s\n' "$remote_repo" >&2
	exit 1
fi

while ! mkdir "$lockdir" 2>/dev/null; do
	sleep 1
done
trap 'rmdir "$lockdir" 2>/dev/null || true' EXIT INT TERM

git -C "$remote_repo" fetch origin main >/dev/null 2>&1 || true
if [ ! -d "$worktree/.git" ] && [ ! -f "$worktree/.git" ]; then
	if git -C "$remote_repo" show-ref --verify --quiet "refs/heads/$branch"; then
		git -C "$remote_repo" worktree add "$worktree" "$branch"
	else
		git -C "$remote_repo" worktree add -b "$branch" "$worktree" origin/main
	fi
fi

if [ ! -s "$token_file" ]; then
	(umask 077; openssl rand -hex 32 >"$token_file")
fi

cat >"$worker_agents" <<EOF
# Manual Spark Worker: $name

You are a focused Codex implementation worker running under supervisor control.

Task prompt:

$(sed 's/^/> /' "$prompt_file")

Rules:
- Work only on the assigned implementation slice and its unit tests.
- Do not run e2e or integration tests unless the supervisor explicitly asks.
- Keep changes inside /workspace/projects/busdk/$module unless the task prompt
  explicitly names another file or dependency path.
- Use the existing project guidance in /workspace/projects/busdk/AGENTS.md and
  nested AGENTS.md files before editing.
- Report progress and blockers in the attached Codex conversation.
- Write any durable scratch notes or command evidence under /workspace/logs.
- Do not commit, push, or delete unrelated work unless the supervisor asks.
EOF

port=$port_start
while ss -ltn | awk '{print $4}' | grep -Eq "[:.]$port$"; do
	port=$((port + 1))
done

if [ -f "$worktree/.gitmodules" ]; then
	git -C "$worktree" submodule update --init "$module"
fi
if [ -d "$worktree/$module/.git" ] || [ -f "$worktree/$module/.git" ]; then
	if git -C "$worktree/$module" show-ref --verify --quiet "refs/heads/$branch"; then
		git -C "$worktree/$module" checkout "$branch"
	else
		git -C "$worktree/$module" checkout -b "$branch"
	fi
fi

docker rm -f "$container" >/dev/null 2>&1 || true
docker run -d \
	--name "$container" \
	--hostname "$container" \
	-p "127.0.0.1:$port:$port" \
	-v "$worktree:/workspace/projects/busdk" \
	-v "$worker_agents:/workspace/AGENTS.md:ro" \
	-v "$worker_logs:/workspace/logs" \
	-v "$prompt_file:$container_prompt:ro" \
	-v "$codex_home:/workspace/codex-home" \
	-v "$auth_home:/workspace/codex-auth:ro" \
	-v "$token_file:/workspace/manual-token:ro" \
	-w "/workspace" \
	--entrypoint sh \
	"$image" \
	-lc 'set -eu
export CODEX_HOME=/workspace/codex-home
mkdir -p "$CODEX_HOME"
if [ -d /workspace/codex-auth ]; then
  cp -a /workspace/codex-auth/. "$CODEX_HOME"/ 2>/dev/null || true
fi
chmod -R u+rwX "$CODEX_HOME" 2>/dev/null || true
exec codex app-server \
  -c model="'"$model"'" \
  --listen "ws://0.0.0.0:'"$port"'" \
  --ws-auth capability-token \
  --ws-token-file /workspace/manual-token'

cat >"$meta_file" <<EOF
name=$name
module=$module
branch=$branch
worktree=$worktree
container_checkout=/workspace/projects/busdk
worker_agents=/workspace/AGENTS.md
worker_logs=/workspace/logs
container_prompt=$container_prompt
container=$container
port=$port
model=$model
sandbox=$sandbox
prompt_file=$prompt_file
EOF

printf 'worker=%s\ncontainer=%s\nworktree=%s\nmodule=%s\nbranch=%s\nport=%s\nmodel=%s\nprompt=%s\n' \
	"$name" "$container" "$worktree" "$module" "$branch" "$port" "$model" "$prompt_file"
REMOTE_SCRIPT

	ssh "$REMOTE" "sh -s -- $(shell_quote "$name") $(shell_quote "$module") $(shell_quote "$branch") $(shell_quote "$REMOTE_REPO") $(shell_quote "$REMOTE_ROOT") $(shell_quote "$IMAGE") $(shell_quote "$MODEL") $(shell_quote "$SANDBOX") $(shell_quote "$AUTH_HOME") $(shell_quote "$PORT_START")" <"$remote_script"
	printf '\nAttach with:\n  %s attach %s\n' "$0" "$name"
	printf '\nStart the live guided task with:\n  %s prompt %s\n' "$0" "$name"
	printf '\nPrompt is stored on the remote host and mounted at /workspace/task.md:\n  %s\n' "$prompt_remote"
	;;

prompt)
	name=${1:-}
	override_prompt=${2:-}
	[ -n "$name" ] || usage
	container=$(remote_meta "$name" container)
	port=$(remote_meta "$name" port)
	model=$(remote_meta "$name" model)
	sandbox=$(remote_meta "$name" sandbox)
	module=$(remote_meta "$name" module)
	[ -n "$container" ] && [ -n "$port" ] || {
		printf 'worker not found or missing metadata: %s\n' "$name" >&2
		exit 1
	}
	remote_url="ws://127.0.0.1:$port"
	if [ -n "$override_prompt" ]; then
		if [ ! -f "$override_prompt" ]; then
			printf 'prompt file not found: %s\n' "$override_prompt" >&2
			exit 2
		fi
		tmp_prompt=$(mktemp "${TMPDIR:-/tmp}/manual-spark-prompt.XXXXXX")
		trap 'rm -f "$tmp_prompt"' EXIT
		cp "$override_prompt" "$tmp_prompt"
		scp "$tmp_prompt" "$REMOTE:$(worker_dir "$name")/live-prompt.md" >/dev/null
	else
		ssh "$REMOTE" "cp $(shell_quote "$(worker_dir "$name")/prompt.md") $(shell_quote "$(worker_dir "$name")/live-prompt.md")"
	fi
	ssh -tt "$REMOTE" "token=\$(cat $(shell_quote "$(worker_dir "$name")/ws-token")); prompt=\$(cat $(shell_quote "$(worker_dir "$name")/live-prompt.md")); docker exec -it -e CODEX_REMOTE_TOKEN=\"\$token\" $(shell_quote "$container") codex --remote $(shell_quote "$remote_url") --remote-auth-token-env CODEX_REMOTE_TOKEN --model $(shell_quote "$model") --sandbox $(shell_quote "$sandbox") -C $(shell_quote "/workspace/projects/busdk/$module") --add-dir /workspace/projects/busdk --no-alt-screen \"\$prompt\""
	;;

attach)
	name=${1:-}
	[ -n "$name" ] || usage
	container=$(remote_meta "$name" container)
	port=$(remote_meta "$name" port)
	model=$(remote_meta "$name" model)
	sandbox=$(remote_meta "$name" sandbox)
	module=$(remote_meta "$name" module)
	[ -n "$container" ] && [ -n "$port" ] || {
		printf 'worker not found or missing metadata: %s\n' "$name" >&2
		exit 1
	}
	remote_url="ws://127.0.0.1:$port"
	ssh -t "$REMOTE" "token=\$(cat $(shell_quote "$(worker_dir "$name")/ws-token")); docker exec -it -e CODEX_REMOTE_TOKEN=\"\$token\" $(shell_quote "$container") codex --remote $(shell_quote "$remote_url") --remote-auth-token-env CODEX_REMOTE_TOKEN --model $(shell_quote "$model") --sandbox $(shell_quote "$sandbox") -C $(shell_quote "/workspace/projects/busdk/$module") --add-dir /workspace/projects/busdk --no-alt-screen"
	;;

logs)
	name=${1:-}
	[ -n "$name" ] || usage
	container=$(remote_meta "$name" container)
	[ -n "$container" ] || {
		printf 'worker not found or missing metadata: %s\n' "$name" >&2
		exit 1
	}
	ssh "$REMOTE" "docker logs -f --tail 120 $(shell_quote "$container")"
	;;

status)
	name=${1:-}
	if [ -n "$name" ]; then
		container=$(remote_meta "$name" container)
		[ -n "$container" ] || {
			printf 'worker not found or missing metadata: %s\n' "$name" >&2
			exit 1
		}
		ssh "$REMOTE" "docker ps -a --filter name=$(shell_quote "$container")"
	else
		ssh "$REMOTE" "docker ps -a --filter name=bus-manual-spark-"
	fi
	;;

stop)
	name=${1:-}
	[ -n "$name" ] || usage
	container=$(remote_meta "$name" container)
	[ -n "$container" ] || {
		printf 'worker not found or missing metadata: %s\n' "$name" >&2
		exit 1
	}
	ssh "$REMOTE" "docker stop $(shell_quote "$container") >/dev/null && docker rm $(shell_quote "$container") >/dev/null"
	printf 'stopped %s\n' "$name"
	;;

*)
	usage
	;;
esac
