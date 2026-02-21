#!/bin/sh
set -euo pipefail

cd "$(dirname "$0")/.."

OUT_FILE="./scripts/prices-data.inc"
DOCS_DATA_DIR="./docs/docs/_data"
DOCS_DATA_FILE="${DOCS_DATA_DIR}/prices-data.json"
TIMESTAMP_UTC="$(date -u +%Y%m%d-%H%M%S)"
PYTHON_BIN="python3"

{
  printf 'PRICES_UTC_TIME=%s\n' "$TIMESTAMP_UTC"
  ./scripts/get-prices-data.sh
} > "$OUT_FILE"

mkdir -p "$DOCS_DATA_DIR"

"$PYTHON_BIN" - "$OUT_FILE" "$DOCS_DATA_FILE" <<'PY'
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
    "module_count": len(modules),
    "modules": modules,
}

with open(out_path, "w", encoding="utf-8") as f:
    json.dump(out, f, ensure_ascii=True, separators=(",", ":"))
    f.write("\n")
PY
