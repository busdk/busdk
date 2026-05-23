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
COMMAND_JSON=${BUS_SSH_DOCKER_MODEL_SMOKE_COMMAND_JSON:-}

json_escape() {
	printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

if [ -z "$COMMAND_JSON" ]; then
	payload=$(printf '{"model":"%s","prompt":"%s","stream":false}' "$MODEL" "$PROMPT")
	command=$(printf 'curl -fsS --max-time 180 %s -H %s --data-binary %s' \
		"$(printf '%s/api/generate' "${MODEL_ENDPOINT%/}")" \
		"'Content-Type: application/json'" \
		"$(printf "'%s'" "$payload")")
	COMMAND_JSON=$(printf '["sh","-lc","%s"]' "$(json_escape "$command")")
fi

BUS_SSH_DOCKER_SMOKE_AGENT_BACKEND=container \
BUS_SSH_DOCKER_SMOKE_CONTAINER_IMAGE="$WORKER_IMAGE" \
BUS_SSH_DOCKER_SMOKE_CONTAINER_PROFILE=local-model \
BUS_SSH_DOCKER_SMOKE_COMMAND_JSON="$COMMAND_JSON" \
BUS_SSH_DOCKER_SMOKE_WORKTREE=false \
BUS_SSH_DOCKER_SMOKE_COMMIT=false \
BUS_SSH_DOCKER_SMOKE_IMAGE="$WORKER_IMAGE" \
BUS_SSH_DOCKER_SMOKE_PROMPT="SSH-Docker local-model smoke for $MODEL: run the configured model command and report the model response; do not edit files." \
"$ROOT/scripts/test-ssh-docker-image-smoke.sh"
