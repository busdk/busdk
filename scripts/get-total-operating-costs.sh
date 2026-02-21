#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

export LC_ALL=C

have() { command -v "$1" >/dev/null 2>&1; }
die() { echo "error: $*" >&2; exit 1; }

# -----------------------------------------------------------------------------
# Config (all script constants)
# -----------------------------------------------------------------------------
CHATGPT_PRO_EUR="225"
EXTRA_COSTS_EUR="0"
USD_TO_EUR_RATE="0.92"
CURSOR_SECRET_NAME="cursor_admin_key"
CURSOR_SPEND_API_URL="https://api.cursor.com/teams/spend"
CURSOR_HTTP_TIMEOUT_SEC="30"
BUS_BIN="bus"
CURL_BIN="curl"
JQ_BIN="jq"
PYTHON_BIN="python3"
HTTP_CONTENT_TYPE="application/json"
HTTP_METHOD="POST"
HTTP_EMPTY_JSON_BODY="{}"

readonly BUS_BIN CURL_BIN JQ_BIN PYTHON_BIN
readonly HTTP_CONTENT_TYPE HTTP_METHOD HTTP_EMPTY_JSON_BODY

have "$BUS_BIN" || die "$BUS_BIN not found"
have "$CURL_BIN" || die "$CURL_BIN not found"
have "$JQ_BIN" || die "$JQ_BIN not found"
have "$PYTHON_BIN" || die "$PYTHON_BIN not found"
[ $# -eq 0 ] || die "unexpected arguments: $*"

CURSOR_ADMIN_API_KEY="$("$BUS_BIN" secrets get "$CURSOR_SECRET_NAME" 2>/dev/null || true)"
[ -n "$CURSOR_ADMIN_API_KEY" ] || die "missing bus secret: $CURSOR_SECRET_NAME"

spend_json="$(
  "$CURL_BIN" -fsSL \
    --max-time "$CURSOR_HTTP_TIMEOUT_SEC" \
    -H "Authorization: Bearer ${CURSOR_ADMIN_API_KEY}" \
    -H "Content-Type: ${HTTP_CONTENT_TYPE}" \
    -X "$HTTP_METHOD" \
    -d "$HTTP_EMPTY_JSON_BODY" \
    "$CURSOR_SPEND_API_URL"
)"

cursor_total_usd="$(
  printf '%s' "$spend_json" \
    | "$JQ_BIN" -r '(([.teamMemberSpend[].spendCents] | add // 0) + ([.teamMemberSpend[].includedSpendCents] | add // 0)) / 100'
)"

"$PYTHON_BIN" - "$CHATGPT_PRO_EUR" "$cursor_total_usd" "$EXTRA_COSTS_EUR" "$USD_TO_EUR_RATE" <<'PY'
import shlex
import sys
from decimal import Decimal, ROUND_HALF_UP

chatgpt_pro_s, cursor_total_usd_s, extra_s, usd_to_eur_rate_s = sys.argv[1:]


def d(value: str) -> Decimal:
    return Decimal(value)


def q2(value: Decimal) -> Decimal:
    return value.quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)

chatgpt_pro = d(chatgpt_pro_s)
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
print(f"ASSUMPTION_USD_TO_EUR_RATE={shlex.quote(str(usd_to_eur_rate))}")
PY
