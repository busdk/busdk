#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "$0")/../.." && pwd)"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"; rm -f "$root_dir"/tmp/local-task-host-workers/logs/*-bus-template-test-any.log*' EXIT

cd "$root_dir"

python3 - <<'PY'
import json
from pathlib import Path

catalog = json.loads(Path(".bus/worker/templates.json").read_text())
templates = {template["id"]: template for template in catalog["templates"]}
expected = {
    "codex-56-sol-high": ("codex-56-sol", "gpt-5.6-sol", "high"),
    "codex-56-sol-xhigh": ("codex-56-sol", "gpt-5.6-sol", "xhigh"),
    "codex-56-sol-max": ("codex-56-sol", "gpt-5.6-sol", "max"),
    "codex-56-sol-ultra": ("codex-56-sol", "gpt-5.6-sol", "ultra"),
    "codex-56-terra-medium": ("codex-56-terra", "gpt-5.6-terra", "medium"),
    "codex-56-terra-high": ("codex-56-terra", "gpt-5.6-terra", "high"),
    "codex-56-terra-max": ("codex-56-terra", "gpt-5.6-terra", "max"),
    "codex-56-luna-low": ("codex-56-luna", "gpt-5.6-luna", "low"),
    "codex-56-luna-medium": ("codex-56-luna", "gpt-5.6-luna", "medium"),
    "codex-56-luna-max": ("codex-56-luna", "gpt-5.6-luna", "max"),
}

actual_56 = {template_id for template_id in templates if template_id.startswith("codex-56-")}
if actual_56 != set(expected):
    raise SystemExit(f"GPT-5.6 template set mismatch: got {sorted(actual_56)}, want {sorted(expected)}")

for template_id, (profile, model, effort) in expected.items():
    template = templates[template_id]
    checks = {
        "default_profile": profile,
        "default_model": model,
        "reasoning_effort": effort,
        "reasoning_summary": "auto",
        "model_verbosity": "medium",
        "runner_kind": "appserver",
        "runner_provider": "codex-appserver",
        "sandbox": "workspace-write",
        "worker_home_policy": "managed-repo",
        "identity_repo_ref": f"repos://workers/{template_id}",
        "identity_base_ref": "refs/heads/main",
    }
    for key, want in checks.items():
        got = template.get(key)
        if got != want:
            raise SystemExit(f"{template_id} {key}: got {got!r}, want {want!r}")
    if "local" not in template.get("eligible_environments", []):
        raise SystemExit(f"{template_id} is not eligible for local")

for template in catalog["templates"]:
    if template.get("runner_provider") == "codex-appserver" and not template.get("reasoning_effort"):
        raise SystemExit(f"Codex template lacks explicit reasoning_effort: {template['id']}")
    if template.get("default_model") == "gpt-5.6":
        raise SystemExit(f"generic GPT-5.6 model slug is not allowed: {template['id']}")

if "deep review" not in templates["codex-56-sol-max"]["summary"]:
    raise SystemExit("Sol max must carry the deep-review role")
if "orchestration" not in templates["codex-56-sol-ultra"]["summary"]:
    raise SystemExit("Sol ultra must carry the orchestration role")
PY

public_bin="$tmp_dir/public-bin"
tool_bin="$tmp_dir/tool-bin"
mkdir -p "$public_bin" "$tool_bin" "$tmp_dir/bin"

BUSDK_WORKSPACE_ROOT="$root_dir" \
  BUSDK_TOOL_WRAPPER_DIR="$public_bin" \
  BUSDK_TOOL_BIN_DIR="$tool_bin" \
  "$root_dir/scripts/busdk-refresh-tools.sh" --refresh-only >/dev/null

if ! PATH="$public_bin:$PATH" command -v bus >/dev/null 2>&1; then
  printf 'public bus command unavailable; hydrate the bus submodule before running this test\n' >&2
  exit 2
fi

real_resolver_output=$(
  PATH="$public_bin:$PATH" BUS_HOST=127.0.0.2 \
    bus workers template show codex-56-sol-ultra
)
printf '%s\n' "$real_resolver_output" | awk -F '	' '$1 == "default_model" && $2 == "gpt-5.6-sol" { found = 1 } END { exit found ? 0 : 1 }'
printf '%s\n' "$real_resolver_output" | awk -F '	' '$1 == "reasoning_effort" && $2 == "ultra" { found = 1 } END { exit found ? 0 : 1 }'
printf '%s\n' "$real_resolver_output" | awk -F '	' '$1 == "reasoning_summary" && $2 == "auto" { found = 1 } END { exit found ? 0 : 1 }'
printf '%s\n' "$real_resolver_output" | awk -F '	' '$1 == "model_verbosity" && $2 == "medium" { found = 1 } END { exit found ? 0 : 1 }'

cat >"$tmp_dir/bin/bus" <<'SH'
#!/usr/bin/env sh
set -eu
printf '%s\n' "$*" >>"$PUBLIC_RESOLVER_ARGS_LOG"
if [ "$#" -ne 4 ] || [ "$1" != "workers" ] || [ "$2" != "template" ] || [ "$3" != "show" ]; then
  printf 'unexpected public resolver invocation: %s\n' "$*" >&2
  exit 1
fi
case "$4" in
  codex-56-sol-ultra)
    profile=codex-56-sol
    model=gpt-5.6-sol
    effort=ultra
    summary=auto
    verbosity=medium
    emit_optional=1
    ;;
  codex-56-luna-max)
    profile=codex-56-luna
    model=gpt-5.6-luna
    effort=max
    summary=
    verbosity=
    emit_optional=0
    ;;
  *)
    printf 'unexpected template id: %s\n' "$4" >&2
    exit 1
    ;;
esac
printf 'id\t%s\n' "$4"
printf 'default_profile\t%s\n' "$profile"
printf 'default_model\t%s\n' "$model"
printf 'reasoning_effort\t%s\n' "$effort"
if [ "$emit_optional" -eq 1 ]; then
  printf 'reasoning_summary\t%s\n' "$summary"
  printf 'model_verbosity\t%s\n' "$verbosity"
fi
printf 'runner_kind\tappserver\n'
printf 'runner_provider\tcodex-appserver\n'
printf 'sandbox\tworkspace-write\n'
SH
chmod +x "$tmp_dir/bin/bus"

cat >"$tmp_dir/bin/fail-bus" <<'SH'
#!/usr/bin/env sh
printf 'resolver should have been skipped\n' >&2
exit 88
SH
chmod +x "$tmp_dir/bin/fail-bus"

fake_task_bin="$tmp_dir/bin/bus-integration-task"
cat >"$fake_task_bin" <<'SH'
#!/usr/bin/env sh
set -eu
env | sort | awk '
  /^BUS_TASK_CODEX_/ ||
  /^BUS_EVENTS_API_URL=/ ||
  /^BUS_HOST=/ {
    print
  }
' >"$BUS_HOST_LAUNCH_ENV_LOG"
SH
chmod +x "$fake_task_bin"

launch_host_worker() {
  template=$1
  env_log=$2
  resolver=$3
  shift 3
  bus_host=127.0.0.2
  sentinel_url="http://${bus_host}:1"
  if ! BUS_HOST="$bus_host" \
    BUS_API_TOKEN=redacted-test-token \
    BUS_EVENTS_API_URL="$sentinel_url" \
    BUS_TASK_RECIPIENT=bus-template-test \
    BUS_TASK_AGENT_BACKEND=fake-appserver \
    BUS_TASK_WORKER_TEMPLATE_CLI="$resolver" \
    BUS_TASK_WORKER_TEMPLATE="$template" \
    BUS_TASK_INTEGRATION_TASK_BIN="$fake_task_bin" \
    BUS_HOST_LAUNCH_ENV_LOG="$env_log" \
    "$@" \
    "$root_dir/scripts/local-task-host-worker-launcher.sh" >"$tmp_dir/launcher.out" 2>"$tmp_dir/launcher.err"; then
    cat "$tmp_dir/launcher.err" >&2 || true
    return 1
  fi

  for _ in $(seq 1 50); do
    [ -s "$env_log" ] && return 0
    sleep 0.1
  done
  printf 'host launcher did not write env log\n' >&2
  cat "$tmp_dir/launcher.err" >&2 || true
  return 1
}

PUBLIC_RESOLVER_ARGS_LOG="$tmp_dir/resolver.args"
export PUBLIC_RESOLVER_ARGS_LOG

host_env="$tmp_dir/host.env"
launch_host_worker codex-56-sol-ultra "$host_env" "$tmp_dir/bin/bus" env -u BUS_TASK_CODEX_MODEL -u BUS_TASK_CODEX_SANDBOX -u BUS_TASK_CODEX_REASONING_EFFORT -u BUS_TASK_CODEX_REASONING_SUMMARY -u BUS_TASK_CODEX_MODEL_VERBOSITY
grep -Fxq 'BUS_HOST=127.0.0.2' "$host_env"
grep -Fxq 'BUS_EVENTS_API_URL=http://127.0.0.2:1' "$host_env"
grep -Fxq 'BUS_TASK_CODEX_MODEL=gpt-5.6-sol' "$host_env"
grep -Fxq 'BUS_TASK_CODEX_SANDBOX=workspace-write' "$host_env"
grep -Fxq 'BUS_TASK_CODEX_REASONING_EFFORT=ultra' "$host_env"
grep -Fxq 'BUS_TASK_CODEX_REASONING_SUMMARY=auto' "$host_env"
grep -Fxq 'BUS_TASK_CODEX_MODEL_VERBOSITY=medium' "$host_env"
grep -Fxq 'workers template show codex-56-sol-ultra' "$PUBLIC_RESOLVER_ARGS_LOG"

missing_optional_env="$tmp_dir/missing-optional.env"
launch_host_worker codex-56-luna-max "$missing_optional_env" "$tmp_dir/bin/bus" env -u BUS_TASK_CODEX_MODEL -u BUS_TASK_CODEX_SANDBOX -u BUS_TASK_CODEX_REASONING_EFFORT -u BUS_TASK_CODEX_REASONING_SUMMARY -u BUS_TASK_CODEX_MODEL_VERBOSITY
grep -Fxq 'BUS_TASK_CODEX_MODEL=gpt-5.6-luna' "$missing_optional_env"
grep -Fxq 'BUS_TASK_CODEX_REASONING_EFFORT=max' "$missing_optional_env"
grep -Fxq 'BUS_TASK_CODEX_REASONING_SUMMARY=' "$missing_optional_env"
grep -Fxq 'BUS_TASK_CODEX_MODEL_VERBOSITY=' "$missing_optional_env"

skip_env="$tmp_dir/skip.env"
launch_host_worker codex-56-sol-ultra "$skip_env" "$tmp_dir/bin/fail-bus" env \
  BUS_TASK_CODEX_MODEL=manual-model \
  BUS_TASK_CODEX_SANDBOX=manual-sandbox \
  BUS_TASK_CODEX_REASONING_EFFORT=max \
  BUS_TASK_CODEX_REASONING_SUMMARY= \
  BUS_TASK_CODEX_MODEL_VERBOSITY=
grep -Fxq 'BUS_TASK_CODEX_MODEL=manual-model' "$skip_env"
grep -Fxq 'BUS_TASK_CODEX_SANDBOX=manual-sandbox' "$skip_env"
grep -Fxq 'BUS_TASK_CODEX_REASONING_EFFORT=max' "$skip_env"
grep -Fxq 'BUS_TASK_CODEX_REASONING_SUMMARY=' "$skip_env"
grep -Fxq 'BUS_TASK_CODEX_MODEL_VERBOSITY=' "$skip_env"

printf 'worker template catalog OK\n'
