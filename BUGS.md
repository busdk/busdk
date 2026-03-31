# BUGS.md

Track defects/blockers that affect this repo's replay/parity workflows.
Feature work belongs in `FEATURE_REQUESTS.md`.

**Last reviewed:** 2026-03-31.

## Active defects

- `bus reports balance-sheet --layout-id fi-kpa-tase-full-accounts` renders ordinary `3xxx..9xxx` profit-and-loss accounts as visible balance-sheet account rows under `Tilikauden voitto/tappio`, even though that line is only the balance-sheet presentation of net current-year result.
  - Repro:
    - `timeout 30 bus -C exports/sendanor/2023/data reports balance-sheet --as-of 2023-12-31 --layout-id fi-kpa-tase-full-accounts --format text`
    - `timeout 30 bus -C exports/sendanor/2023/data reports statement-explain --report balance-sheet --as-of 2023-12-31 --account 3000 --layout-id fi-kpa-tase-full --format csv`
  - Current behavior:
    - `tase-full-accounts` can print rows like `3000`, `3001`, `4100`, `9460`, and `9560` directly under `Tilikauden voitto/tappio`.
    - this comes from `synthetic_current_year_result`: explainability resolves P&L accounts to `bs_current_year_result`, and the `*-accounts` breakdown then emits those contributing accounts as if they were ordinary TASE account rows.
    - that makes revenue/expense accounts look like balance-sheet accounts inside a TASE account listing even though they are only the inputs of the derived net-result line.
  - Expected:
    - `Tilikauden voitto/tappio` may be computed from profit-and-loss accounts, but `fi-kpa-tase-full-accounts` must not render those `3xxx..9xxx` accounts as ordinary balance-sheet account rows.
    - acceptable outcomes are either:
      - show only the aggregate `Tilikauden voitto/tappio` line with no per-account drill-down, or
      - show a clearly separate reconciliation/explanation block instead of TASE account rows.

- `bus accounts report --format pdf` still misses requested tililuettelo features and layout safety in real output: account-group hierarchy rows are not visible as expected, requested balance-history columns are not present, and the trailing `Allekirjoitukset` section can overflow past the page bottom instead of moving to a fresh page.
  - Repro:
    - generate the current `tililuettelo.pdf` from a workspace that has canonical `account-groups.csv`, fiscal-year/period metadata, and `--as-of` report usage.
    - inspect whether group rows appear, whether requested-date/prior-period/opening balance columns appear, and whether the trailing signature section stays inside page bounds.
  - Current behavior:
    - the delivered PDF can still look like a flat account list without the expected account-group breakdown.
    - requested balance-history columns such as requested-date balance, prior period-end balances, and opening balance are missing from the visible report.
    - the trailing `Allekirjoitukset` block can continue past the page bottom instead of starting on a fresh page when needed.
  - Expected:
    - `tililuettelo.pdf` should visibly include canonical account-group hierarchy rows whenever `account-groups.csv` is present.
    - when the report is requested with `--as-of`, the PDF should show the same requested-date / prior-period-end / opening balance columns as the shared tililuettelo report model.
    - the trailing signature section must never overflow beyond the printable page area.

- `bus reports evidence-pack` can hang indefinitely on real Sendanor 2023/2024 workspaces because `day-book --format pdf` no longer completes in practical time after recent PDF-path changes.
  - Repro:
    - `timeout 20s bus -C exports/sendanor/2023/data reports evidence-pack --period 2023 --output-dir /tmp/ep2023-direct`
    - `timeout 20s bus -C exports/sendanor/2024/data reports evidence-pack --period 2024 --output-dir /tmp/ep2024-direct`
    - `timeout 20s bus -C exports/sendanor/2023/data -o /tmp/day2023.pdf reports day-book --period 2023 --format pdf`
    - `timeout 20s bus -C exports/sendanor/2024/data -o /tmp/day2024.pdf reports day-book --period 2024 --format pdf`
  - Current behavior:
    - 2023/2024 `evidence-pack` does not finish within 20 seconds and leaves partial output behind.
    - the run gets as far as `trial-balance.pdf`, `tase.pdf`, `tuloslaskelma.pdf`, `pankkitapahtumat.pdf`, and `tositeluettelo.pdf`, then stalls on a temp file like `.20231231-day-book.pdf.tmp-*`.
    - `day-book --format text` stays fast on the same workspaces, and `day-book --format pdf` still completes on a smaller comparison year such as Sendanor 2025.
    - this isolates the regression to the shared printable PDF path used by `day-book`, not to generic report loading or to the `evidence-pack` wrapper itself.
  - Expected:
    - `day-book --format pdf` should complete in practical time on real year workspaces such as Sendanor 2023/2024.
    - `evidence-pack` should therefore complete normally once it reaches the day-book stage.

- `bus reports profit-and-loss` `fi-kpa-tuloslaskelma-full` / `fi-kpa-tuloslaskelma-full-accounts` do not render visible deeper descendant rows from canonical `account-groups.csv` even though the module docs promise that `*-full` layouts expand those descendants.
  - Repro:
    - `make -C exports/hg/2025/data export`
    - `cd exports/hg/2025/data && bus reports statement-explain --report profit-and-loss --period 2025 | sed -n '1,40p'`
    - `cd exports/hg/2025/data && bus reports profit-and-loss --period 2025 --layout-id fi-kpa-tuloslaskelma-full --format text | sed -n '1,80p'`
    - `cd exports/hg/2023/data && bus reports profit-and-loss --period 2023 --layout-id fi-kpa-tuloslaskelma-full-accounts --format text | sed -n '18,70p'`
  - Current behavior:
    - canonical HG groups contain deeper descendants such as `Eläkekulut`, `Muut henkilösivukulut`, and more specific finance/tax rows.
    - `statement-explain` resolves accounts into those deeper groups, but the visible output collapses them back into ancestor rows like `Henkilöstökulut yhteensä`.
    - in HG 2023 `*-accounts`, the subtotal `Henkilöstökulut yhteensä` is printed before the child block, and rows like `Eläkekulut` / `Muut henkilösivukulut` never appear visibly.
  - Expected:
    - documented deeper descendants from canonical `account-groups.csv` should be injected into Finnish `*-full` profit-and-loss layouts, similarly to how the full TASE layout already expands visible descendants.
    - grouped row order should remain child rows first, subtotal last.

- `bus reports profit-and-loss` prints expense-side child rows in grouped/full layouts, including `*-accounts`, with positive visible amounts even though statutory statement output is documented to show expense amounts as negative.
  - Repro:
    - `make -C exports/hg/2022/data export`
    - `cd exports/hg/2022/data && bus reports profit-and-loss --period 2022 --layout-id fi-kpa-tuloslaskelma-full --format text | sed -n '1,80p'`
    - `cd exports/hg/2025/data && bus reports profit-and-loss --period 2025 --layout-id fi-kpa-tuloslaskelma-full --format text | sed -n '1,80p'`
    - `cd exports/hg/2023/data && bus reports profit-and-loss --period 2023 --layout-id fi-kpa-tuloslaskelma-full-accounts --format text | sed -n '18,70p'`
  - Current behavior:
    - parent expense/subtotal rows render negative statement amounts, but child rows often render positive values, for example `Suunnitelman mukaiset poistot|5 543,74` under `Poistot ja arvonalentumiset|-5 543,74`.
    - the same sign flip appears under personnel costs, finance costs, and income taxes.
  - Expected:
    - child rows under expense-side sections should follow the same negative statement-sign presentation as the parent expense rows.

- `bus reports profit-and-loss` `fi-kpa-tuloslaskelma-full-accounts` omits per-account drill-down rows for some visible statement lines even though `statement-explain` resolves accounts to those exact visible lines.
  - Repro:
    - `make -C exports/hg/2023/data export`
    - `cd exports/hg/2023/data && bus reports statement-explain --report profit-and-loss --period 2023 --layout-id fi-kpa-tuloslaskelma-full-accounts | rg '6130|6300|6870|9490|9940'`
    - `cd exports/hg/2023/data && bus reports profit-and-loss --period 2023 --layout-id fi-kpa-tuloslaskelma-full-accounts --format text | sed -n '18,70p'`
  - Current behavior:
    - `statement-explain` resolves accounts like `6130`, `6870`, `9490`, and `9940` to visible lines such as `Henkilöstökulut yhteensä`, `Poistot ja arvonalentumiset`, `Rahoituskulut`, and `TULOVEROT`.
    - the rendered `*-accounts` output still shows no account rows under those visible lines, only empty child/subtotal rows such as `Henkilösivukulut`, `Suunnitelman mukaiset poistot`, `Muille`, and `Tilikauden ja aikaisempien tilikausien verot`.
  - Expected:
    - in `*-accounts` variants, every visible statement line with non-zero account contributions should show deterministic per-account drill-down rows beneath that same visible line.
