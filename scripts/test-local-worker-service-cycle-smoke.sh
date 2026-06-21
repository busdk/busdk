#!/bin/sh
set -eu

usage() {
  cat <<'EOF'
usage: scripts/test-local-worker-service-cycle-smoke.sh

Starts a disposable local Bus Events API from source, creates one ready task,
and runs one bus-integration-task supervisor cycle that observes the task via
bus task monitor and publishes worker-start/progress/health evidence.

Configuration via environment:
  BUS_WORKER_SERVICE_CYCLE_SMOKE_ADDR=127.0.0.1:18087
  BUS_WORKER_SERVICE_CYCLE_SMOKE_RECIPIENT=bus-integration-task
  BUS_WORKER_SERVICE_CYCLE_SMOKE_TOKEN_FILE=/path/to/api-token
  BUS_WORKER_SERVICE_CYCLE_SMOKE_MINT_TOKEN=true
  BUS_WORKER_SERVICE_CYCLE_SMOKE_CONFIG_DIR=/tmp/custom-bus-config

This is a no-Docker, no-model proof that the local Bus Events path can drive
the worker-owned monitor/reconcile/start service cycle.
EOF
}

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
  usage
  exit 0
fi

ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
ADDR=${BUS_WORKER_SERVICE_CYCLE_SMOKE_ADDR:-127.0.0.1:18087}
API_URL="http://$ADDR"
TOKEN_FILE=${BUS_WORKER_SERVICE_CYCLE_SMOKE_TOKEN_FILE:-$ROOT/tmp/local-ai-platform/bus-config/auth/api-token}
MINT_TOKEN=${BUS_WORKER_SERVICE_CYCLE_SMOKE_MINT_TOKEN:-true}
LOCAL_JWT_SECRET=${BUS_WORKER_SERVICE_CYCLE_SMOKE_LOCAL_JWT_SECRET:-${BUS_AUTH_HS256_SECRET:-not-a-secret-local-development-hs256-key}}
EVENTS_JWT_SECRET=${BUS_WORKER_SERVICE_CYCLE_SMOKE_EVENTS_JWT_SECRET:-not-a-secret-local-development-hs256-key}
RECIPIENT=${BUS_WORKER_SERVICE_CYCLE_SMOKE_RECIPIENT:-bus-integration-task}
TASK_TEXT=${BUS_WORKER_SERVICE_CYCLE_SMOKE_TEXT:-Local worker service cycle smoke}
READY_TEXT=${BUS_WORKER_SERVICE_CYCLE_SMOKE_READY_TEXT:-Ready for supervisor refill}

cleanup_config_dir=false
if [ -n "${BUS_WORKER_SERVICE_CYCLE_SMOKE_CONFIG_DIR:-}" ]; then
  BUS_CONFIG_DIR=$BUS_WORKER_SERVICE_CYCLE_SMOKE_CONFIG_DIR
else
  BUS_CONFIG_DIR=$(mktemp -d "${TMPDIR:-/tmp}/bus-worker-cycle-config.XXXXXX")
  cleanup_config_dir=true
fi
export BUS_CONFIG_DIR

PROOF_DIR=$(mktemp -d "${TMPDIR:-/tmp}/bus-worker-cycle-smoke.XXXXXX")
EVENTS_LOG="$PROOF_DIR/events.log"
EVENTS_PID=
cleanup_token_file=false

cleanup() {
  if [ -n "${EVENTS_PID:-}" ]; then
    kill "$EVENTS_PID" >/dev/null 2>&1 || true
    wait "$EVENTS_PID" >/dev/null 2>&1 || true
  fi
  if [ "$cleanup_token_file" = true ]; then
    rm -f "$TOKEN_FILE"
  fi
  if [ "$cleanup_config_dir" = true ]; then
    rm -rf "$BUS_CONFIG_DIR"
  fi
  rm -rf "$PROOF_DIR"
}
trap cleanup EXIT INT TERM

run_bus_task() {
  if [ -x "$ROOT/bus-task/bin/bus-task" ]; then
    "$ROOT/bus-task/bin/bus-task" "$@"
    return
  fi
  (
    cd "$ROOT/bus-task"
    go run ./cmd/bus-task "$@"
  )
}

run_bus_events() {
  if [ -x "$ROOT/.busdk-tools/bin/bus-events" ]; then
    "$ROOT/.busdk-tools/bin/bus-events" "$@"
    return
  fi
  (
    cd "$ROOT/bus-events"
    go run ./cmd/bus-events "$@"
  )
}

run_bus_integration_task() {
  if [ -x "$ROOT/bus-integration-task/bin/bus-integration-task" ]; then
    "$ROOT/bus-integration-task/bin/bus-integration-task" "$@"
    return
  fi
  (
    cd "$ROOT/bus-integration-task"
    go run ./cmd/bus-integration-task "$@"
  )
}

mint_local_token() {
  if [ -x "$ROOT/bus-operator-token/bin/bus-operator-token" ]; then
    BUS_AUTH_HS256_SECRET=$LOCAL_JWT_SECRET \
      "$ROOT/bus-operator-token/bin/bus-operator-token" \
      --format token issue --local \
      --subject acct_worker_service_cycle \
      --audience ai.hg.fi/api \
      --scope 'events:send events:listen dev:task:send dev:task:read dev:task:reply dev:task:claim container:run notes.write notes.read notes.search' \
      --ttl 2h
    return
  fi
  (
    cd "$ROOT/bus-operator-token"
    BUS_AUTH_HS256_SECRET=$LOCAL_JWT_SECRET \
      go run ./cmd/bus-operator-token \
      --format token issue --local \
      --subject acct_worker_service_cycle \
      --audience ai.hg.fi/api \
      --scope 'events:send events:listen dev:task:send dev:task:read dev:task:reply dev:task:claim container:run notes.write notes.read notes.search' \
      --ttl 2h
  )
}

if [ "$MINT_TOKEN" = true ]; then
  TOKEN_FILE=$(mktemp "${TMPDIR:-/tmp}/bus-worker-cycle-token.XXXXXX")
  cleanup_token_file=true
  mint_local_token >"$TOKEN_FILE"
elif [ ! -f "$TOKEN_FILE" ]; then
  printf 'token file not found: %s\n' "$TOKEN_FILE" >&2
  exit 1
fi

(
  cd "$ROOT/bus-api-provider-events"
  BUS_API_JWT_SECRET=$EVENTS_JWT_SECRET \
    go run ./cmd/bus-api-provider-events --addr "$ADDR" --events-backend memory
) >"$EVENTS_LOG" 2>&1 &
EVENTS_PID=$!

ready=false
attempt=0
while [ "$attempt" -lt 30 ]; do
  if run_bus_task --api-url "$API_URL" --token-file "$TOKEN_FILE" list @"$RECIPIENT" >/dev/null 2>&1; then
    ready=true
    break
  fi
  attempt=$((attempt + 1))
  sleep 1
done

if [ "$ready" != true ]; then
  printf 'local Events API did not become ready at %s\n' "$API_URL" >&2
  printf 'provider log:\n' >&2
  sed -n '1,160p' "$EVENTS_LOG" >&2 || true
  exit 1
fi

create_output=$(run_bus_task --api-url "$API_URL" --token-file "$TOKEN_FILE" new @"$RECIPIENT" "$TASK_TEXT")
printf '%s\n' "$create_output"

work_ref=$(printf '%s\n' "$create_output" | sed -n 's/^created \(bus[^ ]*#[0-9][^ ]*\) ->.*/\1/p' | head -n 1)
if [ -z "$work_ref" ]; then
  printf 'could not determine task ref from create output\n' >&2
  exit 1
fi

run_bus_task --api-url "$API_URL" --token-file "$TOKEN_FILE" ready "$work_ref" "$READY_TEXT" >/dev/null

monitor_command=$(printf '["%s","--api-url","%s","--token-file","%s","monitor","--format","json"]' "$ROOT/bus-task/bin/bus-task" "$API_URL" "$TOKEN_FILE")
if [ ! -x "$ROOT/bus-task/bin/bus-task" ]; then
  printf 'bus-task binary is required for this smoke; run make -C bus-task build first\n' >&2
  exit 1
fi

cycle_output=$(run_bus_integration_task \
  --supervisor-once \
  --events-url "$API_URL" \
  --events-token-file "$TOKEN_FILE" \
  --worker-id local-service-cycle-supervisor \
  --worker-groups smoke \
  --remote-id local \
  --remote-kind bus-events \
  --remote-endpoint "$API_URL" \
  --supervisor-monitor-command-json "$monitor_command" \
  --supervisor-self-check-interval 5m \
  --supervisor-max-parallel-workers 1)
printf '%s\n' "$cycle_output"

printf '%s\n' "$cycle_output" | grep -q '"RefillRequested":1' || {
  printf 'supervisor cycle did not request one refill\n' >&2
  exit 1
}

progress_out="$PROOF_DIR/progress.ndjson"
health_out="$PROOF_DIR/health.ndjson"
start_out="$PROOF_DIR/start.ndjson"

run_bus_events --api-url "$API_URL" --token-file "$TOKEN_FILE" listen --name bus.task.supervisor.progress --replay --no-follow >"$progress_out"
run_bus_events --api-url "$API_URL" --token-file "$TOKEN_FILE" listen --name bus.task.supervisor.health --replay --no-follow >"$health_out"
run_bus_events --api-url "$API_URL" --token-file "$TOKEN_FILE" listen --name bus.task.worker.start.request --replay --no-follow >"$start_out"

grep -q '"kind":"monitor_complete"' "$progress_out" || {
  printf 'missing monitor_complete progress event\n' >&2
  exit 1
}
grep -q '"kind":"refill_started"' "$progress_out" || {
  printf 'missing refill_started progress event\n' >&2
  exit 1
}
grep -q '"kind":"self_check_ok"' "$health_out" || {
  printf 'missing self_check_ok health event\n' >&2
  exit 1
}
grep -q '"name":"bus.task.worker.start.request"' "$start_out" || {
  printf 'missing worker start request event\n' >&2
  exit 1
}
grep -q "\"work_ref\":\"$work_ref\"" "$start_out" || {
  printf 'worker start request did not target %s\n' "$work_ref" >&2
  exit 1
}

printf 'local worker service cycle smoke ok work_ref=%s api_url=%s\n' "$work_ref" "$API_URL"
