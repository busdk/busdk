#!/bin/sh
set -euo pipefail

cd "$(dirname "$0")/.."

OUT_FILE="./scripts/prices-data.inc"
DOCS_DATA_DIR="./docs/docs/_data"
DOCS_DATA_FILE="${DOCS_DATA_DIR}/prices-data.json"
TIMESTAMP_UTC="$(date -u +%Y%m%d-%H%M%S)"
PYTHON_BIN="python3"
tmp_out="$(mktemp)"
tmp_json="$(mktemp)"
trap 'rm -f "$tmp_out" "$tmp_json"' EXIT

{
  printf 'PRICES_UTC_TIME=%s\n' "$TIMESTAMP_UTC"
  ./scripts/get-prices-data.sh
} > "$tmp_out"

mkdir -p "$DOCS_DATA_DIR"

"$PYTHON_BIN" - "$tmp_out" "$tmp_json" <<'PY'
import json
import sys
from decimal import Decimal

inc_path, out_path = sys.argv[1:3]
vars_map = {}

with open(inc_path, "r", encoding="utf-8") as f:
    for raw in f:
        line = raw.strip()
        if not line or "=" not in line:
            continue
        k, v = line.split("=", 1)
        vars_map[k] = v.strip("'")

keys = [k for k in vars_map.get("PRICE_MODULE_KEYS", "").split(",") if k]
modules = []
for key in keys:
    direct_deps_raw = vars_map.get(f"MODULE_{key}_DIRECT_DEPS", "")
    all_deps_raw = vars_map.get(f"MODULE_{key}_ALL_DEPS", "")
    direct_deps = [d for d in direct_deps_raw.split(",") if d]
    all_deps = [d for d in all_deps_raw.split(",") if d]
    modules.append(
        {
            "key": key,
            "name": vars_map.get(f"MODULE_{key}_NAME", ""),
            "base_price_eur": float(Decimal(vars_map.get(f"MODULE_{key}_BASE_PRICE_EUR", "0"))),
            "price_eur": float(Decimal(vars_map.get(f"MODULE_{key}_PRICE_EUR", "0"))),
            "direct_deps": direct_deps,
            "dependencies": all_deps,
        }
    )

out = {
    "prices_utc_time": vars_map.get("PRICES_UTC_TIME", ""),
    "total_price_eur": float(Decimal(vars_map.get("TOTAL_PRICE_EUR", "0"))),
    "source_total_cost_eur": float(Decimal(vars_map.get("SOURCE_TOTAL_COST_EUR", "0"))),
    "module_count": len(modules),
    "assumptions": {
        "chatgpt_base_start_date": vars_map.get("ASSUMPTION_CHATGPT_BASE_START_DATE", ""),
        "chatgpt_base_end_date": vars_map.get("ASSUMPTION_CHATGPT_BASE_END_DATE", ""),
        "chatgpt_months": int(vars_map.get("ASSUMPTION_CHATGPT_MONTHS", "0")),
        "chatgpt_monthly_eur": float(
            Decimal(vars_map.get("ASSUMPTION_CHATGPT_MONTHLY_EUR", "0"))
        ),
        "cursor_total_usd": float(Decimal(vars_map.get("ASSUMPTION_CURSOR_TOTAL_USD", "0"))),
        "usd_to_eur_rate": float(Decimal(vars_map.get("ASSUMPTION_USD_TO_EUR_RATE", "0"))),
        "human_labor_module_base_eur": float(
            Decimal(vars_map.get("ASSUMPTION_HUMAN_LABOR_MODULE_BASE_EUR", "0"))
        ),
        "human_labor_base_start_date": vars_map.get("ASSUMPTION_HUMAN_LABOR_BASE_START_DATE", ""),
        "human_labor_base_end_date": vars_map.get("ASSUMPTION_HUMAN_LABOR_BASE_END_DATE", ""),
        "human_labor_base_days": int(vars_map.get("ASSUMPTION_HUMAN_LABOR_BASE_DAYS", "0")),
        "human_labor_base_per_day_eur": float(
            Decimal(vars_map.get("ASSUMPTION_HUMAN_LABOR_BASE_PER_DAY_EUR", "0"))
        ),
        "human_labor_per_commit_total_eur": float(
            Decimal(vars_map.get("ASSUMPTION_HUMAN_LABOR_PER_COMMIT_TOTAL_EUR", "0"))
        ),
    },
    "modules": modules,
}

with open(out_path, "w", encoding="utf-8") as f:
    json.dump(out, f, ensure_ascii=True, separators=(",", ":"))
    f.write("\n")
PY

mv "$tmp_out" "$OUT_FILE"
mv "$tmp_json" "$DOCS_DATA_FILE"
