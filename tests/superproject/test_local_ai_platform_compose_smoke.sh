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
    cd /workspace/bus-containers
    go run ./cmd/bus-containers run --profile codex -- sh -lc "printf OK" | grep -q "\"stdout\": \"OK\""
    wget -qO- --header="Content-Type: application/json" --post-data="{\"email\":\"local-smoke-'"$$"'@example.invalid\"}" http://nginx:8080/api/v1/auth/register | grep -q "\"status\":\"waitlisted\""
'

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
