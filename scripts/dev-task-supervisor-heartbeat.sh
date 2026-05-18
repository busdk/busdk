#!/bin/sh
set -eu

usage() {
  printf 'usage: %s [run|check|classify SNAPSHOT_FILE [EXIT_CODE]]\n' "$0" >&2
  printf 'Runs or checks the BusDK AI Product Delivery Supervisor heartbeat.\n' >&2
}

truthy() {
  case "${1:-}" in
    1|true|TRUE|yes|YES|on|ON) return 0 ;;
    *) return 1 ;;
  esac
}

json_value() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

timestamp_utc() {
  date -u '+%Y-%m-%dT%H:%M:%SZ'
}

state_dir=${BUS_DEV_SUPERVISOR_STATE_DIR:-/workspace/tmp/dev-task-supervisor}
status_file=${BUS_DEV_SUPERVISOR_STATUS_FILE:-$state_dir/heartbeat-status.json}
policy_file=${BUS_DEV_SUPERVISOR_POLICY_FILE:-$state_dir/policy-cycle.json}
action_plan_file=${BUS_DEV_SUPERVISOR_ACTION_PLAN_FILE:-$state_dir/action-plan.json}
event_file=${BUS_DEV_SUPERVISOR_EVENT_FILE:-$state_dir/supervisor-events.jsonl}
noop_evidence_file=${BUS_DEV_SUPERVISOR_NOOP_EVIDENCE_FILE:-$state_dir/noop-evidence.json}
snapshot_file=${BUS_DEV_SUPERVISOR_SNAPSHOT_FILE:-$state_dir/work-monitor.json}
stderr_file=${BUS_DEV_SUPERVISOR_STDERR_FILE:-$state_dir/work-monitor.stderr}
epoch_file=${BUS_DEV_SUPERVISOR_EPOCH_FILE:-$state_dir/heartbeat.epoch}
interval_seconds=${BUS_DEV_SUPERVISOR_INTERVAL_SECONDS:-300}
max_age_seconds=${BUS_DEV_SUPERVISOR_MAX_AGE_SECONDS:-900}
quiet_after=${BUS_DEV_SUPERVISOR_QUIET_AFTER:-15m}
stale_after=${BUS_DEV_SUPERVISOR_STALE_AFTER:-1h}
once=${BUS_DEV_SUPERVISOR_ONCE:-false}

json_array_for_key() {
  awk -v key="$1" '
    BEGIN { target = "\"" key "\""; found = 0; depth = 0; in_string = 0; escape = 0; out = "" }
    { text = text $0 "\n" }
    END {
      for (i = 1; i <= length(text); i++) {
        c = substr(text, i, 1)
        if (!found && substr(text, i, length(target)) == target) {
          found = 1
          i += length(target) - 1
          continue
        }
        if (found && depth == 0) {
          if (c == "[") {
            depth = 1
            out = c
          }
          continue
        }
        if (depth > 0) {
          out = out c
          if (escape) {
            escape = 0
          } else if (c == "\\") {
            escape = 1
          } else if (c == "\"") {
            in_string = !in_string
          } else if (!in_string && c == "[") {
            depth++
          } else if (!in_string && c == "]") {
            depth--
            if (depth == 0) {
              print out
              exit
            }
          }
        }
      }
      print "[]"
    }
  ' "$2"
}

json_array_is_empty() {
  [ "$(printf '%s' "$1" | tr -d '[:space:]')" = "[]" ]
}

json_array_object_count() {
  awk '
    BEGIN { count = 0; depth = 0; in_string = 0; escape = 0 }
    {
      text = text $0 "\n"
    }
    END {
      for (i = 1; i <= length(text); i++) {
        c = substr(text, i, 1)
        if (escape) {
          escape = 0
        } else if (c == "\\") {
          escape = 1
        } else if (c == "\"") {
          in_string = !in_string
        } else if (!in_string && c == "{") {
          depth++
          if (depth == 1) {
            count++
          }
        } else if (!in_string && c == "}") {
          depth--
        }
      }
      print count
    }
  '
}

json_terminal_classification_counts() {
  awk '
    function classify_object(object_text) {
      if (object_text ~ /"task_complete"[[:space:]]*:[[:space:]]*true/) {
        ready++
      }
      if (object_text ~ /"task_complete"[[:space:]]*:[[:space:]]*false/ ||
          object_text ~ /"status"[[:space:]]*:[[:space:]]*"(failed|error)"/) {
        reopen++
      }
      if (object_text ~ /"status"[[:space:]]*:[[:space:]]*"blocked"/ ||
          object_text ~ /"remaining_blockers"[[:space:]]*:[[:space:]]*\[[[:space:]]*[{"]/) {
        blocked++
      }
    }
    BEGIN { depth = 0; in_string = 0; escape = 0; object_text = ""; ready = 0; reopen = 0; blocked = 0 }
    { text = text $0 "\n" }
    END {
      for (i = 1; i <= length(text); i++) {
        c = substr(text, i, 1)
        if (escape) {
          escape = 0
        } else if (c == "\\") {
          escape = 1
        } else if (c == "\"") {
          in_string = !in_string
        }

        if (!in_string && c == "{") {
          depth++
        }
        if (depth > 0) {
          object_text = object_text c
        }
        if (!in_string && c == "}") {
          if (depth == 1) {
            classify_object(object_text)
            object_text = ""
          }
          depth--
        }
      }
      print ready, reopen, blocked
    }
  '
}

write_noop_evidence() {
  tmp_evidence="$noop_evidence_file.tmp.$$"
  {
    printf '{\n'
    printf '  "schema_version": "busdk.supervisor.noop_evidence/v1",\n'
    printf '  "status": "noop",\n'
    printf '  "reason": "no_active_or_terminal_tasks",\n'
    printf '  "recorded_at": "%s",\n' "$(json_value "$1")"
    printf '  "snapshot_file": "%s"\n' "$(json_value "$snapshot_file")"
    printf '}\n'
  } >"$tmp_evidence"
  mv "$tmp_evidence" "$noop_evidence_file"

  {
    printf '{"schema_version":"busdk.supervisor.event/v1",'
    printf '"event_type":"supervisor.noop",'
    printf '"recorded_at":"%s",' "$(json_value "$1")"
    printf '"reason":"no_active_or_terminal_tasks",'
    printf '"snapshot_file":"%s"}\n' "$(json_value "$snapshot_file")"
  } >>"$event_file"
}

write_action_plan() {
  action_recorded_at=$1
  action_status=$2
  action_snapshot_file=$3
  action_active_total=$4
  action_terminal_total=$5
  action_review_total=$6
  action_reopen_total=$7
  action_blocked_total=$8
  tmp_action_plan="$action_plan_file.tmp.$$"

  refill_eligible=false
  refill_reason=terminal_triage_required
  if [ "$action_status" = "monitor_failed" ]; then
    refill_reason=monitor_failed
  elif [ "$action_active_total" -gt 0 ]; then
    refill_reason=active_workers_running
  elif [ "$action_terminal_total" -eq 0 ]; then
    refill_eligible=true
    refill_reason=no_active_or_terminal_tasks
  fi

  {
    printf '{\n'
    printf '  "schema_version": "busdk.supervisor.action_plan/v1",\n'
    printf '  "status": "%s",\n' "$(json_value "$action_status")"
    printf '  "recorded_at": "%s",\n' "$(json_value "$action_recorded_at")"
    printf '  "snapshot_file": "%s",\n' "$(json_value "$action_snapshot_file")"
    printf '  "dry_run": true,\n'
    printf '  "execute_actions": false,\n'
    printf '  "terminal_actions": {\n'
    printf '    "review_promoted_commits": {\n'
    printf '      "count": %s,\n' "$action_review_total"
    printf '      "trigger": "terminal closeout has task_complete true",\n'
    printf '      "mechanical_next_step": "verify evidence, then pin accepted promoted commits in the superproject"\n'
    printf '    },\n'
    printf '    "reopen_incomplete_tasks": {\n'
    printf '      "count": %s,\n' "$action_reopen_total"
    printf '      "trigger": "terminal closeout has task_complete false or failed/error status",\n'
    printf '      "mechanical_next_step": "reopen with a precise correction brief through bus dev work or bus dev task"\n'
    printf '    },\n'
    printf '    "record_blockers": {\n'
    printf '      "count": %s,\n' "$action_blocked_total"
    printf '      "trigger": "terminal status is blocked or remaining_blockers is non-empty",\n'
    printf '      "mechanical_next_step": "record the blocker in the owning PLAN or cross-module request before refill"\n'
    printf '    }\n'
    printf '  },\n'
    printf '  "refill_decision": {\n'
    printf '    "eligible": %s,\n' "$refill_eligible"
    printf '    "reason": "%s",\n' "$(json_value "$refill_reason")"
    printf '    "mechanical_next_step": "dispatch the next documented non-overlapping Bus worker task only when eligible and local policy allows it"\n'
    printf '  }\n'
    printf '}\n'
  } >"$tmp_action_plan"
  mv "$tmp_action_plan" "$action_plan_file"
}

classify_policy_cycle() {
  classify_snapshot_file=$1
  classify_exit_code=${2:-0}
  classify_recorded_at=${3:-$(timestamp_utc)}
  tmp_policy="$policy_file.tmp.$$"

  policy_status=ok
  decision=monitor
  no_op_reason=
  safe_work_available=false
  active_total=0
  terminal_total=0
  ready_for_review_total=0
  needs_reopen_total=0
  blocked_total=0

  if [ "$classify_exit_code" -ne 0 ]; then
    policy_status=monitor_failed
    decision=none
  else
    active_array=$(json_array_for_key active "$classify_snapshot_file")
    terminal_array=$(json_array_for_key terminal "$classify_snapshot_file")

    if ! json_array_is_empty "$active_array"; then
      active_total=$(printf '%s' "$active_array" | json_array_object_count)
    fi
    if ! json_array_is_empty "$terminal_array"; then
      terminal_total=$(printf '%s' "$terminal_array" | json_array_object_count)
      set -- $(printf '%s' "$terminal_array" | json_terminal_classification_counts)
      ready_for_review_total=$1
      needs_reopen_total=$2
      blocked_total=$3
    fi

    if [ "$active_total" -eq 0 ] && [ "$terminal_total" -eq 0 ]; then
      decision=noop
      no_op_reason=no_active_or_terminal_tasks
    elif [ "$terminal_total" -gt 0 ]; then
      decision=classify_terminal
      safe_work_available=true
    else
      decision=monitor_active
    fi
  fi

  write_action_plan \
    "$classify_recorded_at" \
    "$policy_status" \
    "$classify_snapshot_file" \
    "$active_total" \
    "$terminal_total" \
    "$ready_for_review_total" \
    "$needs_reopen_total" \
    "$blocked_total"

  {
    printf '{\n'
    printf '  "schema_version": "busdk.supervisor.policy_cycle/v1",\n'
    printf '  "status": "%s",\n' "$(json_value "$policy_status")"
    printf '  "decision": "%s",\n' "$(json_value "$decision")"
    printf '  "safe_work_available": %s,\n' "$safe_work_available"
    if [ -n "$no_op_reason" ]; then
      printf '  "no_op_reason": "%s",\n' "$(json_value "$no_op_reason")"
    fi
    printf '  "recorded_at": "%s",\n' "$(json_value "$classify_recorded_at")"
    printf '  "snapshot_file": "%s",\n' "$(json_value "$classify_snapshot_file")"
    printf '  "action_plan_file": "%s",\n' "$(json_value "$action_plan_file")"
    printf '  "monitor_exit_code": %s,\n' "$classify_exit_code"
    printf '  "active": {"total": %s},\n' "$active_total"
    printf '  "terminal": {\n'
    printf '    "total": %s,\n' "$terminal_total"
    printf '    "ready_for_review": %s,\n' "$ready_for_review_total"
    printf '    "needs_reopen": %s,\n' "$needs_reopen_total"
    printf '    "blocked": %s\n' "$blocked_total"
    printf '  }\n'
    printf '}\n'
  } >"$tmp_policy"
  mv "$tmp_policy" "$policy_file"

  if [ "$decision" = "noop" ]; then
    write_noop_evidence "$classify_recorded_at"
  fi
}

run_once() {
  mkdir -p "$state_dir"
  started_at=$(timestamp_utc)
  started_epoch=$(date +%s)
  tmp_snapshot="$snapshot_file.tmp.$$"
  tmp_stderr="$stderr_file.tmp.$$"
  tmp_status="$status_file.tmp.$$"
  tmp_epoch="$epoch_file.tmp.$$"

  set +e
  bus dev work monitor --format json --quiet-after "$quiet_after" --stale-after "$stale_after" >"$tmp_snapshot" 2>"$tmp_stderr"
  exit_code=$?
  set -e
  status=ok
  if [ "$exit_code" -ne 0 ]; then
    status=failed
  fi

  finished_at=$(timestamp_utc)
  mv "$tmp_snapshot" "$snapshot_file"
  mv "$tmp_stderr" "$stderr_file"
  printf '%s\n' "$started_epoch" >"$tmp_epoch"
  mv "$tmp_epoch" "$epoch_file"
  classify_policy_cycle "$snapshot_file" "$exit_code" "$finished_at"

  {
    printf '{\n'
    printf '  "schema_version": "busdk.supervisor.heartbeat/v1",\n'
    printf '  "status": "%s",\n' "$status"
    printf '  "exit_code": %s,\n' "$exit_code"
    printf '  "started_at": "%s",\n' "$(json_value "$started_at")"
    printf '  "finished_at": "%s",\n' "$(json_value "$finished_at")"
    printf '  "monitor_command": "bus dev work monitor --format json --quiet-after %s --stale-after %s",\n' "$(json_value "$quiet_after")" "$(json_value "$stale_after")"
    printf '  "policy_file": "%s",\n' "$(json_value "$policy_file")"
    printf '  "action_plan_file": "%s",\n' "$(json_value "$action_plan_file")"
    printf '  "snapshot_file": "%s",\n' "$(json_value "$snapshot_file")"
    printf '  "stderr_file": "%s"\n' "$(json_value "$stderr_file")"
    printf '}\n'
  } >"$tmp_status"
  mv "$tmp_status" "$status_file"

  if [ "$exit_code" -ne 0 ]; then
    return "$exit_code"
  fi
}

run_loop() {
  while :; do
    if run_once; then
      rc=0
    else
      rc=$?
    fi
    if truthy "$once"; then
      return "$rc"
    fi
    sleep "$interval_seconds"
  done
}

check_status() {
  if [ ! -f "$status_file" ]; then
    printf 'supervisor heartbeat status missing: %s\n' "$status_file" >&2
    return 1
  fi
  if ! grep -q '"status": "ok"' "$status_file"; then
    printf 'supervisor heartbeat is not ok: %s\n' "$status_file" >&2
    return 1
  fi
  if [ ! -f "$epoch_file" ]; then
    printf 'supervisor heartbeat epoch missing: %s\n' "$epoch_file" >&2
    return 1
  fi
  if [ ! -f "$policy_file" ]; then
    printf 'supervisor policy cycle missing: %s\n' "$policy_file" >&2
    return 1
  fi
  if [ ! -f "$action_plan_file" ]; then
    printf 'supervisor action plan missing: %s\n' "$action_plan_file" >&2
    return 1
  fi
  last_epoch=$(cat "$epoch_file")
  case "$last_epoch" in
    ''|*[!0-9]*)
      printf 'supervisor heartbeat epoch is invalid: %s\n' "$last_epoch" >&2
      return 1
      ;;
  esac
  now_epoch=$(date +%s)
  age=$((now_epoch - last_epoch))
  if [ "$age" -lt 0 ] || [ "$age" -gt "$max_age_seconds" ]; then
    printf 'supervisor heartbeat is stale: age=%s max=%s\n' "$age" "$max_age_seconds" >&2
    return 1
  fi
  printf 'supervisor heartbeat OK: age=%ss status=%s\n' "$age" "$status_file"
}

mode=${1:-run}
case "$mode" in
  run) run_loop ;;
  check) check_status ;;
  classify)
    if [ $# -lt 2 ]; then
      usage
      exit 2
    fi
    mkdir -p "$state_dir"
    classify_policy_cycle "$2" "${3:-0}"
    ;;
  -h|--help|help) usage; exit 0 ;;
  *) usage; exit 2 ;;
esac
