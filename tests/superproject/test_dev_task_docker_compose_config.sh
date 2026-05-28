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

env -u BUS_LOCAL_GO_IMAGE -u BUS_LOCAL_GO_VERSION \
  docker compose -f compose.yaml --profile dev-task config >"$tmp_dir/compose.config"
env -u BUS_LOCAL_GO_IMAGE -u BUS_LOCAL_GO_VERSION \
  docker compose -f compose.yaml config >"$tmp_dir/local-ai-platform.compose.config"

if grep -Fq 'golang:1.24' compose.yaml; then
  printf 'unexpected stale golang:1.24 default in root compose files\n' >&2
  exit 1
fi
grep -Fq 'image: golang:1.26.3' "$tmp_dir/compose.config"
grep -Fq 'GO_VERSION: 1.26.3' "$tmp_dir/compose.config"
grep -Fq 'CODEX_VERSION: 0.134.0' "$tmp_dir/compose.config"
grep -Fq 'CODEX_NPM_VERSION: ""' "$tmp_dir/compose.config"
grep -Fq 'CODEX_LINUX_AMD64_SHA256: e54b983c3ab5ca992da8edde83bb29a545761a72c4fa39f18a165d9e792e1c71' "$tmp_dir/compose.config"
grep -Fq 'CODEX_LINUX_ARM64_SHA256: 8e066f998111eb8b44250ac11df004daa07fadf276c5942a7183cb8e421091a3' "$tmp_dir/compose.config"
grep -Fq 'image: golang:1.26.3' "$tmp_dir/local-ai-platform.compose.config"
grep -Fq 'GO_VERSION: 1.26.3' "$tmp_dir/local-ai-platform.compose.config"
grep -Fq 'CODEX_VERSION: 0.134.0' "$tmp_dir/local-ai-platform.compose.config"
grep -Fq 'CODEX_NPM_VERSION: ""' "$tmp_dir/local-ai-platform.compose.config"
grep -Fq 'CODEX_LINUX_AMD64_SHA256: e54b983c3ab5ca992da8edde83bb29a545761a72c4fa39f18a165d9e792e1c71' "$tmp_dir/local-ai-platform.compose.config"
grep -Fq 'CODEX_LINUX_ARM64_SHA256: 8e066f998111eb8b44250ac11df004daa07fadf276c5942a7183cb8e421091a3' "$tmp_dir/local-ai-platform.compose.config"

for service in codex-image bus-integration-task bus-dev-supervisor testing-agent; do
  grep -q "^[[:space:]]*$service:" "$tmp_dir/compose.config"
done

awk '
  /^  codex-image:/ { in_codex = 1; in_worker = 0; in_supervisor = 0 }
  /^  bus-integration-task:/ { in_codex = 0; in_worker = 1; in_supervisor = 0 }
  /^  bus-dev-supervisor:/ { in_codex = 0; in_worker = 0; in_supervisor = 1 }
  /^  [A-Za-z0-9_-]+:/ && $1 != "codex-image:" && $1 != "bus-integration-task:" && $1 != "bus-dev-supervisor:" { in_codex = 0; in_worker = 0; in_supervisor = 0 }
  in_codex && /pull_policy:[[:space:]]+build/ { codex_pull = 1 }
  in_codex && /context: .*deploy\/local-ai-platform\/codex/ { codex_build = 1 }
  in_worker && /pull_policy:[[:space:]]+build/ { worker_pull = 1 }
  in_worker && /context: .*deploy\/local-ai-platform\/codex/ { worker_build = 1 }
  in_worker && /busdk-refresh-tools\.sh --refresh-only/ { worker_refresh = 1 }
  in_supervisor && /dev-task-supervisor-heartbeat\.sh run/ { supervisor_run = 1 }
  in_supervisor && /dev-task-supervisor-heartbeat\.sh check/ { supervisor_check = 1 }
  in_supervisor && /BUS_DEV_SUPERVISOR_INTERVAL_SECONDS/ { supervisor_interval = 1 }
  in_supervisor && /BUS_DEV_SUPERVISOR_STALE_AFTER/ { supervisor_stale = 1 }
  END {
    if (!codex_pull || !codex_build || !worker_pull || !worker_build || !worker_refresh ||
        !supervisor_run || !supervisor_check || !supervisor_interval || !supervisor_stale) exit 1
  }
' "$tmp_dir/compose.config"

grep -q 'scripts/busdk-refresh-tools.sh' deploy/local-ai-platform/codex/Dockerfile
grep -Fq 'ARG CODEX_VERSION=0.134.0' deploy/local-ai-platform/codex/Dockerfile
grep -Fq 'ARG CODEX_LINUX_AMD64_SHA256=e54b983c3ab5ca992da8edde83bb29a545761a72c4fa39f18a165d9e792e1c71' deploy/local-ai-platform/codex/Dockerfile
grep -Fq 'ARG CODEX_LINUX_ARM64_SHA256=8e066f998111eb8b44250ac11df004daa07fadf276c5942a7183cb8e421091a3' deploy/local-ai-platform/codex/Dockerfile
grep -Fq 'codex-${codex_arch}-unknown-linux-musl.tar.gz' deploy/local-ai-platform/codex/Dockerfile
grep -Fq 'ARG GOPLS_VERSION=v0.20.0' deploy/local-ai-platform/codex/Dockerfile
grep -Fq 'go install "golang.org/x/tools/gopls@${GOPLS_VERSION}"' deploy/local-ai-platform/codex/Dockerfile
grep -Fq 'gopls mcp -instructions' deploy/local-ai-platform/codex/Dockerfile
grep -Fq 'ARG DELVE_VERSION=v1.25.2' deploy/local-ai-platform/codex/Dockerfile
grep -Fq 'go install "github.com/go-delve/delve/cmd/dlv@${DELVE_VERSION}"' deploy/local-ai-platform/codex/Dockerfile
grep -Fq 'dlv dap --help' deploy/local-ai-platform/codex/Dockerfile
grep -Fq 'BUS_DEV_TASK_GO_DEBUGGER: ${BUS_DEV_TASK_GO_DEBUGGER:-auto}' compose.yaml
grep -Fq 'BUS_DEV_TASK_GO_DEBUGGER_COMMAND: ${BUS_DEV_TASK_GO_DEBUGGER_COMMAND:-dlv}' compose.yaml
grep -Fq -- '--go-debugger "$${BUS_DEV_TASK_GO_DEBUGGER}"' compose.yaml
grep -Fq -- '--go-debugger-command "$${BUS_DEV_TASK_GO_DEBUGGER_COMMAND}"' compose.yaml
grep -Fq 'if [ -z "$${BUS_API_TOKEN:-}" ]; then' compose.yaml
grep -Fq 'export BUS_NOTES_API_TOKEN="$${BUS_NOTES_API_TOKEN:-$${BUS_API_TOKEN}}"' compose.yaml
if grep -Eq 'dlv[[:space:]]+dap[[:space:]].*(--listen|--accept-multiclient|--client-addr)|attach_policy[[:space:]]*=[[:space:]]*host|--go-debugger-attach' compose.yaml; then
  printf 'unexpected default debugger server or host-attach wiring in compose.yaml\n' >&2
  exit 1
fi
grep -q 'scripts/dev-task-supervisor-heartbeat.sh check' compose.yaml
grep -q 'pull_policy: build' compose.yaml
grep -q 'build: \*codex-image-build' compose.yaml

printf 'dev-task Docker compose config OK\n'
