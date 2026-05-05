#!/usr/bin/env bash
set -euo pipefail
[[ "${BUS_E2E_VERBOSE:-0}" = "1" ]] && set -x

root_dir="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$root_dir"

if ! command -v docker >/dev/null 2>&1; then
  printf 'SKIP dev-task worker benchmark: docker not installed\n'
  exit 0
fi

if ! docker compose version >/dev/null 2>&1; then
  printf 'SKIP dev-task worker benchmark: docker compose unavailable\n'
  exit 0
fi

compose_args=(-f compose.dev-task-docker.yaml)
run_id="worker-bench-$$"
workspace="tmp/dev-task-worker-bench"
token_file="$workspace/api-token"
fake_codex_args_json='["run","/workspace/tests/superproject/fake_codex_appserver.go"]'
counts="${BUS_DEV_TASK_WORKER_BENCH_COUNTS:-1 2 3 4 6}"
recipients=(bus-dev bus-events bus-filing bus-data bus-integration-dev-task bus-integration-docker bus-journal bus-reconcile)
worker_names=()

now_ms() {
  python3 -c 'import time; print(int(time.time() * 1000))'
}

cleanup_workers() {
  for name in "${worker_names[@]}"; do
    docker rm -f "$name" || true
  done
  worker_names=()
}

cleanup() {
  cleanup_workers
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

printf 'workers\tsmoke_tasks\tduration_ms\tsmoke_tasks_per_min\n'

for worker_count in $counts; do
  if [ "$worker_count" -gt "${#recipients[@]}" ]; then
    printf 'FAIL dev-task worker benchmark: worker count %s exceeds recipient fixture count %s\n' "$worker_count" "${#recipients[@]}" >&2
    exit 1
  fi

  cleanup_workers
  bench_dir="$workspace/$worker_count"
  mkdir -p "$bench_dir"
  active_recipients=("${recipients[@]:0:$worker_count}")

  for recipient in "${active_recipients[@]}"; do
    name="busdk-dev-task-${run_id}-${worker_count}-${recipient}"
    worker_names+=("$name")
    docker compose "${compose_args[@]}" run -d --no-deps \
      --name "$name" \
      -e BUS_DEV_TASK_RECIPIENT="$recipient" \
      -e BUS_DEV_TASK_AGENT_BACKEND=codex-appserver \
      -e BUS_DEV_TASK_CODEX_COMMAND=go \
      -e BUS_DEV_TASK_CODEX_ARGS="$fake_codex_args_json" \
      -e BUS_DEV_TASK_PRE_COMMAND_JSON='[]' \
      -e BUS_DEV_TASK_POST_COMMAND_JSON='[]' \
      -e BUS_DEV_TASK_COMMIT=false \
      -e BUS_DEV_TASK_COMMIT_MESSAGE='bench: worker count {work_ref}' \
      -e BUS_DEV_TASK_ONCE=false \
      -e BUS_DEV_TASK_IDLE_TIMEOUT=0 \
      bus-integration-dev-task
  done

  running="$(docker ps --filter "name=busdk-dev-task-${run_id}-${worker_count}" --format '{{.Names}}' | wc -l | tr -d ' ')"
  if [ "$running" != "$worker_count" ]; then
    printf 'FAIL dev-task worker benchmark: expected %s workers, got %s\n' "$worker_count" "$running" >&2
    docker ps -a --filter "name=busdk-dev-task-${run_id}-${worker_count}" >&2
    exit 1
  fi

  start_ms="$(now_ms)"
  work_args=(start)
  for recipient in "${active_recipients[@]}"; do
    work_args+=("@$recipient")
  done
  work_args+=("Worker-count benchmark for ${worker_count} persistent App Server workers. Wait for live guidance, reply with the exact marker you receive, and finish without editing files.")
  (
    cd bus-dev
    go run ./cmd/bus-dev work --token-file "../$token_file" --api-url "$BUS_EVENTS_API_URL" "${work_args[@]}"
  ) | tee "$bench_dir/work-start.out"

  mapfile -t refs < <(awk '/ -> / {print $2}' "$bench_dir/work-start.out")
  if [ "${#refs[@]}" -ne "$worker_count" ]; then
    printf 'FAIL dev-task worker benchmark: expected %s task refs, got %s\n' "$worker_count" "${#refs[@]}" >&2
    cat "$bench_dir/work-start.out" >&2
    exit 1
  fi

  for ref in "${refs[@]}"; do
    show_out="$bench_dir/show-${ref#*#}.out"
    turn_started=0
    for _ in $(seq 1 120); do
      (
        cd bus-dev
        go run ./cmd/bus-dev work --token-file "../$token_file" --api-url "$BUS_EVENTS_API_URL" show "$ref"
      ) > "$show_out" 2> "$bench_dir/show-${ref#*#}.err" || true
      if grep 'Codex app-server turn started' "$show_out"; then
        turn_started=1
        break
      fi
      sleep 1
    done
    if [ "$turn_started" -ne 1 ]; then
      printf 'FAIL dev-task worker benchmark: app-server turn did not start for %s\n' "$ref" >&2
      cat "$show_out" >&2
      cat "$bench_dir/show-${ref#*#}.err" >&2
      exit 1
    fi
  done

  for ref in "${refs[@]}"; do
    (
      cd bus-dev
      go run ./cmd/bus-dev work --token-file "../$token_file" --api-url "$BUS_EVENTS_API_URL" say "$ref" "BENCH_DONE $worker_count $ref"
    )
  done

  pids=()
  for ref in "${refs[@]}"; do
    (
      cd bus-dev
      go run ./cmd/bus-dev work --token-file "../$token_file" --api-url "$BUS_EVENTS_API_URL" watch "$ref" --timeout 3m
    ) > "$bench_dir/watch-${ref#*#}.out" 2> "$bench_dir/watch-${ref#*#}.err" &
    pids+=("$!")
  done

  for pid in "${pids[@]}"; do
    wait "$pid"
  done
  end_ms="$(now_ms)"

  for ref in "${refs[@]}"; do
    watch_out="$bench_dir/watch-${ref#*#}.out"
    watch_err="$bench_dir/watch-${ref#*#}.err"
    if [ -s "$watch_err" ]; then
      printf 'FAIL dev-task worker benchmark: watch stderr for %s\n' "$ref" >&2
      cat "$watch_err" >&2
      exit 1
    fi
    if ! grep "BENCH_DONE $worker_count $ref" "$watch_out" ||
      ! grep 'removed isolated worktree without promotion' "$watch_out" ||
      ! grep 'bus.dev.task.done' "$watch_out"; then
      printf 'FAIL dev-task worker benchmark: task %s did not complete through the worker\n' "$ref" >&2
      cat "$watch_out" >&2
      exit 1
    fi
  done

  duration_ms=$((end_ms - start_ms))
  tasks_per_min="$(awk -v tasks="$worker_count" -v ms="$duration_ms" 'BEGIN { if (ms <= 0) print "inf"; else printf "%.2f", tasks * 60000 / ms }')"
  printf '%s\t%s\t%s\t%s\n' "$worker_count" "$worker_count" "$duration_ms" "$tasks_per_min"
done

printf 'dev-task worker benchmark OK\n'
