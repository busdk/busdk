#!/usr/bin/env bash
set -euo pipefail
[[ "${BUS_E2E_VERBOSE:-0}" = "1" ]] && set -x

if ! command -v docker >/dev/null 2>&1; then
  printf 'SKIP dev-task Docker compose smoke: docker not installed\n'
  exit 0
fi

if ! docker compose version >/dev/null 2>&1; then
  printf 'SKIP dev-task Docker compose smoke: docker compose unavailable\n'
  exit 0
fi

compose_args=(-f compose.dev-task-docker.yaml)

export BUS_DEV_TASK_COMMAND_JSON="${BUS_DEV_TASK_COMMAND_JSON:-[\"codex\",\"--version\"]}"
export BUS_DEV_TASK_PRE_COMMAND_JSON="${BUS_DEV_TASK_PRE_COMMAND_JSON:-[]}"
export BUS_DEV_TASK_POST_COMMAND_JSON="${BUS_DEV_TASK_POST_COMMAND_JSON:-[]}"
export BUS_DEV_TASK_RECIPIENT="${BUS_DEV_TASK_RECIPIENT:-bus-dev}"

cleanup() {
  rm -f bus-dev/.bus/dev/task.json
  if [ -z "${BUS_DEV_TASK_DOCKER_KEEP:-}" ]; then
    docker compose "${compose_args[@]}" down >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

docker compose "${compose_args[@]}" down --remove-orphans >/dev/null 2>&1 || true
docker compose "${compose_args[@]}" up --build -d >/dev/null

docker compose "${compose_args[@]}" exec -T testing-agent sh -ec '
  for i in $(seq 1 120); do
    TOKEN=$(cat /root/.config/bus/auth/api-token 2>/dev/null || true)
    if [ -n "$TOKEN" ] &&
       wget -qO- --header="Authorization: Bearer $TOKEN" \
         http://bus-api-provider-containers:8080/api/v1/containers/status >/dev/null 2>&1; then
      exit 0
    fi
    sleep 1
  done
  exit 1
'

docker compose "${compose_args[@]}" exec -T testing-agent sh -ec '
  cd /workspace/bus-containers
  go run ./cmd/bus-containers run --profile codex -- codex --version | grep -q "codex-cli"
'

docker compose "${compose_args[@]}" exec -T testing-agent sh -ec '
  cd /workspace/bus-containers
  go run ./cmd/bus-containers run --profile codex -- bus-dev --help | grep -q "Usage: bus dev"
'

task_ok=0
task_output=""
for _ in $(seq 1 6); do
  task_ref="$(
    docker compose "${compose_args[@]}" exec -T testing-agent sh -ec '
      cd /workspace/bus-dev
      go run ./cmd/bus-dev task new @bus-dev "Reply from the Docker Codex smoke."
    ' | awk '/ -> / {print $2; exit}'
  )"
  if [ -z "$task_ref" ]; then
    task_output="task reference missing"
    sleep 2
    continue
  fi
  if task_output="$(
    docker compose "${compose_args[@]}" exec -T testing-agent sh -ec "
      cd /workspace/bus-dev
      go run ./cmd/bus-dev task watch '$task_ref' --timeout 30s
    "
  )" && printf '%s\n' "$task_output" | grep -q 'codex-cli'; then
    task_ok=1
    break
  fi
  sleep 2
done

if [ "$task_ok" != "1" ]; then
  printf 'FAIL dev-task Docker compose smoke: task was not processed\n%s\n' "$task_output" >&2
  exit 1
fi

printf 'dev-task Docker compose smoke OK\n'
