#!/bin/sh
set -eu

usage() {
  printf 'usage: %s <container-name> <recipient> [work-ref]\n' "$0" >&2
  printf 'Starts one bus-integration-task worker in the active dev-task Docker Compose stack.\n' >&2
  printf 'When work-ref is provided, the worker is bound to that exact task and must refuse any other ref.\n' >&2
}

if [ "$#" -lt 2 ] || [ "$#" -gt 3 ]; then
  usage
  exit 2
fi

container_name=$1
recipient=$2
work_ref=${3:-${BUS_DEV_TASK_WORK_REF:-}}

case "$container_name" in
  ''|*[!A-Za-z0-9_.-]*)
    printf 'invalid container name: %s\n' "$container_name" >&2
    exit 2
    ;;
esac

case "$recipient" in
  ''|*[!A-Za-z0-9_.-]*)
    printf 'invalid recipient: %s\n' "$recipient" >&2
    exit 2
    ;;
esac

case "$work_ref" in
  *[!A-Za-z0-9_.#:-]*)
    printf 'invalid work ref: %s\n' "$work_ref" >&2
    exit 2
    ;;
esac

compose_file=${BUS_DEV_TASK_COMPOSE_FILE:-compose.yaml}
compose_profile=${BUS_DEV_TASK_COMPOSE_PROFILE:-dev-task}
compose_project=${BUS_DEV_TASK_COMPOSE_PROJECT:-bus-local-ai-platform}
timeout=${BUS_DEV_TASK_TIMEOUT:-90m}
commit=${BUS_DEV_TASK_COMMIT:-true}
default_commit_message='task: {summary}

Task: {text}

Work-ref: {work_ref}
Recipient: {recipient}

Verification: See task closeout evidence and supervisor review before promotion.

Compatibility: Review required; bridge did not classify compatibility impact.

Migration: Review required; bridge did not classify data, schema, or config migration impact.

Security: Review required; bridge did not classify security or privacy impact.'
commit_message=${BUS_DEV_TASK_COMMIT_MESSAGE:-$default_commit_message}
sandbox=${BUS_DEV_TASK_CODEX_SANDBOX:-workspace-write}
once=${BUS_DEV_TASK_ONCE:-true}

if [ ! -f "$compose_file" ]; then
  printf 'compose file not found: %s\n' "$compose_file" >&2
  exit 2
fi

if docker ps --format '{{.Names}}' | grep -Fx "$container_name" >/dev/null 2>&1; then
  printf 'container already running: %s\n' "$container_name" >&2
  exit 2
fi

legacy_stack_names=$(
  docker ps -a \
    --filter 'label=com.docker.compose.project=busdk' \
    --format '{{.Names}}' 2>/dev/null || true
)
if [ -n "$legacy_stack_names" ] && [ ! -f compose.dev-task-docker.yaml ]; then
  printf 'warning: stale legacy dev-task containers from removed compose.dev-task-docker.yaml are present under project "busdk"\n' >&2
  printf 'warning: current local worker platform uses compose project "%s" from %s\n' "$compose_project" "$compose_file" >&2
  printf 'warning: legacy containers do not prove the current local Events/task worker substrate is healthy\n' >&2
fi

if ! docker compose --project-name "$compose_project" -f "$compose_file" --profile "$compose_profile" ps bus-events >/dev/null 2>&1; then
  printf 'compose stack is not available through %s; start it before launching workers\n' "$compose_file" >&2
  printf 'current expected compose project: %s\n' "$compose_project" >&2
  exit 2
fi

docker compose --project-name "$compose_project" -f "$compose_file" --profile "$compose_profile" build bus-integration-task >/dev/null

docker compose --project-name "$compose_project" -f "$compose_file" --profile "$compose_profile" run --rm --no-deps -d \
  --name "$container_name" \
  -e "BUS_DEV_TASK_RECIPIENT=$recipient" \
  -e "BUS_DEV_TASK_WORK_REF=$work_ref" \
  -e "BUS_DEV_TASK_ONCE=$once" \
  -e 'BUS_DEV_TASK_POST_COMMAND_JSON=[]' \
  -e "BUS_DEV_TASK_COMMIT=$commit" \
  -e "BUS_DEV_TASK_COMMIT_MESSAGE=$commit_message" \
  -e "BUS_DEV_TASK_CODEX_SANDBOX=$sandbox" \
  -e "BUS_DEV_TASK_TIMEOUT=$timeout" \
  bus-integration-task
