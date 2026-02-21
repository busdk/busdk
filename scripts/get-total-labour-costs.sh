#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

export LC_ALL=C

have() { command -v "$1" >/dev/null 2>&1; }
die() { echo "error: $*" >&2; exit 1; }

# -----------------------------------------------------------------------------
# Config (all script constants)
# -----------------------------------------------------------------------------
COMMIT_COUNTS_CMD="scripts/get-total-commit-counts.sh"
HUMAN_LABOR_PROJECT_BASE_EUR="0"
HUMAN_LABOR_MODULE_BASE_EUR="0"
HUMAN_LABOR_IMPL_PER_COMMIT_EUR="6.785714285714286"
HUMAN_LABOR_REVIEW_PER_COMMIT_EUR="6.195652173913044"
HUMAN_LABOR_UPKEEP_PER_COMMIT_EUR="6"
PYTHON_BIN="python3"

readonly COMMIT_COUNTS_CMD PYTHON_BIN

have "$PYTHON_BIN" || die "$PYTHON_BIN not found"

[ $# -eq 0 ] || die "unexpected arguments: $*"

[ -x "$COMMIT_COUNTS_CMD" ] || die "commit counts command not executable: $COMMIT_COUNTS_CMD"
eval "$("$COMMIT_COUNTS_CMD")"

"$PYTHON_BIN" - "$MODULE_COUNT" "$TOTAL_COMMITS" \
  "$HUMAN_LABOR_PROJECT_BASE_EUR" "$HUMAN_LABOR_MODULE_BASE_EUR" \
  "$HUMAN_LABOR_IMPL_PER_COMMIT_EUR" "$HUMAN_LABOR_REVIEW_PER_COMMIT_EUR" "$HUMAN_LABOR_UPKEEP_PER_COMMIT_EUR" <<'PY'
import shlex
import sys
from decimal import Decimal, ROUND_HALF_UP

(
    module_count_s,
    total_commits_s,
    human_project_base_s,
    human_module_base_s,
    human_impl_s,
    human_review_s,
    human_upkeep_s,
) = sys.argv[1:]
module_count = int(module_count_s)
total_commits = int(total_commits_s)


def D(x: str) -> Decimal:
    return Decimal(x)


def q2(x: Decimal) -> Decimal:
    return x.quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)


human_project_base = D(human_project_base_s)
human_module_base = D(human_module_base_s)
human_impl = D(human_impl_s)
human_review = D(human_review_s)
human_upkeep = D(human_upkeep_s)

human_per_commit = human_impl + human_review + human_upkeep
human_module_base_total = human_module_base * module_count
human_commit_total = human_per_commit * total_commits
human_total = human_project_base + human_module_base_total + human_commit_total

out = {
    "total_labour_cost_eur": float(q2(human_total)),
    "breakdown_eur": {
        "human_project_base": float(q2(human_project_base)),
        "human_module_base_total": float(q2(human_module_base_total)),
        "human_commit_total": float(q2(human_commit_total)),
    },
    "assumptions": {
        "module_count": module_count,
        "total_commits": total_commits,
        "human_labor_module_base_eur": float(q2(human_module_base)),
        "human_labor_impl_per_commit_eur": float(q2(human_impl)),
        "human_labor_review_per_commit_eur": float(q2(human_review)),
        "human_labor_upkeep_per_commit_eur": float(q2(human_upkeep)),
        "human_labor_per_commit_total_eur": float(q2(human_per_commit)),
    },
}

print(f"TOTAL_LABOUR_COST_EUR={shlex.quote(str(out['total_labour_cost_eur']))}")
print(f"BREAKDOWN_HUMAN_PROJECT_BASE_EUR={shlex.quote(str(out['breakdown_eur']['human_project_base']))}")
print(f"BREAKDOWN_HUMAN_MODULE_BASE_TOTAL_EUR={shlex.quote(str(out['breakdown_eur']['human_module_base_total']))}")
print(f"BREAKDOWN_HUMAN_COMMIT_TOTAL_EUR={shlex.quote(str(out['breakdown_eur']['human_commit_total']))}")
print(f"ASSUMPTION_MODULE_COUNT={shlex.quote(str(out['assumptions']['module_count']))}")
print(f"ASSUMPTION_TOTAL_COMMITS={shlex.quote(str(out['assumptions']['total_commits']))}")
print(f"ASSUMPTION_HUMAN_LABOR_PER_COMMIT_TOTAL_EUR={shlex.quote(str(out['assumptions']['human_labor_per_commit_total_eur']))}")
PY
