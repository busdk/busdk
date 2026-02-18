#!/usr/bin/env bash
set -euo pipefail

URL_DEFAULT="https://docs.busdk.com/assets/data/content-index.json"
URL="${1:-$URL_DEFAULT}"

# You can override with: STATE_DIR=/path/to/state ./script.sh
STATE_DIR="${STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/busdk-content-index}"
RAW_FILE="$STATE_DIR/content-index.json"
MODULES_FILE="$STATE_DIR/modules.json"

mkdir -p "$STATE_DIR"

tmp_raw="$(mktemp)"
tmp_modules="$(mktemp)"
trap 'rm -f "$tmp_raw" "$tmp_modules"' EXIT

# Fetch latest content-index.json
if command -v curl >/dev/null 2>&1; then
  curl -fsSL "$URL" -o "$tmp_raw"
elif command -v wget >/dev/null 2>&1; then
  wget -qO "$tmp_raw" "$URL"
else
  echo "error: need curl or wget" >&2
  exit 127
fi

# Build per-module "latest timestamp" state:
# - considers both /modules/bus-* and /sdd/bus-* entries
# - stores max epoch + original timestamp string per module
python3 - "$tmp_raw" >"$tmp_modules" <<'PY'
import json, sys, re, datetime

path = sys.argv[1]
with open(path, "r", encoding="utf-8") as f:
    data = json.load(f)

rx = re.compile(r'^/(modules|sdd)/(bus-[^/]+)(?:/.*)?$')

mods = {}
for k, v in data.items():
    if k == "@generated_at":
        continue
    m = rx.match(k)
    if not m:
        continue

    mod = m.group(2)
    ts = str(v)

    # Python's fromisoformat doesn't accept "Z" directly.
    ts2 = ts[:-1] + "+00:00" if ts.endswith("Z") else ts

    try:
        dt = datetime.datetime.fromisoformat(ts2)
    except Exception:
        # If parsing fails, skip rather than breaking the script.
        continue

    epoch = int(dt.timestamp())

    prev = mods.get(mod)
    if prev is None or epoch > prev["epoch"]:
        mods[mod] = {"epoch": epoch, "ts": ts}

json.dump(mods, sys.stdout, ensure_ascii=False, sort_keys=True)
PY

# Print changed modules (keywords), compared to last run.
python3 - "$MODULES_FILE" "$tmp_modules" <<'PY'
import json, sys, os

prev_path = sys.argv[1]
cur_path = sys.argv[2]

if os.path.exists(prev_path):
    with open(prev_path, "r", encoding="utf-8") as f:
        prev = json.load(f)
else:
    prev = {}

with open(cur_path, "r", encoding="utf-8") as f:
    cur = json.load(f)

changed = []
for mod, info in cur.items():
    p = prev.get(mod)
    if p is None:
        changed.append(mod)
        continue
    # Detect changes robustly (epoch compare + string compare)
    if int(info.get("epoch", -1)) > int(p.get("epoch", -1)) or info.get("ts") != p.get("ts"):
        changed.append(mod)

for mod in sorted(changed):
    print(mod)
PY

# Persist new state atomically
tmp_save_raw="$(mktemp)"
tmp_save_modules="$(mktemp)"
trap 'rm -f "$tmp_raw" "$tmp_modules" "$tmp_save_raw" "$tmp_save_modules"' EXIT

cp "$tmp_raw" "$tmp_save_raw"
cp "$tmp_modules" "$tmp_save_modules"
mv -f "$tmp_save_raw" "$RAW_FILE"
mv -f "$tmp_save_modules" "$MODULES_FILE"
