#!/usr/bin/env bash
set -euo pipefail
[[ "${BUS_E2E_VERBOSE:-0}" = "1" ]] && set -x

root_dir="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$root_dir"

if ! command -v docker >/dev/null 2>&1; then
  printf 'SKIP dev-task Docker compose parallel smoke: docker not installed\n'
  exit 0
fi

if ! docker compose version >/dev/null 2>&1; then
  printf 'SKIP dev-task Docker compose parallel smoke: docker compose unavailable\n'
  exit 0
fi

compose_args=(-f compose.dev-task-docker.yaml)
run_id="parallel-three-$$"
recipients="bus-dev bus-events bus-filing"
worker_names=""
workspace="tmp/dev-task-parallel-three-smoke"
token_file="$workspace/api-token"
start_output="$workspace/work-start.out"
fake_codex="${BUS_DEV_TASK_DOCKER_FAKE_CODEX:-0}"
fake_codex_args_json='["run","/workspace/tests/superproject/fake_codex_appserver.go"]'

cleanup() {
  for name in $worker_names; do
    docker rm -f "$name" >/dev/null 2>&1 || true
  done
  if [ -z "${BUS_DEV_TASK_DOCKER_KEEP:-}" ]; then
    docker compose "${compose_args[@]}" down --remove-orphans
  fi
}
trap cleanup EXIT

rm -rf "$workspace"
mkdir -p "$workspace"

docker compose "${compose_args[@]}" down --remove-orphans
docker compose "${compose_args[@]}" up --build -d \
  codex-image \
  bus-events \
  bus-api-provider-containers \
  bus-integration-docker \
  bus-integration-containers

export BUS_AUTH_HS256_SECRET="${BUS_LOCAL_JWT_SECRET:-not-a-secret-local-development-hs256-key}"
export BUS_API_TOKEN="$(
  cd bus-operator-token
  go run ./cmd/bus-operator-token --format token issue --local \
    --subject "${BUS_LOCAL_ACCOUNT_ID:-00000000-0000-4000-8000-000000000001}" \
    --audience ai.hg.fi/api \
    --scope 'events:send events:listen dev:task:send dev:task:read dev:task:reply dev:task:claim container:read container:run container:delete' \
    --ttl 2h
)"
printf '%s' "$BUS_API_TOKEN" > "$token_file"
export BUS_EVENTS_API_URL=http://127.0.0.1:8081

ready=0
for _ in $(seq 1 120); do
  if curl --fail --show-error --connect-timeout 2 --max-time 5 --output "$workspace/containers-status.json" \
    --header "Authorization: Bearer $BUS_API_TOKEN" \
    http://127.0.0.1:8080/api/v1/containers/status; then
    ready=1
    break
  fi
  sleep 1
done

if [ "$ready" -ne 1 ]; then
  docker compose "${compose_args[@]}" ps -a >&2
  docker compose "${compose_args[@]}" logs --no-color --tail=160 >&2
  exit 1
fi

for recipient in $recipients; do
  name="busdk-dev-task-${run_id}-${recipient}"
  worker_names="$worker_names $name"
  worker_env=(
    -e BUS_DEV_TASK_RECIPIENT="$recipient" \
    -e BUS_DEV_TASK_AGENT_BACKEND=codex-appserver \
    -e BUS_DEV_TASK_PRE_COMMAND_JSON='[]' \
    -e BUS_DEV_TASK_POST_COMMAND_JSON='[]' \
    -e BUS_DEV_TASK_COMMIT=true \
    -e BUS_DEV_TASK_COMMIT_MESSAGE='test: parallel three {work_ref}' \
    -e BUS_DEV_TASK_ONCE=false \
    -e BUS_DEV_TASK_IDLE_TIMEOUT=0
  )
  if [ "$fake_codex" = "1" ]; then
    worker_env+=(
      -e BUS_DEV_TASK_CODEX_COMMAND=go
      -e BUS_DEV_TASK_CODEX_ARGS="$fake_codex_args_json"
    )
  fi
  docker compose "${compose_args[@]}" run -d --no-deps \
    --name "$name" \
    "${worker_env[@]}" \
    bus-integration-dev-task
done

printf 'Started worker containers:\n'
docker ps --filter "name=busdk-dev-task-${run_id}" --format '  {{.Names}}	{{.Status}}'

worker_count="$(docker ps --filter "name=busdk-dev-task-${run_id}" --format '{{.Names}}' | wc -l | tr -d ' ')"
if [ "$worker_count" != "3" ]; then
  printf 'FAIL dev-task Docker compose parallel smoke: expected 3 running workers, got %s\n' "$worker_count" >&2
  docker ps --filter "name=busdk-dev-task-${run_id}" >&2
  exit 1
fi

(
  cd bus-dev
  go run ./cmd/bus-dev work --token-file "../$token_file" --api-url "$BUS_EVENTS_API_URL" \
    start @bus-dev @bus-events @bus-filing "Parallel Docker smoke: run the App Server worker. Wait for live guidance, then reply with the exact marker you receive and finish without editing files."
) | tee "$start_output"

mapfile -t refs < <(awk '/ -> / {print $2}' "$start_output")
if [ "${#refs[@]}" -ne 3 ]; then
  printf 'FAIL dev-task Docker compose parallel smoke: expected 3 task refs, got %d\n' "${#refs[@]}" >&2
  cat "$start_output" >&2
  exit 1
fi

for ref in "${refs[@]}"; do
  show_out="$workspace/show-${ref#*#}.out"
  ready=0
  for _ in $(seq 1 120); do
    (
      cd bus-dev
      go run ./cmd/bus-dev work --token-file "../$token_file" --api-url "$BUS_EVENTS_API_URL" \
        show "$ref"
    ) > "$show_out" 2> "$workspace/show-${ref#*#}.err" || true
    if grep 'Codex app-server turn started' "$show_out"; then
      ready=1
      break
    fi
    sleep 1
  done
  if [ "$ready" -ne 1 ]; then
    printf 'FAIL dev-task Docker compose parallel smoke: app-server turn did not start for %s\n' "$ref" >&2
    cat "$show_out" >&2
    cat "$workspace/show-${ref#*#}.err" >&2
    exit 1
  fi
done

for ref in "${refs[@]}"; do
  (
    cd bus-dev
    go run ./cmd/bus-dev work --token-file "../$token_file" --api-url "$BUS_EVENTS_API_URL" \
      say "$ref" "APP_SERVER_SMOKE_DONE $ref"
  )
done

printf 'Watching task refs in parallel: %s\n' "${refs[*]}"
pids=""
for ref in "${refs[@]}"; do
  (
    cd bus-dev
    go run ./cmd/bus-dev work --token-file "../$token_file" --api-url "$BUS_EVENTS_API_URL" \
      watch "$ref" --timeout 3m
  ) > "$workspace/watch-${ref#*#}.out" 2> "$workspace/watch-${ref#*#}.err" &
  pids="$pids $!"
done

for pid in $pids; do
  wait "$pid"
done

for ref in "${refs[@]}"; do
  watch_out="$workspace/watch-${ref#*#}.out"
  watch_err="$workspace/watch-${ref#*#}.err"
  if [ -s "$watch_err" ]; then
    printf 'FAIL dev-task Docker compose parallel smoke: watch stderr for %s\n' "$ref" >&2
    cat "$watch_err" >&2
    exit 1
  fi
  if ! grep 'starting Codex app-server task backend' "$watch_out" ||
    ! grep 'live guidance delivered to Codex app-server session' "$watch_out" ||
    ! grep "APP_SERVER_SMOKE_DONE $ref" "$watch_out" ||
    ! grep 'bus.dev.task.done' "$watch_out"; then
    printf 'FAIL dev-task Docker compose parallel smoke: task %s was not completed by App Server worker\n' "$ref" >&2
    cat "$watch_out" >&2
    exit 1
  fi
done

printf 'Worker container final states:\n'
docker ps -a --filter "name=busdk-dev-task-${run_id}" --format '  {{.Names}}	{{.Status}}'
worker_count="$(docker ps --filter "name=busdk-dev-task-${run_id}" --format '{{.Names}}' | wc -l | tr -d ' ')"
if [ "$worker_count" != "3" ]; then
  printf 'FAIL dev-task Docker compose parallel smoke: expected 3 persistent workers after task completion, got %s\n' "$worker_count" >&2
  docker ps -a --filter "name=busdk-dev-task-${run_id}" >&2
  exit 1
fi

printf 'dev-task Docker compose parallel smoke OK (%s)\n' "${refs[*]}"
