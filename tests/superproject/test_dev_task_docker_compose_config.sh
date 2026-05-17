#!/usr/bin/env bash
set -euo pipefail

root_dir=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

cd "$root_dir"

if ! command -v docker >/dev/null 2>&1; then
  printf 'SKIP dev-task Docker compose config: docker not installed\n'
  exit 0
fi

if ! docker compose version >/dev/null 2>&1; then
  printf 'SKIP dev-task Docker compose config: docker compose unavailable\n'
  exit 0
fi

docker compose -f compose.dev-task-docker.yaml config >"$tmp_dir/compose.config"

for service in codex-image bus-integration-dev-task testing-agent; do
  grep -q "^[[:space:]]*$service:" "$tmp_dir/compose.config"
done

awk '
  /^  codex-image:/ { in_codex = 1; in_worker = 0 }
  /^  bus-integration-dev-task:/ { in_codex = 0; in_worker = 1 }
  /^  [A-Za-z0-9_-]+:/ && $1 != "codex-image:" && $1 != "bus-integration-dev-task:" { in_codex = 0; in_worker = 0 }
  in_codex && /pull_policy:[[:space:]]+build/ { codex_pull = 1 }
  in_codex && /context: .*deploy\/local-ai-platform\/codex/ { codex_build = 1 }
  in_worker && /pull_policy:[[:space:]]+build/ { worker_pull = 1 }
  in_worker && /context: .*deploy\/local-ai-platform\/codex/ { worker_build = 1 }
  in_worker && /busdk-refresh-tools\.sh --refresh-only/ { worker_refresh = 1 }
  END {
    if (!codex_pull || !codex_build || !worker_pull || !worker_build || !worker_refresh) exit 1
  }
' "$tmp_dir/compose.config"

grep -q 'scripts/busdk-refresh-tools.sh' deploy/local-ai-platform/codex/Dockerfile
grep -q 'pull_policy: build' compose.dev-task-docker.yaml
grep -q 'build: \*codex-image-build' compose.dev-task-docker.yaml

printf 'dev-task Docker compose config OK\n'
