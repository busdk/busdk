#!/bin/sh
set -eu

usage() {
  cat <<'EOF'
usage: scripts/local-task-host-worker-launcher.sh

Launch one local bus-integration-task worker directly on the host instead of
through docker compose. The worker contract comes from BUS_TASK_* and
BUS_API_TOKEN / BUS_EVENTS_API_URL environment variables, as provided by
bus-task's BUS_DEV_WORKER_LAUNCHER hook.

The script starts the worker detached, writes logs under
tmp/local-task-host-workers/logs, and prints one opaque worker token on stdout.
EOF
}

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
  usage
  exit 0
fi

ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)

require_env() {
  name=$1
  eval "value=\${$name:-}"
  if [ -z "$value" ]; then
    printf 'missing required environment variable: %s\n' "$name" >&2
    exit 2
  fi
}

sanitize() {
  printf '%s' "$1" | tr -cs '[:alnum:]._-#' '-'
}

worker_template_value() {
  wtv_output=$1
  wtv_key=$2
  printf '%s\n' "$wtv_output" | awk -F '	' -v key="$wtv_key" '
    $1 == key {
      print $2
      found = 1
      exit
    }
    END {
      if (!found) {
        exit 1
      }
    }
  '
}

require_env BUS_API_TOKEN
require_env BUS_EVENTS_API_URL
require_env BUS_TASK_RECIPIENT

recipient=${BUS_TASK_RECIPIENT}
work_ref=${BUS_TASK_WORK_REF:-any}
backend=${BUS_TASK_AGENT_BACKEND:-codex-appserver}
codex_command=${BUS_TASK_CODEX_COMMAND:-codex}

export BUS_TASK_WORKSPACE_ROOT=${BUS_TASK_WORKSPACE_ROOT:-$ROOT}
export BUS_TASK_WORKSPACE_HOST_ROOT=${BUS_TASK_WORKSPACE_HOST_ROOT:-$ROOT}
export BUS_TASK_WORKTREE=${BUS_TASK_WORKTREE:-true}
export BUS_TASK_WORKTREE_ROOT=${BUS_TASK_WORKTREE_ROOT:-$ROOT/tmp/bus-dev-task-worktrees}
export BUS_TASK_CODEX_STATE_ROOT=${BUS_TASK_CODEX_STATE_ROOT:-$ROOT/tmp/bus-dev-task-codex-homes}
export BUS_TASK_CODEX_NETWORK_ACCESS=${BUS_TASK_CODEX_NETWORK_ACCESS:-true}
export BUS_TASK_GOPLS_MCP=${BUS_TASK_GOPLS_MCP:-auto}
export BUS_TASK_GOPLS_COMMAND=${BUS_TASK_GOPLS_COMMAND:-gopls}
export BUS_TASK_GOPLS_MIN_VERSION=${BUS_TASK_GOPLS_MIN_VERSION:-v0.20.0}
export BUS_TASK_GO_DEBUGGER=${BUS_TASK_GO_DEBUGGER:-auto}
export BUS_TASK_GO_DEBUGGER_COMMAND=${BUS_TASK_GO_DEBUGGER_COMMAND:-dlv}
export BUS_TASK_COMMIT=${BUS_TASK_COMMIT:-true}
export BUS_TASK_TIMEOUT=${BUS_TASK_TIMEOUT:-30m}

if [ -z "${BUS_NOTES_API_TOKEN:-}" ]; then
  export BUS_NOTES_API_TOKEN=$BUS_API_TOKEN
fi

if [ -z "${BUS_TASK_CODEX_SOURCE_HOME:-}" ] && [ -d "${HOME}/.codex" ]; then
  export BUS_TASK_CODEX_SOURCE_HOME=${HOME}/.codex
fi

if [ "$backend" = "codex-appserver" ] && ! command -v "$codex_command" >/dev/null 2>&1; then
  printf 'required codex command not found on PATH: %s\n' "$codex_command" >&2
  exit 2
fi

mkdir -p \
  "$ROOT/.busdk-tools/bin" \
  "$ROOT/tmp/busdk-tools" \
  "$ROOT/tmp/local-task-host-workers/logs" \
  "$BUS_TASK_WORKTREE_ROOT" \
  "$BUS_TASK_CODEX_STATE_ROOT"

BUSDK_WORKSPACE_ROOT=$ROOT \
BUSDK_TOOL_WRAPPER_DIR=$ROOT/.busdk-tools/bin \
BUSDK_TOOL_BIN_DIR=$ROOT/tmp/busdk-tools \
  "$ROOT/scripts/busdk-refresh-tools.sh" --refresh-only >/dev/null

export PATH=$ROOT/.busdk-tools/bin:$PATH

if [ -n "${BUS_TASK_WORKER_TEMPLATE:-}" ] && { [ -z "${BUS_TASK_CODEX_MODEL:-}" ] || [ -z "${BUS_TASK_CODEX_SANDBOX:-}" ]; }; then
  worker_template_cli=${BUS_TASK_WORKER_TEMPLATE_CLI:-$ROOT/bus-worker/bin/bus-worker}
  if [ ! -x "$worker_template_cli" ]; then
    printf 'worker template resolver not executable: %s\n' "$worker_template_cli" >&2
    exit 2
  fi
  worker_template_output=$("$worker_template_cli" -C "$ROOT" template show "$BUS_TASK_WORKER_TEMPLATE")
  if [ -z "${BUS_TASK_CODEX_MODEL:-}" ]; then
    export BUS_TASK_CODEX_MODEL=$(worker_template_value "$worker_template_output" default_model)
  fi
  if [ -z "${BUS_TASK_CODEX_SANDBOX:-}" ]; then
    export BUS_TASK_CODEX_SANDBOX=$(worker_template_value "$worker_template_output" sandbox)
  fi
fi

stamp=$(date '+%Y%m%d-%H%M%S')
token=$(sanitize "${recipient}-${work_ref}")
log_file=$ROOT/tmp/local-task-host-workers/logs/${stamp}-${token}.log

(
  cd "$ROOT"
  nohup "$ROOT/.busdk-tools/bin/bus-integration-task" >"$log_file" 2>&1 &
  pid=$!
  printf '%s\n' "$pid" >"${log_file}.pid"
  printf '%s\n' "$log_file" >"${log_file}.path"
  printf 'host-worker-pid-%s\n' "$pid"
)
