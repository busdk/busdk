#!/bin/sh
set -eu

cd "$(dirname "$0")/../.."

operating_output="$(
  CHATGPT_BASE_START_DATE=2026-01-23 \
  CHATGPT_BASE_END_DATE=2026-04-29 \
  CHATGPT_MONTHLY_EUR=180 \
  CURSOR_TOTAL_USD=3000 \
  scripts/get-total-operating-costs.sh
)"

chatgpt_months="$(printf '%s\n' "$operating_output" | awk -F= '$1 == "ASSUMPTION_CHATGPT_MONTHS" {print $2}')"
chatgpt_total="$(printf '%s\n' "$operating_output" | awk -F= '$1 == "BREAKDOWN_CHATGPT_PRO_EUR" {print $2}')"
cursor_total="$(printf '%s\n' "$operating_output" | awk -F= '$1 == "BREAKDOWN_CURSOR_TOTAL_EUR" {print $2}')"

python3 - "$chatgpt_months" "$chatgpt_total" "$cursor_total" <<'PY'
from decimal import Decimal
import sys

chatgpt_months = int(sys.argv[1])
chatgpt_total = Decimal(sys.argv[2])
cursor_total = Decimal(sys.argv[3])
if chatgpt_months != 4:
    raise SystemExit(f"unexpected ChatGPT month count: got {chatgpt_months}, want 4")
if chatgpt_total != Decimal("720.0"):
    raise SystemExit(f"unexpected ChatGPT total: got {chatgpt_total}, want 720.0")
if cursor_total != Decimal("2760.0"):
    raise SystemExit(f"unexpected Cursor total: got {cursor_total}, want 2760.0")
PY

labour_output="$(
  HUMAN_LABOR_BASE_START_DATE=2026-01-23 \
  HUMAN_LABOR_BASE_END_DATE=2026-01-25 \
  HUMAN_LABOR_BASE_PER_DAY_EUR=1 \
  HUMAN_LABOR_MODULE_BASE_EUR=0 \
  HUMAN_LABOR_IMPL_PER_COMMIT_EUR=0 \
  HUMAN_LABOR_REVIEW_PER_COMMIT_EUR=0 \
  HUMAN_LABOR_UPKEEP_PER_COMMIT_EUR=0 \
  scripts/get-total-labour-costs.sh
)"

module_count="$(printf '%s\n' "$labour_output" | awk -F= '$1 == "ASSUMPTION_MODULE_COUNT" {print $2}')"
base_days="$(printf '%s\n' "$labour_output" | awk -F= '$1 == "ASSUMPTION_HUMAN_LABOR_BASE_DAYS" {print $2}')"
labour_total="$(printf '%s\n' "$labour_output" | awk -F= '$1 == "TOTAL_LABOUR_COST_EUR" {print $2}')"

python3 - "$module_count" "$base_days" "$labour_total" <<'PY'
from decimal import Decimal
import sys

module_count = int(sys.argv[1])
base_days = int(sys.argv[2])
labour_total = Decimal(sys.argv[3])
if module_count <= 0:
    raise SystemExit("expected at least one priced module")
if base_days != 3:
    raise SystemExit(f"unexpected human labor base days: got {base_days}, want 3")
if labour_total != Decimal(base_days):
    raise SystemExit(
        f"date baseline was not included in labour total: got {labour_total}, want {base_days}"
    )
PY

tmp_costs="$(mktemp)"
trap 'rm -f "$tmp_costs"' EXIT
{
  printf '%s\n' 'printf "%s\n" "TOTAL_COST_EUR=0"'
  printf '%s\n' 'printf "%s\n" "AI_COST_EUR=0"'
  printf '%s\n' 'printf "%s\n" "BREAKDOWN_HUMAN_PROJECT_BASE_EUR=3"'
  printf '%s\n' 'printf "%s\n" "ASSUMPTION_HUMAN_LABOR_MODULE_BASE_EUR=0"'
  printf '%s\n' 'printf "%s\n" "ASSUMPTION_HUMAN_LABOR_BASE_START_DATE=2026-01-23"'
  printf '%s\n' 'printf "%s\n" "ASSUMPTION_HUMAN_LABOR_BASE_END_DATE=2026-01-25"'
  printf '%s\n' 'printf "%s\n" "ASSUMPTION_HUMAN_LABOR_BASE_DAYS=3"'
  printf '%s\n' 'printf "%s\n" "ASSUMPTION_HUMAN_LABOR_BASE_PER_DAY_EUR=1"'
  printf '%s\n' 'printf "%s\n" "ASSUMPTION_HUMAN_LABOR_PER_COMMIT_TOTAL_EUR=0"'
} > "$tmp_costs"
chmod +x "$tmp_costs"

pricing_output="$(TOTAL_COSTS_CMD="$tmp_costs" scripts/get-prices-data.sh)"
price_keys="$(printf '%s\n' "$pricing_output" | awk -F= '$1 == "PRICE_MODULE_KEYS" {print $2}')"
pricing_total="$(printf '%s\n' "$pricing_output" | awk -F= '$1 == "TOTAL_PRICE_EUR" {print $2}')"

old_ifs="$IFS"
IFS=,
set -- $price_keys
IFS="$old_ifs"
priced_module_count="$#"

python3 - "$priced_module_count" "$pricing_total" <<'PY'
from decimal import Decimal
import sys

priced_module_count = int(sys.argv[1])
pricing_total = Decimal(sys.argv[2])
if priced_module_count <= 0:
    raise SystemExit("expected at least one generated price module")
if pricing_total != Decimal(3):
    raise SystemExit(
        f"date baseline was not included in generated prices: got {pricing_total}, want 3"
    )
PY

printf '%s\n' "pricing costs OK"
