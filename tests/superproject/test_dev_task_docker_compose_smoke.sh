#!/usr/bin/env bash
set -euo pipefail
[[ "${BUS_E2E_VERBOSE:-0}" = "1" ]] && set -x

compose_args=(-f compose.dev-task-docker.yaml)
tmp_dir=$(mktemp -d)
export DOCKER_CONFIG="${DOCKER_CONFIG:-$tmp_dir/docker-config}"
mkdir -p "$DOCKER_CONFIG"

cleanup() {
  rm -f bus-dev/.bus/dev/task.json
  if [ -z "${BUS_DEV_TASK_DOCKER_KEEP:-}" ]; then
    docker compose "${compose_args[@]}" down >/dev/null 2>&1 || true
  fi
  rm -rf "$tmp_dir"
}
trap cleanup EXIT

if ! command -v docker >/dev/null 2>&1; then
  printf 'SKIP dev-task Docker compose smoke: docker not installed\n'
  exit 0
fi

if ! docker compose version >/dev/null 2>&1; then
  printf 'SKIP dev-task Docker compose smoke: docker compose unavailable\n'
  exit 0
fi

export BUS_DEV_TASK_COMMAND_JSON="${BUS_DEV_TASK_COMMAND_JSON:-[\"codex\",\"--version\"]}"
export BUS_DEV_TASK_PRE_COMMAND_JSON="${BUS_DEV_TASK_PRE_COMMAND_JSON:-[]}"
export BUS_DEV_TASK_POST_COMMAND_JSON="${BUS_DEV_TASK_POST_COMMAND_JSON:-[]}"
export BUS_DEV_TASK_AGENT_BACKEND="${BUS_DEV_TASK_AGENT_BACKEND:-container}"
export BUS_DEV_TASK_RECIPIENT="${BUS_DEV_TASK_RECIPIENT:-bus-containers}"
export BUS_DEV_TASK_COMMIT="${BUS_DEV_TASK_COMMIT:-false}"
task_recipient="@${BUS_DEV_TASK_RECIPIENT}"

docker compose "${compose_args[@]}" down --remove-orphans >/dev/null 2>&1 || true
compose_up_output="$tmp_dir/compose-up.output"
if ! docker compose "${compose_args[@]}" up --build -d >"$compose_up_output" 2>&1; then
  if grep -q 'Mounts denied' "$compose_up_output"; then
    printf 'SKIP dev-task Docker compose smoke: workspace path is not shared with Docker\n'
    exit 0
  fi
  cat "$compose_up_output" >&2
  exit 1
fi

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
  go run ./cmd/bus-containers run --profile codex -- gopls version | grep -q "v0.20.0"
'

docker compose "${compose_args[@]}" exec -T testing-agent sh -ec '
  cd /workspace/bus-containers
  go run ./cmd/bus-containers run --profile codex -- sh -ec "test \"$(command -v dlv)\" = /usr/local/bin/dlv && dlv version | grep -q \"Version: 1.25.2\" && dlv dap --help | grep -qi dap"
'

docker compose "${compose_args[@]}" exec -T testing-agent sh -ec '
  cd /workspace/bus-containers
  go run ./cmd/bus-containers run --profile codex -- bus-dev --help | grep -q "Usage: bus dev"
'

docker run --rm \
  -v "${PWD}:/workspace" \
  -w /workspace/bus-containers \
  "${DOCKER_CONTAINER_CODEX_IMAGE:-bus-local-codex:dev}" \
  bus-dev context | grep -q 'MODULE_NAME=bus-containers'

docker run --rm \
  -v "${PWD}:/workspace" \
  -w /workspace/bus \
  "${DOCKER_CONTAINER_CODEX_IMAGE:-bus-local-codex:dev}" \
  bus --help | grep -q 'Available commands:'

docker run --rm \
  -v "${PWD}:/workspace" \
  -w /workspace/bus \
  "${DOCKER_CONTAINER_CODEX_IMAGE:-bus-local-codex:dev}" \
  bus --help | grep -q '  gx'

docker run --rm \
  -v "${PWD}:/workspace" \
  -w /workspace/bus \
  "${DOCKER_CONTAINER_CODEX_IMAGE:-bus-local-codex:dev}" \
  bus --help | grep -q '  lint'

docker run --rm \
  -v "${PWD}:/workspace" \
  -w /workspace \
  "${DOCKER_CONTAINER_CODEX_IMAGE:-bus-local-codex:dev}" \
  sh -ec '
    test "$(command -v bus)" = /usr/local/bin/bus
    test "$(command -v bus-dev)" = /usr/local/bin/bus-dev
    test "$(command -v bus-lint)" = /usr/local/bin/bus-lint
    test "$(command -v bus-notes)" = /usr/local/bin/bus-notes
    bus dev work monitor --help >/dev/null
    bus lint --help >/dev/null
    bus notes --help >/dev/null
  '

docker run --rm \
  -v "${PWD}:/workspace" \
  -w /workspace \
  "${DOCKER_CONTAINER_CODEX_IMAGE:-bus-local-codex:dev}" \
  sh -ec '
    test "$(command -v gopls)" = /usr/local/bin/gopls
    gopls version | grep -q "v0.20.0"
    gopls mcp -instructions | grep -qi "gopls MCP server"
  '

docker run --rm \
  -v "${PWD}:/workspace" \
  -w /workspace \
  "${DOCKER_CONTAINER_CODEX_IMAGE:-bus-local-codex:dev}" \
  sh -ec '
    test "$(command -v dlv)" = /usr/local/bin/dlv
    dlv version | grep -q "Version: 1.25.2"
    dlv dap --help | grep -qi dap
  '

docker run --rm \
  -v "${PWD}:/workspace" \
  -w /workspace/docs \
  "${DOCKER_CONTAINER_CODEX_IMAGE:-bus-local-codex:dev}" \
  bus lint --help | grep -q 'Usage: bus-lint'

docker run --rm \
  -v "${PWD}:/workspace" \
  -w /workspace/bus-gx \
  "${DOCKER_CONTAINER_CODEX_IMAGE:-bus-local-codex:dev}" \
  bus gx help | grep -q 'Usage:'

docker compose "${compose_args[@]}" exec -T testing-agent sh -ec '
  cd /workspace/bus-containers
  go run ./cmd/bus-containers run --profile codex -- sh -ec "bus-dev -C /workspace/bus-containers context | grep -q MODULE_NAME=bus-containers"
' | grep -q '"exit_code": 0'

docker compose "${compose_args[@]}" exec -T bus-integration-dev-task sh -ec '
  test "$(command -v gopls)" = /usr/local/bin/gopls
  gopls version | grep -q "v0.20.0"
  gopls mcp -instructions | grep -qi "gopls MCP server"
'

docker compose "${compose_args[@]}" exec -T bus-integration-dev-task sh -ec '
  test "${BUS_DEV_TASK_GO_DEBUGGER:-}" = auto
  test "${BUS_DEV_TASK_GO_DEBUGGER_COMMAND:-}" = dlv
  test "$(command -v dlv)" = /usr/local/bin/dlv
  dlv version | grep -q "Version: 1.25.2"
  dlv dap --help | grep -qi dap
'

docker compose "${compose_args[@]}" exec -T bus-integration-dev-task sh -ec '
  export BUS_API_TOKEN="$(cd /workspace/bus-operator-token && go run ./cmd/bus-operator-token --format token issue --local --subject "$BUS_LOCAL_ACCOUNT_ID" --audience ai.hg.fi/api --scope "notes.write notes.read notes.search" --ttl 2h)"
  bus notes --api-url "$BUS_NOTES_API_URL" --format json add \
    --title "dev-task smoke note" \
    --body "worker note path available" \
    --author-id "dev-task-smoke" | grep -q "\"id\""
'

task_ok=0
task_output=""
for _ in $(seq 1 6); do
  task_ref="$(
    docker compose "${compose_args[@]}" exec -T testing-agent sh -ec "
      cd /workspace/bus-dev
      go run ./cmd/bus-dev task new '$task_recipient' 'Reply from the Docker Codex smoke.'
    " | awk '/ -> / {print $2; exit}'
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
  )" && printf '%s\n' "$task_output" | grep -q 'status=done'; then
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
