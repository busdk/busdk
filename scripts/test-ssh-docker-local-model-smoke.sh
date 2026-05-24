#!/bin/sh
set -eu

# Runs the image-backed SSH-Docker smoke with a model-backed container command.
# The target host must already expose a model endpoint reachable from task
# containers, for example an Ollama container on the same Docker network.

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

MODEL=${BUS_SSH_DOCKER_MODEL_SMOKE_MODEL:-${BUS_UPCLOUD_OFFLOAD_MODEL:-gemma4:31b}}
MODEL_ENDPOINT=${BUS_SSH_DOCKER_MODEL_SMOKE_ENDPOINT:-${BUS_UPCLOUD_OFFLOAD_MODEL_ENDPOINT:-http://ollama:11434}}
WORKER_IMAGE=${BUS_SSH_DOCKER_MODEL_SMOKE_IMAGE:-${BUS_SSH_DOCKER_SMOKE_IMAGE:-bus-integration-dev-task:local-image-smoke}}
PROMPT=${BUS_SSH_DOCKER_MODEL_SMOKE_PROMPT:-Reply with one short sentence confirming the Bus remote model worker can reach local inference.}
TASK_PROMPT=${BUS_SSH_DOCKER_MODEL_SMOKE_TASK_PROMPT:-}
TOOL_PROFILE=${BUS_SSH_DOCKER_MODEL_SMOKE_TOOL_PROFILE:-shell-only}
COMMAND_JSON=${BUS_SSH_DOCKER_MODEL_SMOKE_COMMAND_JSON:-}
POST_COMMAND_JSON=${BUS_SSH_DOCKER_MODEL_SMOKE_POST_COMMAND_JSON:-${BUS_SSH_DOCKER_SMOKE_POST_COMMAND_JSON:-}}
WORKTREE=${BUS_SSH_DOCKER_MODEL_SMOKE_WORKTREE:-${BUS_SSH_DOCKER_SMOKE_WORKTREE:-false}}
COMMIT=${BUS_SSH_DOCKER_MODEL_SMOKE_COMMIT:-${BUS_SSH_DOCKER_SMOKE_COMMIT:-false}}
WRITE_SCOPE=${BUS_SSH_DOCKER_MODEL_SMOKE_WRITE_SCOPE:-${BUS_SSH_DOCKER_SMOKE_WRITE_SCOPE:-}}
NEW_BRANCH=${BUS_SSH_DOCKER_MODEL_SMOKE_NEW_BRANCH:-${BUS_SSH_DOCKER_SMOKE_NEW_BRANCH:-}}
BASE_BRANCH=${BUS_SSH_DOCKER_MODEL_SMOKE_BASE_BRANCH:-${BUS_SSH_DOCKER_SMOKE_BASE_BRANCH:-}}
COMMIT_MESSAGE=${BUS_SSH_DOCKER_MODEL_SMOKE_COMMIT_MESSAGE:-${BUS_SSH_DOCKER_SMOKE_COMMIT_MESSAGE:-}}

usage() {
	cat >&2 <<'USAGE'
usage: test-ssh-docker-local-model-smoke.sh [options] [-- image-smoke-options...]

Options override compatibility BUS_SSH_DOCKER_MODEL_SMOKE_* environment
variables. Unknown lower-level SSH-Docker smoke options can be passed after
-- and are forwarded to test-ssh-docker-image-smoke.sh.

  --model MODEL                  local model name
  --model-endpoint URL           Ollama-compatible endpoint
  --image IMAGE                  worker launcher/container image
  --prompt TEXT                  model prompt when command JSON is omitted
  --task-prompt TEXT             dev-task prompt forwarded to bus-dev
  --tool-profile NAME            tool profile hint: shell-only or unrestricted
  --command-json JSON            explicit command JSON
  --post-command-json JSON       explicit post-command JSON
  --worktree[=BOOL]              request a task worktree
  --commit[=BOOL]                request worker commit
  --write-scope PATH             task write scope
  --new-branch BRANCH            task new branch
  --base-branch BRANCH           task base branch
  --commit-message TEXT          worker commit message
USAGE
}

need_arg() {
	if [ "$#" -lt 2 ]; then
		printf 'missing value for %s\n' "$1" >&2
		usage
		exit 2
	fi
}

set -- "$@"
while [ "$#" -gt 0 ]; do
	case "$1" in
		--)
			shift
			break
			;;
		--model) need_arg "$@"; MODEL=$2; shift 2 ;;
		--model-endpoint|--endpoint) need_arg "$@"; MODEL_ENDPOINT=$2; shift 2 ;;
		--image|--worker-image) need_arg "$@"; WORKER_IMAGE=$2; shift 2 ;;
		--prompt) need_arg "$@"; PROMPT=$2; shift 2 ;;
		--task-prompt) need_arg "$@"; TASK_PROMPT=$2; shift 2 ;;
		--tool-profile) need_arg "$@"; TOOL_PROFILE=$2; shift 2 ;;
		--command-json) need_arg "$@"; COMMAND_JSON=$2; shift 2 ;;
		--post-command-json) need_arg "$@"; POST_COMMAND_JSON=$2; shift 2 ;;
		--worktree) WORKTREE=true; shift ;;
		--worktree=*) WORKTREE=${1#*=}; shift ;;
		--no-worktree) WORKTREE=false; shift ;;
		--commit) COMMIT=true; shift ;;
		--commit=*) COMMIT=${1#*=}; shift ;;
		--no-commit) COMMIT=false; shift ;;
		--write-scope) need_arg "$@"; WRITE_SCOPE=$2; shift 2 ;;
		--new-branch) need_arg "$@"; NEW_BRANCH=$2; shift 2 ;;
		--base-branch) need_arg "$@"; BASE_BRANCH=$2; shift 2 ;;
		--commit-message) need_arg "$@"; COMMIT_MESSAGE=$2; shift 2 ;;
		--help|-h) usage; exit 0 ;;
		*)
			break
			;;
	esac
done

case "$TOOL_PROFILE" in
	shell-only|unrestricted) ;;
	*) printf 'invalid --tool-profile=%s; expected shell-only or unrestricted\n' "$TOOL_PROFILE" >&2; exit 2 ;;
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

if [ -z "$COMMAND_JSON" ]; then
	payload=$(printf '{"model":"%s","prompt":"%s","stream":false}' "$MODEL" "$PROMPT")
	command=$(printf 'curl -fsS --max-time 180 %s -H %s --data-binary %s' \
		"$(printf '%s/api/generate' "${MODEL_ENDPOINT%/}")" \
		"'Content-Type: application/json'" \
		"$(printf "'%s'" "$payload")")
	COMMAND_JSON=$(printf '["sh","-lc","%s"]' "$(json_escape "$command")")
fi

if [ -z "$TASK_PROMPT" ]; then
	TASK_PROMPT="SSH-Docker local-model smoke for $MODEL: run the configured model command and report the model response; do not edit files."
fi
if [ "$TOOL_PROFILE" = shell-only ]; then
	TASK_PROMPT="$TASK_PROMPT

Tool profile: shell-only. The child worker can run normal shell commands in its writable task worktree, but it must not call an apply_patch tool or assume App Server-only tools exist. Use ordinary shell commands or checked-in scripts for file edits."
fi

"$ROOT/scripts/test-ssh-docker-image-smoke.sh" \
	--agent-backend container \
	--container-image "$WORKER_IMAGE" \
	--container-profile local-model \
	--command-json "$COMMAND_JSON" \
	--post-command-json "$POST_COMMAND_JSON" \
	--worktree="$WORKTREE" \
	--commit="$COMMIT" \
	--write-scope "$WRITE_SCOPE" \
	--new-branch "$NEW_BRANCH" \
	--base-branch "$BASE_BRANCH" \
	--commit-message "$COMMIT_MESSAGE" \
	--image "$WORKER_IMAGE" \
	--prompt "$TASK_PROMPT" \
	"$@"
