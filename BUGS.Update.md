# BUGS.md

Track defects/blockers that affect this repo's replay/parity workflows.
Feature work belongs in `FEATURE_REQUESTS.md`.

**Last reviewed:** 2026-03-10.

## Active defects

### `bus reports balance-sheet-reconciliation` can show `VASTATTAVAA` mismatch even when the balance sheet itself is balanced

- Status: active
- Module: `bus-reports`
- Impact: the review document can falsely accuse a valid year workspace of liability-side mismatch, which makes `tase-tasmaytys` unsuitable as audit evidence even when the actual balance sheet is correct.

Observed repo symptom:
- [tase-tasmaytys-2023-12-31.md](/Users/jhh/git/sendanor/sendanor-books-2023/exports/sendanor/2023/tmp/reports/tase-tasmaytys-2023-12-31.md#L4) reports:
  - `VASTATTAVAA: ledger vs TASE | expected 9 072,86 | actual 9 573,39 | difference 500,53 | mismatch`
- But the same workspace's primary balance-sheet output [balance-sheet-2023-12-31.csv](/Users/jhh/git/sendanor/sendanor-books-2023/exports/sendanor/2023/tmp/balance-sheet-2023-12-31.csv#L17) and [balance-sheet-2023-12-31.csv](/Users/jhh/git/sendanor/sendanor-books-2023/exports/sendanor/2023/tmp/balance-sheet-2023-12-31.csv#L30) shows:
  - `VASTAAVAA YHTEENSÄ,9072.86`
  - `VASTATTAVAA YHTEENSÄ,9072.86`
- The reconciliation report is therefore contradicting the balanced TASE generated from the same workspace.

Minimal repro:

```sh
tmpdir=$(mktemp -d /tmp/bus-bs-recon-current-result-XXXXXX)
cd "$tmpdir"

bus config init
bus accounts init
bus journal init

bus accounts add --code 1910 --name Bank --type asset
bus accounts add --code 2200 --name Equity --type equity
bus accounts add --code 3000 --name Sales --type income

bus journal add --date 2024-01-31 --desc sale --debit 1910=100.00 --credit 3000=100.00
bus reports balance-sheet --as-of 2024-01-31 --format csv
bus reports balance-sheet-reconciliation --as-of 2024-01-31 --format markdown
```

Current result:
- `balance-sheet --format csv` exits `0` and shows a balanced statement:
  - `VASTAAVAA YHTEENSÄ,100.00`
  - `VASTATTAVAA YHTEENSÄ,100.00`
- `balance-sheet-reconciliation --format markdown` exits `0` but still reports:
  - `| summary | VASTATTAVAA: ledger vs TASE | 100.00 | 0.00 | -100.00 | mismatch |`
- the same reconciliation document then lists the missing liability-side detail row:
  - `| liabilities_statement | ... | Tilikauden voitto/tappio | 3000 | Sales | 100.00 |`
- that means the report is internally contradictory: its own liability detail contains the current-year-result row, but its liability ledger summary ignores it.

Expected result:
- when the generated balance sheet is balanced, `balance-sheet-reconciliation` should not invent a liability-side mismatch.
- the `VASTATTAVAA: ledger vs TASE` summary should be derived from the same effective liability-side content that the report itself lists in `liabilities_statement`, including the current-year result line.

Why this is a bug:
- the failure reproduces in a clean standalone workspace with only native Bus commands.
- no repo-local replay transforms, attachments, VAT, or report stages are required.
- likely implementation area in current local runtime:
  - [computeBalanceSheetReconciliation](/Users/jhh/git/busdk/busdk/bus-reports/internal/report/review_documents.go#L153) builds the liability statement detail from full balance-sheet display rows, so it does see current-year-result rows that come from P&L accounts
  - but its liability ledger total is computed separately at [lines 184-201](/Users/jhh/git/busdk/busdk/bus-reports/internal/report/review_documents.go#L184) by summing only accounts whose type is literally `liability` or `equity`
  - the summary check at [lines 225-227](/Users/jhh/git/busdk/busdk/bus-reports/internal/report/review_documents.go#L225) therefore ignores the same current-year-result amount that the report includes in `liabilities_statement`
  - the clean 100 EUR sales repro proves this directly: the balance sheet is balanced, the reconciliation detail shows `Tilikauden voitto/tappio = 100.00`, but the summary still claims liability ledger total `0.00`

### `bus reports profit-and-loss --layout-id pma-full-accounts` does not inherit explicit `pma-full` mapping, so the account-breakdown report can contradict the normal tuloslaskelma

- Status: active
- Module: `bus-reports`
- Impact: internal tuloslaskelma account-breakdown PDFs/Markdown can classify accounts under different statement groups than the normal `pma-full` report for the same workspace.

Observed workspace symptom:
- In a workspace with explicit `pma-full` mapping for account `6100 YEL-maksut`, the normal `pma-full` report places the account under `Henkilöstökulut`.
- The matching `pma-full-accounts` report instead places the same account under `Poistot ja arvonalentumiset`.

Minimal repro:

```sh
tmpdir=$(mktemp -d /tmp/bus-reports-bug-XXXXXX)
cd "$tmpdir"

bus init
bus accounts init
bus journal init

bus accounts add --code 1910 --name Bank --type asset
bus accounts add --code 3000 --name Sales --type income
bus accounts add --code 6100 --name YEL --type expense

bus journal add --date 2024-01-31 --desc sales --debit 1910=100.00 --credit 3000=100.00 --source-id j:1
bus journal add --date 2024-01-31 --desc yel --debit 6100=20.00 --credit 1910=20.00 --source-id j:2

bus reports mapping add --layout-id pma-full --account 3000 --statement-target tuloslaskelma --line-id revenue --normal-side credit --rollup-rule default
bus reports mapping add --layout-id pma-full --account 6100 --statement-target tuloslaskelma --line-id pl_personnel_expenses --normal-side debit --rollup-rule default

bus reports profit-and-loss --period 2024 --format markdown --layout-id pma-full
bus reports profit-and-loss --period 2024 --format markdown --layout-id pma-full-accounts
bus reports profit-and-loss --period 2024 --format markdown --layout-id pma-full-accounts --explain-mapping >/tmp/out.md 2>/tmp/map.txt
cat /tmp/map.txt
```

Current result:
- `pma-full` shows `Henkilöstökulut yhteensä = -20.00`
- `pma-full-accounts` shows `Henkilöstökulut yhteensä = 0.00`
- `pma-full-accounts` shows `Poistot ja arvonalentumiset = -20.00`
- `--explain-mapping` reports:
  - `3000,income,revenue,layout_default`
  - `6100,expense,pl_depreciation_and_impairment,layout_default`

Expected result:
- `pma-full-accounts` should preserve the same effective statement grouping as `pma-full` and only add account drill-down rows beneath those groups.
- `--explain-mapping` for `pma-full-accounts` should resolve `6100` to the same effective line as the base layout mapping (`pl_personnel_expenses`), rather than falling back to `layout_default`.

Why this is a bug:
- The `*-accounts` variant is supposed to be an account-breakdown form of the same statement, not a different classification engine.
- Current behavior makes the account-breakdown PDF unsuitable for audit/review because it can disagree with the normal tuloslaskelma in the same workspace.

### `bus reports evidence-pack` can fail with `duplicate primary key` on a month-closed workspace that contains both `journal-YYYY.csv` and `journal-YYYY-MM.csv`

- Status: active
- Module: `bus-reports`
- Impact: `evidence-pack` cannot currently be treated as a safe rerunnable year-end package command on normal closed workspaces that have month-closed journal slices.

Minimal repro:

```sh
tmpdir=$(mktemp -d /tmp/bus-ep-monthclose-XXXXXX)
cd "$tmpdir"

bus config init
bus config set --base-currency=EUR --fiscal-year-start=2024-01-01 --fiscal-year-end=2024-12-31 --business-name TestCo --vat-registered=false

bus accounts init
bus journal init
bus period init

bus accounts add --code 1910 --name Bank --type asset
bus accounts add --code 2200 --name Equity --type equity
bus accounts add --code 2400 --name Liability --type liability
bus accounts add --code 3000 --name Sales --type income
bus accounts add --code 4000 --name Expense --type expense

bus period add --period 2024-01 --retained-earnings-account 2200
bus period add --period 2024-02 --retained-earnings-account 2200
bus period open --period 2024-01
bus period open --period 2024-02

bus journal add --date 2024-01-15 --desc jan-sale --debit 1910=100.00 --credit 3000=100.00 --source-id t:1
bus journal add --date 2024-02-15 --desc feb-expense --debit 4000=40.00 --credit 1910=40.00 --source-id t:2

bus period close --period 2024-01 --post-date 2024-01-31
bus period close --period 2024-02 --post-date 2024-02-29

bus reports evidence-pack --period 2024 --output-dir out
```

Current result:

```text
bus-reports: row 6 duplicate primary key
```

Expected result:
- `evidence-pack` should load a normal month-closed workspace without double-counting journal postings.
- The presence of `journal-2024.csv` plus `journal-2024-01.csv`, `journal-2024-02.csv`, ... should not make report generation fail.

Why this is a bug:
- Month-close is a normal legal/accounting state, not a malformed workspace.
- Current behavior strongly suggests `bus-reports` is loading the same postings twice from overlapping journal resources and then tripping its own key checks.

Repo verification update (2026-03-11):
- Current closed workspaces in `exports/sendanor/2024/data`, `exports/sendanor/2025/data`, and `exports/sendanor/2026/data` all reproduce the same class of failure after their report-mapping prep:
  - `exports/sendanor/2024/data`: `bus-reports: row 2277 duplicate primary key`
  - `exports/sendanor/2025/data`: `bus-reports: row 555 duplicate primary key`
  - `exports/sendanor/2026/data`: `bus-reports: row 110 duplicate primary key`
- In all three workspaces, `datapackage.json` includes both the year root journal resource (`journal-YYYY`) and the month slices (`journal-YYYY-01` .. `journal-YYYY-12`).

### `bus reports evidence-pack` still fails in the active 2023 replay workspace through the statutory `fi-kpa-tuloslaskelma-kululaji` reconciliation path

- Status: active
- Module: `bus-reports`
- Impact: the current native 2023 report step still does not complete end-to-end, so `make -C exports/sendanor/2023/data export` remains blocked in `2024-01-01-reports.bus`.

Current status:
- The older broad isolated-year repro that previously triggered `FR-REP-010` no longer reproduces on the current runtime; do not use that stale repro.
- The remaining active failure is narrower: it still occurs on the real 2023 replay workspace in the statutory reconciliation path that `evidence-pack` uses.

Repo repro:

```sh
make -C exports/sendanor/2023/data export
```

Current result:

```text
../2024-01-01-reports.bus:68: command failed (exit 1): reports evidence-pack --period 2023 --output-dir reports
bus-reports: income-result reconciliation failed (FR-REP-010): period result from profit-and-loss (18646.25) does not equal balance-sheet equity change for period 2023-01-01 to 2023-12-31 after excluding opening entries (equity at 2022-12-31: 0.00, at 2023-12-31 excluding opening: -134760.56, delta: -134760.56); layout-id=fi-kpa-tuloslaskelma-kululaji
```

Additional verification:
- In that same pre-close 2023 workspace:
  - `bus reports -o /tmp/pl-2023-pma-full.csv profit-and-loss --period 2023 --format csv --layout-id pma-full` succeeds.
  - `bus reports -o /tmp/pl-2023-fi-kpa.csv profit-and-loss --period 2023 --format csv --layout-id fi-kpa-tuloslaskelma-kululaji` fails with the same `FR-REP-010` error.
- This shows the blocker is not a general `evidence-pack` command failure and not a general 2023-data invalidity; it is the statutory `fi-kpa-tuloslaskelma-kululaji` reconciliation path that `evidence-pack` currently depends on in this workspace.

Expected result:
- `make -C exports/sendanor/2023/data export` should complete through the native `reports evidence-pack` step.
- The statutory `fi-kpa-tuloslaskelma-kululaji` path should reconcile against the 2023 workspace the same way the non-statutory `pma-full` path already does.

### `bus reports balance-sheet --layout-id fi-kpa-tase` can fail with `FR-REP-007` even when `mapping-template` says the account already has a valid `layout_default`

- Status: active
- Module: `bus-reports`
- Impact: statutory `fi-kpa-tase` generation can fail on normal workspaces unless the operator manually materializes explicit `report-account-mapping.csv` rows for accounts that Bus already claims to know how to place by default.

Minimal repro:

```sh
tmpdir=$(mktemp -d /tmp/bus-fi-kpa-tase-default-XXXXXX)
cd "$tmpdir"

cat > repro.bus <<'BUS'
config init
config set --base-currency=EUR --fiscal-year-start=2024-01-01 --fiscal-year-end=2024-12-31 --vat-registered=true --vat-reporting-period=monthly
config set --business-name "Example Tmi" --business-id 2092540-6 --business-form tmi

accounts init
journal init
period init

accounts add --code 1910 --name "Bank" --type asset
accounts add --code 2200 --name "Edellisten tilikausien voitto" --type equity
accounts add --code 2910 --name "Input VAT receivable" --type liability
accounts add --code 3000 --name "Sales" --type income

period add --period 2024
period open --period 2024

journal add --date 2024-01-01 --desc opening --debit 1910=1000.00 --credit 2200=1000.00 --source-id open:1
journal add --date 2024-06-30 --desc sale --debit 1910=124.00 --credit 3000=100.00 --credit 2910=24.00 --source-id j:1

reports mapping add --layout-id fi-kpa-tase --account 3000 --statement-target tase --line-id equity --normal-side credit --rollup-rule default
BUS

bus shell < repro.bus
bus reports mapping-template --layout-id fi-kpa-tase --statement-target tase
bus reports balance-sheet --as-of 2024-12-31 --layout-id fi-kpa-tase --format csv --explain-mapping
bus reports balance-sheet --as-of 2024-12-31 --layout-id fi-kpa-tase --format csv
```

Current result:
- `mapping-template` shows accounts like:
  - `1910 -> bs_current_assets (layout_default)`
  - `2200 -> equity (layout_default)`
  - `2910 -> bs_other_liab (layout_default)`
- `--explain-mapping` can also report those same effective default placements
- but the actual `balance-sheet` command still fails with:
  - `bus-reports: unmapped account for balance-sheet (FR-REP-007): account 2910 has postings but no row in report-account-mapping.csv ...`
  - or the same failure for another account such as `1910` / `2200`

Expected result:
- if `mapping-template` and `--explain-mapping` both resolve an account through `layout_default`, the actual `balance-sheet` report should accept that mapping and render successfully.
- operators should not need to copy default placements into explicit CSV rows just to make the command stop failing.

Why this is a bug:
- `mapping-template` and the real report execution disagree about whether a valid mapping exists.
- that makes statutory reporting brittle and forced local workspaces to materialize many explicit `fi-kpa-tase` rows only to restate Bus's own documented defaults.
