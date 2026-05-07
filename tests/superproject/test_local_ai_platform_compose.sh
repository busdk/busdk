#!/usr/bin/env bash
set -eu

root_dir="$(cd "$(dirname "$0")/../.." && pwd)"
tmp_dir="${TMPDIR:-/tmp}/bus-local-ai-platform-test.$$"
mkdir -p "$tmp_dir"
trap 'rm -rf "$tmp_dir"' EXIT

cd "$root_dir"

if ! command -v docker >/dev/null 2>&1; then
    printf 'SKIP local ai platform compose: docker not installed\n'
    exit 0
fi

if ! docker compose version >/dev/null 2>&1; then
    printf 'SKIP local ai platform compose: docker compose unavailable\n'
    exit 0
fi

docker compose --env-file .env.example -f compose.yaml config > "$tmp_dir/compose.config"

for service in postgres mailhog bus-events bus-auth bus-usage-api bus-usage-worker bus-billing-api bus-billing-worker bus-stripe bus-vm bus-containers bus-docker bus-codex bus-llm nginx testing-agent; do
    grep -q "^[[:space:]]*$service:" "$tmp_dir/compose.config"
done

for route in '/v1/' '/api/v1/auth/' '/api/v1/events' '/api/v1/billing/' '/api/internal/usage-events' '/api/v1/vm/' '/api/v1/containers/' '/api/internal/stripe/webhook'; do
    grep -q "$route" deploy/local-ai-platform/nginx.conf
done

grep -q '^BUS_LOCAL_JWT_SECRET=not-a-secret-local-development-hs256-key$' .env.example
grep -q 'codex-chatgpt' deploy/local-ai-platform/model-catalog.json
grep -q 'BUS_LLM_EXECUTION_BACKEND: events' "$tmp_dir/compose.config"
grep -q 'BUS_STRIPE_SECRET_KEY: ""' "$tmp_dir/compose.config"

if grep -R '/Users/' compose.yaml .env.example deploy/local-ai-platform >/dev/null; then
    printf 'developer-machine absolute path leaked into local AI Platform stack\n' >&2
    exit 1
fi

printf 'local ai platform compose OK\n'
