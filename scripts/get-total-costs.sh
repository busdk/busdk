#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

export LC_ALL=C

have() { command -v "$1" >/dev/null 2>&1; }
die() { echo "error: $*" >&2; exit 1; }

# -----------------------------------------------------------------------------
# Config (all script constants)
# -----------------------------------------------------------------------------
OPERATING_COSTS_CMD="scripts/get-total-operating-costs.sh"
LABOUR_COSTS_CMD="scripts/get-total-labour-costs.sh"
PYTHON_BIN="python3"

readonly OPERATING_COSTS_CMD LABOUR_COSTS_CMD PYTHON_BIN

have "$PYTHON_BIN" || die "$PYTHON_BIN not found"
[ -x "$OPERATING_COSTS_CMD" ] || die "operating costs command not executable: $OPERATING_COSTS_CMD"
[ -x "$LABOUR_COSTS_CMD" ] || die "labour costs command not executable: $LABOUR_COSTS_CMD"
[ $# -eq 0 ] || die "unexpected arguments: $*"

eval "$("$OPERATING_COSTS_CMD")"
eval "$("$LABOUR_COSTS_CMD")"

"$PYTHON_BIN" - \
  "$TOTAL_OPERATING_COST_EUR" \
  "$TOTAL_LABOUR_COST_EUR" \
  "$BREAKDOWN_CHATGPT_PRO_EUR" \
  "$BREAKDOWN_CURSOR_TOTAL_EUR" \
  "$BREAKDOWN_EXTRA_EUR" \
  "$BREAKDOWN_HUMAN_PROJECT_BASE_EUR" \
  "$BREAKDOWN_HUMAN_MODULE_BASE_TOTAL_EUR" \
  "$BREAKDOWN_HUMAN_COMMIT_TOTAL_EUR" \
  "$ASSUMPTION_MODULE_COUNT" \
  "$ASSUMPTION_TOTAL_COMMITS" \
  "$ASSUMPTION_HUMAN_LABOR_PER_COMMIT_TOTAL_EUR" <<'PY'
import shlex
import sys
from decimal import Decimal, ROUND_HALF_UP

(
    total_operating_s,
    total_labour_s,
    chatgpt_pro_s,
    cursor_total_s,
    extra_s,
    human_project_base_s,
    human_module_base_total_s,
    human_commit_total_s,
    module_count_s,
    total_commits_s,
    human_per_commit_s,
) = sys.argv[1:]

def D(x: str) -> Decimal:
    return Decimal(x)

def q2(x: Decimal) -> Decimal:
    return x.quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)

total_operating = D(total_operating_s)
total_labour = D(total_labour_s)
total_cost = total_operating + total_labour

print(f"TOTAL_COST_EUR={shlex.quote(str(float(q2(total_cost))))}")
print(f"AI_COST_EUR={shlex.quote(str(float(q2(total_operating))))}")
print(f"HUMAN_LABOUR_COST_EUR={shlex.quote(str(float(q2(total_labour))))}")
print(f"BREAKDOWN_CHATGPT_PRO_EUR={shlex.quote(str(float(q2(D(chatgpt_pro_s)))))}")
print(f"BREAKDOWN_CURSOR_TOTAL_EUR={shlex.quote(str(float(q2(D(cursor_total_s)))))}")
print(f"BREAKDOWN_EXTRA_EUR={shlex.quote(str(float(q2(D(extra_s)))))}")
print(f"BREAKDOWN_HUMAN_PROJECT_BASE_EUR={shlex.quote(str(float(q2(D(human_project_base_s)))))}")
print(f"BREAKDOWN_HUMAN_MODULE_BASE_TOTAL_EUR={shlex.quote(str(float(q2(D(human_module_base_total_s)))))}")
print(f"BREAKDOWN_HUMAN_COMMIT_TOTAL_EUR={shlex.quote(str(float(q2(D(human_commit_total_s)))))}")
print(f"ASSUMPTION_MODULE_COUNT={shlex.quote(str(int(module_count_s)))}")
print(f"ASSUMPTION_TOTAL_COMMITS={shlex.quote(str(int(total_commits_s)))}")
print(f"ASSUMPTION_HUMAN_LABOR_PER_COMMIT_TOTAL_EUR={shlex.quote(str(float(q2(D(human_per_commit_s)))))}")
PY
