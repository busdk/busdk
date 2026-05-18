#!/bin/sh
set -eu

usage() {
  printf 'usage: %s [run|check|inspect|plan-execute|classify SNAPSHOT_FILE [EXIT_CODE]]\n' "$0" >&2
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
action_queue_file=${BUS_DEV_SUPERVISOR_ACTION_QUEUE_FILE:-$state_dir/action-queue.json}
executor_plan_file=${BUS_DEV_SUPERVISOR_EXECUTOR_PLAN_FILE:-$state_dir/executor-plan.json}
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

json_first_scalar_for_key() {
  awk -v key="$1" '
    BEGIN { target = "\"" key "\""; found = 0; in_string = 0; escape = 0; after_colon = 0; value = "" }
    { text = text $0 "\n" }
    END {
      for (i = 1; i <= length(text); i++) {
        c = substr(text, i, 1)
        if (!found && substr(text, i, length(target)) == target) {
          found = 1
          i += length(target) - 1
          continue
        }
        if (!found) {
          continue
        }
        if (!after_colon) {
          if (c == ":") {
            after_colon = 1
          }
          continue
        }
        if (value == "" && c ~ /[[:space:]]/) {
          continue
        }
        if (value == "" && c == "\"") {
          in_string = 1
          continue
        }
        if (in_string) {
          if (escape) {
            value = value c
            escape = 0
          } else if (c == "\\") {
            escape = 1
          } else if (c == "\"") {
            print value
            exit
          } else {
            value = value c
          }
        } else if (c == "," || c == "}" || c == "]" || c ~ /[[:space:]]/) {
          if (value != "") {
            print value
            exit
          }
        } else {
          value = value c
        }
      }
      if (value != "") {
        print value
      }
    }
  ' "$2"
}

json_object_scalar_for_key() {
  awk -v object_key="$1" -v field_key="$2" '
    function scalar_field(object_text, key,    target, pos, rest, i, c, value, escape, in_string) {
      target = "\"" key "\""
      pos = index(object_text, target)
      if (pos == 0) {
        return ""
      }
      rest = substr(object_text, pos + length(target))
      pos = index(rest, ":")
      if (pos == 0) {
        return ""
      }
      rest = substr(rest, pos + 1)
      sub(/^[[:space:]]*/, "", rest)
      value = ""
      if (substr(rest, 1, 1) == "\"") {
        rest = substr(rest, 2)
        escape = 0
        for (i = 1; i <= length(rest); i++) {
          c = substr(rest, i, 1)
          if (escape) {
            value = value c
            escape = 0
          } else if (c == "\\") {
            escape = 1
          } else if (c == "\"") {
            return value
          } else {
            value = value c
          }
        }
        return value
      }
      for (i = 1; i <= length(rest); i++) {
        c = substr(rest, i, 1)
        if (c == "," || c == "}" || c == "]" || c ~ /[[:space:]]/) {
          return value
        }
        value = value c
      }
      return value
    }
    BEGIN { target = "\"" object_key "\""; found = 0; depth = 0; in_string = 0; escape = 0; object_text = "" }
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
          if (c == "{") {
            depth = 1
            object_text = c
          }
          continue
        }
        if (depth > 0) {
          object_text = object_text c
          if (escape) {
            escape = 0
          } else if (c == "\\") {
            escape = 1
          } else if (c == "\"") {
            in_string = !in_string
          } else if (!in_string && c == "{") {
            depth++
          } else if (!in_string && c == "}") {
            depth--
            if (depth == 0) {
              print scalar_field(object_text, field_key)
              exit
            }
          }
        }
      }
    }
  ' "$3"
}

plan_open_count() {
  if [ ! -f "$1" ]; then
    printf '0\n'
    return
  fi
  awk '/^[[:space:]]*- \[ \]/ { count++ } END { print count + 0 }' "$1"
}

module_plan_summary() {
  find bus bus-* -maxdepth 1 -type f -name PLAN.md 2>/dev/null | sort | awk '
    BEGIN { files = 0; open = 0 }
    {
      files++
      while ((getline line < $0) > 0) {
        if (line ~ /^[[:space:]]*- \[ \]/) {
          open++
        }
      }
      close($0)
    }
    END { printf "%s %s\n", files, open }
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

write_action_queue() {
  action_queue_recorded_at=$1
  action_queue_snapshot_file=$2
  action_queue_status=$3
  action_queue_terminal_array=$4
  tmp_action_queue="$action_queue_file.tmp.$$"

  printf '%s' "$action_queue_terminal_array" | awk \
    -v recorded_at="$action_queue_recorded_at" \
    -v snapshot_file="$action_queue_snapshot_file" \
    -v status="$action_queue_status" '
    function escape_json(value,    i, c, out) {
      out = ""
      for (i = 1; i <= length(value); i++) {
        c = substr(value, i, 1)
        if (c == "\\") {
          out = out "\\\\"
        } else if (c == "\"") {
          out = out "\\\""
        } else {
          out = out c
        }
      }
      return out
    }
    function string_field(object_text, key,    target, pos, rest, i, c, value, escape) {
      target = "\"" key "\""
      pos = index(object_text, target)
      if (pos == 0) {
        return ""
      }
      rest = substr(object_text, pos + length(target))
      pos = index(rest, ":")
      if (pos == 0) {
        return ""
      }
      rest = substr(rest, pos + 1)
      sub(/^[[:space:]]*/, "", rest)
      if (substr(rest, 1, 1) != "\"") {
        return ""
      }
      rest = substr(rest, 2)
      value = ""
      escape = 0
      for (i = 1; i <= length(rest); i++) {
        c = substr(rest, i, 1)
        if (escape) {
          value = value c
          escape = 0
        } else if (c == "\\") {
          escape = 1
        } else if (c == "\"") {
          return value
        } else {
          value = value c
        }
      }
      return value
    }
    function action_for_terminal(object_text,    work_ref, recipient, route, reason, next_step, requires_approval, blocked, complete, incomplete) {
      work_ref = string_field(object_text, "work_ref")
      recipient = string_field(object_text, "recipient")
      blocked = object_text ~ /"status"[[:space:]]*:[[:space:]]*"blocked"/ ||
        object_text ~ /"remaining_blockers"[[:space:]]*:[[:space:]]*\[[[:space:]]*[{"]/
      complete = object_text ~ /"task_complete"[[:space:]]*:[[:space:]]*true/
      incomplete = object_text ~ /"task_complete"[[:space:]]*:[[:space:]]*false/ ||
        object_text ~ /"status"[[:space:]]*:[[:space:]]*"(failed|error)"/

      if (blocked) {
        route = "record_blocker"
        reason = "terminal closeout is blocked or has remaining blockers"
        next_step = "record the blocker in the owning PLAN or cross-module request before refill"
        requires_approval = "false"
      } else if (complete) {
        route = "review_pin_candidate"
        reason = "terminal closeout has task_complete true"
        next_step = "verify evidence, then pin accepted promoted commits in the superproject"
        requires_approval = "true"
      } else if (incomplete) {
        route = "reopen_candidate"
        reason = "terminal closeout is incomplete or failed"
        next_step = "reopen with a precise correction brief through bus dev work or bus dev task"
        requires_approval = "false"
      } else {
        route = "inspect_terminal"
        reason = "terminal closeout needs manual classification"
        next_step = "inspect monitor evidence before choosing review, reopen, blocker, or refill"
        requires_approval = "true"
      }

      if (action_count > 0) {
        printf ",\n"
      }
      printf "    {\n"
      printf "      \"work_ref\": \"%s\",\n", escape_json(work_ref)
      if (recipient != "") {
        printf "      \"recipient\": \"%s\",\n", escape_json(recipient)
      }
      printf "      \"route\": \"%s\",\n", route
      printf "      \"reason\": \"%s\",\n", reason
      printf "      \"requires_operator_approval\": %s,\n", requires_approval
      printf "      \"execute_action\": false,\n"
      printf "      \"mechanical_next_step\": \"%s\"\n", next_step
      printf "    }"
      action_count++
    }
    BEGIN {
      depth = 0
      in_string = 0
      escape = 0
      object_text = ""
      action_count = 0
      printf "{\n"
      printf "  \"schema_version\": \"busdk.supervisor.action_queue/v1\",\n"
      printf "  \"status\": \"%s\",\n", escape_json(status)
      printf "  \"recorded_at\": \"%s\",\n", escape_json(recorded_at)
      printf "  \"snapshot_file\": \"%s\",\n", escape_json(snapshot_file)
      printf "  \"execute_actions\": false,\n"
      printf "  \"actions\": [\n"
    }
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
        }

        if (!in_string && c == "{") {
          depth++
        }
        if (depth > 0) {
          object_text = object_text c
        }
        if (!in_string && c == "}") {
          if (depth == 1) {
            action_for_terminal(object_text)
            object_text = ""
          }
          depth--
        }
      }
      printf "\n"
      printf "  ],\n"
      printf "  \"action_count\": %s\n", action_count
      printf "}\n"
    }
  ' >"$tmp_action_queue"
  mv "$tmp_action_queue" "$action_queue_file"
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
    printf '  "action_queue_file": "%s",\n' "$(json_value "$action_queue_file")"
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

write_executor_plan() {
  executor_recorded_at=${1:-$(timestamp_utc)}
  executor_status=ok
  executor_refill_eligible=false
  executor_refill_reason=unknown

  if [ ! -f "$action_queue_file" ]; then
    executor_status=missing_action_queue
  fi
  if [ ! -f "$action_plan_file" ]; then
    if [ "$executor_status" = "ok" ]; then
      executor_status=missing_action_plan
    else
      executor_status=missing_evidence
    fi
  fi
  if [ "$executor_status" = "ok" ]; then
    executor_status=$(json_first_scalar_for_key status "$action_queue_file")
    executor_refill_eligible=$(json_object_scalar_for_key refill_decision eligible "$action_plan_file")
    executor_refill_reason=$(json_object_scalar_for_key refill_decision reason "$action_plan_file")
  fi
  case "$executor_refill_eligible" in
    true|false) ;;
    *) executor_refill_eligible=false ;;
  esac
  if [ -z "$executor_refill_reason" ]; then
    executor_refill_reason=unknown
  fi

  tmp_executor_plan="$executor_plan_file.tmp.$$"
  tmp_executor_queue=
  if [ -f "$action_queue_file" ]; then
    tmp_executor_queue="$executor_plan_file.actions.$$"
    json_array_for_key actions "$action_queue_file" >"$tmp_executor_queue"
    executor_queue_input=$tmp_executor_queue
  else
    executor_queue_input=/dev/null
  fi

  awk \
    -v recorded_at="$executor_recorded_at" \
    -v status="$executor_status" \
    -v action_queue_file="$action_queue_file" \
    -v action_plan_file="$action_plan_file" \
    -v refill_eligible="$executor_refill_eligible" \
    -v refill_reason="$executor_refill_reason" '
    function escape_json(value,    i, c, out) {
      out = ""
      for (i = 1; i <= length(value); i++) {
        c = substr(value, i, 1)
        if (c == "\\") {
          out = out "\\\\"
        } else if (c == "\"") {
          out = out "\\\""
        } else {
          out = out c
        }
      }
      return out
    }
    function string_field(object_text, key,    target, pos, rest, i, c, value, escape) {
      target = "\"" key "\""
      pos = index(object_text, target)
      if (pos == 0) {
        return ""
      }
      rest = substr(object_text, pos + length(target))
      pos = index(rest, ":")
      if (pos == 0) {
        return ""
      }
      rest = substr(rest, pos + 1)
      sub(/^[[:space:]]*/, "", rest)
      if (substr(rest, 1, 1) != "\"") {
        return ""
      }
      rest = substr(rest, 2)
      value = ""
      escape = 0
      for (i = 1; i <= length(rest); i++) {
        c = substr(rest, i, 1)
        if (escape) {
          value = value c
          escape = 0
        } else if (c == "\\") {
          escape = 1
        } else if (c == "\"") {
          return value
        } else {
          value = value c
        }
      }
      return value
    }
    function bool_field(object_text, key,    target, pos, rest) {
      target = "\"" key "\""
      pos = index(object_text, target)
      if (pos == 0) {
        return "false"
      }
      rest = substr(object_text, pos + length(target))
      pos = index(rest, ":")
      if (pos == 0) {
        return "false"
      }
      rest = substr(rest, pos + 1)
      sub(/^[[:space:]]*/, "", rest)
      if (substr(rest, 1, 4) == "true") {
        return "true"
      }
      return "false"
    }
    function emit_action(action, route, work_ref, recipient, reason, approval, gate, command_preview) {
      if (planned_action_count > 0) {
        printf ",\n"
      }
      printf "    {\n"
      printf "      \"action\": \"%s\",\n", escape_json(action)
      if (route != "") {
        printf "      \"source_route\": \"%s\",\n", escape_json(route)
      }
      if (work_ref != "") {
        printf "      \"work_ref\": \"%s\",\n", escape_json(work_ref)
      }
      if (recipient != "") {
        printf "      \"recipient\": \"%s\",\n", escape_json(recipient)
      }
      printf "      \"reason\": \"%s\",\n", escape_json(reason)
      printf "      \"execute_action\": false,\n"
      printf "      \"requires_operator_approval\": %s,\n", approval
      printf "      \"operator_gate\": \"%s\",\n", escape_json(gate)
      printf "      \"command_preview\": \"%s\"\n", escape_json(command_preview)
      printf "    }"
      planned_action_count++
      if (approval == "true") {
        operator_approval_required = "true"
      }
    }
    function plan_for_queue_action(object_text,    route, work_ref, recipient, approval) {
      route = string_field(object_text, "route")
      work_ref = string_field(object_text, "work_ref")
      recipient = string_field(object_text, "recipient")
      approval = bool_field(object_text, "requires_operator_approval")

      if (route == "review_pin_candidate") {
        emit_action("dispatch_review_worker", route, work_ref, "bus-dev", "terminal closeout needs independent review before promotion pin handling", "false", "dry_run_only_task_stream_mutation_disabled", "bus dev task new @bus-dev review-terminal-work:" work_ref)
        emit_action("pin_promoted_commit_after_accepted_review", route, work_ref, recipient, "root submodule pin changes require accepted review evidence before Git mutation", "true", "accepted_review_and_operator_approval_required", "bus dev stage commit accepted-promotion-pin-for:" work_ref)
      } else if (route == "reopen_candidate") {
        emit_action("reopen_incomplete_task", route, work_ref, recipient, "terminal closeout is incomplete or failed and needs a precise correction brief", approval, "dry_run_only_task_stream_mutation_disabled", "bus dev work reopen " work_ref " <precise-correction-brief>")
      } else if (route == "record_blocker") {
        emit_action("record_terminal_blocker", route, work_ref, recipient, "terminal closeout reports a blocker that must be recorded before refill", approval, "dry_run_only_repository_mutation_disabled", "record owning PLAN.md blocker for " work_ref)
      } else if (route == "inspect_terminal") {
        emit_action("inspect_terminal_evidence", route, work_ref, recipient, "terminal closeout could not be mechanically classified", "true", "operator_classification_required", "inspect monitor evidence for " work_ref)
      }
    }
    BEGIN {
      depth = 0
      in_string = 0
      escape = 0
      object_text = ""
      planned_action_count = 0
      operator_approval_required = "false"
      printf "{\n"
      printf "  \"schema_version\": \"busdk.supervisor.executor_plan/v1\",\n"
      printf "  \"status\": \"%s\",\n", escape_json(status)
      printf "  \"recorded_at\": \"%s\",\n", escape_json(recorded_at)
      printf "  \"action_queue_file\": \"%s\",\n", escape_json(action_queue_file)
      printf "  \"action_plan_file\": \"%s\",\n", escape_json(action_plan_file)
      printf "  \"dry_run\": true,\n"
      printf "  \"execute_actions\": false,\n"
      printf "  \"approval_gates\": {\n"
      printf "    \"git_mutation\": \"operator_required\",\n"
      printf "    \"task_stream_mutation\": \"dry_run_only\",\n"
      printf "    \"worker_dispatch\": \"dry_run_only\",\n"
      printf "    \"product_security_cost_destructive_architecture\": \"operator_required\"\n"
      printf "  },\n"
      printf "  \"planned_actions\": [\n"
    }
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
        }

        if (!in_string && c == "{") {
          depth++
        }
        if (depth > 0) {
          object_text = object_text c
        }
        if (!in_string && c == "}") {
          if (depth == 1) {
            plan_for_queue_action(object_text)
            object_text = ""
          }
          depth--
        }
      }
      if (refill_eligible == "true") {
        emit_action("dispatch_refill_worker", "refill_decision", "", "", "no active or terminal tasks remain and refill is mechanically eligible", "false", "dry_run_only_worker_dispatch_disabled", "bus dev task new @<recipient> <next-non-overlapping-PLAN-item-brief>")
      }
      printf "\n"
      printf "  ],\n"
      printf "  \"planned_action_count\": %s,\n", planned_action_count
      printf "  \"operator_approval_required\": %s,\n", operator_approval_required
      printf "  \"refill_decision\": {\n"
      printf "    \"eligible\": %s,\n", refill_eligible
      printf "    \"reason\": \"%s\"\n", escape_json(refill_reason)
      printf "  }\n"
      printf "}\n"
    }
  ' "$executor_queue_input" >"$tmp_executor_plan"
  mv "$tmp_executor_plan" "$executor_plan_file"
  if [ -n "$tmp_executor_queue" ]; then
    rm -f "$tmp_executor_queue"
  fi
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
    terminal_array='[]'
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

  write_action_queue "$classify_recorded_at" "$classify_snapshot_file" "$policy_status" "$terminal_array"

  write_action_plan \
    "$classify_recorded_at" \
    "$policy_status" \
    "$classify_snapshot_file" \
    "$active_total" \
    "$terminal_total" \
    "$ready_for_review_total" \
    "$needs_reopen_total" \
    "$blocked_total"

  write_executor_plan "$classify_recorded_at"

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
    printf '  "action_queue_file": "%s",\n' "$(json_value "$action_queue_file")"
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
    printf '  "action_queue_file": "%s",\n' "$(json_value "$action_queue_file")"
    printf '  "executor_plan_file": "%s",\n' "$(json_value "$executor_plan_file")"
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
  if [ ! -f "$action_queue_file" ]; then
    printf 'supervisor action queue missing: %s\n' "$action_queue_file" >&2
    return 1
  fi
  if [ ! -f "$executor_plan_file" ]; then
    printf 'supervisor executor plan missing: %s\n' "$executor_plan_file" >&2
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

inspect_state() {
  check_status >/dev/null

  status=$(json_first_scalar_for_key status "$status_file")
  decision=$(json_first_scalar_for_key decision "$policy_file")
  active_total=$(json_object_scalar_for_key active total "$policy_file")
  terminal_total=$(json_object_scalar_for_key terminal total "$policy_file")
  ready_for_review=$(json_object_scalar_for_key terminal ready_for_review "$policy_file")
  needs_reopen=$(json_object_scalar_for_key terminal needs_reopen "$policy_file")
  blocked=$(json_object_scalar_for_key terminal blocked "$policy_file")
  action_count=$(json_first_scalar_for_key action_count "$action_queue_file")
  planned_action_count=$(json_first_scalar_for_key planned_action_count "$executor_plan_file")
  operator_approval_required=$(json_first_scalar_for_key operator_approval_required "$executor_plan_file")
  refill_eligible=$(json_object_scalar_for_key refill_decision eligible "$action_plan_file")
  refill_reason=$(json_object_scalar_for_key refill_decision reason "$action_plan_file")
  root_plan_open=$(plan_open_count PLAN.md)
  root_bugs_open=$(plan_open_count BUGS.md)
  set -- $(module_plan_summary)
  module_plan_files=$1
  module_plan_open=$2

  printf 'supervisor heartbeat: status=%s status_file=%s\n' "$status" "$status_file"
  printf 'supervisor policy: decision=%s active=%s terminal=%s review=%s reopen=%s blocked=%s\n' \
    "$decision" "$active_total" "$terminal_total" "$ready_for_review" "$needs_reopen" "$blocked"
  printf 'supervisor actions: queued=%s refill_eligible=%s refill_reason=%s action_queue=%s\n' \
    "$action_count" "$refill_eligible" "$refill_reason" "$action_queue_file"
  printf 'supervisor executor: planned=%s operator_approval_required=%s executor_plan=%s\n' \
    "$planned_action_count" "$operator_approval_required" "$executor_plan_file"
  printf 'supervisor backlog: root_plan_open=%s root_bugs_open=%s module_plan_files=%s module_plan_open=%s\n' \
    "$root_plan_open" "$root_bugs_open" "$module_plan_files" "$module_plan_open"
  printf 'supervisor evidence: snapshot=%s policy=%s action_plan=%s\n' \
    "$snapshot_file" "$policy_file" "$action_plan_file"
}

mode=${1:-run}
case "$mode" in
  run) run_loop ;;
  check) check_status ;;
  inspect) inspect_state ;;
  plan-execute)
    mkdir -p "$state_dir"
    write_executor_plan "$(timestamp_utc)"
    planned_action_count=$(json_first_scalar_for_key planned_action_count "$executor_plan_file")
    operator_approval_required=$(json_first_scalar_for_key operator_approval_required "$executor_plan_file")
    printf 'supervisor executor plan: planned=%s execute_actions=false operator_approval_required=%s executor_plan=%s\n' \
      "$planned_action_count" "$operator_approval_required" "$executor_plan_file"
    ;;
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
