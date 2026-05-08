#!/usr/bin/env bash
set -eu

root_dir="$(cd "$(dirname "$0")/../.." && pwd)"

cd "$root_dir"

export BUS_LOCAL_AI_PLATFORM_PROJECT_NAME="${BUS_LOCAL_AI_PLATFORM_PROJECT_NAME:-bus-local-ai-platform-smoke-$$}"

compose_env_file="${BUS_LOCAL_AI_PLATFORM_ENV_FILE:-}"
if [ -z "$compose_env_file" ]; then
    if [ -f .env ]; then
        compose_env_file=".env"
    else
        compose_env_file=".env.example"
    fi
fi
compose_args=(-p "$BUS_LOCAL_AI_PLATFORM_PROJECT_NAME" --env-file "$compose_env_file" -f compose.yaml)

export BUS_DEV_TASK_AGENT_BACKEND="${BUS_DEV_TASK_AGENT_BACKEND:-container}"
export BUS_DEV_TASK_COMMAND_JSON="${BUS_DEV_TASK_COMMAND_JSON:-[\"codex\",\"--version\"]}"
export BUS_DEV_TASK_PRE_COMMAND_JSON="${BUS_DEV_TASK_PRE_COMMAND_JSON:-[]}"
export BUS_DEV_TASK_POST_COMMAND_JSON="${BUS_DEV_TASK_POST_COMMAND_JSON:-[]}"

diagnose_failure() {
    status=$?
    line="${1:-unknown}"
    printf 'FAIL local ai platform compose smoke: line %s exited %s\n' "$line" "$status" >&2
    docker compose "${compose_args[@]}" ps -a >&2 || true
    docker compose "${compose_args[@]}" logs --no-color --tail=160 >&2 || true
    exit "$status"
}

cleanup() {
    if [ "${BUS_LOCAL_AI_PLATFORM_KEEP:-0}" != "1" ]; then
        docker compose "${compose_args[@]}" down -v >/dev/null
    fi
}
trap 'diagnose_failure "$LINENO"' ERR
trap cleanup EXIT

printf 'RUN local ai platform compose up\n'
docker compose "${compose_args[@]}" up --build -d
printf 'PASS local ai platform compose up\n'

printf 'RUN local ai platform readiness\n'
ready=0
for _ in $(seq 1 90); do
    if docker compose "${compose_args[@]}" exec -T testing-agent sh -ec '
        test -s /root/.config/bus/auth/api-token
        TOKEN="$(cat /root/.config/bus/auth/api-token)"
        wget -qO- --header="Authorization: Bearer $TOKEN" http://nginx:8080/readyz >/dev/null
        wget -qO- --header="Authorization: Bearer $TOKEN" http://nginx:8080/v1/models | grep -q codex-chatgpt
        wget -qO- --header="Authorization: Bearer $TOKEN" http://nginx:8080/api/v1/vm/status | grep -q "\"provider\":\"static\""
        wget -qO- --header="Authorization: Bearer $TOKEN" http://nginx:8080/api/v1/containers/status | grep -q "\"items\""
        wget -qO- http://nginx:8080/portal/local-dev/v1/healthz | grep -q "\"ok\":true"
    ' >/dev/null 2>&1; then
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
printf 'PASS local ai platform readiness\n'

printf 'RUN in-container API and task smoke\n'
docker compose "${compose_args[@]}" exec -T testing-agent sh -ec '
    set -eu
    TOKEN="$(cat /root/.config/bus/auth/api-token)"
    printf "RUN llm models route\n"
    wget -qO- --header="Authorization: Bearer $TOKEN" http://nginx:8080/v1/models | grep -q codex-chatgpt
    printf "PASS llm models route\n"
    printf "RUN vm and container routes\n"
    wget -qO- --header="Authorization: Bearer $TOKEN" http://nginx:8080/api/v1/vm/status | grep -q "\"provider\":\"static\""
    wget -qO- --header="Authorization: Bearer $TOKEN" http://nginx:8080/api/v1/containers/status | grep -q "\"items\""
    printf "PASS vm and container routes\n"
    printf "RUN notes API route\n"
    cd /workspace/bus-notes
    NOTE_TITLE="Local stack note '"$$"'"
    BUS_NOTES_API_URL=http://nginx:8080/api BUS_API_TOKEN="$TOKEN" go run ./cmd/bus-notes add --title "$NOTE_TITLE" --body "Notes API is reachable. local-smoke." --author-id local-agent --module bus-dev --task local-smoke --tags agent-work-log | grep -q "$NOTE_TITLE"
    BUS_NOTES_API_URL=http://nginx:8080/api BUS_API_TOKEN="$TOKEN" go run ./cmd/bus-notes search local-smoke | grep -q "$NOTE_TITLE"
    printf "PASS notes API route\n"
    printf "RUN portal routes\n"
    wget -qO- http://nginx:8080/portal/local-dev/v1/healthz | grep -q "\"ok\":true"
    MODULES="$(wget -qO- http://nginx:8080/portal/local-dev/v1/modules)"
    printf "%s\n" "$MODULES" | grep -q "\"id\":\"auth\""
    printf "%s\n" "$MODULES" | grep -q "\"id\":\"ai\""
    printf "%s\n" "$MODULES" | grep -q "\"id\":\"accounting\""
    printf "PASS portal routes\n"
    printf "RUN container command route\n"
    cd /workspace/bus-containers
    go run ./cmd/bus-containers run --profile codex -- sh -lc "printf OK" | grep -q "\"stdout\": \"OK\""
    printf "PASS container command route\n"
    printf "RUN in-container dev task route\n"
    cd /workspace/bus-dev
    TASK_REF="$(go run ./cmd/bus-dev task new @bus-dev "Show the Codex CLI version." | awk "/ -> / {print \$2; exit}")"
    test -n "$TASK_REF"
    TASK_OUTPUT="$(go run ./cmd/bus-dev task watch "$TASK_REF" --timeout 5m)"
    printf "%s\n" "$TASK_OUTPUT" | grep -q "codex-cli"
    test ! -e /workspace/bus-dev/.bus/dev/task.json
    printf "PASS in-container dev task route\n"
    printf "RUN auth waitlist route\n"
    wget -qO- --header="Content-Type: application/json" --post-data="{\"email\":\"local-smoke-'"$$"'@example.invalid\"}" http://nginx:8080/api/v1/auth/register | grep -q "\"status\":\"waitlisted\""
    printf "PASS auth waitlist route\n"
'
printf 'PASS in-container API and task smoke\n'

printf 'RUN notes PostgreSQL persistence check\n'
docker compose "${compose_args[@]}" exec -T postgres sh -ec '
    count="$(psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -tAc "select count(*) from bus_notes.bus_integration_notes_notes where body like '\''%Notes API is reachable.%'\''")"
    test "$count" -ge 1
'
printf 'PASS notes PostgreSQL persistence check\n'

printf 'RUN host dev task route\n'
test -s tmp/local-ai-platform/bus-config/auth/api-token
host_api_url="http://127.0.0.1:${LOCAL_AI_PLATFORM_PORT:-8080}"
HOST_TASK_REF="$(cd bus-dev && go run ./cmd/bus-dev task --api-url "$host_api_url" --timeout 30s new @bus-dev "Show the Codex CLI version." | awk "/ -> / {print \$2; exit}")"
test -n "$HOST_TASK_REF"
HOST_TASK_OUTPUT="$(cd bus-dev && go run ./cmd/bus-dev task --api-url "$host_api_url" --timeout 5m watch "$HOST_TASK_REF")"
printf "%s\n" "$HOST_TASK_OUTPUT" | grep -q "codex-cli"
printf 'PASS host dev task route\n'

if [ "${BUS_LOCAL_AI_PLATFORM_LIVE_CODEX:-0}" = "1" ]; then
    printf 'RUN live Codex chat smoke\n'
    docker compose "${compose_args[@]}" exec -T testing-agent sh -ec '
        set -eu
        TOKEN="$(cat /root/.config/bus/auth/api-token)"
        wget -qO- --header="Authorization: Bearer $TOKEN" --header="Content-Type: application/json" --post-data="{\"model\":\"codex-chatgpt\",\"messages\":[{\"role\":\"user\",\"content\":\"Reply with BUS_CODEX_OK only.\"}]}" http://nginx:8080/v1/chat/completions | grep -q "BUS_CODEX_OK"
    '
    printf 'PASS live Codex chat smoke\n'
else
    printf 'SKIP live Codex chat smoke: set BUS_LOCAL_AI_PLATFORM_LIVE_CODEX=1 after making Codex credentials available to the bus-codex container\n'
fi

printf 'local ai platform compose smoke OK\n'
