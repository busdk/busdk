#!/usr/bin/env bash
set -euo pipefail

(

URL_DEFAULT="https://docs.busdk.com/assets/data/content-index.json"
URL="${1:-$URL_DEFAULT}"

# Override if you want: STATE_DIR=/path/to/state ./script.sh
STATE_DIR="${STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/busdk-content-index}"
RAW_FILE="$STATE_DIR/content-index.json"

mkdir -p "$STATE_DIR"

tmp_raw="$(mktemp)"
trap 'rm -f "$tmp_raw"' EXIT

# Fetch latest content-index.json
if command -v curl >/dev/null 2>&1; then
  curl -fsSL "$URL" -o "$tmp_raw"
elif command -v wget >/dev/null 2>&1; then
  wget -qO "$tmp_raw" "$URL"
else
  echo "error: need curl or wget" >&2
  exit 127
fi

# Find docs changed in last 24h (relative to now), print their keys (paths).
python3 - "$tmp_raw" <<'PY'
import json, sys, datetime

path = sys.argv[1]
with open(path, "r", encoding="utf-8") as f:
    data = json.load(f)

now = datetime.datetime.now(datetime.timezone.utc)
cutoff = now - datetime.timedelta(hours=24)

changed = []
for k, v in data.items():
    if k == "@generated_at":
        continue
    ts = str(v)
    ts2 = ts[:-1] + "+00:00" if ts.endswith("Z") else ts
    try:
        dt = datetime.datetime.fromisoformat(ts2)
    except Exception:
        continue
    # Ensure timezone-aware
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=datetime.timezone.utc)
    if dt >= cutoff:
        changed.append(k)

for k in sorted(changed):
    print(k)
PY

# Persist raw state (optional, but keeps a local copy)
tmp_save="$(mktemp)"
trap 'rm -f "$tmp_raw" "$tmp_save"' EXIT
cp "$tmp_raw" "$tmp_save"
mv -f "$tmp_save" "$RAW_FILE"

)|grep -vF /sdd/modules|grep -E '/(sdd|modules)/'|sed -re 's@/(sdd|modules)/@@'|sort|uniq
