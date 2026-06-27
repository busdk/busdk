#!/bin/sh
set -eu

# Minimal manual Spark worker launcher.
# This intentionally does not use bus-task, Bus Events, Docker, or providers.

SCRIPT_DIR=$(CDPATH= cd "$(dirname "$0")" && pwd)
DEFAULT_REPO=$(CDPATH= cd "$SCRIPT_DIR/.." && pwd)
. "$DEFAULT_REPO/scripts/lib-worker-template.sh"

HOST=${BUS_MANUAL_SPARK_HOST:-local}
REPO=${BUS_MANUAL_SPARK_REPO:-$DEFAULT_REPO}
WORKER_ROOT=${BUS_MANUAL_SPARK_WORKER_ROOT:-$REPO/tmp/workers}
WORKER_REPO=${BUS_MANUAL_SPARK_WORKER_REPO:-$REPO/agents/worker}
TEMPLATE=${BUS_MANUAL_SPARK_TEMPLATE:-}
MODEL=${BUS_MANUAL_SPARK_MODEL:-}
SANDBOX=${BUS_MANUAL_SPARK_SANDBOX:-workspace-write}
CODEX_CMD=${BUS_MANUAL_SPARK_CODEX:-codex}
AUTH_HOME=${BUS_MANUAL_SPARK_AUTH_HOME:-${CODEX_HOME:-$HOME/.codex}}
BASE_REF=${BUS_MANUAL_SPARK_BASE_REF:-HEAD}
WORKER_BASE_REF=${BUS_MANUAL_SPARK_WORKER_BASE_REF:-HEAD}
SESSION_BACKEND=${BUS_MANUAL_SPARK_SESSION_BACKEND:-screen}
PATH_PREFIX=${BUS_MANUAL_SPARK_PATH_PREFIX:-$REPO/bin:$REPO/scripts:$HOME/.local/bin:$HOME/go/bin:/usr/local/go/bin}

usage() {
	cat >&2 <<'USAGE'
usage:
  manual-dev-hg-spark-worker.sh start NAME MODULE BRANCH PROMPT_FILE
  manual-dev-hg-spark-worker.sh prompt NAME [PROMPT_FILE]
  manual-dev-hg-spark-worker.sh attach NAME
  manual-dev-hg-spark-worker.sh logs NAME
  manual-dev-hg-spark-worker.sh status [NAME]
  manual-dev-hg-spark-worker.sh stop NAME

Starts host-run Codex workers without Docker or virtualization. Each worker gets
a BusDK product worktree, a module implementation branch, a worker identity
worktree from agents/worker, worker-local memo/log/scratch paths, isolated
CODEX_HOME, and a Codex session with an explicit sandbox.

The default session backend is screen. The worker inherits a Go-friendly tool
environment with PATH_PREFIX prepended so it can run git, go, make, Bus
binaries, and module-local scripts from inside the Codex sandbox.

Environment overrides:
  BUS_MANUAL_SPARK_HOST             default local
  BUS_MANUAL_SPARK_REPO             default parent of this script directory
  BUS_MANUAL_SPARK_WORKER_ROOT      default $REPO/tmp/workers
  BUS_MANUAL_SPARK_WORKER_REPO      default $REPO/agents/worker
  BUS_MANUAL_SPARK_TEMPLATE         required unless using BUS_MANUAL_SPARK_MODEL compatibility override
  BUS_MANUAL_SPARK_MODEL            optional explicit model override
  BUS_MANUAL_SPARK_SANDBOX          default workspace-write
  BUS_MANUAL_SPARK_CODEX            default codex
  BUS_MANUAL_SPARK_AUTH_HOME        default CODEX_HOME or $HOME/.codex
  BUS_MANUAL_SPARK_BASE_REF         default HEAD
  BUS_MANUAL_SPARK_WORKER_BASE_REF  default HEAD
  BUS_MANUAL_SPARK_SESSION_BACKEND  default screen
  BUS_MANUAL_SPARK_PATH_PREFIX      default repo/bin, repo/scripts, common Go paths
USAGE
	exit 2
}

shell_quote() {
	printf "'%s'" "$(printf "%s" "$1" | sed "s/'/'\\\\''/g")"
}

worker_dir() {
	printf '%s/%s\n' "$WORKER_ROOT" "$1"
}

meta_file_for() {
	printf '%s/meta.env\n' "$(worker_dir "$1")"
}

meta_value() {
	mv_name=$1
	mv_key=$2
	mv_meta=$(meta_file_for "$mv_name")
	if [ -f "$mv_meta" ]; then
		sed -n "s/^$mv_key=//p" "$mv_meta" | tail -1
	fi
}

validate_worker() {
	case "$1" in
		''|*[!abcdefghijklmnopqrstuvwxyz0123456789-]*)
			printf 'worker NAME must be a lowercase slug using letters, digits, and dash: %s\n' "$1" >&2
			exit 2
			;;
	esac
}

validate_module() {
	case "$1" in
		''|*/*|*..*|*[!abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_.-]*)
			printf 'MODULE must be a BusDK module directory name without slashes or shell metacharacters: %s\n' "$1" >&2
			exit 2
			;;
	esac
}

validate_branch() {
	if ! git check-ref-format --branch "$1" >/dev/null 2>&1; then
		printf 'invalid branch name: %s\n' "$1" >&2
		exit 2
	fi
}

require_local_host() {
	case "$HOST" in
		local|localhost|127.0.0.1|'')
			;;
		*)
			printf 'remote host mode is not implemented by this host-run launcher yet: %s\n' "$HOST" >&2
			printf 'run on macOS/local host with BUS_MANUAL_SPARK_HOST=local\n' >&2
			exit 2
			;;
	esac
}

require_command() {
	if ! command -v "$1" >/dev/null 2>&1; then
		printf 'required command not found in PATH: %s\n' "$1" >&2
		exit 1
	fi
}

screen_session_alive() {
	ssa_session=$1
	screen -ls 2>/dev/null | grep -Eq "[.]$ssa_session([[:space:]]|$)"
}

ensure_worker_repo() {
	if [ -d "$WORKER_REPO/.git" ] || [ -f "$WORKER_REPO/.git" ]; then
		return 0
	fi
	git -C "$REPO" submodule update --init agents/worker
	if [ ! -d "$WORKER_REPO/.git" ] && [ ! -f "$WORKER_REPO/.git" ]; then
		printf 'worker identity repository is not initialized: %s\n' "$WORKER_REPO" >&2
		exit 1
	fi
}

add_worktree() {
	aw_repo=$1
	aw_path=$2
	aw_branch=$3
	aw_base_ref=$4
	if [ -d "$aw_path/.git" ] || [ -f "$aw_path/.git" ]; then
		return 0
	fi
	mkdir -p "$(dirname "$aw_path")"
	if git -C "$aw_repo" show-ref --verify --quiet "refs/heads/$aw_branch"; then
		git -C "$aw_repo" worktree add "$aw_path" "$aw_branch"
	else
		git -C "$aw_repo" worktree add -b "$aw_branch" "$aw_path" "$aw_base_ref"
	fi
}

init_module_checkout() {
	im_product_worktree=$1
	im_module=$2
	if [ -d "$im_product_worktree/$im_module/.git" ] || [ -f "$im_product_worktree/$im_module/.git" ]; then
		return 0
	fi
	git -C "$im_product_worktree" submodule update --init "$im_module"
}

init_go_replace_siblings() {
	igr_product_worktree=$1
	igr_module=$2
	igr_go_mod="$igr_product_worktree/$igr_module/go.mod"
	if [ ! -f "$igr_go_mod" ]; then
		return 0
	fi
	sed -n 's/^[[:space:]]*replace[[:space:]][^=]*=>[[:space:]]*..\/\([^[:space:]]*\).*/\1/p' "$igr_go_mod" | while IFS= read -r igr_dep_module; do
		case "$igr_dep_module" in
			''|*/*|.*)
				continue
				;;
		esac
		if [ "$igr_dep_module" != "$igr_module" ]; then
			init_module_checkout "$igr_product_worktree" "$igr_dep_module"
		fi
	done
}

prepare_codex_home() {
	pch_codex_home=$1
	mkdir -p "$pch_codex_home"
	chmod 700 "$pch_codex_home" 2>/dev/null || true
	if [ -d "$AUTH_HOME" ] && [ ! -e "$pch_codex_home/config.toml" ] && [ ! -e "$pch_codex_home/auth.json" ]; then
		(umask 077; cp -pR "$AUTH_HOME/." "$pch_codex_home"/ 2>/dev/null || true)
	fi
	chmod -R u+rwX,go-rwx "$pch_codex_home" 2>/dev/null || true
}

write_worker_identity_files() {
	wwif_name=$1
	wwif_module=$2
	wwif_branch=$3
	wwif_identity_worktree=$4
	wwif_prompt_file=$5
	mkdir -p "$wwif_identity_worktree/logs" "$wwif_identity_worktree/memory"
	cp "$wwif_prompt_file" "$wwif_identity_worktree/TASK.md"
	cat >"$wwif_identity_worktree/SUPERVISOR.md" <<EOF
# Manual Spark Worker Assignment

Worker: $wwif_name
Module: $wwif_module
Implementation branch: $wwif_branch
Template: $TEMPLATE
Model: $MODEL
Sandbox: $SANDBOX

Rules:
- Work only on the assigned implementation slice and focused unit tests.
- Use the BusDK product worktree for product/module changes.
- Use this worker identity worktree for editable operating rules, memory, and
  memo logs.
- Keep memo logs under ./logs using the hourly agent memo convention.
- Do not commit, push, or delete unrelated work unless the supervisor asks.
EOF
	if ! grep -q '^## Manual Bootstrap Assignment$' "$wwif_identity_worktree/AGENTS.md" 2>/dev/null; then
		cat >>"$wwif_identity_worktree/AGENTS.md" <<EOF

## Manual Bootstrap Assignment

This worker identity branch is assigned to worker $wwif_name.

Read SUPERVISOR.md and TASK.md before changing product files. Keep durable
worker memory and hourly memo logs in this identity worktree. Product changes
belong in the assigned BusDK product worktree and module branch.
EOF
	fi
}

write_runner() {
	wr_runner=$1
	wr_product_worktree=$2
	wr_identity_worktree=$3
	wr_module=$4
	wr_prompt_file=$5
	wr_log_file=$6
	wr_codex_home=$7
	cat >"$wr_runner" <<EOF
#!/bin/sh
set -eu
export CODEX_HOME=$(shell_quote "$wr_codex_home")
export BUSDK_ROOT=$(shell_quote "$wr_product_worktree")
export BUS_WORKER_IDENTITY_ROOT=$(shell_quote "$wr_identity_worktree")
export PATH=$(shell_quote "$PATH_PREFIX"):\$PATH
mkdir -p "\$CODEX_HOME"
cd $(shell_quote "$wr_product_worktree/$wr_module")
printf 'manual Spark worker started at %s\n' "\$(date -u '+%Y-%m-%dT%H:%M:%SZ')" >>$(shell_quote "$wr_log_file")
printf 'workdir=%s\nidentity=%s\nmodel=%s\nsandbox=%s\n' $(shell_quote "$wr_product_worktree/$wr_module") $(shell_quote "$wr_identity_worktree") $(shell_quote "$MODEL") $(shell_quote "$SANDBOX") >>$(shell_quote "$wr_log_file")
exec $(shell_quote "$CODEX_CMD") \\
  --model $(shell_quote "$MODEL") \\
  --sandbox $(shell_quote "$SANDBOX") \\
  -C $(shell_quote "$wr_product_worktree/$wr_module") \\
  --add-dir $(shell_quote "$wr_product_worktree") \\
  --add-dir $(shell_quote "$wr_identity_worktree") \\
  --no-alt-screen \\
  "\$(cat $(shell_quote "$wr_prompt_file"))"
EOF
	chmod +x "$wr_runner"
}

cmd=${1:-}
[ -n "$cmd" ] || usage
shift

case "$cmd" in
start)
	name=${1:-}
	module=${2:-}
	branch=${3:-}
	prompt_source=${4:-}
	[ -n "$name" ] && [ -n "$module" ] && [ -n "$branch" ] && [ -n "$prompt_source" ] || usage
	validate_worker "$name"
	validate_module "$module"
	validate_branch "$branch"
	require_local_host
	require_command git
	require_command go
	require_command make
	require_command "$CODEX_CMD"
	if [ -z "$MODEL" ]; then
		if [ -z "$TEMPLATE" ]; then
			printf 'set BUS_MANUAL_SPARK_TEMPLATE to an environment-local worker template, or set BUS_MANUAL_SPARK_MODEL as a compatibility override\n' >&2
			exit 2
		fi
		resolve_worker_template "$REPO" "$TEMPLATE"
		MODEL=$BUS_WORKER_TEMPLATE_MODEL
	fi
	if [ "$SESSION_BACKEND" = "screen" ]; then
		require_command screen
	else
		printf 'unsupported BUS_MANUAL_SPARK_SESSION_BACKEND: %s\n' "$SESSION_BACKEND" >&2
		exit 2
	fi
	if [ ! -f "$prompt_source" ]; then
		printf 'prompt file not found: %s\n' "$prompt_source" >&2
		exit 2
	fi
	if [ ! -d "$REPO/.git" ] && [ ! -f "$REPO/.git" ]; then
		printf 'BusDK repository not found: %s\n' "$REPO" >&2
		exit 1
	fi
	ensure_worker_repo

	dir=$(worker_dir "$name")
	product_worktree="$dir/product"
	identity_worktree="$dir/agent-worker"
	logs_path="$dir/logs"
	scratch_path="$dir/scratch"
	codex_home="$dir/codex-home"
	prompt_file="$dir/prompt.md"
	live_prompt="$dir/live-prompt.md"
	meta_file="$dir/meta.env"
	runner="$dir/run-codex.sh"
	log_file="$logs_path/screenlog.0"
	pid_file="$dir/pid"
	session="bus-manual-spark-$name"
	identity_branch="worker/$name"
	lockdir="$WORKER_ROOT/.manual-spark.lock"

	mkdir -p "$WORKER_ROOT"
	while ! mkdir "$lockdir" 2>/dev/null; do
		sleep 1
	done
	trap 'rmdir "$lockdir" 2>/dev/null || true' EXIT INT TERM

	if [ -f "$meta_file" ]; then
		old_worker=$(meta_value "$name" worker)
		old_session=$(meta_value "$name" session_name)
		if [ "$old_worker" != "$name" ]; then
			printf 'metadata at %s belongs to another worker: %s\n' "$meta_file" "$old_worker" >&2
			exit 1
		fi
		if [ -n "$old_session" ] && screen_session_alive "$old_session"; then
			printf 'worker already appears live: %s\n' "$name" >&2
			printf 'use status, attach, prompt, logs, stop, or an explicit recovery flow\n' >&2
			exit 1
		fi
	fi

	mkdir -p "$dir" "$logs_path" "$scratch_path"
	cp "$prompt_source" "$prompt_file"
	cp "$prompt_source" "$live_prompt"

	add_worktree "$REPO" "$product_worktree" "$branch" "$BASE_REF"
	init_module_checkout "$product_worktree" "$module"
	if [ -d "$product_worktree/$module/.git" ] || [ -f "$product_worktree/$module/.git" ]; then
		if git -C "$product_worktree/$module" show-ref --verify --quiet "refs/heads/$branch"; then
			git -C "$product_worktree/$module" checkout "$branch"
		else
			git -C "$product_worktree/$module" checkout -b "$branch"
		fi
	fi
	init_go_replace_siblings "$product_worktree" "$module"

	add_worktree "$WORKER_REPO" "$identity_worktree" "$identity_branch" "$WORKER_BASE_REF"
	write_worker_identity_files "$name" "$module" "$branch" "$identity_worktree" "$prompt_file"
	prepare_codex_home "$codex_home"
	write_runner "$runner" "$product_worktree" "$identity_worktree" "$module" "$prompt_file" "$log_file" "$codex_home"

	cat >"$meta_file" <<EOF
worker=$name
module=$module
branch=$branch
worktree_path=$product_worktree
worker_identity_branch=$identity_branch
worker_identity_worktree_path=$identity_worktree
logs_path=$logs_path
scratch_path=$scratch_path
codex_home=$codex_home
prompt_file=$prompt_file
live_prompt=$live_prompt
runner=$runner
session_backend=$SESSION_BACKEND
session_name=$session
pid_file=$pid_file
template=$TEMPLATE
model=$MODEL
sandbox=$SANDBOX
codex_cmd=$CODEX_CMD
host=$HOST
created_at=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
owner=manual-spark-worker-bootstrap
EOF

	(cd "$logs_path" && screen -L -dmS "$session" /bin/sh "$runner")
	printf '%s\n' "$$" >"$pid_file"

	printf 'worker=%s\nsession=%s\nproduct_worktree=%s\nmodule=%s\nbranch=%s\nidentity_branch=%s\nidentity_worktree=%s\nlogs=%s\ncodex_home=%s\ntemplate=%s\nmodel=%s\nsandbox=%s\n' \
		"$name" "$session" "$product_worktree" "$module" "$branch" "$identity_branch" "$identity_worktree" "$logs_path" "$codex_home" "$TEMPLATE" "$MODEL" "$SANDBOX"
	printf '\nAttach with:\n  %s attach %s\n' "$0" "$name"
	printf '\nSend more guidance with:\n  %s prompt %s /path/to/prompt.md\n' "$0" "$name"
	;;

prompt)
	name=${1:-}
	override_prompt=${2:-}
	[ -n "$name" ] || usage
	validate_worker "$name"
	require_local_host
	require_command screen
	session=$(meta_value "$name" session_name)
	live_prompt=$(meta_value "$name" live_prompt)
	[ -n "$session" ] && [ -n "$live_prompt" ] || {
		printf 'worker not found or missing metadata: %s\n' "$name" >&2
		exit 1
	}
	if ! screen_session_alive "$session"; then
		printf 'worker session is not live: %s\n' "$session" >&2
		exit 1
	fi
	if [ -n "$override_prompt" ]; then
		if [ ! -f "$override_prompt" ]; then
			printf 'prompt file not found: %s\n' "$override_prompt" >&2
			exit 2
		fi
		cp "$override_prompt" "$live_prompt"
	fi
	screen -S "$session" -X readbuf "$live_prompt"
	screen -S "$session" -X paste .
	screen -S "$session" -X stuff "$(printf '\015')"
	printf 'sent prompt to %s\n' "$name"
	;;

attach)
	name=${1:-}
	[ -n "$name" ] || usage
	validate_worker "$name"
	require_local_host
	require_command screen
	session=$(meta_value "$name" session_name)
	[ -n "$session" ] || {
		printf 'worker not found or missing metadata: %s\n' "$name" >&2
		exit 1
	}
	screen -r "$session"
	;;

logs)
	name=${1:-}
	[ -n "$name" ] || usage
	validate_worker "$name"
	logs_path=$(meta_value "$name" logs_path)
	[ -n "$logs_path" ] || {
		printf 'worker not found or missing metadata: %s\n' "$name" >&2
		exit 1
	}
	tail -n 120 -f "$logs_path/screenlog.0"
	;;

status)
	name=${1:-}
	if [ -n "$name" ]; then
		validate_worker "$name"
		meta=$(meta_file_for "$name")
		if [ ! -f "$meta" ]; then
			printf 'worker not found: %s\n' "$name" >&2
			exit 1
		fi
		cat "$meta"
		session=$(meta_value "$name" session_name)
		if [ -n "$session" ] && command -v screen >/dev/null 2>&1 && screen_session_alive "$session"; then
			printf 'live=true\n'
		else
			printf 'live=false\n'
		fi
	else
		for meta in "$WORKER_ROOT"/*/meta.env; do
			[ -f "$meta" ] || continue
			sed -n 's/^worker=/worker=/p; s/^module=/module=/p; s/^branch=/branch=/p; s/^session_name=/session_name=/p' "$meta"
			printf '\n'
		done
	fi
	;;

stop)
	name=${1:-}
	[ -n "$name" ] || usage
	validate_worker "$name"
	require_local_host
	require_command screen
	session=$(meta_value "$name" session_name)
	[ -n "$session" ] || {
		printf 'worker not found or missing metadata: %s\n' "$name" >&2
		exit 1
	}
	if screen_session_alive "$session"; then
		screen -S "$session" -X quit
		printf 'stopped %s\n' "$name"
	else
		printf 'worker session was not live: %s\n' "$name"
	fi
	;;

*)
	usage
	;;
esac
