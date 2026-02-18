#!/usr/bin/env bash
set -euo pipefail
#set -x

cd "$(dirname "$0")/.."

have() { command -v "$1" >/dev/null 2>&1; }
die() { echo "error: $*" >&2; exit 1; }

# -----------------------------------------------------------------------------
# REQUIRED: Cursor Admin API key
# -----------------------------------------------------------------------------
: "${CURSOR_ADMIN_API_KEY:?CURSOR_ADMIN_API_KEY is required (Cursor Admin API key)}"

# Required tooling for this script (we keep everything in this same script)
have git     || die "git not found"
have curl    || die "curl not found"
have jq      || die "jq not found"
have python3 || die "python3 not found"

# -----------------------------------------------------------------------------
# Snapshot
# -----------------------------------------------------------------------------
SNAPSHOT_TZ="Europe/Helsinki"
SNAPSHOT="$(TZ="$SNAPSHOT_TZ" date '+%Y-%m-%d %H:%M %Z')"

tmp_dates="$(mktemp)"
tmp_pairs="$(mktemp)"
tmp_modules="$(mktemp)"
tmp_usage_ndjson="$(mktemp)"
tmp_usage_ndjson_sorted="$(mktemp)"
trap 'rm -f "$tmp_dates" "$tmp_pairs" "$tmp_modules" "$tmp_usage_ndjson" "$tmp_usage_ndjson_sorted"' EXIT

# -----------------------------------------------------------------------------
# Manual costs (USD)
# -----------------------------------------------------------------------------
CHATGPT_PLUS_USD="${CHATGPT_PLUS_USD:-21.76}"
EXTRA_COSTS_USD="${EXTRA_COSTS_USD:-0}" # add any other costs here (USD), e.g. 12.34

# -----------------------------------------------------------------------------
# Human labor cost model (USD)
# -----------------------------------------------------------------------------
HUMAN_LABOR_PROJECT_BASE_USD="${HUMAN_LABOR_PROJECT_BASE_USD:-0}"   # one-time project overhead, distributed across modules
HUMAN_LABOR_MODULE_BASE_USD="${HUMAN_LABOR_MODULE_BASE_USD:-0}"     # fixed overhead per module
HUMAN_LABOR_IMPL_PER_COMMIT_USD="${HUMAN_LABOR_IMPL_PER_COMMIT_USD:-6.785714285714286}"       # implementation effort per commit
HUMAN_LABOR_REVIEW_PER_COMMIT_USD="${HUMAN_LABOR_REVIEW_PER_COMMIT_USD:-6.195652173913044}"   # PR review effort per commit (future)
HUMAN_LABOR_UPKEEP_PER_COMMIT_USD="${HUMAN_LABOR_UPKEEP_PER_COMMIT_USD:-6}"   # upkeep/bugfix provision per commit (future)

# -----------------------------------------------------------------------------
# Cursor token price knobs (optional sanity-check; NOT used as authoritative billing)
# -----------------------------------------------------------------------------
CURSOR_RATE_INPUT_USD_PER_1M="${CURSOR_RATE_INPUT_USD_PER_1M:-1.25}"   # input + cache write
CURSOR_RATE_OUTPUT_USD_PER_1M="${CURSOR_RATE_OUTPUT_USD_PER_1M:-6.00}"  # output
CURSOR_RATE_CACHE_READ_USD_PER_1M="${CURSOR_RATE_CACHE_READ_USD_PER_1M:-0.25}" # cache read

# -----------------------------------------------------------------------------
# Cursor usage fetch range (required fetch; range has defaults)
# -----------------------------------------------------------------------------
CURSOR_USAGE_PAGE_SIZE="${CURSOR_USAGE_PAGE_SIZE:-1000}"
CURSOR_USAGE_START_DATE="${CURSOR_USAGE_START_DATE:-}"
CURSOR_USAGE_END_DATE="${CURSOR_USAGE_END_DATE:-}"

# Admin API appears to enforce pageSize max (requesting >1000 has produced 400s).
if [ "$CURSOR_USAGE_PAGE_SIZE" -gt 1000 ]; then CURSOR_USAGE_PAGE_SIZE=1000; fi
if [ "$CURSOR_USAGE_PAGE_SIZE" -lt 1 ]; then CURSOR_USAGE_PAGE_SIZE=1; fi

# -----------------------------------------------------------------------------
# Output header
# -----------------------------------------------------------------------------
echo "# BusDK metrics snapshot: $SNAPSHOT"
echo "# cwd: $(pwd)"
echo

# ---------------------------------------------------------------------------
# Per-module metrics
# ---------------------------------------------------------------------------
echo "# per-module (tsv): module	commits	active_days	avg_commits_per_active_day	first_date	last_date	human_labor_usd_est"

git submodule foreach --quiet '
  commits="$(git rev-list --count HEAD 2>/dev/null || echo 0)"
  dates="$(git log --pretty=format:%cs 2>/dev/null || true)"

  if [ -n "$dates" ]; then
    active_days="$(printf "%s\n" "$dates" | LC_ALL=C sort -u | wc -l | tr -d " ")"
    last_date="$(printf "%s\n" "$dates" | head -n 1)"
    first_date="$(printf "%s\n" "$dates" | tail -n 1)"
  else
    active_days="0"
    last_date=""
    first_date=""
  fi

  if [ "$active_days" -gt 0 ]; then
    avg="$(awk -v c="$commits" -v d="$active_days" "BEGIN{printf \"%.2f\", c/d}")"
  else
    avg="0.00"
  fi

  printf "%s\t%s\t%s\t%s\t%s\t%s\n" "$name" "$commits" "$active_days" "$avg" "$first_date" "$last_date" >> "'"$tmp_modules"'"

  if [ -n "$dates" ]; then
    printf "%s\n" "$dates" >> "'"$tmp_dates"'"
    printf "%s\n" "$dates" | awk -v m="$name" "{print \$0\"\t\"m}" >> "'"$tmp_pairs"'"
  fi
'

python3 - "$tmp_modules" <<PY
import sys
path = sys.argv[1]

project_base = float("${HUMAN_LABOR_PROJECT_BASE_USD}")
module_base  = float("${HUMAN_LABOR_MODULE_BASE_USD}")
impl_pc      = float("${HUMAN_LABOR_IMPL_PER_COMMIT_USD}")
review_pc    = float("${HUMAN_LABOR_REVIEW_PER_COMMIT_USD}")
upkeep_pc    = float("${HUMAN_LABOR_UPKEEP_PER_COMMIT_USD}")
per_commit_total = impl_pc + review_pc + upkeep_pc

rows = []
with open(path, "r", encoding="utf-8") as f:
    for line in f:
        line = line.rstrip("\n")
        if not line:
            continue
        parts = line.split("\t")
        name = parts[0]
        commits = int(float(parts[1] or 0))
        rows.append((name, commits, parts))

n = len(rows)
total_commits = sum(r[1] for r in rows)

def project_share(commits: int) -> float:
    if n == 0:
        return 0.0
    if total_commits > 0:
        return project_base * (commits / total_commits)
    return project_base / n

out = []
for name, commits, parts in rows:
    share = project_share(commits)
    human = module_base + share + commits * per_commit_total
    out.append((name, parts + [f"{human:.2f}"]))

out.sort(key=lambda x: x[0])
for _, parts in out:
    print("\t".join(parts))
PY

echo

# ---------------------------------------------------------------------------
# Daily distributions + derived totals (same as before)
# ---------------------------------------------------------------------------

commits_per_day_tsv="$(
  if [ -s "$tmp_dates" ]; then
    grep -Eo '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' "$tmp_dates" \
      | LC_ALL=C sort | uniq -c | awk '{print $2 "\t" $1}' | LC_ALL=C sort
  fi
)"

active_modules_per_day_tsv="$(
  if [ -s "$tmp_pairs" ]; then
    LC_ALL=C sort -u "$tmp_pairs" \
      | awk -F'\t' '{c[$1]++} END{for (d in c) print d "\t" c[d]}' \
      | LC_ALL=C sort
  fi
)"

total_commits_sum="$(
  git submodule foreach --quiet 'git rev-list --count HEAD 2>/dev/null || echo 0' \
    | awk '{s+=$1} END{print s+0}'
)"

total_active_days_union="$(
  if [ -s "$tmp_dates" ]; then
    grep -Eo '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' "$tmp_dates" \
      | LC_ALL=C sort -u | wc -l | tr -d " "
  else
    echo 0
  fi
)"

avg_commits_per_day="$(
  awk -v c="$total_commits_sum" -v d="$total_active_days_union" \
    'BEGIN{ if(d>0) printf "%.2f", c/d; else print "0.00" }'
)"

busiest_day="—"
max_commits_on_busiest_day="0"
if [ -n "$commits_per_day_tsv" ]; then
  line="$(printf "%s\n" "$commits_per_day_tsv" | awk -F'\t' '($2>m){m=$2; d=$1} END{print d "\t" m}')"
  busiest_day="$(printf "%s" "$line" | awk '{print $1}')"
  max_commits_on_busiest_day="$(printf "%s" "$line" | awk '{print $2}')"
fi

avg_active_modules_per_day="0.00"
sum_active_module_days="0"
if [ -n "$active_modules_per_day_tsv" ]; then
  sum_active_module_days="$(printf "%s\n" "$active_modules_per_day_tsv" | awk -F'\t' '{s+=$2} END{print s+0}')"
  avg_active_modules_per_day="$(
    printf "%s\n" "$active_modules_per_day_tsv" \
      | awk -F'\t' '{s+=$2; n++} END{ if(n>0) printf "%.2f", s/n; else print "0.00" }'
  )"
fi

commits_per_active_module_day="$(
  awk -v c="$total_commits_sum" -v d="$sum_active_module_days" \
    'BEGIN{ if(d>0) printf "%.4f", c/d; else print "0.0000" }'
)"

date_first="—"
date_last="—"
if [ -s "$tmp_dates" ]; then
  date_first="$(grep -Eo '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' "$tmp_dates" | LC_ALL=C sort | head -n 1 || true)"
  date_last="$(grep -Eo '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' "$tmp_dates" | LC_ALL=C sort | tail -n 1 || true)"
fi

echo "# totals (derived)"
echo "total_commits_sum	${total_commits_sum}"
echo "total_active_days_union	${total_active_days_union}"
echo "avg_commits_per_day	${avg_commits_per_day}"
echo "busiest_day	${busiest_day}"
echo "max_commits_on_busiest_day	${max_commits_on_busiest_day}"
echo "avg_active_modules_per_day	${avg_active_modules_per_day}"
echo "sum_active_module_days	${sum_active_module_days}"
echo "commits_per_active_module_day	${commits_per_active_module_day}"
echo "date_span_first	${date_first}"
echo "date_span_last	${date_last}"
echo

echo "# commits-per-day across all modules (tsv): date	commits"
if [ -n "$commits_per_day_tsv" ]; then printf "%s\n" "$commits_per_day_tsv"; fi
echo

echo "# active-modules-per-day across all modules (tsv): date	active_modules"
if [ -n "$active_modules_per_day_tsv" ]; then printf "%s\n" "$active_modules_per_day_tsv"; fi
echo

# ---------------------------------------------------------------------------
# Cursor Costs (Admin API) — REQUIRED and authoritative for cost analysis
# ---------------------------------------------------------------------------

# Retries:
# - for 429 and 5xx: retry with exponential backoff
# - for other non-200: fail (print body)
CURL_MAX_RETRIES="${CURL_MAX_RETRIES:-8}"
CURL_RETRY_BASE_SLEEP_SEC="${CURL_RETRY_BASE_SLEEP_SEC:-1}"

curl_json() {
  local url="$1"
  local body="$2"

  local attempt=1
  local sleep_s="$CURL_RETRY_BASE_SLEEP_SEC"

  while :; do
    local out status
    out="$(
      curl -sS -u "${CURSOR_ADMIN_API_KEY}:" \
        -H "Content-Type: application/json" \
        -d "$body" \
        -w $'\n%{http_code}' \
        "$url" || true
    )"

    status="$(printf "%s" "$out" | tail -n 1)"
    out="$(printf "%s" "$out" | sed '$d')"

    if [ "$status" = "200" ]; then
      printf "%s" "$out"
      return 0
    fi

    # Retry on 429 and 5xx
    if [ "$status" = "429" ] || [[ "$status" =~ ^5[0-9][0-9]$ ]]; then
      if [ "$attempt" -ge "$CURL_MAX_RETRIES" ]; then
        echo "error: Cursor Admin API request failed after retries" >&2
        echo "url: $url" >&2
        echo "http_status: $status" >&2
        echo "request_body: $body" >&2
        echo "response_body: $out" >&2
        exit 1
      fi
      echo "warn: Cursor Admin API http_status=$status retrying attempt=$attempt sleep=${sleep_s}s" >&2
      sleep "$sleep_s"
      attempt=$((attempt+1))
      sleep_s=$((sleep_s*2))
      continue
    fi

    # Fail on other errors
    echo "error: Cursor Admin API request failed" >&2
    echo "url: $url" >&2
    echo "http_status: $status" >&2
    echo "request_body: $body" >&2
    echo "response_body: $out" >&2
    exit 1
  done
}

to_epoch_ms_py() {
  local tz="$1"
  local datestr="$2"
  python3 - "$tz" "$datestr" <<'PY'
import sys
from datetime import datetime
try:
  from zoneinfo import ZoneInfo
except Exception:
  ZoneInfo = None

tz = sys.argv[1]
s = sys.argv[2].strip()
if not s:
  print("")
  raise SystemExit(0)

dt = None
for fmt in ("%Y-%m-%d", "%Y-%m-%dT%H:%M", "%Y-%m-%dT%H:%M:%S"):
  try:
    dt = datetime.strptime(s, fmt)
    break
  except Exception:
    pass
if dt is None:
  dt = datetime.fromisoformat(s)

if ZoneInfo:
  dt = dt.replace(tzinfo=ZoneInfo(tz))
print(int(dt.timestamp() * 1000))
PY
}

default_month_start() { TZ="$SNAPSHOT_TZ" date '+%Y-%m-01'; }

start_date="${CURSOR_USAGE_START_DATE:-$(default_month_start)}"
end_date="${CURSOR_USAGE_END_DATE:-}"

start_ms="$(to_epoch_ms_py "$SNAPSHOT_TZ" "$start_date")"
if [ -n "$end_date" ]; then
  end_ms="$(to_epoch_ms_py "$SNAPSHOT_TZ" "$end_date")"
else
  end_ms="$(python3 - <<'PY'
import time
print(int(time.time()*1000))
PY
)"
fi

echo "# costs"
echo "chatgpt_plus_usd	${CHATGPT_PLUS_USD}"
echo "extra_costs_usd	${EXTRA_COSTS_USD}"

# --- /teams/spend (kept) ---
spend_json="$(curl_json "https://api.cursor.com/teams/spend" '{}')"

cursor_spend_usd="$(printf "%s" "$spend_json" | jq -r '([.teamMemberSpend[].spendCents] | add // 0) / 100')"
cursor_included_usd="$(printf "%s" "$spend_json" | jq -r '([.teamMemberSpend[].includedSpendCents] | add // 0) / 100')"
cursor_total_usd_spend="$(printf "%s" "$spend_json" | jq -r '(([.teamMemberSpend[].spendCents] | add // 0) + ([.teamMemberSpend[].includedSpendCents] | add // 0)) / 100')"

echo "cursor_team_spend_usd	${cursor_spend_usd}"
echo "cursor_team_included_usd	${cursor_included_usd}"
echo "cursor_team_total_usd	${cursor_total_usd_spend}"

# --- /teams/filtered-usage-events (required; used for cost analysis) ---
echo
echo "# cursor usage events (Admin API): filtered-usage-events"
echo "cursor_usage_fetch_tz	${SNAPSHOT_TZ}"
echo "cursor_usage_fetch_start_date	${start_date}"
echo "cursor_usage_fetch_end_date	${end_date:-now}"
echo "cursor_usage_fetch_start_ms	${start_ms}"
echo "cursor_usage_fetch_end_ms	${end_ms}"
echo "cursor_usage_fetch_page_size	${CURSOR_USAGE_PAGE_SIZE}"

: > "$tmp_usage_ndjson"

page=1
total_count=0
seen_count=0

while :; do
  body="$(printf '{"pageSize":%s,"startDate":%s,"endDate":%s,"page":%s}' \
    "$CURSOR_USAGE_PAGE_SIZE" "$start_ms" "$end_ms" "$page")"

  resp="$(curl_json "https://api.cursor.com/teams/filtered-usage-events" "$body")"

  if [ "$page" -eq 1 ]; then
    total_count="$(printf "%s" "$resp" | jq -r '.totalUsageEventsCount // 0')"
    echo "cursor_usage_events_total_count	${total_count}"
  fi

  # Append events
  got="$(printf "%s" "$resp" | jq -r '.usageEventsDisplay | length')"
  printf "%s" "$resp" | jq -c '.usageEventsDisplay[]?' >> "$tmp_usage_ndjson"
  seen_count=$((seen_count + got))

  echo "cursor_usage_events_page_${page}_rows	${got}"

  # Stop conditions:
  # 1) short page => last page
  if [ "$got" -lt "$CURSOR_USAGE_PAGE_SIZE" ]; then
    break
  fi
  # 2) total count satisfied (when API provides it)
  if [ "$total_count" -gt 0 ] && [ "$seen_count" -ge "$total_count" ]; then
    break
  fi

  page=$((page+1))
done

echo "cursor_usage_events_seen_count	${seen_count}"
echo

# Deterministic ordering for analysis output (independent of pagination/network)
LC_ALL=C sort "$tmp_usage_ndjson" > "$tmp_usage_ndjson_sorted"
mv "$tmp_usage_ndjson_sorted" "$tmp_usage_ndjson"

# Analyze usage events deterministically and emit:
# - key/value facts
# - TSV blocks for dashboards
usage_analysis="$(
  python3 - "$tmp_usage_ndjson" <<PY
import json, math
from collections import defaultdict
from datetime import datetime, timezone

path = "$tmp_usage_ndjson"

RATE_IN = float("$CURSOR_RATE_INPUT_USD_PER_1M")
RATE_OUT = float("$CURSOR_RATE_OUTPUT_USD_PER_1M")
RATE_CR  = float("$CURSOR_RATE_CACHE_READ_USD_PER_1M")

def fnum(x):
    if x is None:
        return None
    if isinstance(x, (int, float)):
        return float(x)
    s = str(x).strip()
    if s.lower() in ("included", "-", "", "none", "null"):
        return None
    if s.startswith("$"):
        s = s[1:]
    try:
        return float(s)
    except Exception:
        return None

def cents_to_usd(x):
    try:
        return float(x) / 100.0
    except Exception:
        return 0.0

def get_ts(ev):
    for k in ("timestamp", "createdAt", "time", "ts"):
        if k in ev and ev[k] is not None:
            return ev[k]
    return None

def iso_utc_from_ms(ms):
    try:
        ms = int(ms)
        dt = datetime.fromtimestamp(ms/1000.0, tz=timezone.utc)
        return dt.isoformat().replace("+00:00","Z")
    except Exception:
        return "—"

def pct(a, b):
    return 0.0 if b == 0 else (a / b) * 100.0

def safe_quantile(vals, q):
    if not vals:
        return 0.0
    s = sorted(vals)
    k = max(1, min(len(s), int(math.ceil(q * len(s)))))
    return float(s[k-1])

def fmt(n, d=6):
    return f"{n:.{d}f}"

def parse_cost(ev):
    tu = ev.get("tokenUsage") or {}
    token_cost = cents_to_usd(tu.get("totalCents") or 0)

    ub = ev.get("usageBasedCosts")
    ubv = fnum(ub)
    if ubv is None:
        ubv = 0.0

    rc = ev.get("requestsCosts")
    rcv = fnum(rc)
    if rcv is None:
        rcv = 0.0

    cost = token_cost + ubv
    if cost == 0.0 and rcv != 0.0:
        cost = rcv

    return max(cost, 0.0)

def parse_tokens(ev):
    tu = ev.get("tokenUsage") or {}
    cw = int(tu.get("cacheWriteTokens") or 0)
    inp = int(tu.get("inputTokens") or 0)
    cr = int(tu.get("cacheReadTokens") or 0)
    out = int(tu.get("outputTokens") or 0)
    return inp, out, cw, cr

def cost_estimated_usd(inp, out, cw, cr):
    return ((inp+cw) / 1_000_000.0) * RATE_IN + (out / 1_000_000.0) * RATE_OUT + (cr / 1_000_000.0) * RATE_CR

def day_key_from_ts(ts):
    try:
        ms = int(ts)
        dt = datetime.fromtimestamp(ms/1000.0, tz=timezone.utc)
        return dt.strftime("%Y-%m-%d")
    except Exception:
        return "—"

events=[]
with open(path, "r", encoding="utf-8") as f:
    for line in f:
        line=line.strip()
        if not line:
            continue
        try:
            events.append(json.loads(line))
        except Exception:
            continue

rows = len(events)

# Always emit facts, even if rows=0 (deterministic “empty” output)
distinct_users=set()
distinct_models=set()
distinct_kinds=set()

cost_total = 0.0
cost_included_rows = 0
cost_billed_rows = 0

tok_in = tok_out = tok_cw = tok_cr = tok_total = 0
max_mode_yes = 0

event_costs = []
most_expensive = None
most_tokens = None

by_day = defaultdict(lambda: {"cost":0.0,"rows":0,"tokens":0,"users":set(),"models":set(),"max_yes":0})
by_model = defaultdict(lambda: {"cost":0.0,"rows":0,"tokens":0,"max_yes":0})
by_user = defaultdict(lambda: {"cost":0.0,"rows":0,"tokens":0})
by_kind = defaultdict(lambda: {"cost":0.0,"rows":0,"tokens":0})
by_max  = defaultdict(lambda: {"cost":0.0,"rows":0,"tokens":0})

def add_agg(agg, key, cost, tokens, user=None, model=None, max_yes=False):
    a = agg[key]
    a["cost"] += cost
    a["rows"] += 1
    a["tokens"] += tokens
    if "users" in a and user is not None:
        a["users"].add(user)
    if "models" in a and model is not None:
        a["models"].add(model)
    if "max_yes" in a and max_yes:
        a["max_yes"] += 1

cost_est_total = 0.0

for ev in events:
    user = ev.get("userEmail") or ev.get("email") or ev.get("owningUser") or ""
    model = ev.get("model") or ""
    kind = ev.get("kind") or ""
    max_mode = bool(ev.get("maxMode") or False)

    if user: distinct_users.add(user)
    if model: distinct_models.add(model)
    if kind: distinct_kinds.add(kind)

    inp, out, cw, cr = parse_tokens(ev)
    tokens = inp + out + cw + cr

    tok_in += inp
    tok_out += out
    tok_cw += cw
    tok_cr += cr
    tok_total += tokens

    cost = parse_cost(ev)
    event_costs.append(cost)

    if cost > 0:
        cost_billed_rows += 1
    else:
        cost_included_rows += 1

    if max_mode:
        max_mode_yes += 1

    cost_total += cost
    cost_est_total += cost_estimated_usd(inp,out,cw,cr)

    ts = get_ts(ev)
    day = day_key_from_ts(ts) if ts is not None else "—"

    add_agg(by_day, day, cost, tokens, user=user, model=model, max_yes=max_mode)
    add_agg(by_model, model or "—", cost, tokens, max_yes=max_mode)
    add_agg(by_user, user or "—", cost, tokens)
    add_agg(by_kind, kind or "—", cost, tokens)
    add_agg(by_max, "Yes" if max_mode else "No", cost, tokens)

    if most_expensive is None or cost > most_expensive[0] or (cost == most_expensive[0] and tokens > most_expensive[2]):
        most_expensive = (cost, ev, tokens)
    if most_tokens is None or tokens > most_tokens[0] or (tokens == most_tokens[0] and cost > most_tokens[2]):
        most_tokens = (tokens, ev, cost)

unique_users = len(distinct_users)
unique_models = len(distinct_models)
unique_days = len(by_day)

avg_cost_per_event = (cost_total / rows) if rows else 0.0
median_cost = safe_quantile(event_costs, 0.50)
p90_cost = safe_quantile(event_costs, 0.90)
p95_cost = safe_quantile(event_costs, 0.95)
p99_cost = safe_quantile(event_costs, 0.99)

peak_cost_day = "—"
peak_cost_val = 0.0
peak_tokens_day = "—"
peak_tokens_val = 0
for d, v in by_day.items():
    if v["cost"] > peak_cost_val or (v["cost"] == peak_cost_val and d < peak_cost_day):
        peak_cost_day, peak_cost_val = d, v["cost"]
    if v["tokens"] > peak_tokens_val or (v["tokens"] == peak_tokens_val and d < peak_tokens_day):
        peak_tokens_day, peak_tokens_val = d, v["tokens"]

def top_key_by_cost(m):
    if not m:
        return ("—", 0.0)
    items = list(m.items())
    items.sort(key=lambda kv: (-kv[1]["cost"], str(kv[0])))
    k, v = items[0]
    return (k, float(v.get("cost", 0.0)))

top_model, top_model_cost = top_key_by_cost(by_model)
top_user, top_user_cost = top_key_by_cost(by_user)

cache_read_share = pct(tok_cr, tok_total)
cache_write_share = pct(tok_cw, tok_total)
input_share = pct(tok_in, tok_total)
output_share = pct(tok_out, tok_total)

max_mode_share = pct(max_mode_yes, rows)

cost_per_1m_tokens = (cost_total / tok_total) * 1_000_000.0 if tok_total else 0.0
est_cost_per_1m_tokens = (cost_est_total / tok_total) * 1_000_000.0 if tok_total else 0.0

# Top 10 events by cost (deterministic tie-break: tokens desc, ts asc)
top_events = []
for ev in events:
    c = parse_cost(ev)
    inp, out, cw, cr = parse_tokens(ev)
    tokens = inp + out + cw + cr
    ts = get_ts(ev)
    top_events.append((c, tokens, ts, ev))
top_events.sort(key=lambda x: (-x[0], -x[1], x[2] if x[2] is not None else 0))
top_events = top_events[:10]

print("# cursor_usage_facts (derived; key\\tvalue)")
print(f"cursor_usage_events_rows\\t{rows}")
print(f"cursor_usage_distinct_users\\t{unique_users}")
print(f"cursor_usage_distinct_models\\t{unique_models}")
print(f"cursor_usage_distinct_days\\t{unique_days}")

print(f"cursor_usage_total_cost_usd\\t{fmt(cost_total,6)}")
print(f"cursor_usage_total_cost_estimated_usd\\t{fmt(cost_est_total,6)}")
print(f"cursor_usage_total_tokens\\t{tok_total}")
print(f"cursor_usage_tokens_input\\t{tok_in}")
print(f"cursor_usage_tokens_output\\t{tok_out}")
print(f"cursor_usage_tokens_cache_write\\t{tok_cw}")
print(f"cursor_usage_tokens_cache_read\\t{tok_cr}")

print(f"cursor_usage_share_input_pct\\t{fmt(input_share,4)}")
print(f"cursor_usage_share_output_pct\\t{fmt(output_share,4)}")
print(f"cursor_usage_share_cache_write_pct\\t{fmt(cache_write_share,4)}")
print(f"cursor_usage_share_cache_read_pct\\t{fmt(cache_read_share,4)}")

print(f"cursor_usage_billed_rows\\t{cost_billed_rows}")
print(f"cursor_usage_included_rows\\t{cost_included_rows}")
print(f"cursor_usage_max_mode_rows\\t{max_mode_yes}")
print(f"cursor_usage_max_mode_share_pct\\t{fmt(max_mode_share,4)}")

print(f"cursor_usage_avg_cost_per_event_usd\\t{fmt(avg_cost_per_event,6)}")
print(f"cursor_usage_median_cost_per_event_usd\\t{fmt(median_cost,6)}")
print(f"cursor_usage_p90_cost_per_event_usd\\t{fmt(p90_cost,6)}")
print(f"cursor_usage_p95_cost_per_event_usd\\t{fmt(p95_cost,6)}")
print(f"cursor_usage_p99_cost_per_event_usd\\t{fmt(p99_cost,6)}")

print(f"cursor_usage_cost_per_1m_tokens_usd\\t{fmt(cost_per_1m_tokens,6)}")
print(f"cursor_usage_est_cost_per_1m_tokens_usd\\t{fmt(est_cost_per_1m_tokens,6)}")

print(f"cursor_usage_peak_cost_day\\t{peak_cost_day}")
print(f"cursor_usage_peak_cost_day_usd\\t{fmt(peak_cost_val,6)}")
print(f"cursor_usage_peak_tokens_day\\t{peak_tokens_day}")
print(f"cursor_usage_peak_tokens_day_tokens\\t{peak_tokens_val}")

print(f"cursor_usage_top_model\\t{top_model}")
print(f"cursor_usage_top_model_cost_usd\\t{fmt(top_model_cost,6)}")
print(f"cursor_usage_top_model_cost_share_pct\\t{fmt(pct(top_model_cost,cost_total),4)}")

print(f"cursor_usage_top_user\\t{top_user}")
print(f"cursor_usage_top_user_cost_usd\\t{fmt(top_user_cost,6)}")
print(f"cursor_usage_top_user_cost_share_pct\\t{fmt(pct(top_user_cost,cost_total),4)}")

if most_expensive:
    c, ev, tokens = most_expensive
    print(f"cursor_usage_most_expensive_event_cost_usd\\t{fmt(c,6)}")
    print(f"cursor_usage_most_expensive_event_tokens\\t{tokens}")
    print(f"cursor_usage_most_expensive_event_model\\t{ev.get('model','')}")
    print(f"cursor_usage_most_expensive_event_user\\t{ev.get('userEmail') or ev.get('email') or ''}")
    print(f"cursor_usage_most_expensive_event_ts_utc\\t{iso_utc_from_ms(get_ts(ev) or 0)}")

if most_tokens:
    tokens, ev, c = most_tokens
    print(f"cursor_usage_most_tokens_event_tokens\\t{tokens}")
    print(f"cursor_usage_most_tokens_event_cost_usd\\t{fmt(c,6)}")
    print(f"cursor_usage_most_tokens_event_model\\t{ev.get('model','')}")
    print(f"cursor_usage_most_tokens_event_user\\t{ev.get('userEmail') or ev.get('email') or ''}")
    print(f"cursor_usage_most_tokens_event_ts_utc\\t{iso_utc_from_ms(get_ts(ev) or 0)}")

def emit_tsv(title, header, items, limit=None, sort_by_cost=True):
    print()
    print(title)
    print(header)
    rows=[]
    for k, v in items.items():
        users = len(v["users"]) if "users" in v else 0
        models = len(v["models"]) if "models" in v else 0
        max_yes = v.get("max_yes", 0)
        rows.append((k, v["cost"], v["tokens"], v["rows"], users, models, max_yes))
    if sort_by_cost:
        rows.sort(key=lambda r: (-r[1], str(r[0])))
    else:
        rows.sort(key=lambda r: str(r[0]))
    if limit is not None:
        rows = rows[:limit]
    for r in rows:
        print(f"{r[0]}\t{fmt(r[1],6)}\t{int(r[2])}\t{int(r[3])}\t{int(r[4])}\t{int(r[5])}\t{int(r[6])}")

emit_tsv(
    "# cursor-usage by day (tsv): day\tcost_usd\ttokens\trows\tdistinct_users\tdistinct_models\tmax_mode_rows",
    "day\tcost_usd\ttokens\trows\tdistinct_users\tdistinct_models\tmax_mode_rows",
    by_day,
    limit=None,
    sort_by_cost=False
)

emit_tsv(
    "# cursor-usage by model (tsv): model\tcost_usd\ttokens\trows\tdistinct_users\tdistinct_models\tmax_mode_rows",
    "model\tcost_usd\ttokens\trows\tdistinct_users\tdistinct_models\tmax_mode_rows",
    by_model,
    limit=50,
    sort_by_cost=True
)

emit_tsv(
    "# cursor-usage by user (tsv): user\tcost_usd\ttokens\trows\tdistinct_users\tdistinct_models\tmax_mode_rows",
    "user\tcost_usd\ttokens\trows\tdistinct_users\tdistinct_models\tmax_mode_rows",
    by_user,
    limit=50,
    sort_by_cost=True
)

emit_tsv(
    "# cursor-usage by kind (tsv): kind\tcost_usd\ttokens\trows\tdistinct_users\tdistinct_models\tmax_mode_rows",
    "kind\tcost_usd\ttokens\trows\tdistinct_users\tdistinct_models\tmax_mode_rows",
    by_kind,
    limit=50,
    sort_by_cost=True
)

emit_tsv(
    "# cursor-usage by max-mode (tsv): max_mode\tcost_usd\ttokens\trows\tdistinct_users\tdistinct_models\tmax_mode_rows",
    "max_mode\tcost_usd\ttokens\trows\tdistinct_users\tdistinct_models\tmax_mode_rows",
    by_max,
    limit=None,
    sort_by_cost=True
)

print()
print("# cursor-usage top-events by cost (tsv): rank\tcost_usd\ttokens\tts_utc\tuser\tmodel\tkind\tmax_mode")
print("rank\tcost_usd\ttokens\tts_utc\tuser\tmodel\tkind\tmax_mode")
for i, (c, tokens, ts, ev) in enumerate(top_events, start=1):
    user = ev.get("userEmail") or ev.get("email") or ev.get("owningUser") or ""
    model = ev.get("model","")
    kind = ev.get("kind","")
    maxm = "Yes" if (ev.get("maxMode") or False) else "No"
    print(f"{i}\t{fmt(c,6)}\t{int(tokens)}\t{iso_utc_from_ms(ts or 0)}\t{user}\t{model}\t{kind}\t{maxm}")
PY
)" || die "cursor usage analysis failed"

printf "%s\n" "$usage_analysis"
echo

cursor_total_usd_usage="$(
  printf "%s\n" "$usage_analysis" | awk -F'\t' '$1=="cursor_usage_total_cost_usd"{print $2; exit}'
)"
if [ -z "$cursor_total_usd_usage" ]; then cursor_total_usd_usage="0"; fi

echo "# cursor cost source used for overall totals"
echo "cursor_total_usd_source	filtered-usage-events"
echo "cursor_total_usd	${cursor_total_usd_usage}"
echo

# ---------------------------------------------------------------------------
# Human labor totals (project-level)
# ---------------------------------------------------------------------------

human_per_commit_total_usd="$(
  awk -v a="$HUMAN_LABOR_IMPL_PER_COMMIT_USD" -v b="$HUMAN_LABOR_REVIEW_PER_COMMIT_USD" -v c="$HUMAN_LABOR_UPKEEP_PER_COMMIT_USD" \
    'BEGIN{ printf "%.2f", (a+0)+(b+0)+(c+0) }'
)"
module_count="$(
  if [ -s "$tmp_modules" ]; then wc -l < "$tmp_modules" | tr -d " "; else echo 0; fi
)"
human_module_base_total_usd="$(
  awk -v base="$HUMAN_LABOR_MODULE_BASE_USD" -v n="$module_count" \
    'BEGIN{ printf "%.2f", (base+0)*(n+0) }'
)"
human_commit_cost_total_usd="$(
  awk -v pc="$human_per_commit_total_usd" -v c="$total_commits_sum" \
    'BEGIN{ printf "%.2f", (pc+0)*(c+0) }'
)"
human_project_base_total_usd="$(awk -v x="$HUMAN_LABOR_PROJECT_BASE_USD" 'BEGIN{ printf "%.2f", (x+0) }')"
human_total_usd="$(
  awk -v a="$human_project_base_total_usd" -v b="$human_module_base_total_usd" -v c="$human_commit_cost_total_usd" \
    'BEGIN{ printf "%.2f", (a+0)+(b+0)+(c+0) }'
)"

echo "# human-labor assumptions (usd)"
echo "human_labor_project_base_usd	${human_project_base_total_usd}"
echo "human_labor_module_base_usd	$(awk -v x="$HUMAN_LABOR_MODULE_BASE_USD" 'BEGIN{ printf "%.2f", (x+0) }')"
echo "human_labor_impl_per_commit_usd	$(awk -v x="$HUMAN_LABOR_IMPL_PER_COMMIT_USD" 'BEGIN{ printf "%.2f", (x+0) }')"
echo "human_labor_review_per_commit_usd	$(awk -v x="$HUMAN_LABOR_REVIEW_PER_COMMIT_USD" 'BEGIN{ printf "%.2f", (x+0) }')"
echo "human_labor_upkeep_per_commit_usd	$(awk -v x="$HUMAN_LABOR_UPKEEP_PER_COMMIT_USD" 'BEGIN{ printf "%.2f", (x+0) }')"
echo "human_labor_per_commit_total_usd	${human_per_commit_total_usd}"
echo

echo "# human-labor totals (derived)"
echo "human_labor_module_count	${module_count}"
echo "human_labor_module_base_total_usd	${human_module_base_total_usd}"
echo "human_labor_commit_cost_total_usd	${human_commit_cost_total_usd}"
echo "human_labor_project_base_total_usd	${human_project_base_total_usd}"
echo "human_labor_total_usd	${human_total_usd}"
echo

# ---------------------------------------------------------------------------
# Overall totals
# ---------------------------------------------------------------------------

overall_total_cost_usd="$(
  awk -v a="$cursor_total_usd_usage" -v b="$CHATGPT_PLUS_USD" -v c="$EXTRA_COSTS_USD" \
    'BEGIN{ printf "%.2f", (a+0) + (b+0) + (c+0) }'
)"
echo "overall_total_cost_usd	${overall_total_cost_usd}"

overall_total_cost_including_human_usd="$(
  awk -v x="$overall_total_cost_usd" -v h="$human_total_usd" \
    'BEGIN{ printf "%.2f", (x+0) + (h+0) }'
)"
echo "overall_total_cost_including_human_usd	${overall_total_cost_including_human_usd}"

