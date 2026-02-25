# BUGS.md

Track defects/blockers that affect this repo's replay/parity workflows.
Feature work belongs in `FEATURE_REQUESTS.md`.

**Last reviewed:** 2026-02-24 (retested after latest Bus updates; no active reproducible defects).

---

## Active issues
- None currently reproducible (retested 2026-02-24 after latest local Bus re-check).

---

## Recently resolved (retested 2026-02-23)

- 2026-02-23: `bus invoices list` filtered-read hard-fail on non-target legacy due-date rows no longer reproduces.
  - Verification commands:
    1. `bus -C /tmp/repro-invoices-list-filter-crossvalidate-20260223-retest invoices list --type sales`
    2. `bus -C /tmp/repro-invoices-list-filter-crossvalidate-20260223-retest invoices --legacy-replay list --type sales`
    3. `bus -C data/2024 invoices list --type sales --from 2024-01-01 --to 2024-12-31`
    4. `bus -C data/2026 invoices list --type sales --from 2026-01-01 --to 2026-12-31`
  - Result: all commands return exit code `0`; list output is produced with warnings where applicable, no hard failure from non-target purchase due-date rows.

- 2026-02-23: `bus reconcile propose` period ambiguity (`YYYY` vs `YYYY-12`) no longer reproduces in replay workspaces.
  - Verification commands:
    1. `bus -C data/2024 reconcile propose --target-kind invoice_payment --exclude-exact-journal --exclude-already-matched --from-date 2024-01-01 --to-date 2024-12-31`
    2. `bus -C data/2025 reconcile propose --target-kind invoice_payment --exclude-exact-journal --exclude-already-matched --from-date 2025-01-01 --to-date 2025-12-31`
  - Result: both commands return proposal rows (exit code 0), no `ambiguous across periods` error.
- 2026-02-23: `bus invoices add` flag handling is now deterministic.
  - Verification commands:
    1. `bus -C /tmp/repro-invoices-flag-parse-20260223c invoices add --type sales --invoice-id t1 --invoice-date 2024-01-10 --customer CUST --definitely-unknown-flag`
    2. `bus -C /tmp/repro-invoices-flag-parse-20260223c invoices add --type sales --invoice-id t2 --invoice-date 2024-01-10 --due-date 2024-01-01 --customer CUST2 --legacy-replay`
  - Result: unknown flag is rejected with non-zero exit; `--legacy-replay` is accepted and logged as active behavior.
- 2026-02-23: `bus bank coverage` now detects journal linkage via `source_id=bank_row:<id>`.
  - Verification command:
    1. `bus --format tsv -C /tmp/repro-bank-coverage-link-20260223c bank coverage --year 2024`
  - Result: summary includes `journal_linked=1`, and row `b2` is reported as `coverage_state=journal_linked reason_code=journal_source_id`.
- 2026-02-23: `bus invoices list` no longer hard-fails on legacy `total_net` mismatch rows.
  - Verification commands:
    1. `bus validate -C /tmp/repro-invoices-legacy-total-20260223c`
    2. `bus --format tsv -C /tmp/repro-invoices-legacy-total-20260223c invoices list --type sales`
  - Result: `invoices list` returns row output with warning diagnostics (exit code 0), not hard failure.

- 2026-02-21: prior `bus vat report --source reconcile --basis cash` purchase-side concern was re-evaluated.
  - Standalone synthetic repro (fresh `/tmp` workspace) with one sales and one purchase invoice, matched bank rows, and `bus reconcile post` produced expected reconcile totals with non-zero input VAT.
  - Conclusion: no standalone tool defect reproduced; keep as workspace data/coverage investigation, not an active core bug.
- 2026-02-21: `bus status readiness` period-state gate issue no longer reproduces.
  - Standalone synthetic repro:
    1. Create fresh workspace in `/tmp`
    2. `bus init defaults`
    3. Initialize `accounts`, `journal`, `period`
    4. Add minimal balanced journal row in target year
    5. `bus period add/open/close/lock --period 2024-12`
    6. `bus status readiness --year 2024 --format json`
  - Result: `latest_period=2024-12`, `latest_state=locked`, `TECH_PERIOD_STATE_OK=pass`.
- 2026-02-21: `bus status readiness --compliance` no-op issue no longer reproduces.
  - Standalone synthetic repro in fresh `/tmp` workspace:
    1. Produce baseline output: `bus status readiness --year 2024 --format json`
    2. Produce compliance output: `bus status readiness --year 2024 --format json --compliance`
    3. Compare hashes / content.
  - Result: outputs differ and compliance gates are evaluated (no silent no-op).

- 2026-02-23: `bus status` now defaults to the active workspace year correctly.
  - Standalone synthetic verification:
    1. Create fresh workspace in `/tmp` and run `bus init defaults`.
    2. Add period records for two years and ensure one year is active/selected in workspace context.
    3. Run `bus status --format json`.
  - Result: reported default year follows active workspace year (no unintended fallback to another year).
- 2026-02-23: `bus bank statement extract` accepts UTF-8 BOM + quoted CSV in raw extraction mode.
  - Standalone synthetic verification:
    1. Create fresh workspace in `/tmp` and run `bus init defaults`.
    2. Create a small UTF-8 BOM-prefixed quoted CSV statement fixture.
    3. Run `bus bank statement extract --file <fixture.csv> --header-row 1 --map date=<...> --map amount=<...> --map balance=<...>`.
  - Result: command parses successfully; no `bare " in non-quoted-field` parser abort.
- 2026-02-23: `bus invoices list` applies `--type` and `--status` filters correctly.
  - Standalone synthetic verification:
    1. Create fresh workspace in `/tmp`, run `bus init defaults`, and `bus invoices init`.
    2. Add multiple sales/purchase invoices with mixed statuses.
    3. Run:
       - `bus --format tsv invoices list --type sales`
       - `bus --format tsv invoices list --status sent`
  - Result: output is filtered according to requested `--type` / `--status` selectors (no selector-ignore behavior).
