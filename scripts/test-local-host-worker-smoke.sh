#!/bin/sh
set -eu

usage() {
  cat <<'EOF'
usage: scripts/test-local-host-worker-smoke.sh

Starts a disposable local Bus Events API from source, creates one ready task,
launches a host-side local worker through scripts/local-task-host-worker-launcher.sh,
waits for terminal state, and prints replay/status evidence.

Defaults are deterministic and quota-safe:
  BUS_LOCAL_HOST_WORKER_SMOKE_AGENT_BACKEND=self-test
  BUS_LOCAL_HOST_WORKER_SMOKE_WORKTREE=false
  BUS_LOCAL_HOST_WORKER_SMOKE_COMMIT=false

Useful overrides:
  BUS_LOCAL_HOST_WORKER_SMOKE_AGENT_BACKEND=codex-appserver
  BUS_LOCAL_HOST_WORKER_SMOKE_MODEL=gpt-5.3-codex-spark
  BUS_LOCAL_HOST_WORKER_SMOKE_RECIPIENT=bus-worker
  BUS_LOCAL_HOST_WORKER_SMOKE_TEXT="Local host worker smoke"
EOF
}

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
  usage
  exit 0
fi

ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
ADDR=${BUS_LOCAL_HOST_WORKER_SMOKE_ADDR:-127.0.0.1:8081}
API_URL="http://$ADDR"
TOKEN_FILE=${BUS_LOCAL_HOST_WORKER_SMOKE_TOKEN_FILE:-$ROOT/tmp/local-ai-platform/bus-config/auth/api-token}
MINT_TOKEN=${BUS_LOCAL_HOST_WORKER_SMOKE_MINT_TOKEN:-true}
LOCAL_JWT_SECRET=${BUS_LOCAL_HOST_WORKER_SMOKE_LOCAL_JWT_SECRET:-${BUS_AUTH_HS256_SECRET:-not-a-secret-local-development-hs256-key}}
EVENTS_JWT_SECRET=${BUS_LOCAL_HOST_WORKER_SMOKE_EVENTS_JWT_SECRET:-not-a-secret-local-development-hs256-key}
RECIPIENT=${BUS_LOCAL_HOST_WORKER_SMOKE_RECIPIENT:-bus-worker}
TASK_TEXT=${BUS_LOCAL_HOST_WORKER_SMOKE_TEXT:-Local host worker smoke}
READY_TEXT=${BUS_LOCAL_HOST_WORKER_SMOKE_READY_TEXT:-Approved for host worker pickup}
AGENT_BACKEND=${BUS_LOCAL_HOST_WORKER_SMOKE_AGENT_BACKEND:-self-test}
MODEL=${BUS_LOCAL_HOST_WORKER_SMOKE_MODEL:-}
WORKTREE=${BUS_LOCAL_HOST_WORKER_SMOKE_WORKTREE:-false}
COMMIT=${BUS_LOCAL_HOST_WORKER_SMOKE_COMMIT:-false}
CODEX_NETWORK_ACCESS=${BUS_LOCAL_HOST_WORKER_SMOKE_CODEX_NETWORK_ACCESS:-true}
EVENTS_TRACE=${BUS_LOCAL_HOST_WORKER_SMOKE_EVENTS_TRACE:-true}
TASK_PROMPT_PROFILE=${BUS_LOCAL_HOST_WORKER_SMOKE_TASK_PROMPT_PROFILE:-minimal-smoke}

cleanup_config_dir=false
if [ -n "${BUS_LOCAL_HOST_WORKER_SMOKE_CONFIG_DIR:-}" ]; then
  BUS_CONFIG_DIR=$BUS_LOCAL_HOST_WORKER_SMOKE_CONFIG_DIR
else
  BUS_CONFIG_DIR=$(mktemp -d "${TMPDIR:-/tmp}/bus-local-host-worker-config.XXXXXX")
  cleanup_config_dir=true
fi
export BUS_CONFIG_DIR

PROOF_DIR=$(mktemp -d "${TMPDIR:-/tmp}/bus-local-host-worker-smoke.XXXXXX")
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

mint_local_token() {
  if [ -x "$ROOT/bus-operator-token/bin/bus-operator-token" ]; then
    BUS_AUTH_HS256_SECRET=$LOCAL_JWT_SECRET \
      "$ROOT/bus-operator-token/bin/bus-operator-token" \
      --format token issue --local \
      --subject acct_local_spark \
      --audience ai.hg.fi/api \
      --scope 'events:send events:listen dev:task:send dev:task:read dev:task:reply dev:task:claim notes.write notes.read notes.search' \
      --ttl 2h
    return
  fi
  (
    cd "$ROOT/bus-operator-token"
    BUS_AUTH_HS256_SECRET=$LOCAL_JWT_SECRET \
      go run ./cmd/bus-operator-token \
      --format token issue --local \
      --subject acct_local_spark \
      --audience ai.hg.fi/api \
      --scope 'events:send events:listen dev:task:send dev:task:read dev:task:reply dev:task:claim notes.write notes.read notes.search' \
      --ttl 2h
  )
}

if [ "$MINT_TOKEN" = true ]; then
  TOKEN_FILE=$(mktemp "${TMPDIR:-/tmp}/bus-local-host-worker-token.XXXXXX")
  cleanup_token_file=true
  mint_local_token >"$TOKEN_FILE"
elif [ ! -f "$TOKEN_FILE" ]; then
  printf 'token file not found: %s\n' "$TOKEN_FILE" >&2
  exit 1
fi

(
  cd "$ROOT/bus-api-provider-events"
  BUS_EVENTS_JWT_SECRET=$EVENTS_JWT_SECRET \
  BUS_EVENTS_TRACE=$EVENTS_TRACE \
    go run ./cmd/bus-api-provider-events --addr "$ADDR" --events-backend memory
) >"$EVENTS_LOG" 2>&1 &
EVENTS_PID=$!

ready=false
attempt=0
while [ "$attempt" -lt 30 ]; do
  if ! kill -0 "$EVENTS_PID" >/dev/null 2>&1; then
    printf 'local Events API process exited before readiness at %s\n' "$API_URL" >&2
    sed -n '1,160p' "$EVENTS_LOG" >&2 || true
    exit 1
  fi
  if run_bus_task --api-url "$API_URL" --token-file "$TOKEN_FILE" list @"$RECIPIENT" >/dev/null 2>&1; then
    ready=true
    break
  fi
  attempt=$((attempt + 1))
  sleep 1
done

if [ "$ready" != true ]; then
  printf 'local Events API did not become ready at %s\n' "$API_URL" >&2
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

worker_token=$(
  BUS_API_TOKEN=$(cat "$TOKEN_FILE") \
  BUS_EVENTS_API_URL=$API_URL \
  BUS_TASK_REMOTE_ID=localhost \
  BUS_TASK_REMOTE_KIND=compose \
  BUS_TASK_RECIPIENT=$RECIPIENT \
  BUS_TASK_WORK_REF=$work_ref \
  BUS_TASK_AGENT_BACKEND=$AGENT_BACKEND \
  BUS_TASK_WORKSPACE_ROOT=$ROOT \
  BUS_TASK_WORKSPACE_HOST_ROOT=$ROOT \
  BUS_TASK_WORKTREE=$WORKTREE \
  BUS_TASK_COMMIT=$COMMIT \
  BUS_TASK_CODEX_NETWORK_ACCESS=$CODEX_NETWORK_ACCESS \
  BUS_TASK_CODEX_STATE_ROOT=$ROOT/tmp/bus-dev-task-codex-homes \
  BUS_TASK_WORKTREE_ROOT=$ROOT/tmp/bus-dev-task-worktrees \
  BUS_TASK_CODEX_MODEL=$MODEL \
  BUS_TASK_PROMPT_PROFILE=$TASK_PROMPT_PROFILE \
  "$ROOT/scripts/local-task-host-worker-launcher.sh"
)
printf 'launched worker %s for %s\n' "$worker_token" "$work_ref"

run_bus_task --api-url "$API_URL" --token-file "$TOKEN_FILE" wait "$work_ref"
run_bus_task --api-url "$API_URL" --token-file "$TOKEN_FILE" show "$work_ref"
run_bus_task --api-url "$API_URL" --token-file "$TOKEN_FILE" status
