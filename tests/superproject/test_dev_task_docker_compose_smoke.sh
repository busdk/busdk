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

cleanup() {
  rm -f bus-dev/.bus/dev/task.json
  if [ -z "${BUS_DEV_TASK_DOCKER_KEEP:-}" ]; then
    docker compose "${compose_args[@]}" down >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

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

task_ref="$(
  docker compose "${compose_args[@]}" exec -T testing-agent sh -ec '
    cd /workspace/bus-dev
    go run ./cmd/bus-dev task new @bus-dev "Reply from the Docker Codex smoke."
  ' | awk '/ -> / {print $2; exit}'
)"

if [ -z "$task_ref" ]; then
  printf 'FAIL dev-task Docker compose smoke: task reference missing\n' >&2
  exit 1
fi

docker compose "${compose_args[@]}" exec -T testing-agent sh -ec "
  cd /workspace/bus-dev
  go run ./cmd/bus-dev task watch '$task_ref' --timeout 2m | grep -q 'codex-cli'
"

printf 'dev-task Docker compose smoke OK\n'
