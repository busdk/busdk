# BUGS.md

Track defects/blockers that affect this repo's replay/parity workflows.
Feature work belongs in `FEATURE_REQUESTS.md`.

**Last reviewed:** 2026-04-02.

## Active defects

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

- `bus reports balance-sheet --layout-id fi-kpa-tase-full-accounts` renders `3xxx..9xxx` profit-and-loss accounts as ordinary balance-sheet account rows under `Tilikauden voitto/tappio`, even though the line itself is only the balance-sheet presentation of net current-year result.
  - Repro:
    - run `bus -C exports/sendanor/2023/data reports balance-sheet --as-of 2023-12-31 --layout-id fi-kpa-tase-full-accounts --format text`.
    - compare with `reports statement-explain --report balance-sheet --as-of 2023-12-31 --account 3000 --layout-id fi-kpa-tase-full`.
  - Current behavior:
    - the visible TASE account breakdown under `Tilikauden voitto/tappio` contains raw `3xxx..9xxx` income/expense accounts as if they were ordinary balance-sheet accounts.
  - Expected:
    - the current-year result line may be derived from profit-and-loss accounts, but `fi-kpa-tase-full-accounts` must not present those P&L inputs as normal TASE account rows.

- `bus reports profit-and-loss` `fi-kpa-tuloslaskelma-full` and `fi-kpa-tuloslaskelma-full-accounts` do not render visible deeper descendant rows from canonical `account-groups.csv` even though `statement-explain` resolves accounts into those deeper groups.
  - Repro:
    - run the HG 2025/2023 repros from `BUGS.Update.md` against `statement-explain`, `fi-kpa-tuloslaskelma-full`, and `fi-kpa-tuloslaskelma-full-accounts`.
  - Current behavior:
    - visible output collapses deeper descendants such as `Eläkekulut` and `Muut henkilösivukulut` back into ancestor subtotal rows.
  - Expected:
    - Finnish `*-full` profit-and-loss layouts should visibly inject documented deeper descendants from canonical `account-groups.csv`, with child rows before subtotals.

- `bus reports profit-and-loss` prints expense-side child rows in grouped/full layouts, including `*-accounts`, with positive visible amounts even though statutory statement output is documented to show expense amounts as negative.
  - Repro:
    - run the HG 2022/2025/2023 repros from `BUGS.Update.md` against `fi-kpa-tuloslaskelma-full` and `fi-kpa-tuloslaskelma-full-accounts`.
  - Current behavior:
    - child rows under expense-side sections can render as positive values while the parent expense row renders negative.
  - Expected:
    - expense-side child rows should follow the same negative statutory presentation as their parent expense rows.

- `bus reports profit-and-loss` `fi-kpa-tuloslaskelma-full-accounts` omits per-account drill-down rows for some visible statement lines even though `statement-explain` resolves accounts to those same visible lines.
  - Repro:
    - run the HG 2023 repros from `BUGS.Update.md` against `statement-explain` and `fi-kpa-tuloslaskelma-full-accounts`.
  - Current behavior:
    - visible rows such as `Henkilöstökulut yhteensä`, `Poistot ja arvonalentumiset`, `Rahoituskulut`, and `TULOVEROT` can show no account drill-down even when `statement-explain` resolves non-zero account contributions to them.
  - Expected:
    - every visible `*-accounts` statement line with non-zero account contributions should show deterministic per-account drill-down rows beneath that same visible line.
