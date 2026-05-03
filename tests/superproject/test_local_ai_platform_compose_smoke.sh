#!/usr/bin/env bash
set -eu

root_dir="$(cd "$(dirname "$0")/../.." && pwd)"

cd "$root_dir"

compose_env_file="${BUS_LOCAL_AI_PLATFORM_ENV_FILE:-}"
if [ -z "$compose_env_file" ]; then
    if [ -f .env ]; then
        compose_env_file=".env"
    else
        compose_env_file=".env.example"
    fi
fi
compose_args=(--env-file "$compose_env_file" -f compose.yaml)

export BUS_DEV_TASK_COMMAND_JSON="${BUS_DEV_TASK_COMMAND_JSON:-[\"codex\",\"--version\"]}"
export BUS_DEV_TASK_PRE_COMMAND_JSON="${BUS_DEV_TASK_PRE_COMMAND_JSON:-[]}"
export BUS_DEV_TASK_POST_COMMAND_JSON="${BUS_DEV_TASK_POST_COMMAND_JSON:-[]}"

cleanup() {
    if [ "${BUS_LOCAL_AI_PLATFORM_KEEP:-0}" != "1" ]; then
        docker compose "${compose_args[@]}" down >/dev/null
    fi
}
trap cleanup EXIT

docker compose "${compose_args[@]}" up --build -d

ready=0
for _ in $(seq 1 90); do
    if docker compose "${compose_args[@]}" exec -T testing-agent sh -ec 'test -s /root/.config/bus/auth/api-token && TOKEN="$(cat /root/.config/bus/auth/api-token)" && wget -qO- --header="Authorization: Bearer $TOKEN" http://nginx:8080/readyz >/dev/null && wget -qO- --header="Authorization: Bearer $TOKEN" http://nginx:8080/v1/models | grep -q codex-chatgpt' >/dev/null 2>&1; then
        ready=1
        break
    fi
    sleep 2
done

if [ "$ready" -ne 1 ]; then
    docker compose "${compose_args[@]}" ps -a >&2
    docker compose "${compose_args[@]}" logs --no-color --tail=120 >&2
    exit 1
fi

docker compose "${compose_args[@]}" exec -T testing-agent sh -ec '
    set -eu
    TOKEN="$(cat /root/.config/bus/auth/api-token)"
    wget -qO- --header="Authorization: Bearer $TOKEN" http://nginx:8080/v1/models | grep -q codex-chatgpt
    wget -qO- --header="Authorization: Bearer $TOKEN" http://nginx:8080/api/v1/vm/status | grep -q "\"provider\":\"static\""
    wget -qO- --header="Authorization: Bearer $TOKEN" http://nginx:8080/api/v1/containers/status | grep -q "\"items\""
    wget -qO- http://nginx:8080/portal/local-dev/v1/healthz | grep -q "\"ok\":true"
    MODULES="$(wget -qO- http://nginx:8080/portal/local-dev/v1/modules)"
    printf "%s\n" "$MODULES" | grep -q "\"id\":\"auth\""
    printf "%s\n" "$MODULES" | grep -q "\"id\":\"ai\""
    printf "%s\n" "$MODULES" | grep -q "\"id\":\"accounting\""
    cd /workspace/bus-containers
    go run ./cmd/bus-containers run --profile codex -- sh -lc "printf OK" | grep -q "\"stdout\": \"OK\""
    cd /workspace/bus-dev
    TASK_REF="$(go run ./cmd/bus-dev task new @bus-dev "Show the Codex CLI version." | awk "/ -> / {print \$2; exit}")"
    test -n "$TASK_REF"
    TASK_OUTPUT="$(go run ./cmd/bus-dev task watch "$TASK_REF" --timeout 5m)"
    printf "%s\n" "$TASK_OUTPUT" | grep -q "codex-cli"
    test ! -e /workspace/bus-dev/.bus/dev/task.json
    wget -qO- --header="Content-Type: application/json" --post-data="{\"email\":\"local-smoke-'"$$"'@example.invalid\"}" http://nginx:8080/api/v1/auth/register | grep -q "\"status\":\"waitlisted\""
'

test -s tmp/local-ai-platform/bus-config/auth/api-token
HOST_TASK_REF="$(cd bus-dev && go run ./cmd/bus-dev task --timeout 30s new @bus-dev "Show the Codex CLI version." | awk "/ -> / {print \$2; exit}")"
test -n "$HOST_TASK_REF"
HOST_TASK_OUTPUT="$(cd bus-dev && go run ./cmd/bus-dev task --timeout 5m watch "$HOST_TASK_REF")"
printf "%s\n" "$HOST_TASK_OUTPUT" | grep -q "codex-cli"

if [ "${BUS_LOCAL_AI_PLATFORM_LIVE_CODEX:-0}" = "1" ]; then
    docker compose "${compose_args[@]}" exec -T testing-agent sh -ec '
        set -eu
        TOKEN="$(cat /root/.config/bus/auth/api-token)"
        wget -qO- --header="Authorization: Bearer $TOKEN" --header="Content-Type: application/json" --post-data="{\"model\":\"codex-chatgpt\",\"messages\":[{\"role\":\"user\",\"content\":\"Reply with BUS_CODEX_OK only.\"}]}" http://nginx:8080/v1/chat/completions | grep -q "BUS_CODEX_OK"
    '
else
    printf 'SKIP live Codex chat smoke: set BUS_LOCAL_AI_PLATFORM_LIVE_CODEX=1 after making Codex credentials available to the bus-codex container\n'
fi

printf 'local ai platform compose smoke OK\n'
