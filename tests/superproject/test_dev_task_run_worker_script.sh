#!/usr/bin/env bash
set -euo pipefail
[[ "${BUS_E2E_VERBOSE:-0}" = "1" ]] && set -x

root_dir="$(cd "$(dirname "$0")/../.." && pwd)"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

mkdir -p "$tmp_dir/bin"
printf 'services: {}\n' >"$tmp_dir/compose.yaml"

cat >"$tmp_dir/bin/docker" <<'SH'
#!/usr/bin/env sh
set -eu
printf '%s\n' "$*" >>"$DOCKER_STUB_LOG"
case "$*" in
  "ps --format {{.Names}}"*) exit 0 ;;
  "compose -f compose.yaml --profile dev-task ps bus-events"*) exit 0 ;;
  "compose -f compose.yaml --profile dev-task build bus-integration-dev-task"*) exit 0 ;;
  "compose -f compose.yaml --profile dev-task run "* ) exit 0 ;;
  * )
    printf 'unexpected docker invocation: %s\n' "$*" >&2
    exit 1
    ;;
esac
SH
chmod +x "$tmp_dir/bin/docker"

(
  cd "$tmp_dir"
  env -u BUS_DEV_TASK_ONCE \
    -u BUS_DEV_TASK_TIMEOUT \
    -u BUS_DEV_TASK_COMMIT \
    -u BUS_DEV_TASK_COMMIT_MESSAGE \
    -u BUS_DEV_TASK_CODEX_SANDBOX \
    PATH="$tmp_dir/bin:$PATH" DOCKER_STUB_LOG="$tmp_dir/docker.log" \
    "$root_dir/scripts/dev-task-run-worker.sh" busdk-test-worker bus-data >/dev/null
)

run_line="$(grep 'compose -f compose.yaml --profile dev-task run ' "$tmp_dir/docker.log")"
grep -q 'compose -f compose.yaml --profile dev-task build bus-integration-dev-task' "$tmp_dir/docker.log"
case "$run_line" in
  *" run --rm --no-deps -d "* ) ;;
  * )
    printf 'FAIL dev-task run worker script: docker run was not disposable: %s\n' "$run_line" >&2
    exit 1
    ;;
esac
case "$run_line" in
  *"-e BUS_DEV_TASK_ONCE=true"* ) ;;
  * )
    printf 'FAIL dev-task run worker script: BUS_DEV_TASK_ONCE default missing: %s\n' "$run_line" >&2
    exit 1
    ;;
esac
grep -q 'BUS_DEV_TASK_COMMIT_MESSAGE=task: {summary}' "$tmp_dir/docker.log"
grep -q 'Task: {text}' "$tmp_dir/docker.log"
grep -q 'Verification: See task closeout evidence and supervisor review before promotion.' "$tmp_dir/docker.log"
if grep -q 'BUS_DEV_TASK_COMMIT_MESSAGE=chore: dev task {work_ref}' "$tmp_dir/docker.log"; then
  printf 'FAIL dev-task run worker script: default commit message is ref-only\n' >&2
  exit 1
fi

printf 'dev-task run worker script OK\n'
