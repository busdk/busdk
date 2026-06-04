#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

(
  cd "$ROOT_DIR/bus-services"
  go run ./cmd/bus-services profile bus/api/local \
    --profile-dir "$ROOT_DIR/profiles" \
    --format json
) >"$TMP_DIR/local-profile.json"

(
  cd "$ROOT_DIR/bus-services"
  go run ./cmd/bus-services profile bus/api/workers \
    --profile-dir "$ROOT_DIR/profiles" \
    --format json
) >"$TMP_DIR/workers-profile.json"

python3 - "$TMP_DIR/local-profile.json" "$TMP_DIR/workers-profile.json" <<'PY'
import json
import sys

local_path, workers_path = sys.argv[1:]

def assert_profile(path, expected_envs):
    profile = json.load(open(path, encoding="utf-8"))
    params = {item["name"]: item for item in profile.get("parameters", [])}
    token_param = params.get("token_file")
    if not token_param:
        raise SystemExit(f"{profile.get('id')} missing token_file parameter")
    if token_param.get("default") != "{env:BUS_SERVICES_BUS_DIR}/tokens/local-events.jwt":
        raise SystemExit(f"{profile.get('id')} token_file default = {token_param.get('default')!r}")
    env = {item["name"]: item for item in profile.get("runtime", {}).get("env", [])}
    for name in expected_envs:
        item = env.get(name)
        if not item:
            raise SystemExit(f"{profile.get('id')} missing {name}")
        if item.get("default") != "{param:token_file}":
            raise SystemExit(f"{profile.get('id')} {name} default = {item.get('default')!r}")
    if "BUS_API_TOKEN" not in env:
        raise SystemExit(f"{profile.get('id')} missing BUS_API_TOKEN fallback env")

assert_profile(local_path, ("BUS_TASK_EVENTS_TOKEN_FILE", "BUS_WORKERS_EVENTS_TOKEN_FILE", "BUS_EVENTS_TOKEN_FILE"))
assert_profile(workers_path, ("BUS_WORKERS_EVENTS_TOKEN_FILE", "BUS_EVENTS_TOKEN_FILE"))
PY
