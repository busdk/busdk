#!/bin/sh
set -eu

# Proves the H100 local-model path can make a controlled writable change and
# preserve it through the dev-task worktree/commit path.

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

STAMP=$(date +%Y%m%d%H%M%S)
MODEL=${BUS_H100_WRITE_SMOKE_MODEL:-gemma4:31b}
MODEL_ENDPOINT=${BUS_H100_WRITE_SMOKE_MODEL_ENDPOINT:-http://127.0.0.1:11434}
REMOTE_ROOT=${BUS_H100_WRITE_SMOKE_REMOTE_ROOT:-/home/dev/workspace/busdk/busdk}
SSH_TARGET=${BUS_H100_WRITE_SMOKE_SSH_TARGET:-dev@ai.hg.fi}
BRANCH=${BUS_H100_WRITE_SMOKE_BRANCH:-codex/h100-local-model-write-smoke-${STAMP}}
BASE_BRANCH=${BUS_H100_WRITE_SMOKE_BASE_BRANCH:-}
SMOKE_FILE=${BUS_H100_WRITE_SMOKE_FILE:-testdata/h100-local-model-write-smoke.txt}
COMMIT_MESSAGE=${BUS_H100_WRITE_SMOKE_COMMIT_MESSAGE:-test: h100 local-model write smoke}
EXPECTED=${BUS_H100_WRITE_SMOKE_EXPECTED:-The Bus H100 local model worker wrote this file.}
WAIT_TIMEOUT=${BUS_H100_WRITE_SMOKE_WAIT_TIMEOUT:-10m}
RUN_WAIT_TIMEOUT=${BUS_H100_WRITE_SMOKE_RUN_SSH_WAIT_TIMEOUT:-900}
VERIFY_SSH_WAIT_TIMEOUT=${BUS_H100_WRITE_SMOKE_VERIFY_SSH_WAIT_TIMEOUT:-300}
MODE=${BUS_H100_WRITE_SMOKE_MODE:-run}
STATE_FILE=${BUS_H100_WRITE_SMOKE_STATE_FILE:-${TMPDIR:-/tmp}/bus-h100-local-model-write-smoke.env}
REASONING_EFFORT=${BUS_H100_WRITE_SMOKE_REASONING_EFFORT:-}
KEEP_CONTAINER=${BUS_H100_WRITE_SMOKE_KEEP_CONTAINER:-false}
SMOKE_DIR=${BUS_H100_WRITE_SMOKE_DIR:-}
RUNNER_LOG=${BUS_H100_WRITE_SMOKE_RUNNER_LOG:-}

usage() {
	cat >&2 <<'USAGE'
usage: test-h100-local-model-write-smoke.sh [options]

Options override compatibility BUS_H100_WRITE_SMOKE_* environment variables.
The default target is dev@ai.hg.fi and the default model is gemma4:31b.

  --mode run|verify|resume       operation mode
  --model MODEL                  local model name, e.g. gpt-oss:120b
  --model-endpoint URL           Ollama-compatible endpoint
  --reasoning-effort EFFORT      none|minimal|low|medium|high|xhigh|hard
  --ssh-target USER@HOST         H100 SSH target
  --remote-root DIR              H100 BusDK checkout path
  --branch BRANCH                branch created by the write smoke
  --base-branch BRANCH           optional task base branch
  --file PATH                    controlled file written by the worker
  --commit-message TEXT          worker commit message
  --expected TEXT                exact text expected in the written file
  --wait-timeout DURATION        bus-dev work wait timeout
  --run-ssh-wait-timeout SEC     long remote run timeout
  --verify-ssh-wait-timeout SEC  verification SSH timeout
  --state-file FILE              resume/verify state file
  --keep-container[=BOOL]        keep worker container after the smoke
  --smoke-dir DIR                remote smoke project directory
  --runner-log FILE              remote runner log path
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
		--mode) need_arg "$@"; MODE=$2; shift 2 ;;
		--model) need_arg "$@"; MODEL=$2; shift 2 ;;
		--model-endpoint|--endpoint) need_arg "$@"; MODEL_ENDPOINT=$2; shift 2 ;;
		--reasoning-effort|--reasoning) need_arg "$@"; REASONING_EFFORT=$2; shift 2 ;;
		--ssh-target) need_arg "$@"; SSH_TARGET=$2; shift 2 ;;
		--remote-root) need_arg "$@"; REMOTE_ROOT=$2; shift 2 ;;
		--branch) need_arg "$@"; BRANCH=$2; shift 2 ;;
		--base-branch) need_arg "$@"; BASE_BRANCH=$2; shift 2 ;;
		--file|--smoke-file) need_arg "$@"; SMOKE_FILE=$2; shift 2 ;;
		--commit-message) need_arg "$@"; COMMIT_MESSAGE=$2; shift 2 ;;
		--expected) need_arg "$@"; EXPECTED=$2; shift 2 ;;
		--wait-timeout) need_arg "$@"; WAIT_TIMEOUT=$2; shift 2 ;;
		--run-ssh-wait-timeout) need_arg "$@"; RUN_WAIT_TIMEOUT=$2; shift 2 ;;
		--verify-ssh-wait-timeout) need_arg "$@"; VERIFY_SSH_WAIT_TIMEOUT=$2; shift 2 ;;
		--state-file) need_arg "$@"; STATE_FILE=$2; shift 2 ;;
		--keep-container) KEEP_CONTAINER=true; shift ;;
		--keep-container=*) KEEP_CONTAINER=${1#*=}; shift ;;
		--no-keep-container) KEEP_CONTAINER=false; shift ;;
		--smoke-dir) need_arg "$@"; SMOKE_DIR=$2; shift 2 ;;
		--runner-log) need_arg "$@"; RUNNER_LOG=$2; shift 2 ;;
		--help|-h) usage; exit 0 ;;
		*)
			printf 'unknown option: %s\n' "$1" >&2
			usage
			exit 2
			;;
	esac
done

case "$REASONING_EFFORT" in
	''|none|minimal|low|medium|high|xhigh|hard) ;;
	*)
		printf 'invalid reasoning effort: %s\n' "$REASONING_EFFORT" >&2
		exit 2
		;;
esac

case "$VERIFY_SSH_WAIT_TIMEOUT" in
	''|*[!0-9]*)
		printf 'invalid BUS_H100_WRITE_SMOKE_VERIFY_SSH_WAIT_TIMEOUT=%s; expected a positive integer\n' "$VERIFY_SSH_WAIT_TIMEOUT" >&2
		exit 2
		;;
	0)
		printf 'invalid BUS_H100_WRITE_SMOKE_VERIFY_SSH_WAIT_TIMEOUT=0; use a positive integer\n' >&2
		exit 2
		;;
esac

json_escape() {
	printf '%s' "$1" | awk '
		BEGIN { sep = "" }
		{
			gsub(/\\/, "\\\\")
			gsub(/"/, "\\\"")
			printf "%s%s", sep, $0
			sep = "\\n"
		}
	'
}

shell_quote() {
	printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"
}

run_ssh_with_input_timeout() {
	wait_timeout=$1
	input_file=$2
	shift 2
	out=$(mktemp "${TMPDIR:-/tmp}/bus-h100-write-ssh-out.XXXXXX")
	err=$(mktemp "${TMPDIR:-/tmp}/bus-h100-write-ssh-err.XXXXXX")
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
	status=0
	wait "$pid" || status=$?
	cat "$out"
	cat "$err" >&2
	rm -f "$out" "$err"
	return "$status"
}

run_ssh_command_with_timeout() {
	wait_timeout=$1
	shift
	run_ssh_with_input_timeout "$wait_timeout" /dev/null "$@"
}

run_ssh_script_with_timeout() {
	wait_timeout=$1
	script=$(mktemp "${TMPDIR:-/tmp}/bus-h100-write-ssh-script.XXXXXX")
	cat > "$script"
	status=0
	run_ssh_with_input_timeout "$wait_timeout" "$script" sh -s || status=$?
	rm -f "$script"
	return "$status"
}

write_state() {
	{
		printf 'BUS_H100_WRITE_SMOKE_SSH_TARGET=%s\n' "$(shell_quote "$SSH_TARGET")"
		printf 'BUS_H100_WRITE_SMOKE_REMOTE_ROOT=%s\n' "$(shell_quote "$REMOTE_ROOT")"
		printf 'BUS_H100_WRITE_SMOKE_BRANCH=%s\n' "$(shell_quote "$BRANCH")"
		printf 'BUS_H100_WRITE_SMOKE_FILE=%s\n' "$(shell_quote "$SMOKE_FILE")"
		printf 'BUS_H100_WRITE_SMOKE_EXPECTED=%s\n' "$(shell_quote "$EXPECTED")"
	} > "$STATE_FILE"
}

verify_result() {
	remote_root_q=$(shell_quote "$REMOTE_ROOT")
	branch_q=$(shell_quote "$BRANCH")
	smoke_file_q=$(shell_quote "$SMOKE_FILE")
	expected_q=$(shell_quote "$EXPECTED")
	run_ssh_script_with_timeout "$VERIFY_SSH_WAIT_TIMEOUT" <<VERIFY
set -eu
cd $remote_root_q/bus-dev
git show $branch_q:$smoke_file_q | grep -q $expected_q
git log -1 --format='%H %s' $branch_q
VERIFY
}

if { [ "$MODE" = verify ] || [ "$MODE" = resume ]; } && [ -f "$STATE_FILE" ]; then
	. "$STATE_FILE"
fi

case "$MODE" in
	run)
		write_state
		;;
	verify)
		verify_result
		exit 0
		;;
	resume)
		set +e
		verify_result
		verify_status=$?
		set -e
		case "$verify_status" in
			0)
				exit 0
				;;
			124|255)
				exit "$verify_status"
				;;
			*)
				printf 'existing H100 write-smoke branch was not verified; running a fresh smoke\n' >&2
				write_state
				;;
		esac
		;;
	*)
		printf 'invalid BUS_H100_WRITE_SMOKE_MODE=%s; expected run, verify, or resume\n' "$MODE" >&2
		exit 2
		;;
esac

case "$REASONING_EFFORT" in
	'')
		think_json=
		reasoning_label=default
		;;
	none)
		think_json=',"think":false'
		reasoning_label=none
		;;
	minimal|low|medium|high|xhigh|hard)
		think_json=',"think":true'
		reasoning_label=$REASONING_EFFORT
		;;
esac
payload=$(printf '{"model":"%s","prompt":"Reply with exactly this sentence and no markdown: %s","stream":false%s}' "$MODEL" "$EXPECTED" "$think_json")
payload_q=$(shell_quote "$payload")
command=$(cat <<EOF
set -eu
mkdir -p "$(dirname "$SMOKE_FILE")"
response=\$(curl -fsS --max-time 180 "${MODEL_ENDPOINT%/}/api/generate" -H 'Content-Type: application/json' --data-binary $payload_q)
{
  printf 'h100 local-model write smoke\n'
  printf 'model: %s\n' "$MODEL"
  printf 'reasoning-effort: %s\n' "$reasoning_label"
  printf 'expected: %s\n' "$EXPECTED"
  printf 'response: %s\n' "\$response"
} > "$SMOKE_FILE"
grep -q "$EXPECTED" "$SMOKE_FILE"
EOF
)
COMMAND_JSON=$(printf '["sh","-lc","%s"]' "$(json_escape "$command")")
post_command=$(printf 'test -s "%s" && grep -q "%s" "%s"' "$SMOKE_FILE" "$EXPECTED" "$SMOKE_FILE")
POST_COMMAND_JSON=$(printf '["sh","-lc","%s"]' "$(json_escape "$post_command")")

set -- "$ROOT/scripts/test-h100-local-model-worker-smoke.sh" \
	--ssh-target "$SSH_TARGET" \
	--remote-root "$REMOTE_ROOT" \
	--model "$MODEL" \
	--model-endpoint "$MODEL_ENDPOINT" \
	--wait-timeout "$WAIT_TIMEOUT" \
	--run-ssh-wait-timeout "$RUN_WAIT_TIMEOUT" \
	--model-command-json "$COMMAND_JSON" \
	--model-post-command-json "$POST_COMMAND_JSON" \
	--model-worktree \
	--model-commit \
	--model-write-scope "$SMOKE_FILE" \
	--model-new-branch "$BRANCH" \
	--model-base-branch "$BASE_BRANCH" \
	--model-commit-message "$COMMIT_MESSAGE"
case "$KEEP_CONTAINER" in
	true|1|yes|on) set -- "$@" --keep-container ;;
	false|0|no|off|'') ;;
	*) set -- "$@" --keep-container="$KEEP_CONTAINER" ;;
esac
if [ -n "$SMOKE_DIR" ]; then
	set -- "$@" --smoke-dir "$SMOKE_DIR"
fi
if [ -n "$RUNNER_LOG" ]; then
	set -- "$@" --runner-log "$RUNNER_LOG"
fi
"$@"

verify_result
