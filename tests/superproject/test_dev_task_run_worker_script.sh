#!/usr/bin/env bash
set -euo pipefail
[[ "${BUS_E2E_VERBOSE:-0}" = "1" ]] && set -x

root_dir="$(cd "$(dirname "$0")/../.." && pwd)"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

mkdir -p "$tmp_dir/bin"
printf 'services: {}\n' >"$tmp_dir/compose.dev-task-docker.yaml"

cat >"$tmp_dir/bin/docker" <<'SH'
#!/usr/bin/env sh
set -eu
printf '%s\n' "$*" >>"$DOCKER_STUB_LOG"
case "$*" in
  "ps --format {{.Names}}"*) exit 0 ;;
  "compose -f compose.dev-task-docker.yaml ps bus-events"*) exit 0 ;;
  "compose -f compose.dev-task-docker.yaml run "* ) exit 0 ;;
  * )
    printf 'unexpected docker invocation: %s\n' "$*" >&2
    exit 1
    ;;
esac
SH
chmod +x "$tmp_dir/bin/docker"

(
  cd "$tmp_dir"
  PATH="$tmp_dir/bin:$PATH" DOCKER_STUB_LOG="$tmp_dir/docker.log" \
    "$root_dir/scripts/dev-task-run-worker.sh" busdk-test-worker bus-data >/dev/null
)

run_line="$(grep 'compose -f compose.dev-task-docker.yaml run ' "$tmp_dir/docker.log")"
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

printf 'dev-task run worker script OK\n'
