#!/bin/sh
set -eu

is_true() {
  case "${1:-}" in
    1|true|TRUE|yes|YES|on|ON) return 0 ;;
    *) return 1 ;;
  esac
}

workspace_root=${BUSDK_WORKSPACE_ROOT:-/workspace}
refresh_script=$workspace_root/scripts/busdk-refresh-tools.sh
if [ -x "$refresh_script" ]; then
  "$refresh_script" --refresh-only
fi

if [ "$#" -gt 0 ]; then
  case "$1" in
    -*) set -- bus-integration-dev-task "$@" ;;
  esac
  exec "$@"
fi

: "${BUS_DEV_TASK_AGENT_BACKEND:=codex-appserver}"
: "${BUS_DEV_TASK_CODEX_COMMAND:=codex}"
if [ -z "${BUS_DEV_TASK_CODEX_ARGS+x}" ]; then
  BUS_DEV_TASK_CODEX_ARGS='["app-server","-c","approval_policy=\"never\"","-c","shell_environment_policy.inherit=all","-c","sandbox_mode=\"workspace-write\"","-c","sandbox_workspace_write.network_access=true"]'
fi
: "${BUS_DEV_TASK_CODEX_APPROVAL_POLICY:=never}"
: "${BUS_DEV_TASK_CODEX_SANDBOX:=workspace-write}"
: "${BUS_DEV_TASK_CODEX_NETWORK_ACCESS:=true}"
: "${BUS_DEV_TASK_CODEX_INHERIT_ENV:=true}"
: "${BUS_DEV_TASK_CODEX_STATE_ROOT:=/tmp/bus-dev-task-codex-homes}"
: "${BUS_DEV_TASK_GOPLS_MCP:=auto}"
: "${BUS_DEV_TASK_GOPLS_COMMAND:=gopls}"
: "${BUS_DEV_TASK_GOPLS_MIN_VERSION:=v0.20.0}"
: "${BUS_DEV_TASK_GO_DEBUGGER:=auto}"
: "${BUS_DEV_TASK_GO_DEBUGGER_COMMAND:=dlv}"
: "${BUS_DEV_TASK_CONTAINER_PROFILE:=codex}"
: "${BUS_DEV_TASK_WORKSPACE_ROOT:=/workspace}"
: "${BUS_DEV_TASK_WORKTREE:=true}"
: "${BUS_DEV_TASK_WORKTREE_ROOT:=/workspace/tmp/bus-dev-task-worktrees}"
: "${BUS_DEV_TASK_COMMAND_JSON:=[]}"
: "${BUS_DEV_TASK_PRE_COMMAND_JSON:=[]}"
: "${BUS_DEV_TASK_POST_COMMAND_JSON:=[]}"
: "${BUS_DEV_TASK_COMMIT:=true}"
: "${BUS_DEV_TASK_TIMEOUT:=30m}"
: "${BUS_DEV_TASK_ONCE:=true}"
: "${BUS_DEV_TASK_IDLE_TIMEOUT:=10m}"

export BUS_DEV_TASK_AGENT_BACKEND
export BUS_DEV_TASK_CODEX_COMMAND
export BUS_DEV_TASK_CODEX_ARGS
export BUS_DEV_TASK_CODEX_APPROVAL_POLICY
export BUS_DEV_TASK_CODEX_SANDBOX
export BUS_DEV_TASK_CODEX_NETWORK_ACCESS
export BUS_DEV_TASK_CODEX_INHERIT_ENV
export BUS_DEV_TASK_CODEX_STATE_ROOT
export BUS_DEV_TASK_GOPLS_MCP
export BUS_DEV_TASK_GOPLS_COMMAND
export BUS_DEV_TASK_GOPLS_MIN_VERSION
export BUS_DEV_TASK_GO_DEBUGGER
export BUS_DEV_TASK_GO_DEBUGGER_COMMAND
export BUS_DEV_TASK_CONTAINER_PROFILE
export BUS_DEV_TASK_WORKSPACE_ROOT
export BUS_DEV_TASK_WORKTREE
export BUS_DEV_TASK_WORKTREE_ROOT
export BUS_DEV_TASK_COMMAND_JSON
export BUS_DEV_TASK_PRE_COMMAND_JSON
export BUS_DEV_TASK_POST_COMMAND_JSON
export BUS_DEV_TASK_COMMIT
export BUS_DEV_TASK_TIMEOUT
export BUS_DEV_TASK_ONCE
export BUS_DEV_TASK_IDLE_TIMEOUT

if [ -z "${BUS_NOTES_API_TOKEN:-}" ] && [ -n "${BUS_API_TOKEN:-}" ]; then
  export BUS_NOTES_API_TOKEN=$BUS_API_TOKEN
fi

set -- bus-integration-dev-task

if is_true "${BUS_DEV_TASK_WORKER_START_REQUEST_CONSUMER:-}"; then
  set -- "$@" --worker-start-request-consumer
fi
if is_true "${BUS_DEV_TASK_TRACE:-}"; then
  set -- "$@" --trace
fi

if [ -n "${BUS_EVENTS_API_URL:-}" ]; then
  set -- "$@" --events-url "$BUS_EVENTS_API_URL"
fi
if [ -n "${BUS_DEV_TASK_RECIPIENT:-}" ]; then
  set -- "$@" --recipient "$BUS_DEV_TASK_RECIPIENT"
fi
if [ -n "${BUS_DEV_TASK_WORK_REF:-}" ]; then
  set -- "$@" --work-ref "$BUS_DEV_TASK_WORK_REF"
fi
if [ -n "${BUS_DEV_TASK_WRITE_SCOPES:-}" ]; then
  set -- "$@" --write-scopes "$BUS_DEV_TASK_WRITE_SCOPES"
fi
if [ -n "${BUS_DEV_TASK_REMOTE_ID:-}" ]; then
  set -- "$@" --remote-id "$BUS_DEV_TASK_REMOTE_ID"
fi
if [ -n "${BUS_DEV_TASK_REMOTE_KIND:-}" ]; then
  set -- "$@" --remote-kind "$BUS_DEV_TASK_REMOTE_KIND"
fi
if [ -n "${BUS_DEV_TASK_REMOTE_ENDPOINT:-}" ]; then
  set -- "$@" --remote-endpoint "$BUS_DEV_TASK_REMOTE_ENDPOINT"
fi
if [ -n "${BUS_DEV_TASK_ACCOUNT_ID:-}" ]; then
  set -- "$@" --account-id "$BUS_DEV_TASK_ACCOUNT_ID"
fi
if [ -n "${BUS_DEV_TASK_CONTAINER_IMAGE:-}" ]; then
  set -- "$@" --container-image "$BUS_DEV_TASK_CONTAINER_IMAGE"
fi
if [ -n "${BUS_DEV_TASK_CODEX_MODEL:-}" ]; then
  set -- "$@" --codex-model "$BUS_DEV_TASK_CODEX_MODEL"
fi
if [ -n "${BUS_DEV_TASK_POLICY_FILE:-}" ]; then
  set -- "$@" --policy-file "$BUS_DEV_TASK_POLICY_FILE"
fi
if [ -n "${BUS_DEV_TASK_WORKSPACE_HOST_ROOT:-}" ]; then
  set -- "$@" --workspace-host-root "$BUS_DEV_TASK_WORKSPACE_HOST_ROOT"
fi
if [ -n "${BUS_DEV_TASK_WORKSPACE_RECIPIENT:-}" ]; then
  set -- "$@" --workspace-recipient "$BUS_DEV_TASK_WORKSPACE_RECIPIENT"
fi
if [ -n "${BUS_DEV_TASK_COMMIT_MESSAGE:-}" ]; then
  set -- "$@" --commit-message "$BUS_DEV_TASK_COMMIT_MESSAGE"
fi

set -- "$@" \
  --agent-backend "$BUS_DEV_TASK_AGENT_BACKEND" \
  --codex-command "$BUS_DEV_TASK_CODEX_COMMAND" \
  --codex-args-json "$BUS_DEV_TASK_CODEX_ARGS" \
  --codex-approval-policy "$BUS_DEV_TASK_CODEX_APPROVAL_POLICY" \
  --codex-sandbox "$BUS_DEV_TASK_CODEX_SANDBOX" \
  --codex-network-access="$BUS_DEV_TASK_CODEX_NETWORK_ACCESS" \
  --codex-inherit-env="$BUS_DEV_TASK_CODEX_INHERIT_ENV" \
  --codex-state-root "$BUS_DEV_TASK_CODEX_STATE_ROOT" \
  --gopls-mcp "$BUS_DEV_TASK_GOPLS_MCP" \
  --gopls-command "$BUS_DEV_TASK_GOPLS_COMMAND" \
  --gopls-min-version "$BUS_DEV_TASK_GOPLS_MIN_VERSION" \
  --go-debugger "$BUS_DEV_TASK_GO_DEBUGGER" \
  --go-debugger-command "$BUS_DEV_TASK_GO_DEBUGGER_COMMAND" \
  --container-profile "$BUS_DEV_TASK_CONTAINER_PROFILE" \
  --workspace-root "$BUS_DEV_TASK_WORKSPACE_ROOT" \
  --worktree="$BUS_DEV_TASK_WORKTREE" \
  --worktree-root "$BUS_DEV_TASK_WORKTREE_ROOT" \
  --command-json "$BUS_DEV_TASK_COMMAND_JSON" \
  --pre-command-json "$BUS_DEV_TASK_PRE_COMMAND_JSON" \
  --post-command-json "$BUS_DEV_TASK_POST_COMMAND_JSON" \
  --commit="$BUS_DEV_TASK_COMMIT" \
  --timeout "$BUS_DEV_TASK_TIMEOUT" \
  --once="$BUS_DEV_TASK_ONCE" \
  --idle-timeout "$BUS_DEV_TASK_IDLE_TIMEOUT"

if is_true "${BUS_DEV_TASK_IMAGE_DRY_RUN:-}"; then
  printf 'busdk dev-task worker image dry run\n'
  printf 'command:'
  for arg in "$@"; do
    printf ' %s' "$arg"
  done
  printf '\n'
  for key in BUS_API_TOKEN BUS_NOTES_API_TOKEN BUS_EVENTS_API_URL BUS_DEV_TASK_RECIPIENT BUS_DEV_TASK_WORK_REF BUS_DEV_TASK_WRITE_SCOPES; do
    case "$key" in
      BUS_API_TOKEN) value=${BUS_API_TOKEN:-} ;;
      BUS_NOTES_API_TOKEN) value=${BUS_NOTES_API_TOKEN:-} ;;
      BUS_EVENTS_API_URL) value=${BUS_EVENTS_API_URL:-} ;;
      BUS_DEV_TASK_RECIPIENT) value=${BUS_DEV_TASK_RECIPIENT:-} ;;
      BUS_DEV_TASK_WORK_REF) value=${BUS_DEV_TASK_WORK_REF:-} ;;
      BUS_DEV_TASK_WRITE_SCOPES) value=${BUS_DEV_TASK_WRITE_SCOPES:-} ;;
    esac
    case "$key" in
      *TOKEN*)
        if [ -n "$value" ]; then
          printf '%s=present(redacted)\n' "$key"
        else
          printf '%s=missing\n' "$key"
        fi
        ;;
      *)
        if [ -n "$value" ]; then
          printf '%s=%s\n' "$key" "$value"
        else
          printf '%s=missing\n' "$key"
        fi
        ;;
    esac
  done
  exit 0
fi

exec "$@"
