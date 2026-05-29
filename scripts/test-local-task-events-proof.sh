#!/bin/sh
set -eu

usage() {
  cat <<'EOF'
usage: scripts/test-local-task-events-proof.sh

Starts a disposable local Bus Events API from source on 127.0.0.1:8081,
creates one bus task, marks it ready, and prints list/show/monitor evidence.

Configuration via environment:
  BUS_LOCAL_TASK_EVENTS_PROOF_ADDR=127.0.0.1:8081
  BUS_LOCAL_TASK_EVENTS_PROOF_TOKEN_FILE=/path/to/api-token
  BUS_LOCAL_TASK_EVENTS_PROOF_EVENTS_JWT_SECRET=...
  BUS_LOCAL_TASK_EVENTS_PROOF_RECIPIENT=bus-worker
  BUS_LOCAL_TASK_EVENTS_PROOF_TEXT="Local substrate proof task"
  BUS_LOCAL_TASK_EVENTS_PROOF_READY_TEXT="Approved for worker pickup"
  BUS_LOCAL_TASK_EVENTS_PROOF_CONFIG_DIR=/tmp/custom-bus-config

This is an explicit disposable proof path. It uses the Events memory backend
and is not a substitute for the durable local Compose/systemd stack used for
real worker lanes.
EOF
}

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
  usage
  exit 0
fi

ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
ADDR=${BUS_LOCAL_TASK_EVENTS_PROOF_ADDR:-127.0.0.1:8081}
API_URL="http://$ADDR"
TOKEN_FILE=${BUS_LOCAL_TASK_EVENTS_PROOF_TOKEN_FILE:-$ROOT/tmp/local-ai-platform/bus-config/auth/api-token}
EVENTS_JWT_SECRET=${BUS_LOCAL_TASK_EVENTS_PROOF_EVENTS_JWT_SECRET:-not-a-secret-local-development-hs256-key}
RECIPIENT=${BUS_LOCAL_TASK_EVENTS_PROOF_RECIPIENT:-bus-worker}
TASK_TEXT=${BUS_LOCAL_TASK_EVENTS_PROOF_TEXT:-Local substrate proof task}
READY_TEXT=${BUS_LOCAL_TASK_EVENTS_PROOF_READY_TEXT:-Approved for worker pickup}

cleanup_config_dir=false
if [ -n "${BUS_LOCAL_TASK_EVENTS_PROOF_CONFIG_DIR:-}" ]; then
  BUS_CONFIG_DIR=$BUS_LOCAL_TASK_EVENTS_PROOF_CONFIG_DIR
else
  BUS_CONFIG_DIR=$(mktemp -d "${TMPDIR:-/tmp}/bus-task-proof.XXXXXX")
  cleanup_config_dir=true
fi
export BUS_CONFIG_DIR

if [ ! -f "$TOKEN_FILE" ]; then
  printf 'token file not found: %s\n' "$TOKEN_FILE" >&2
  exit 1
fi

PROOF_DIR=$(mktemp -d "${TMPDIR:-/tmp}/bus-task-events-proof.XXXXXX")
EVENTS_LOG="$PROOF_DIR/events.log"
EVENTS_PID=

cleanup() {
  if [ -n "${EVENTS_PID:-}" ]; then
    kill "$EVENTS_PID" >/dev/null 2>&1 || true
    wait "$EVENTS_PID" >/dev/null 2>&1 || true
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

(
  cd "$ROOT/bus-api-provider-events"
  BUS_EVENTS_JWT_SECRET=$EVENTS_JWT_SECRET \
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

run_bus_task --api-url "$API_URL" --token-file "$TOKEN_FILE" ready "$work_ref" "$READY_TEXT"
run_bus_task --api-url "$API_URL" --token-file "$TOKEN_FILE" list @"$RECIPIENT"
run_bus_task --api-url "$API_URL" --token-file "$TOKEN_FILE" show "$work_ref"
run_bus_task --api-url "$API_URL" --token-file "$TOKEN_FILE" monitor --format json
