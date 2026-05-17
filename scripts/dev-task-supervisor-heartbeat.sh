#!/bin/sh
set -eu

usage() {
  printf 'usage: %s [run|check]\n' "$0" >&2
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
snapshot_file=${BUS_DEV_SUPERVISOR_SNAPSHOT_FILE:-$state_dir/work-monitor.json}
stderr_file=${BUS_DEV_SUPERVISOR_STDERR_FILE:-$state_dir/work-monitor.stderr}
epoch_file=${BUS_DEV_SUPERVISOR_EPOCH_FILE:-$state_dir/heartbeat.epoch}
interval_seconds=${BUS_DEV_SUPERVISOR_INTERVAL_SECONDS:-300}
max_age_seconds=${BUS_DEV_SUPERVISOR_MAX_AGE_SECONDS:-900}
quiet_after=${BUS_DEV_SUPERVISOR_QUIET_AFTER:-15m}
stale_after=${BUS_DEV_SUPERVISOR_STALE_AFTER:-1h}
once=${BUS_DEV_SUPERVISOR_ONCE:-false}

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

  {
    printf '{\n'
    printf '  "schema_version": "busdk.supervisor.heartbeat/v1",\n'
    printf '  "status": "%s",\n' "$status"
    printf '  "exit_code": %s,\n' "$exit_code"
    printf '  "started_at": "%s",\n' "$(json_value "$started_at")"
    printf '  "finished_at": "%s",\n' "$(json_value "$finished_at")"
    printf '  "monitor_command": "bus dev work monitor --format json --quiet-after %s --stale-after %s",\n' "$(json_value "$quiet_after")" "$(json_value "$stale_after")"
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
  -h|--help|help) usage; exit 0 ;;
  *) usage; exit 2 ;;
esac
