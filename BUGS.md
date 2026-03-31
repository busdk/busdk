# BUGS.md

Track defects/blockers that affect this repo's replay/parity workflows.
Feature work belongs in `FEATURE_REQUESTS.md`.

**Last reviewed:** 2026-03-31.

## Active defects

- Shared human-facing PDF row-text emission in `bus reports bank-transactions`, `day-book`, and `general-ledger` can collapse adjacent wrapped-table columns together, so headers and row data lose visible/extracted separation (for example `SummaSelite` instead of distinct `Summa` and `Selite` columns).
  - Repro:
    - generate current PDF exports for `bank-transactions`, `day-book`, or `general-ledger` on a workspace with the default wrapped review columns.
    - inspect the visible PDF text or extracted text/annotation behavior around `Amount`/`Description` (`Summa`/`Selite`) and nearby row data.
  - Current behavior:
    - adjacent wrapped-table columns can render or extract as one merged text run, such as `SummaSelite`, with corresponding row values also collapsing together.
    - the same regression shape appears across at least `bank-transactions`, `day-book`, and `general-ledger`, which points to the shared wrapped-table PDF row-text path rather than one report-specific renderer.
  - Expected:
    - wrapped review-table PDFs must preserve deterministic visible and extracted column separation for headers and row data without reverting to cell/MultiCell-based rendering.

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
