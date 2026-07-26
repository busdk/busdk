#!/bin/sh
set -eu

usage() {
  cat <<'EOF'
usage: scripts/test-local-worker-service-cycle-smoke.sh

Starts a disposable local Bus Events API from source, creates one open task,
and runs one bus-integration-worker observed scheduler cycle that publishes
worker-create/progress/health evidence for that exact task.

Configuration via environment:
  BUS_HOST=127.0.0.2
  BUS_WORKER_SERVICE_CYCLE_SMOKE_ADDR=127.0.0.2:18087
  BUS_WORKER_SERVICE_CYCLE_SMOKE_IDENTITIES_ADDR=127.0.0.2:18088
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
BUS_TEST_HOST=${BUS_HOST:-127.0.0.1}
ADDR=${BUS_WORKER_SERVICE_CYCLE_SMOKE_ADDR:-$BUS_TEST_HOST:18087}
API_URL="http://$ADDR"
IDENTITIES_ADDR=${BUS_WORKER_SERVICE_CYCLE_SMOKE_IDENTITIES_ADDR:-$BUS_TEST_HOST:18088}
IDENTITIES_API_URL="http://$IDENTITIES_ADDR"
TOKEN_FILE=${BUS_WORKER_SERVICE_CYCLE_SMOKE_TOKEN_FILE:-$ROOT/tmp/local-ai-platform/bus-config/auth/api-token}
MINT_TOKEN=${BUS_WORKER_SERVICE_CYCLE_SMOKE_MINT_TOKEN:-true}
LOCAL_JWT_SECRET=${BUS_WORKER_SERVICE_CYCLE_SMOKE_LOCAL_JWT_SECRET:-${BUS_AUTH_HS256_SECRET:-not-a-secret-local-development-hs256-key}}
EVENTS_JWT_SECRET=${BUS_WORKER_SERVICE_CYCLE_SMOKE_EVENTS_JWT_SECRET:-not-a-secret-local-development-hs256-key}
RECIPIENT=${BUS_WORKER_SERVICE_CYCLE_SMOKE_RECIPIENT:-bus-integration-task}
TASK_TEXT=${BUS_WORKER_SERVICE_CYCLE_SMOKE_TEXT:-Local worker service cycle smoke}

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
IDENTITIES_LOG="$PROOF_DIR/identities.log"
EVENTS_PID=
IDENTITIES_PID=
cleanup_token_file=false

cleanup() {
  if [ -n "${EVENTS_PID:-}" ]; then
    kill "$EVENTS_PID" >/dev/null 2>&1 || true
    wait "$EVENTS_PID" >/dev/null 2>&1 || true
  fi
  if [ -n "${IDENTITIES_PID:-}" ]; then
    kill "$IDENTITIES_PID" >/dev/null 2>&1 || true
    wait "$IDENTITIES_PID" >/dev/null 2>&1 || true
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

run_bus_identities_provider() {
  if [ -x "$ROOT/bus-api-provider-identities/bin/bus-api-provider-identities" ]; then
    "$ROOT/bus-api-provider-identities/bin/bus-api-provider-identities" "$@"
    return
  fi
  (
    cd "$ROOT/bus-api-provider-identities"
    go run ./cmd/bus-api-provider-identities "$@"
  )
}

run_bus_integration_workers() {
  if [ -x "$ROOT/bus-integration-worker/bin/bus-integration-worker" ]; then
    "$ROOT/bus-integration-worker/bin/bus-integration-worker" "$@"
    return
  fi
  (
    cd "$ROOT/bus-integration-worker"
    go run ./cmd/bus-integration-worker "$@"
  )
}

mint_local_token() {
  if [ -x "$ROOT/bus-operator-token/bin/bus-operator-token" ]; then
    BUS_AUTH_HS256_SECRET=$LOCAL_JWT_SECRET \
      "$ROOT/bus-operator-token/bin/bus-operator-token" \
      --format token issue --local \
      --subject acct_worker_service_cycle \
      --audience ai.hg.fi/api \
      --scope 'events:send events:listen identities:resolve task:send task:read workers:write workers:read' \
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
      --scope 'events:send events:listen identities:resolve task:send task:read workers:write workers:read' \
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

BUS_API_JWT_SECRET=$EVENTS_JWT_SECRET \
BUS_IDENTITIES_BOOTSTRAP_PRINCIPAL_ID=acct_worker_service_cycle \
BUS_IDENTITIES_BOOTSTRAP_GRANTS='identities:resolve events:send events:listen task:send task:read workers:write workers:read' \
run_bus_identities_provider \
  --listen "$IDENTITIES_ADDR" \
  --state-file "$PROOF_DIR/identities-state.json" >"$IDENTITIES_LOG" 2>&1 &
IDENTITIES_PID=$!

identities_ready=false
attempt=0
while [ "$attempt" -lt 30 ]; do
  if curl -sS -o /dev/null "$IDENTITIES_API_URL/api/v1/identities/access/check" 2>/dev/null; then
    identities_ready=true
    break
  fi
  attempt=$((attempt + 1))
  sleep 1
done
if [ "$identities_ready" != true ]; then
  printf 'local Identities API did not become ready at %s\n' "$IDENTITIES_API_URL" >&2
  printf 'provider log:\n' >&2
  sed -n '1,160p' "$IDENTITIES_LOG" >&2 || true
  exit 1
fi

(
  cd "$ROOT/bus-api-provider-events"
  BUS_API_JWT_SECRET=$EVENTS_JWT_SECRET \
    BUS_API_IDENTITIES_API_URL=$IDENTITIES_API_URL \
    BUS_API_IDENTITIES_API_TOKEN_FILE=$TOKEN_FILE \
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

create_output=$(run_bus_task --api-url "$API_URL" --token-file "$TOKEN_FILE" --format json new @"$RECIPIENT" "$TASK_TEXT")
printf '%s\n' "$create_output"

work_ref=$(printf '%s\n' "$create_output" | jq -er '.task_ref | strings | select(length > 0)')
if [ -z "$work_ref" ]; then
  printf 'could not determine task ref from create output\n' >&2
  exit 1
fi

status_output=$(run_bus_task --api-url "$API_URL" --token-file "$TOKEN_FILE" --format json status "$work_ref")
printf '%s\n' "$status_output" | jq -e --arg work_ref "$work_ref" \
  '.task_ref == $work_ref and .status == "open"' >/dev/null || {
  printf 'created task is not the expected open task: %s\n' "$status_output" >&2
  exit 1
}

tasks_file="$PROOF_DIR/tasks.json"
jq -n --arg work_ref "$work_ref" --arg recipient "$RECIPIENT" \
  '{tasks:[{work_ref:$work_ref,recipient:$recipient,status:"open"}]}' >"$tasks_file"

cycle_output=$(run_bus_integration_workers \
  --scheduler-observed-once \
  --events-url "$API_URL" \
  --token-file "$TOKEN_FILE" \
  --scheduler-tasks-file "$tasks_file" \
  --scheduler-worker-id local-service-cycle-supervisor \
  --scheduler-worker-groups smoke \
  --environment-id local \
  --scheduler-max-parallel 1)
printf '%s\n' "$cycle_output"

printf '%s\n' "$cycle_output" | jq -e --arg work_ref "$work_ref" \
  '.refill_requested == 1 and .create_request_work_refs == [$work_ref]' >/dev/null || {
  printf 'supervisor cycle did not request one refill\n' >&2
  exit 1
}

progress_out="$PROOF_DIR/progress.ndjson"
health_out="$PROOF_DIR/health.ndjson"
start_out="$PROOF_DIR/start.ndjson"

run_bus_events --api-url "$API_URL" --token-file "$TOKEN_FILE" listen --name bus.worker.supervisor.progress --replay --no-follow >"$progress_out"
run_bus_events --api-url "$API_URL" --token-file "$TOKEN_FILE" listen --name bus.worker.supervisor.health --replay --no-follow >"$health_out"
run_bus_events --api-url "$API_URL" --token-file "$TOKEN_FILE" listen --name bus.workers.create.request --replay --no-follow >"$start_out"

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
grep -q '"name":"bus.workers.create.request"' "$start_out" || {
  printf 'missing worker start request event\n' >&2
  exit 1
}
grep -q "\"task_ref\":\"$work_ref\"" "$start_out" || {
  printf 'worker start request did not target %s\n' "$work_ref" >&2
  exit 1
}

printf 'local worker service cycle smoke ok work_ref=%s api_url=%s\n' "$work_ref" "$API_URL"
