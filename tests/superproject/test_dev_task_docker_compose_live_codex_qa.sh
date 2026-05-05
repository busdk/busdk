#!/usr/bin/env bash
set -euo pipefail
[[ "${BUS_E2E_VERBOSE:-0}" = "1" ]] && set -x

root_dir="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$root_dir"

if [ "${BUS_DEV_TASK_DOCKER_LIVE_CODEX:-0}" != "1" ]; then
  printf 'SKIP live Codex submodule QA smoke: set BUS_DEV_TASK_DOCKER_LIVE_CODEX=1 to use real codex app-server\n'
  exit 0
fi

if ! command -v docker >/dev/null 2>&1; then
  printf 'SKIP live Codex submodule QA smoke: docker not installed\n'
  exit 0
fi

if ! docker compose version >/dev/null 2>&1; then
  printf 'SKIP live Codex submodule QA smoke: docker compose unavailable\n'
  exit 0
fi

compose_args=(-f compose.dev-task-docker.yaml)
run_id="live-codex-qa-$$"
worker_name="busdk-dev-task-${run_id}-bus-dev"
workspace="tmp/dev-task-live-codex-qa-smoke"
token_file="$workspace/api-token"
start_output="$workspace/work-start.out"
watch_output="$workspace/watch.out"
watch_error="$workspace/watch.err"
answer_output="$workspace/worker-answers.out"
question_one_id="live-q1-${run_id}"
question_two_id="live-q2-${run_id}"
expected_module_path="$(awk '/^module / {print $2; exit}' bus-dev/go.mod)"
expected_go_version="$(awk '/^go / {print $2; exit}' bus-dev/go.mod)"

cleanup() {
  docker rm -f "$worker_name" || true
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
  docker compose "${compose_args[@]}" logs --no-color --tail=220 >&2
  exit 1
fi

docker compose "${compose_args[@]}" run -d --no-deps \
  --name "$worker_name" \
  -e BUS_DEV_TASK_RECIPIENT=bus-dev \
  -e BUS_DEV_TASK_AGENT_BACKEND=codex-appserver \
  -e BUS_DEV_TASK_POST_COMMAND_JSON='[]' \
  -e BUS_DEV_TASK_COMMIT=false \
  -e BUS_DEV_TASK_COMMIT_MESSAGE='test: live codex qa {work_ref}' \
  -e BUS_DEV_TASK_ONCE=false \
  -e BUS_DEV_TASK_IDLE_TIMEOUT=0 \
  -e BUS_DEV_TASK_TRACE=true \
  bus-integration-dev-task

printf 'Started live Codex worker container:\n'
docker ps --filter "name=$worker_name" --format '  {{.Names}}	{{.Status}}'

(
  cd bus-dev
  go run ./cmd/bus-dev work --token-file "../$token_file" --api-url "$BUS_EVENTS_API_URL" \
    start @bus-dev "Live Codex QA smoke for the bus-dev submodule. Do not edit files. Start by running sleep 30 so this turn stays active for live follow-up questions. After receiving follow-up questions, inspect the current submodule files needed to answer them and include each question id in your concise final answer."
) | tee "$start_output"

ref="$(awk '/ -> / {print $2; exit}' "$start_output")"
if [ -z "$ref" ]; then
  printf 'FAIL live Codex submodule QA smoke: no task ref found\n' >&2
  cat "$start_output" >&2
  exit 1
fi

turn_started=0
for _ in $(seq 1 120); do
  (
    cd bus-dev
    go run ./cmd/bus-dev work --token-file "../$token_file" --api-url "$BUS_EVENTS_API_URL" \
      show "$ref"
  ) > "$workspace/show.out" 2> "$workspace/show.err" || true
  if grep 'Codex app-server turn started' "$workspace/show.out"; then
    turn_started=1
    break
  fi
  sleep 1
done

if [ "$turn_started" -ne 1 ]; then
  printf 'FAIL live Codex submodule QA smoke: Codex turn did not start for %s\n' "$ref" >&2
  cat "$workspace/show.out" >&2
  cat "$workspace/show.err" >&2
  docker logs "$worker_name" >&2 || true
  exit 1
fi

(
  cd bus-dev
  go run ./cmd/bus-dev work --token-file "../$token_file" --api-url "$BUS_EVENTS_API_URL" \
    say "$ref" "Question $question_one_id: inspect go.mod in the current submodule and tell me the declared module path. Include the question id and the value you found."
)
(
  cd bus-dev
  go run ./cmd/bus-dev work --token-file "../$token_file" --api-url "$BUS_EVENTS_API_URL" \
    say "$ref" "Question $question_two_id: inspect go.mod in the current submodule and tell me the declared Go version. Include the question id and the value you found."
)

(
  cd bus-dev
  go run ./cmd/bus-dev work --token-file "../$token_file" --api-url "$BUS_EVENTS_API_URL" \
    watch "$ref" --timeout 5m
) > "$watch_output" 2> "$watch_error"

if [ -s "$watch_error" ]; then
  printf 'FAIL live Codex submodule QA smoke: watch stderr for %s\n' "$ref" >&2
  cat "$watch_error" >&2
  exit 1
fi

awk -F '\t' '$1 == "bus.dev.task.message" && $0 ~ /source=bus-integration-dev-task/ {print}' "$watch_output" > "$answer_output"

if ! grep 'live guidance delivered to Codex app-server session' "$watch_output" ||
  ! grep 'removed isolated worktree without promotion' "$watch_output" ||
  ! grep "$question_one_id" "$answer_output" ||
  ! grep "$expected_module_path" "$answer_output" ||
  ! grep "$question_two_id" "$answer_output" ||
  ! grep "$expected_go_version" "$answer_output" ||
  ! grep 'bus.dev.task.done' "$watch_output"; then
  printf 'FAIL live Codex submodule QA smoke: missing live QA evidence for %s\n' "$ref" >&2
  printf 'Expected worker-authored answer facts: %s %s %s %s\n' "$question_one_id" "$expected_module_path" "$question_two_id" "$expected_go_version" >&2
  printf 'Worker-authored messages:\n' >&2
  cat "$answer_output" >&2
  printf 'Full task stream:\n' >&2
  cat "$watch_output" >&2
  docker logs "$worker_name" >&2 || true
  exit 1
fi

printf 'Live Codex QA answer evidence:\n'
cat "$answer_output"

worker_count="$(docker ps --filter "name=$worker_name" --format '{{.Names}}' | wc -l | tr -d ' ')"
if [ "$worker_count" != "1" ]; then
  printf 'FAIL live Codex submodule QA smoke: expected persistent worker after completion, got %s\n' "$worker_count" >&2
  docker ps -a --filter "name=$worker_name" >&2
  exit 1
fi

printf 'live Codex submodule QA smoke OK (%s)\n' "$ref"
