#!/bin/sh
set -eu

usage() {
  printf 'usage: %s <container-name> <recipient>\n' "$0" >&2
  printf 'Starts one recipient-scoped bus-integration-dev-task worker in the active dev-task Docker Compose stack.\n' >&2
}

if [ "$#" -ne 2 ]; then
  usage
  exit 2
fi

container_name=$1
recipient=$2

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

compose_file=${BUS_DEV_TASK_COMPOSE_FILE:-compose.dev-task-docker.yaml}
timeout=${BUS_DEV_TASK_TIMEOUT:-90m}
commit=${BUS_DEV_TASK_COMMIT:-true}
commit_message=${BUS_DEV_TASK_COMMIT_MESSAGE:-chore: dev task {work_ref}}
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

if ! docker compose -f "$compose_file" ps bus-events >/dev/null 2>&1; then
  printf 'compose stack is not available through %s; start it before launching workers\n' "$compose_file" >&2
  exit 2
fi

docker compose -f "$compose_file" run --rm --no-deps -d \
  --name "$container_name" \
  -e "BUS_DEV_TASK_RECIPIENT=$recipient" \
  -e "BUS_DEV_TASK_ONCE=$once" \
  -e 'BUS_DEV_TASK_POST_COMMAND_JSON=[]' \
  -e "BUS_DEV_TASK_COMMIT=$commit" \
  -e "BUS_DEV_TASK_COMMIT_MESSAGE=$commit_message" \
  -e "BUS_DEV_TASK_CODEX_SANDBOX=$sandbox" \
  -e "BUS_DEV_TASK_TIMEOUT=$timeout" \
  bus-integration-dev-task
