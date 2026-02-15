#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

SNAPSHOT_TZ="Europe/Helsinki"
SNAPSHOT="$(TZ="$SNAPSHOT_TZ" date '+%Y-%m-%d %H:%M %Z')"

tmp_dates="$(mktemp)"
tmp_pairs="$(mktemp)"
trap 'rm -f "$tmp_dates" "$tmp_pairs"' EXIT

# Optional manual line-items (USD)
CHATGPT_PLUS_USD="${CHATGPT_PLUS_USD:-21.76}"
EXTRA_COSTS_USD="${EXTRA_COSTS_USD:-0}" # add any other costs here (USD), e.g. 12.34

echo "# BusDK metrics snapshot: $SNAPSHOT"
echo "# cwd: $(pwd)"
echo

# ---------------------------------------------------------------------------
# Per-module metrics
# ---------------------------------------------------------------------------

echo "# per-module (tsv): module	commits	active_days	avg_commits_per_active_day	first_date	last_date"

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

  printf "%s\t%s\t%s\t%s\t%s\t%s\n" "$name" "$commits" "$active_days" "$avg" "$first_date" "$last_date"

  if [ -n "$dates" ]; then
    printf "%s\n" "$dates" >> "'"$tmp_dates"'"
    printf "%s\n" "$dates" | awk -v m="$name" "{print \$0\"\t\"m}" >> "'"$tmp_pairs"'"
  fi
' | LC_ALL=C sort

echo

# ---------------------------------------------------------------------------
# Daily distributions + derived totals
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

# busiest day (commits)
busiest_day="—"
max_commits_on_busiest_day="0"
if [ -n "$commits_per_day_tsv" ]; then
  line="$(printf "%s\n" "$commits_per_day_tsv" | awk -F'\t' '($2>m){m=$2; d=$1} END{print d "\t" m}')"
  busiest_day="$(printf "%s" "$line" | awk '{print $1}')"
  max_commits_on_busiest_day="$(printf "%s" "$line" | awk '{print $2}')"
fi

# avg active modules/day
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
# Costs (overall)
#   - Cursor team spend (optional; requires CURSOR_ADMIN_API_KEY + jq)
#   - ChatGPT Plus (manual line item)
#   - Extra manual costs via EXTRA_COSTS_USD
# ---------------------------------------------------------------------------

cursor_spend_usd="0"
cursor_included_usd="0"
cursor_total_usd="0"

echo "# costs"
echo "chatgpt_plus_usd	${CHATGPT_PLUS_USD}"
echo "extra_costs_usd	${EXTRA_COSTS_USD}"

if [ -n "${CURSOR_ADMIN_API_KEY:-}" ]; then
  if ! command -v jq >/dev/null 2>&1; then
    echo "cursor_team_spend_usd	ERROR(jq_missing)"
    echo "cursor_team_included_usd	ERROR(jq_missing)"
    echo "cursor_team_total_usd	ERROR(jq_missing)"
  else
    # NOTE: This endpoint may be paginated for larger teams; your earlier response had totalPages=1.
    json="$(curl -sS -u "${CURSOR_ADMIN_API_KEY}:" -H "Content-Type: application/json" -d '{}' https://api.cursor.com/teams/spend)"

    cursor_spend_usd="$(printf "%s" "$json" | jq -r '([.teamMemberSpend[].spendCents] | add // 0) / 100')"
    cursor_included_usd="$(printf "%s" "$json" | jq -r '([.teamMemberSpend[].includedSpendCents] | add // 0) / 100')"
    cursor_total_usd="$(printf "%s" "$json" | jq -r '(([.teamMemberSpend[].spendCents] | add // 0) + ([.teamMemberSpend[].includedSpendCents] | add // 0)) / 100')"

    echo "cursor_team_spend_usd	${cursor_spend_usd}"
    echo "cursor_team_included_usd	${cursor_included_usd}"
    echo "cursor_team_total_usd	${cursor_total_usd}"
  fi
else
  echo "cursor_team_spend_usd	skipped(CURSOR_ADMIN_API_KEY_not_set)"
  echo "cursor_team_included_usd	skipped(CURSOR_ADMIN_API_KEY_not_set)"
  echo "cursor_team_total_usd	skipped(CURSOR_ADMIN_API_KEY_not_set)"
fi

overall_total_cost_usd="$(
  awk -v a="$cursor_total_usd" -v b="$CHATGPT_PLUS_USD" -v c="$EXTRA_COSTS_USD" \
    'BEGIN{ printf "%.2f", (a+0) + (b+0) + (c+0) }'
)"
echo "overall_total_cost_usd	${overall_total_cost_usd}"
