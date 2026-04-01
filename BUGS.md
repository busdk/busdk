# BUGS.md

Track defects/blockers that affect this repo's replay/parity workflows.
Feature work belongs in `FEATURE_REQUESTS.md`.

**Last reviewed:** 2026-04-01.

## Active defects

- `bus reports day-book --format pdf` and the shared accountant-facing PDF table path can still let adjacent visible cell selection regions bleed together in Apple Preview on some pages even though the logical columns are separate; for example `Selite` and `Tx` can look merged on one page while behaving correctly on the next page of the same report.
  - Repro:
    - generate a real multi-page `day-book.pdf` or `general-ledger.pdf` where one page lets Preview selection around `Selite` spill over the `Tx` column boundary even though another nearby page with similar content behaves correctly.
  - Current behavior:
    - the shared single-layer cell renderer keeps logical cells separate in code, but some page-local layouts still leave adjacent text regions close enough that Preview draws a selection rectangle across the column boundary.
  - Expected:
    - the shared accountant-facing PDF table renderer should keep all logical cells visually and semantically separate enough that Preview-like viewers do not merge neighboring cell selection regions page by page.

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
