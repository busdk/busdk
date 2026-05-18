#!/usr/bin/env bash
set -euo pipefail
[[ "${BUS_E2E_VERBOSE:-0}" = "1" ]] && set -x

root_dir="$(cd "$(dirname "$0")/../.." && pwd)"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

mkdir -p "$tmp_dir/bin" "$tmp_dir/state"

cat >"$tmp_dir/bin/bus" <<'SH'
#!/usr/bin/env sh
set -eu
printf '%s\n' "$*" >>"$BUS_STUB_LOG"
if [ "${BUS_STUB_FAIL:-0}" = "1" ]; then
  printf 'forced monitor failure\n' >&2
  exit 7
fi
case "$*" in
  "dev work monitor --format json --quiet-after 20m --stale-after 2h")
    printf '{"active":[],"terminal":[],"quiet":false}\n'
    ;;
  *)
    printf 'unexpected bus invocation: %s\n' "$*" >&2
    exit 2
    ;;
esac
SH
chmod +x "$tmp_dir/bin/bus"

env PATH="$tmp_dir/bin:$PATH" \
  BUS_STUB_LOG="$tmp_dir/bus.log" \
  BUS_DEV_SUPERVISOR_STATE_DIR="$tmp_dir/state" \
  BUS_DEV_SUPERVISOR_ONCE=true \
  BUS_DEV_SUPERVISOR_QUIET_AFTER=20m \
  BUS_DEV_SUPERVISOR_STALE_AFTER=2h \
  "$root_dir/scripts/dev-task-supervisor-heartbeat.sh" run

grep -q '^dev work monitor --format json --quiet-after 20m --stale-after 2h$' "$tmp_dir/bus.log"
grep -q '"schema_version": "busdk.supervisor.heartbeat/v1"' "$tmp_dir/state/heartbeat-status.json"
grep -q '"status": "ok"' "$tmp_dir/state/heartbeat-status.json"
grep -q '"policy_file": "' "$tmp_dir/state/heartbeat-status.json"
grep -q '"action_plan_file": "' "$tmp_dir/state/heartbeat-status.json"
grep -q '"active":\[\]' "$tmp_dir/state/work-monitor.json"
grep -q '"schema_version": "busdk.supervisor.policy_cycle/v1"' "$tmp_dir/state/policy-cycle.json"
grep -q '"decision": "noop"' "$tmp_dir/state/policy-cycle.json"
grep -q '"safe_work_available": false' "$tmp_dir/state/policy-cycle.json"
grep -q '"no_op_reason": "no_active_or_terminal_tasks"' "$tmp_dir/state/policy-cycle.json"
grep -q '"action_plan_file": "' "$tmp_dir/state/policy-cycle.json"
grep -q '"schema_version": "busdk.supervisor.action_plan/v1"' "$tmp_dir/state/action-plan.json"
grep -q '"dry_run": true' "$tmp_dir/state/action-plan.json"
grep -q '"execute_actions": false' "$tmp_dir/state/action-plan.json"
grep -q '"eligible": true' "$tmp_dir/state/action-plan.json"
grep -q '"reason": "no_active_or_terminal_tasks"' "$tmp_dir/state/action-plan.json"
grep -q '"event_type":"supervisor.noop"' "$tmp_dir/state/supervisor-events.jsonl"
grep -q '"schema_version": "busdk.supervisor.noop_evidence/v1"' "$tmp_dir/state/noop-evidence.json"

env PATH="$tmp_dir/bin:$PATH" \
  BUS_DEV_SUPERVISOR_STATE_DIR="$tmp_dir/state" \
  BUS_DEV_SUPERVISOR_MAX_AGE_SECONDS=86400 \
  "$root_dir/scripts/dev-task-supervisor-heartbeat.sh" check >/dev/null

printf '1\n' >"$tmp_dir/state/heartbeat.epoch"
if env PATH="$tmp_dir/bin:$PATH" \
  BUS_DEV_SUPERVISOR_STATE_DIR="$tmp_dir/state" \
  BUS_DEV_SUPERVISOR_MAX_AGE_SECONDS=1 \
  "$root_dir/scripts/dev-task-supervisor-heartbeat.sh" check >/dev/null 2>&1; then
  printf 'FAIL supervisor heartbeat selftest: stale heartbeat passed health check\n' >&2
  exit 1
fi

if env PATH="$tmp_dir/bin:$PATH" \
  BUS_STUB_LOG="$tmp_dir/bus-fail.log" \
  BUS_STUB_FAIL=1 \
  BUS_DEV_SUPERVISOR_STATE_DIR="$tmp_dir/state-fail" \
  BUS_DEV_SUPERVISOR_ONCE=true \
  "$root_dir/scripts/dev-task-supervisor-heartbeat.sh" run >/dev/null 2>&1; then
  printf 'FAIL supervisor heartbeat selftest: failed monitor exited successfully\n' >&2
  exit 1
fi
grep -q '"status": "failed"' "$tmp_dir/state-fail/heartbeat-status.json"
grep -q '"status": "monitor_failed"' "$tmp_dir/state-fail/policy-cycle.json"
grep -q '"status": "monitor_failed"' "$tmp_dir/state-fail/action-plan.json"
grep -q '"reason": "monitor_failed"' "$tmp_dir/state-fail/action-plan.json"

cat >"$tmp_dir/terminal-monitor.json" <<'JSON'
{
  "active": [],
  "terminal": [
    {
      "work_ref": "busdk#1",
      "status": "done",
      "app_server_closeout": {
        "task_complete": true,
        "remaining_blockers": []
      }
    },
    {
      "work_ref": "busdk#2",
      "status": "failed",
      "app_server_closeout": {
        "task_complete": false,
        "remaining_blockers": ["missing tests"]
      }
    }
  ],
  "quiet": false
}
JSON

env BUS_DEV_SUPERVISOR_STATE_DIR="$tmp_dir/state-classify" \
  "$root_dir/scripts/dev-task-supervisor-heartbeat.sh" classify "$tmp_dir/terminal-monitor.json"

grep -q '"decision": "classify_terminal"' "$tmp_dir/state-classify/policy-cycle.json"
grep -q '"safe_work_available": true' "$tmp_dir/state-classify/policy-cycle.json"
grep -q '"total": 2' "$tmp_dir/state-classify/policy-cycle.json"
grep -q '"ready_for_review": 1' "$tmp_dir/state-classify/policy-cycle.json"
grep -q '"needs_reopen": 1' "$tmp_dir/state-classify/policy-cycle.json"
grep -q '"blocked": 1' "$tmp_dir/state-classify/policy-cycle.json"
grep -q '"review_promoted_commits"' "$tmp_dir/state-classify/action-plan.json"
grep -q '"reopen_incomplete_tasks"' "$tmp_dir/state-classify/action-plan.json"
grep -q '"record_blockers"' "$tmp_dir/state-classify/action-plan.json"
grep -q '"reason": "terminal_triage_required"' "$tmp_dir/state-classify/action-plan.json"
test ! -e "$tmp_dir/state-classify/supervisor-events.jsonl"

printf 'dev-task supervisor heartbeat OK\n'
