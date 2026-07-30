#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "$0")/../.." && pwd)"
tmp_dir="$(mktemp -d)"
invocation_id=${tmp_dir##*/}
artifact_recipient="bus-template-test-${invocation_id}"
artifact_work_prefix="work-${invocation_id}"
trap 'rm -rf "$tmp_dir"; rm -f "$root_dir"/tmp/local-task-host-workers/logs/*-"$artifact_recipient"-"$artifact_work_prefix"-*.log*' EXIT

cd "$root_dir"

python3 - <<'PY'
import json
import re
from pathlib import Path

catalog = json.loads(Path(".bus/worker/templates.json").read_text())
templates = {template["id"]: template for template in catalog["templates"]}
CODEX_KEYS = (
    "capability_tags",
    "default_model",
    "default_profile",
    "description",
    "eligible_environments",
    "id",
    "identity_base_ref",
    "identity_repo_ref",
    "label",
    "model_verbosity",
    "reasoning_effort",
    "reasoning_summary",
    "runner_kind",
    "runner_provider",
    "sandbox",
    "summary",
    "worker_home_policy",
)
CLAUDE_KEYS = (
    "capability_tags",
    "default_model",
    "default_profile",
    "description",
    "eligible_environments",
    "id",
    "identity_base_ref",
    "identity_repo_ref",
    "label",
    "reasoning_effort",
    "runner_kind",
    "runner_provider",
    "sandbox",
    "summary",
    "worker_home_policy",
)
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
if set(templates) != set(expected).union({
    "codex-53-spark",
    "codex-54-mini",
    "codex-55",
    "codex-55-high",
    "claude-fable-5",
    "claude-opus-4-8",
    "claude-opus-5",
    "claude-sonnet-5",
    "claude-haiku-4-5",
}):
    raise SystemExit("catalog must contain exactly the expected 19 entries")

EXPECTED_SUMMARIES = {
    "codex-53-spark": "Spark: narrowly frozen mechanical work with independent review.",
    "codex-54-mini": "Mini: bounded implementation and support work with compact evidence.",
    "codex-55": "GPT-5.5 medium: evidence-limited bounded implementation lane with independent review.",
    "codex-55-high": "GPT-5.5 High: hard bounded source/rescue candidate with independent review and composed E2E.",
    "codex-56-sol-high": "Sol High: focused repair and bounded diagnostics.",
    "codex-56-sol-xhigh": "Sol XHigh: architecture and root-cause diagnosis before patching.",
    "codex-56-sol-max": "Sol Max: concurrency, replay, process, and exact-contract review.",
    "codex-56-sol-ultra": "Sol Ultra: split work, produce candidates, and compose evidence without self-acceptance.",
    "codex-56-terra-medium": "Terra Medium: evidence-limited bounded follow-through with independent review.",
    "codex-56-terra-high": "Terra High: complex implementation and review-driven integration debugging.",
    "codex-56-terra-max": "Terra Max: lifecycle, security, migration, and regression review.",
    "codex-56-luna-low": "Luna Low: docs, bounded diagnosis, and smoke checks.",
    "codex-56-luna-medium": "Luna Medium: evidence-limited implementation with practical review.",
    "codex-56-luna-max": "Luna Max: convergence and order review before promotion.",
    "claude-fable-5": "Fable: architecture, supply-chain, and exact-byte challenge review.",
    "claude-opus-4-8": "Opus: read-only consultation or tightly bounded external execution with exact stop conditions.",
    "claude-opus-5": "Opus 5: evidence-limited high-effort managed lane pending an audited local record; requires independent review.",
    "claude-sonnet-5": "Sonnet: provider-diverse fallback for balanced coding, planning, and follow-through.",
    "claude-haiku-4-5": "Haiku: evidence-limited experimental trial for low-risk extraction or triage.",
}
if set(templates) != set(EXPECTED_SUMMARIES):
    raise SystemExit(f"Catalog ID set mismatch: got {sorted(templates)}, want {sorted(EXPECTED_SUMMARIES)}")
for template_id, expected_summary in EXPECTED_SUMMARIES.items():
    template = templates[template_id]
    if template["summary"] != expected_summary:
        raise SystemExit(f"{template_id} summary mismatch: got {template['summary']!r}, want {expected_summary!r}")

for template_id, template in templates.items():
    if template["runner_provider"] == "codex-appserver":
        required_keys = CODEX_KEYS
    elif template["runner_provider"] == "claude-appserver":
        required_keys = CLAUDE_KEYS
    else:
        raise SystemExit(f"unknown runner_provider for {template_id}: {template['runner_provider']!r}")
    if tuple(sorted(template.keys())) != required_keys:
        raise SystemExit(f"{template_id} key-set changed: got {tuple(sorted(template.keys()))}, want {required_keys}")
    if "\t" in template["description"] or "\r" in template["description"] or "\n" in template["description"]:
        raise SystemExit(f"{template_id} description contains a forbidden newline/tab/CR")
    if len(template["description"].encode("utf-8")) > 1200:
        raise SystemExit(f"{template_id} description exceeds 1200 UTF-8 bytes")
    if template_id == "codex-56-luna-low":
        if re.findall(r"\$[0-9]+\.[0-9]{2}", template["description"]) != ["$0.20", "$0.02", "$0.25", "$1.20"]:
            raise SystemExit("codex-56-luna-low price list mismatch")
    elif template_id == "codex-56-luna-medium":
        if re.findall(r"\$[0-9]+\.[0-9]{2}", template["description"]) != ["$0.20", "$0.02", "$0.25", "$1.20"]:
            raise SystemExit("codex-56-luna-medium price list mismatch")
    elif template_id == "codex-56-luna-max":
        if re.findall(r"\$[0-9]+\.[0-9]{2}", template["description"]) != ["$0.20", "$0.02", "$0.25", "$1.20"]:
            raise SystemExit("codex-56-luna-max price list mismatch")
    elif template_id == "codex-56-terra-medium":
        if re.findall(r"\$[0-9]+\.[0-9]{2}", template["description"]) != ["$2.00", "$0.20", "$2.50", "$12.00"]:
            raise SystemExit("codex-56-terra-medium price list mismatch")
    elif template_id == "codex-56-terra-high":
        if re.findall(r"\$[0-9]+\.[0-9]{2}", template["description"]) != ["$2.00", "$0.20", "$2.50", "$12.00"]:
            raise SystemExit("codex-56-terra-high price list mismatch")
    elif template_id == "codex-56-terra-max":
        if re.findall(r"\$[0-9]+\.[0-9]{2}", template["description"]) != ["$2.00", "$0.20", "$2.50", "$12.00"]:
            raise SystemExit("codex-56-terra-max price list mismatch")
    elif template_id in {
        "codex-56-sol-high",
        "codex-56-sol-xhigh",
        "codex-56-sol-max",
        "codex-56-sol-ultra",
    }:
        if re.search(r"\$", template["description"]):
            raise SystemExit(f"{template_id} Sol description must not contain dollar values")
        for required in (
            "Sol Standard pricing is unchanged",
            "Sol Fast replaces Priority Processing",
            "2.5 times Standard speed",
            "twice the Standard API price",
            "does not change intelligence",
            "does not select a processing mode",
        ):
            if required not in template["description"]:
                raise SystemExit(f"{template_id} missing Sol required claim: {required!r}")

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

if "exact-contract review" not in templates["codex-56-sol-max"]["summary"]:
    raise SystemExit("Sol max must carry the exact-contract review role")
if "split work" not in templates["codex-56-sol-ultra"]["summary"]:
    raise SystemExit("Sol ultra must carry the split-work orchestration role")
if "without self-acceptance" not in templates["codex-56-sol-ultra"]["summary"]:
    raise SystemExit("Sol ultra summary must forbid self-acceptance")
if "never owns terminal self-acceptance" not in templates["codex-56-sol-ultra"]["description"]:
    raise SystemExit("Sol ultra description must forbid terminal self-acceptance")
if "architecture and root-cause" not in templates["codex-56-sol-xhigh"]["summary"]:
    raise SystemExit("Sol xhigh must carry the architecture/root-cause role")
if "evidence-limited" not in templates["codex-56-terra-medium"]["summary"]:
    raise SystemExit("Terra medium must be evidence-limited")
if "provider-diverse fallback" not in templates["claude-sonnet-5"]["summary"]:
    raise SystemExit("Sonnet must be the provider-diverse fallback")
sonnet_text = " ".join((
    templates["claude-sonnet-5"]["summary"],
    templates["claude-sonnet-5"]["description"],
))
if "after Fable or Opus research" in sonnet_text:
    raise SystemExit("Sonnet must not depend on Fable or Opus research")
for required in ("bounded implementation and follow-through", "medium-depth code review", "practical planning", "provider-diverse fallback"):
    if required not in sonnet_text:
        raise SystemExit(f"Sonnet must retain {required!r} role wording")
if "read-only consultation" not in templates["claude-opus-4-8"]["summary"]:
    raise SystemExit("Opus summary must advertise the read-only consultation limit")

claude_expected = {
    "claude-fable-5": ("claude-fable-5", "high"),
    "claude-opus-4-8": ("claude-opus-4-8", "high"),
    "claude-opus-5": ("claude-opus-5", "high"),
    "claude-sonnet-5": ("claude-sonnet-5", "medium"),
    "claude-haiku-4-5": ("claude-haiku-4-5", "low"),
}
actual_claude = {
    template_id
    for template_id, template in templates.items()
    if template.get("runner_provider") == "claude-appserver"
}
if actual_claude != set(claude_expected):
    raise SystemExit(f"Claude template set mismatch: got {sorted(actual_claude)}, want {sorted(claude_expected)}")
for template_id, (model, effort) in claude_expected.items():
    template = templates[template_id]
    checks = {
        "default_profile": "claude",
        "default_model": model,
        "reasoning_effort": effort,
        "runner_kind": "appserver",
        "runner_provider": "claude-appserver",
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

opus5_text = " ".join((
    templates["claude-opus-5"]["summary"],
    templates["claude-opus-5"]["description"],
))
if templates["claude-opus-5"]["default_model"] != "claude-opus-5":
    raise SystemExit("Opus 5 must keep the exact model id claude-opus-5 with no alias or rewrite")
for required in ("evidence-limited", "independent review", "exact model claude-opus-5", "default high effort"):
    if required not in opus5_text:
        raise SystemExit(f"Opus 5 must retain {required!r} wording")
if "read-only consultation" in opus5_text:
    raise SystemExit("Opus 5 is the first-class managed lane; the read-only consultation limit belongs to claude-opus-4-8 only")
if "cannot be the sole acceptance owner" not in opus5_text:
    raise SystemExit("Opus 5 must not be the sole acceptance owner")
haiku_text = " ".join((
    templates["claude-haiku-4-5"]["summary"],
    templates["claude-haiku-4-5"]["description"],
)).lower()
for required in ("evidence-limited", "experimental", "low-risk", "independent confirmation", "required evidence gate"):
    if required not in haiku_text:
        raise SystemExit(f"Haiku must retain {required!r} constraint wording")
if "never owns a required evidence gate" not in haiku_text or "hard acceptance" not in haiku_text:
    raise SystemExit("Haiku must never own required evidence gates or hard acceptance")

catalog_local_routing_text = " ".join(
    value
    for template_id in (
        "codex-53-spark",
        "codex-54-mini",
        "codex-56-luna-medium",
        "claude-opus-4-8",
        "claude-sonnet-5",
        "claude-haiku-4-5",
    )
    for value in (templates[template_id]["summary"], templates[template_id]["description"])
).lower()
for stale in (
    "fast, narrowly frozen",
    "speed matters more than maximum reasoning depth",
    "balance speed and reasoning",
    "quality matters more than latency",
    "cheap extraction",
    "best as a scout",
):
    stale = stale.lower()
    if stale in catalog_local_routing_text:
        raise SystemExit(f"catalog must reject stale routing phrase {stale!r}")

spark_text = " ".join((
    templates["codex-53-spark"]["summary"],
    templates["codex-53-spark"]["description"],
)).lower()
if "narrowly frozen mechanical work" not in spark_text:
    raise SystemExit("Spark must remain narrowly frozen mechanical work")
if "independent review" not in spark_text or "sole acceptance" not in spark_text:
    raise SystemExit("Spark must require independent review and forbid sole acceptance")
mini_text = " ".join((
    templates["codex-54-mini"]["summary"],
    templates["codex-54-mini"]["description"],
)).lower()
if "current mini-low" not in mini_text or "evidence-limited" not in mini_text:
    raise SystemExit("Mini must retain current Mini-low evidence-limited wording")
if "cannot own acceptance" not in mini_text:
    raise SystemExit("Mini must not own acceptance")
luna_medium_text = " ".join((
    templates["codex-56-luna-medium"]["summary"],
    templates["codex-56-luna-medium"]["description"],
)).lower()
if "evidence-limited" not in luna_medium_text or "sole acceptance owner" not in luna_medium_text:
    raise SystemExit("Luna Medium must be evidence-limited and never own sole acceptance")
opus_text = " ".join((
    templates["claude-opus-4-8"]["summary"],
    templates["claude-opus-4-8"]["description"],
)).lower()
if "read-only consultation" not in opus_text or "tightly isolated externally bounded execution" not in opus_text:
    raise SystemExit("Opus must remain read-only or tightly externally bounded")
if "GPT-5.5 medium" not in templates["codex-55"]["description"]:
    raise SystemExit("GPT-5.5 medium must be explicitly named in its description")
if "evidence-limited" not in templates["codex-55"]["description"]:
    raise SystemExit("GPT-5.5 medium must be evidence-limited")
if "default" in templates["codex-55"]["summary"]:
    raise SystemExit("GPT-5.5 medium summary must not claim default ownership")
if "default" in templates["codex-55"]["description"]:
    raise SystemExit("GPT-5.5 medium description must not claim default ownership")
if "Terra" in templates["codex-55"]["summary"] or "Terra" in templates["codex-55"]["description"]:
    raise SystemExit("GPT-5.5 medium must not carry Terra wording")
gpt55_high_text = " ".join((
    templates["codex-55-high"]["summary"],
    templates["codex-55-high"]["description"],
))
if "hard bounded source/rescue candidate" not in gpt55_high_text:
    raise SystemExit("GPT-5.5 high must be a hard bounded source/rescue candidate")
if "independent review" not in gpt55_high_text or "current-target composed E2E" not in gpt55_high_text:
    raise SystemExit("GPT-5.5 high must require independent review and composed E2E")
for prohibited in ("Terra", "complex implementation", "broad coordination", "default"):
    if prohibited in gpt55_high_text:
        raise SystemExit(f"GPT-5.5 high must reject {prohibited!r} wording")
terra_medium_text = " ".join((
    templates["codex-56-terra-medium"]["summary"],
    templates["codex-56-terra-medium"]["description"],
))
if "evidence-limited" not in terra_medium_text or "independent review" not in terra_medium_text:
    raise SystemExit("Terra medium must be evidence-limited and independently reviewed")
if "default implementation" in terra_medium_text:
    raise SystemExit("Terra medium must reject default implementation wording")
sol_high_text = " ".join((
    templates["codex-56-sol-high"]["summary"],
    templates["codex-56-sol-high"]["description"],
))
if "focused repair" not in sol_high_text or "bounded diagnostics" not in sol_high_text:
    raise SystemExit("Sol high must be limited to focused repair and diagnostics")
if "general difficult initial implementer" not in sol_high_text or "Terra High is available" not in sol_high_text:
    raise SystemExit("Sol high must defer general difficult initial implementation while Terra High is available")
fable_text = " ".join((
    templates["claude-fable-5"]["summary"],
    templates["claude-fable-5"]["description"],
)).lower()
expected_fable_description = "Use only for architecture, supply-chain, exact-byte, and specification review."
if templates["claude-fable-5"]["description"] != expected_fable_description:
    raise SystemExit("Fable description must be the exact evidenced operator-use sentence")
for required in ("architecture", "supply-chain", "exact-byte", "specification review"):
    if required not in fable_text:
        raise SystemExit(f"Fable must retain {required!r} review scope")
for prohibited in ("deep-research lead", "guide haiku", "multi-hour reasoning", "slower replies", "vendor positioning"):
    if prohibited in fable_text:
        raise SystemExit(f"Fable must reject local-performance claim {prohibited!r}")
skill_text = Path("skills/bus-dev-task-worker-ops/SKILL.md").read_text()
normalized_skill_text = " ".join(skill_text.split())
if "polling them on a timer wastes" in skill_text or "sleep 45" in skill_text:
    raise SystemExit("worker-ops skill must not keep the stale polling loop wording")
if "bus thread wait" not in skill_text:
    raise SystemExit("worker-ops skill must teach event-driven bus thread wait practice")
if "current Mini-low" not in skill_text:
    raise SystemExit("worker-ops skill must mention current Mini-low")
if "evidence-limited" not in skill_text:
    raise SystemExit("worker-ops skill must mention evidence-limited profile behavior")
if "risk-matched heterogeneous review relay" not in skill_text:
    raise SystemExit("worker-ops skill must mention risk-matched heterogeneous review relay")
if "quota and substrate separate" not in skill_text:
    raise SystemExit("worker-ops skill must mention quota and substrate separation")
if "independent acceptance" not in skill_text:
    raise SystemExit("worker-ops skill must mention independent acceptance")
if "installed event-driven multi-thread wait" not in skill_text:
    raise SystemExit("worker-ops skill must mention installed event-driven multi-thread wait")
if "complete active catalog" not in skill_text:
    raise SystemExit("worker-ops skill must mention complete active catalog")
skill_local_routing_text = "\n".join(
    line for line in skill_text.splitlines()
    if any(marker in line for marker in (
        "codex-53-spark", "Mini-low", "Luna Medium", "Opus", "Sonnet",
        "Haiku", "provider-diverse", "fallback", "quota and substrate",
    ))
).lower()
for stale in (
    "fast narrowly frozen mechanical",
    "Haiku remains a cheap scout",
):
    stale = stale.lower()
    if stale in skill_local_routing_text:
        raise SystemExit(f"worker-ops skill must reject stale routing phrase {stale!r}")
for required in (
    "docs/docs/reports/2026-07-15-bus-worker-model-performance.md",
    "audited local record, not a future probability or universal ranking",
    "Terra High: complex implementation",
    "Spark Low: directly validated narrowly frozen mechanical implementation and review-driven repair; require independent review and separate final acceptance",
    "Exact current Mini Low and GPT-5.5 Medium remain evidence-limited bounded trials. Sonnet Medium has direct accepted bounded implementation, documentation/synthesis, and provider-diverse review evidence",
    "Sol XHigh: architecture/root cause",
    "Sol Max, Luna Max, Terra Max, and Fable: risk-matched review",
    "Luna Low: docs, diagnosis, and smoke",
    "Sol Ultra: no self-acceptance",
    "current-target composed E2E",
):
    if required not in normalized_skill_text:
        raise SystemExit(f"worker-ops skill must contain routing anchor {required!r}")
for unsupported in (
    "Spark, Mini, GPT-5.5 medium, and Sonnet: bounded work plus independent review",
    "Sol, Luna, Terra Max, and Fable: risk-matched review",
):
    if unsupported in normalized_skill_text:
        raise SystemExit(f"worker-ops skill must reject unsupported routing claim {unsupported!r}")
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
    bus worker template show codex-56-sol-ultra
)
printf '%s\n' "$real_resolver_output" | awk -F '	' '$1 == "default_model" && $2 == "gpt-5.6-sol" { found = 1 } END { exit found ? 0 : 1 }'
printf '%s\n' "$real_resolver_output" | awk -F '	' '$1 == "reasoning_effort" && $2 == "ultra" { found = 1 } END { exit found ? 0 : 1 }'
printf '%s\n' "$real_resolver_output" | awk -F '	' '$1 == "reasoning_summary" && $2 == "auto" { found = 1 } END { exit found ? 0 : 1 }'
printf '%s\n' "$real_resolver_output" | awk -F '	' '$1 == "model_verbosity" && $2 == "medium" { found = 1 } END { exit found ? 0 : 1 }'

real_opus5_output=$(
  PATH="$public_bin:$PATH" BUS_HOST=127.0.0.2 \
    bus worker template show claude-opus-5
)
printf '%s\n' "$real_opus5_output" | awk -F '	' '$1 == "default_model" && $2 == "claude-opus-5" { found = 1 } END { exit found ? 0 : 1 }'
printf '%s\n' "$real_opus5_output" | awk -F '	' '$1 == "reasoning_effort" && $2 == "high" { found = 1 } END { exit found ? 0 : 1 }'
printf '%s\n' "$real_opus5_output" | awk -F '	' '$1 == "runner_kind" && $2 == "appserver" { found = 1 } END { exit found ? 0 : 1 }'
printf '%s\n' "$real_opus5_output" | awk -F '	' '$1 == "runner_provider" && $2 == "claude-appserver" { found = 1 } END { exit found ? 0 : 1 }'

real_opus48_output=$(
  PATH="$public_bin:$PATH" BUS_HOST=127.0.0.2 \
    bus worker template show claude-opus-4-8
)
printf '%s\n' "$real_opus48_output" | awk -F '	' '$1 == "default_model" && $2 == "claude-opus-4-8" { found = 1 } END { exit found ? 0 : 1 }'
printf '%s\n' "$real_opus48_output" | awk -F '	' '$1 == "reasoning_effort" && $2 == "high" { found = 1 } END { exit found ? 0 : 1 }'

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
  launch_id=${env_log##*/}
  launch_id=${launch_id%.*}
  if ! BUS_HOST="$bus_host" \
    BUS_API_TOKEN=redacted-test-token \
    BUS_EVENTS_API_URL="$sentinel_url" \
    BUS_TASK_RECIPIENT="$artifact_recipient" \
    BUS_TASK_WORK_REF="${artifact_work_prefix}-${launch_id}" \
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
