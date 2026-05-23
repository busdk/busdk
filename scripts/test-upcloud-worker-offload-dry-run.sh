#!/bin/sh
set -eu

# No-spend proof package for the first Upcloud GPU worker lane.
# It models an operator-provisioned H100/GPU server as an SSH-Docker remote,
# checks the static Upcloud runner surface, and verifies the inference/model
# plan without creating, resizing, deleting, pulling, or running cloud resources.

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

REMOTE_ID=${BUS_UPCLOUD_OFFLOAD_REMOTE_ID:-upcloud-h100}
SSH_HOST=${BUS_UPCLOUD_OFFLOAD_SSH_HOST:-upcloud-h100.example.invalid}
SSH_USER=${BUS_UPCLOUD_OFFLOAD_SSH_USER:-bus}
SSH_PORT=${BUS_UPCLOUD_OFFLOAD_SSH_PORT:-22}
REMOTE_WORKDIR=${BUS_UPCLOUD_OFFLOAD_REMOTE_WORKDIR:-/srv/busdk/busdk}
CONTROLLER_EVENTS_URL=${BUS_UPCLOUD_OFFLOAD_CONTROLLER_EVENTS_URL:-http://127.0.0.1:18086}
WORKER_EVENTS_URL=${BUS_UPCLOUD_OFFLOAD_WORKER_EVENTS_URL:-http://bus-events:8081}
WORKER_IMAGE=${BUS_UPCLOUD_OFFLOAD_WORKER_IMAGE:-bus-integration-dev-task:local-image-smoke}
MODEL=${BUS_UPCLOUD_OFFLOAD_MODEL:-gemma4:31b}
MODEL_ENDPOINT=${BUS_UPCLOUD_OFFLOAD_MODEL_ENDPOINT:-http://ollama:11434}
INFERENCE_PROVIDER=${BUS_UPCLOUD_OFFLOAD_INFERENCE_PROVIDER:-ollama}
RUNNER_PROVISIONING=${BUS_UPCLOUD_OFFLOAD_RUNNER_PROVISIONING:-existing-only}
RUNNER_NAME=${BUS_UPCLOUD_OFFLOAD_RUNNER_NAME:-$REMOTE_ID}
MODEL_COMMAND_JSON=${BUS_UPCLOUD_OFFLOAD_MODEL_COMMAND_JSON:-}
WORK_DIR=${BUS_UPCLOUD_OFFLOAD_DRY_RUN_DIR:-}

if [ -z "$WORK_DIR" ]; then
	WORK_DIR=$(mktemp -d "${TMPDIR:-/tmp}/bus-upcloud-offload-dry-run.XXXXXX")
fi

require_executable() {
	if [ ! -x "$1" ]; then
		printf 'missing executable: %s\n' "$1" >&2
		printf 'build the owning module first, then rerun this script\n' >&2
		exit 2
	fi
}

require_executable "$ROOT/bus-remote/bin/bus-remote"
require_executable "$ROOT/bus-dev/bin/bus-dev"
require_executable "$ROOT/bus-integration-upcloud/bin/bus-integration-upcloud"
require_executable "$ROOT/bus-operator-inference/bin/bus-operator-inference"
require_executable "$ROOT/bus-integration-ollama/bin/bus-integration-ollama"

mkdir -p "$WORK_DIR"
if [ ! -d "$WORK_DIR/.git" ]; then
	git -C "$WORK_DIR" init >/dev/null
fi

printf 'BUS_UPCLOUD_OFFLOAD_DRY_RUN_DIR=%s\n' "$WORK_DIR"

json_escape() {
	printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

if [ -z "$MODEL_COMMAND_JSON" ]; then
	model_payload=$(printf '{"model":"%s","prompt":"Reply with one sentence confirming Bus remote worker offload is connected.","stream":false}' "$MODEL")
	model_command=$(printf 'curl -fsS --max-time 120 %s -H %s --data-binary %s' \
		"$(printf '%s/api/generate' "${MODEL_ENDPOINT%/}")" \
		"'Content-Type: application/json'" \
		"$(printf "'%s'" "$model_payload")")
	MODEL_COMMAND_JSON=$(printf '["sh","-lc","%s"]' "$(json_escape "$model_command")")
fi

{
	printf 'provider=%s\n' "$INFERENCE_PROVIDER"
	printf 'model=%s\n' "$MODEL"
	printf 'model_endpoint=%s\n' "$MODEL_ENDPOINT"
	printf 'worker_image=%s\n' "$WORKER_IMAGE"
	printf 'agent_backend=container\n'
	printf 'child_container_image=%s\n' "$WORKER_IMAGE"
	printf 'command_json_file=%s\n' "$WORK_DIR/local-model-command.json"
} >"$WORK_DIR/local-model-worker-profile.env"
printf '%s\n' "$MODEL_COMMAND_JSON" >"$WORK_DIR/local-model-command.json"

"$ROOT/bus-remote/bin/bus-remote" -C "$WORK_DIR" --format json add \
	--id "$REMOTE_ID" \
	--kind ssh-docker \
	--ssh-host "$SSH_HOST" \
	--ssh-user "$SSH_USER" \
	--ssh-port "$SSH_PORT" \
	--remote-workdir "$REMOTE_WORKDIR" \
	--controller-events-url "$CONTROLLER_EVENTS_URL" \
	--worker-events-url "$WORKER_EVENTS_URL" \
	--capacity 1 \
	--tags gpu,h100,linux \
	--description "No-spend Upcloud GPU candidate remote" \
	>"$WORK_DIR/remote.json"

"$ROOT/bus-integration-upcloud/bin/bus-integration-upcloud" \
	--provider static \
	--container-runner-provisioning "$RUNNER_PROVISIONING" \
	--container-runner-name "$RUNNER_NAME" \
	--check-vm-status \
	>"$WORK_DIR/upcloud-status.json"

"$ROOT/bus-operator-inference/bin/bus-operator-inference" \
	--provider "$INFERENCE_PROVIDER" \
	--node "$REMOTE_ID" \
	--model "$MODEL" \
	model ensure \
	>"$WORK_DIR/inference-model-ensure.json"

"$ROOT/bus-integration-ollama/bin/bus-integration-ollama" \
	--dry-run \
	--model "$MODEL" \
	install \
	>"$WORK_DIR/ollama-install-plan.json"

BUS_API_TOKEN=${BUS_API_TOKEN:-dry-run-token} \
BUS_DEV_SSH_DOCKER_LAUNCH_MODE=image \
BUS_DEV_SSH_DOCKER_WORKER_IMAGE="$WORKER_IMAGE" \
BUS_DEV_TASK_AGENT_BACKEND=container \
BUS_DEV_TASK_CONTAINER_IMAGE="$WORKER_IMAGE" \
BUS_DEV_TASK_CONTAINER_PROFILE=local-model \
BUS_DEV_TASK_COMMAND_JSON="$MODEL_COMMAND_JSON" \
BUS_DEV_TASK_COMMIT=false \
"$ROOT/bus-dev/bin/bus-dev" -C "$WORK_DIR" work --remote "$REMOTE_ID" start --dry-run \
	@bus-dev "No-spend Upcloud GPU worker scheduling proof for $MODEL" \
	>"$WORK_DIR/bus-dev-work-dry-run.txt"

printf 'wrote %s\n' "$WORK_DIR/local-model-worker-profile.env"
printf 'wrote %s\n' "$WORK_DIR/local-model-command.json"
printf 'wrote %s\n' "$WORK_DIR/remote.json"
printf 'wrote %s\n' "$WORK_DIR/upcloud-status.json"
printf 'wrote %s\n' "$WORK_DIR/inference-model-ensure.json"
printf 'wrote %s\n' "$WORK_DIR/ollama-install-plan.json"
printf 'wrote %s\n' "$WORK_DIR/bus-dev-work-dry-run.txt"
printf 'OK no-spend Upcloud worker offload dry-run\n'
