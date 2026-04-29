#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

export LC_ALL=C

have() { command -v "$1" >/dev/null 2>&1; }
die() { echo "error: $*" >&2; exit 1; }

# -----------------------------------------------------------------------------
# Config (all script constants)
# -----------------------------------------------------------------------------
CHATGPT_BASE_START_DATE="${CHATGPT_BASE_START_DATE:-2026-01-23}"
CHATGPT_BASE_END_DATE="${CHATGPT_BASE_END_DATE:-$(date -u +%F)}"
CHATGPT_MONTHLY_EUR="${CHATGPT_MONTHLY_EUR:-180}"
CURSOR_TOTAL_USD="${CURSOR_TOTAL_USD:-3000}"
EXTRA_COSTS_EUR="0"
USD_TO_EUR_RATE="0.92"
PYTHON_BIN="python3"

readonly PYTHON_BIN

have "$PYTHON_BIN" || die "$PYTHON_BIN not found"
[ $# -eq 0 ] || die "unexpected arguments: $*"

"$PYTHON_BIN" - \
  "$CHATGPT_BASE_START_DATE" \
  "$CHATGPT_BASE_END_DATE" \
  "$CHATGPT_MONTHLY_EUR" \
  "$CURSOR_TOTAL_USD" \
  "$EXTRA_COSTS_EUR" \
  "$USD_TO_EUR_RATE" <<'PY'
from datetime import date
import shlex
import sys
from decimal import Decimal, ROUND_HALF_UP

(
    chatgpt_start_s,
    chatgpt_end_s,
    chatgpt_monthly_s,
    cursor_total_usd_s,
    extra_s,
    usd_to_eur_rate_s,
) = sys.argv[1:]


def d(value: str) -> Decimal:
    return Decimal(value)


def q2(value: Decimal) -> Decimal:
    return value.quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)

try:
    chatgpt_start = date.fromisoformat(chatgpt_start_s)
    chatgpt_end = date.fromisoformat(chatgpt_end_s)
except ValueError as exc:
    raise SystemExit(f"error: invalid ChatGPT base date: {exc}") from exc

if chatgpt_end < chatgpt_start:
    raise SystemExit("error: CHATGPT_BASE_END_DATE must be on or after CHATGPT_BASE_START_DATE")

chatgpt_months = (chatgpt_end.year - chatgpt_start.year) * 12 + chatgpt_end.month - chatgpt_start.month + 1
chatgpt_monthly = d(chatgpt_monthly_s)
chatgpt_pro = chatgpt_monthly * Decimal(chatgpt_months)
cursor_total_usd = d(cursor_total_usd_s)
extra = d(extra_s)
usd_to_eur_rate = d(usd_to_eur_rate_s)
cursor_total_eur = cursor_total_usd * usd_to_eur_rate

operating_total = chatgpt_pro + cursor_total_eur + extra

out = {
    "total_operating_cost_eur": float(q2(operating_total)),
    "breakdown_eur": {
        "chatgpt_pro": float(q2(chatgpt_pro)),
        "cursor_total": float(q2(cursor_total_eur)),
        "extra": float(q2(extra)),
    },
}

print(f"TOTAL_OPERATING_COST_EUR={shlex.quote(str(out['total_operating_cost_eur']))}")
print(f"BREAKDOWN_CHATGPT_PRO_EUR={shlex.quote(str(out['breakdown_eur']['chatgpt_pro']))}")
print(f"BREAKDOWN_CURSOR_TOTAL_EUR={shlex.quote(str(out['breakdown_eur']['cursor_total']))}")
print(f"BREAKDOWN_EXTRA_EUR={shlex.quote(str(out['breakdown_eur']['extra']))}")
print(f"ASSUMPTION_CHATGPT_BASE_START_DATE={shlex.quote(chatgpt_start_s)}")
print(f"ASSUMPTION_CHATGPT_BASE_END_DATE={shlex.quote(chatgpt_end_s)}")
print(f"ASSUMPTION_CHATGPT_MONTHS={shlex.quote(str(chatgpt_months))}")
print(f"ASSUMPTION_CHATGPT_MONTHLY_EUR={shlex.quote(str(float(q2(chatgpt_monthly))))}")
print(f"ASSUMPTION_CURSOR_TOTAL_USD={shlex.quote(str(float(q2(cursor_total_usd))))}")
print(f"ASSUMPTION_USD_TO_EUR_RATE={shlex.quote(str(usd_to_eur_rate))}")
PY
