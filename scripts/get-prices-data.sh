#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

export LC_ALL=C

have() { command -v "$1" >/dev/null 2>&1; }
die() { echo "error: $*" >&2; exit 1; }

# -----------------------------------------------------------------------------
# Config (all script constants)
# -----------------------------------------------------------------------------
MODULES_GLOB="bus-*"
TOTAL_COSTS_CMD="scripts/get-total-costs.sh"
COMMIT_COUNTS_CMD="scripts/get-total-commit-counts.sh"
PYTHON_BIN="python3"

readonly MODULES_GLOB TOTAL_COSTS_CMD COMMIT_COUNTS_CMD PYTHON_BIN

have "$PYTHON_BIN" || die "$PYTHON_BIN not found"
[ -x "$TOTAL_COSTS_CMD" ] || die "total costs command not executable: $TOTAL_COSTS_CMD"
[ -x "$COMMIT_COUNTS_CMD" ] || die "commit counts command not executable: $COMMIT_COUNTS_CMD"

eval "$("$TOTAL_COSTS_CMD")"
[ -n "${TOTAL_COST_EUR:-}" ] || die "TOTAL_COST_EUR missing from $TOTAL_COSTS_CMD"
TOTAL_PRICE_EUR="$TOTAL_COST_EUR"

# Validate total is numeric and non-negative.
"$PYTHON_BIN" - <<'PY' "$TOTAL_PRICE_EUR"
from decimal import Decimal
import sys
try:
    value = Decimal(sys.argv[1])
except Exception:
    raise SystemExit("error: TOTAL_PRICE_EUR must be a valid decimal number")
if value < 0:
    raise SystemExit("error: TOTAL_PRICE_EUR must be >= 0")
PY

tmp_modules="$(mktemp)"
trap 'rm -f "$tmp_modules"' EXIT

eval "$("$COMMIT_COUNTS_CMD")"

[ -n "${MODULE_KEYS:-}" ] || die "no modules found"
IFS=',' read -r -a module_keys_arr <<< "$MODULE_KEYS"
for key in "${module_keys_arr[@]}"; do
  [ -n "$key" ] || continue
  name_var="MODULE_${key}_NAME"
  commits_var="MODULE_${key}_COMMITS"
  mod="${!name_var:-}"
  commits="${!commits_var:-0}"
  case "$mod" in
    $MODULES_GLOB) ;;
    *) continue ;;
  esac
  [ -n "$mod" ] || continue
  printf "%s\t%s\n" "$mod" "$commits" >> "$tmp_modules"
done

[ -s "$tmp_modules" ] || die "no modules found (MODULES_GLOB=$MODULES_GLOB)"

"$PYTHON_BIN" - "$tmp_modules" "$TOTAL_PRICE_EUR" "." <<'PY'
import re
import shlex
import sys
from decimal import Decimal, ROUND_HALF_UP
from pathlib import Path

path = sys.argv[1]
total_price_eur = Decimal(sys.argv[2])
repo_root = Path(sys.argv[3])

rows = []
with open(path, "r", encoding="utf-8") as f:
    for raw in f:
        line = raw.rstrip("\n")
        if not line:
            continue
        name, commits_s = line.split("\t", 1)
        commits = int(commits_s)
        if commits < 0:
            raise SystemExit(f"error: negative commit count for {name}")
        rows.append((name, commits))

if not rows:
    raise SystemExit("error: no module rows parsed")

rows.sort(key=lambda x: x[0])
module_names = {name for name, _ in rows}

# Allocate to integer cents deterministically with largest-remainder method.
total_cents = int((total_price_eur * Decimal("100")).quantize(Decimal("1"), rounding=ROUND_HALF_UP))
weights = {name: commits for name, commits in rows}
weight_sum = sum(weights.values())

if weight_sum == 0:
    # If all repos have zero commits, split equally.
    n = len(rows)
    exact = {name: Decimal(total_cents) / Decimal(n) for name, _ in rows}
else:
    exact = {
        name: Decimal(total_cents) * Decimal(weights[name]) / Decimal(weight_sum)
        for name, _ in rows
    }

base = {name: int(v) for name, v in exact.items()}
remainder = total_cents - sum(base.values())

order = sorted(rows, key=lambda x: (-(exact[x[0]] - Decimal(base[x[0]])), x[0]))
for i in range(remainder):
    base[order[i][0]] += 1

deps = {name: set() for name, _ in rows}
repo_module_rx = re.compile(r"^github\.com/busdk/(bus(?:-[a-z0-9]+)*)$")

def map_dep_token(token):
    token = token.strip()
    if not token:
        return None
    if token in module_names:
        return token
    m = repo_module_rx.match(token)
    if m:
        candidate = m.group(1)
        return candidate if candidate in module_names else None
    if token.startswith("./") or token.startswith("../") or token.startswith("/"):
        candidate = Path(token).name
        return candidate if candidate in module_names else None
    return None

for name, _ in rows:
    makefiles = [repo_root / name / "Makefile.local", repo_root / name / "Makefile"]
    for mk_path in makefiles:
        if not mk_path.exists():
            continue

        logical_lines = []
        current = ""
        for raw in mk_path.read_text(encoding="utf-8").splitlines():
            line = raw.rstrip()
            if current:
                current += line.lstrip()
            else:
                current = line
            if current.endswith("\\"):
                current = current[:-1]
                continue
            logical_lines.append(current)
            current = ""
        if current:
            logical_lines.append(current)

        for raw in logical_lines:
            line = raw.split("#", 1)[0].strip()
            if not line:
                continue
            m = re.match(r"^(MODULE_(?:BIN|SRC)_DEPS)\s*(?::=|\?=|\+=|=)\s*(.*)$", line)
            if not m:
                continue
            rhs = m.group(2).strip()
            for dep in rhs.split():
                mapped = map_dep_token(dep)
                if not mapped or mapped == name:
                    continue
                deps[name].add(mapped)

    go_mod = repo_root / name / "go.mod"
    if go_mod.exists():
        in_require_block = False
        for raw in go_mod.read_text(encoding="utf-8").splitlines():
            line = raw.split("//", 1)[0].strip()
            if not line:
                continue

            if in_require_block:
                if line.startswith(")"):
                    in_require_block = False
                    continue
                token = line.split()[0]
                mapped = map_dep_token(token)
                if mapped and mapped != name:
                    deps[name].add(mapped)
                continue

            if line.startswith("require ("):
                in_require_block = True
                continue

            if line.startswith("require "):
                rest = line[len("require "):].strip()
                if rest:
                    token = rest.split()[0]
                    mapped = map_dep_token(token)
                    if mapped and mapped != name:
                        deps[name].add(mapped)
                continue

            if line.startswith("replace "):
                rest = line[len("replace "):].strip()
                if "=>" not in rest:
                    continue
                lhs, rhs = rest.split("=>", 1)
                lhs_tok = lhs.strip().split()[0] if lhs.strip() else ""
                rhs_tok = rhs.strip().split()[0] if rhs.strip() else ""
                mapped_lhs = map_dep_token(lhs_tok)
                mapped_rhs = map_dep_token(rhs_tok)
                for mapped in (mapped_lhs, mapped_rhs):
                    if mapped and mapped != name:
                        deps[name].add(mapped)

closure_cache = {}

def closure(name):
    if name in closure_cache:
        return closure_cache[name]
    visited = set()
    stack = [name]
    while stack:
        cur = stack.pop()
        if cur in visited:
            continue
        visited.add(cur)
        for dep in sorted(deps.get(cur, ())):
            if dep not in visited:
                stack.append(dep)
    closure_cache[name] = visited
    return visited

inclusive = {}
transitive_deps = {}
for name, _ in rows:
    nodes = closure(name)
    inclusive[name] = sum(base[n] for n in nodes)
    transitive_deps[name] = sorted(n for n in nodes if n != name)

def emit(name: str, value) -> None:
    print(f"{name}={shlex.quote(str(value))}")

emit("TOTAL_PRICE_EUR", float((Decimal(total_cents) / Decimal("100")).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)))

sorted_modules = sorted(base.keys())
module_keys = []
for name in sorted_modules:
    key = re.sub(r"[^A-Za-z0-9]+", "_", name).strip("_").upper()
    module_keys.append(key)
    base_price = float((Decimal(base[name]) / Decimal("100")).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP))
    total_price = float((Decimal(inclusive[name]) / Decimal("100")).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP))
    emit(f"MODULE_{key}_NAME", name)
    emit(f"MODULE_{key}_BASE_PRICE_EUR", base_price)
    emit(f"MODULE_{key}_PRICE_EUR", total_price)
    emit(f"MODULE_{key}_DIRECT_DEPS", ",".join(sorted(deps[name])))
    emit(f"MODULE_{key}_ALL_DEPS", ",".join(transitive_deps[name]))

emit("PRICE_MODULE_KEYS", ",".join(module_keys))
PY
