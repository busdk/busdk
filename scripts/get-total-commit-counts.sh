#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

export LC_ALL=C

have() { command -v "$1" >/dev/null 2>&1; }
die() { echo "error: $*" >&2; exit 1; }

# -----------------------------------------------------------------------------
# Config (all script constants)
# -----------------------------------------------------------------------------
INCLUDE_ROOT="0"
INCLUDE_BUS="1"
MODULES_GLOB="bus-*"
GIT_BIN="git"
PYTHON_BIN="python3"

readonly INCLUDE_ROOT INCLUDE_BUS MODULES_GLOB GIT_BIN PYTHON_BIN

have "$GIT_BIN" || die "$GIT_BIN not found"
have "$PYTHON_BIN" || die "$PYTHON_BIN not found"
[ $# -eq 0 ] || die "unexpected arguments: $*"

tmp_modules="$(mktemp)"
trap 'rm -f "$tmp_modules"' EXIT

# Deterministic repository discovery.
# - include ./bus when configured
# - include directories matching MODULES_GLOB
# - only keep git repos
{
  [ "$INCLUDE_BUS" = "1" ] && [ -d "bus" ] && echo "bus"
  find . -mindepth 1 -maxdepth 1 -type d -name "$MODULES_GLOB" -print | sed 's#^\./##'
} | LC_ALL=C sort -u | while IFS= read -r mod; do
  [ -n "$mod" ] || continue
  "$GIT_BIN" -C "$mod" rev-parse --is-inside-work-tree >/dev/null 2>&1 || continue

  commits="$("$GIT_BIN" -C "$mod" rev-list --count HEAD 2>/dev/null || echo 0)"
  dates="$("$GIT_BIN" -C "$mod" log --pretty=format:%cs 2>/dev/null || true)"

  if [ -n "$dates" ]; then
    active_days="$(printf "%s\n" "$dates" | LC_ALL=C sort -u | wc -l | tr -d ' ')"
    first_date="$(printf "%s\n" "$dates" | LC_ALL=C sort | head -n 1)"
    last_date="$(printf "%s\n" "$dates" | LC_ALL=C sort | tail -n 1)"
  else
    active_days="0"
    first_date=""
    last_date=""
  fi

  printf "%s\t%s\t%s\t%s\t%s\n" "$mod" "$commits" "$active_days" "$first_date" "$last_date" >> "$tmp_modules"
done

if [ "$INCLUDE_ROOT" = "1" ] && "$GIT_BIN" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  root_commits="$("$GIT_BIN" rev-list --count HEAD 2>/dev/null || echo 0)"
  root_dates="$("$GIT_BIN" log --pretty=format:%cs 2>/dev/null || true)"

  if [ -n "$root_dates" ]; then
    root_active_days="$(printf "%s\n" "$root_dates" | LC_ALL=C sort -u | wc -l | tr -d ' ')"
    root_first_date="$(printf "%s\n" "$root_dates" | LC_ALL=C sort | head -n 1)"
    root_last_date="$(printf "%s\n" "$root_dates" | LC_ALL=C sort | tail -n 1)"
  else
    root_active_days="0"
    root_first_date=""
    root_last_date=""
  fi

  printf "%s\t%s\t%s\t%s\t%s\n" "." "$root_commits" "$root_active_days" "$root_first_date" "$root_last_date" >> "$tmp_modules"
fi

[ -s "$tmp_modules" ] || die "no module repositories found"

"$PYTHON_BIN" - "$tmp_modules" <<'PY'
import re
import shlex
import sys

path = sys.argv[1]
rows = []

with open(path, "r", encoding="utf-8") as f:
    for raw in f:
        line = raw.rstrip("\n")
        if not line:
            continue
        name, commits_s, active_days_s, first_date, last_date = line.split("\t")
        commits = int(commits_s)
        active_days = int(active_days_s)
        rows.append((name, commits, active_days, first_date, last_date))

rows.sort(key=lambda x: x[0])

total_commits = sum(r[1] for r in rows)
module_count = len(rows)

first_dates = [r[3] for r in rows if r[3]]
last_dates = [r[4] for r in rows if r[4]]

date_first = min(first_dates) if first_dates else ""
date_last = max(last_dates) if last_dates else ""

# Union of active days over module-level date spans cannot be reconstructed exactly
# without full date sets; keep deterministic useful aggregate from span only.
span_days_hint = 0
if date_first and date_last:
    from datetime import date
    y1,m1,d1 = map(int, date_first.split("-"))
    y2,m2,d2 = map(int, date_last.split("-"))
    span_days_hint = (date(y2,m2,d2) - date(y1,m1,d1)).days + 1

modules = {}
module_keys = []
for name, commits, active_days, first_date, last_date in rows:
    key = re.sub(r"[^A-Za-z0-9]+", "_", name).strip("_").upper() or "ROOT"
    module_keys.append(key)
    modules[name] = {
        "key": key,
        "commits": commits,
        "active_days": active_days,
        "first_date": first_date,
        "last_date": last_date,
    }

def emit(name: str, value) -> None:
    print(f"{name}={shlex.quote(str(value))}")

emit("MODULE_COUNT", module_count)
emit("TOTAL_COMMITS", total_commits)
emit("DATE_FIRST", date_first)
emit("DATE_LAST", date_last)
emit("DATE_SPAN_DAYS_HINT", span_days_hint)
emit("MODULE_KEYS", ",".join(module_keys))

for name, meta in sorted(modules.items()):
    key = meta["key"]
    emit(f"MODULE_{key}_NAME", name)
    emit(f"MODULE_{key}_COMMITS", meta["commits"])
    emit(f"MODULE_{key}_ACTIVE_DAYS", meta["active_days"])
    emit(f"MODULE_{key}_FIRST_DATE", meta["first_date"])
    emit(f"MODULE_{key}_LAST_DATE", meta["last_date"])
PY
