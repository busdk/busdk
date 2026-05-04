#!/usr/bin/env bash
set -euo pipefail
[[ "${BUS_E2E_VERBOSE:-0}" = "1" ]] && set -x

if ! command -v docker >/dev/null 2>&1; then
  printf 'SKIP dev-task worktree commit smoke: docker not installed\n'
  exit 0
fi

if ! docker compose version >/dev/null 2>&1; then
  printf 'SKIP dev-task worktree commit smoke: docker compose unavailable\n'
  exit 0
fi

root_dir="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$root_dir"

compose_args=(-f compose.dev-task-docker.yaml)
smoke_root="tmp/dev-task-worktree-commit-smoke"
smoke_repo="$smoke_root/smoke-repo"
worker_name="busdk-dev-task-smoke-commit"

cleanup() {
  docker rm -f "$worker_name" >/dev/null 2>&1 || true
  rm -rf "$smoke_root"
}
trap cleanup EXIT

cleanup
mkdir -p "$smoke_repo"
git -C "$smoke_repo" init -q
git -C "$smoke_repo" config user.name "Smoke Test"
git -C "$smoke_repo" config user.email "smoke@example.invalid"
printf 'base\n' >"$smoke_repo/README.md"
git -C "$smoke_repo" add README.md
git -C "$smoke_repo" commit -q -m "base"

docker compose "${compose_args[@]}" up --build -d \
  bus-events \
  bus-api-provider-containers \
  bus-integration-docker \
  bus-integration-containers \
  testing-agent >/dev/null

docker compose "${compose_args[@]}" exec -T testing-agent sh -ec '
  for i in $(seq 1 120); do
    TOKEN=$(cat /root/.config/bus/auth/api-token 2>/dev/null || true)
    if [ -n "$TOKEN" ] &&
       wget -qO- --header="Authorization: Bearer $TOKEN" \
         http://bus-api-provider-containers:8080/api/v1/containers/status >/dev/null 2>&1; then
      exit 0
    fi
    sleep 1
  done
  exit 1
'

task_ref="$(
  docker compose "${compose_args[@]}" exec -T testing-agent sh -ec '
    cd /workspace/bus-dev
    go run ./cmd/bus-dev task --api-url http://bus-events:8081 new --new-branch smoke-task @smoke-repo "Write a deterministic smoke-test change."
  ' | awk '/ -> / {print $2; exit}'
)"
test -n "$task_ref"

docker compose "${compose_args[@]}" run -d --no-deps --name "$worker_name" \
  -e BUS_DEV_TASK_RECIPIENT=smoke-repo \
  -e BUS_DEV_TASK_WORKSPACE_ROOT=/workspace/tmp/dev-task-worktree-commit-smoke \
  -e BUS_DEV_TASK_WORKSPACE_HOST_ROOT="$root_dir/tmp/dev-task-worktree-commit-smoke" \
  -e BUS_DEV_TASK_WORKSPACE_RECIPIENT=smoke-root \
  -e BUS_DEV_TASK_COMMAND_JSON='["sh","-c","printf \"change\\n\" >> README.md && mkdir -p .git-local/worktrees/smoke && printf \"gitdir: %s/.git-local/worktrees/smoke\\n\" \"$PWD\" > .git"]' \
  -e BUS_DEV_TASK_PRE_COMMAND_JSON='[]' \
  -e BUS_DEV_TASK_POST_COMMAND_JSON='[]' \
  -e BUS_DEV_TASK_COMMIT=true \
  -e BUS_DEV_TASK_COMMIT_MESSAGE='test: smoke {work_ref}' \
  -e BUS_DEV_TASK_ONCE=true \
  -e BUS_DEV_TASK_IDLE_TIMEOUT=2m \
  bus-integration-dev-task >/dev/null

task_output="$(
  docker compose "${compose_args[@]}" exec -T testing-agent sh -ec "
    cd /workspace/bus-dev
    go run ./cmd/bus-dev task --api-url http://bus-events:8081 watch '$task_ref' --timeout 2m
  "
)"
printf '%s\n' "$task_output" | grep -q 'completed'
grep -q '^change$' "$smoke_repo/README.md"
subject="$(git -C "$smoke_repo" log -1 --format=%s)"
case "$subject" in
  "test: smoke "* ) ;;
  * )
    printf 'FAIL dev-task worktree commit smoke: unexpected subject %s\n' "$subject" >&2
    exit 1
    ;;
esac

printf 'dev-task worktree commit smoke OK\n'
