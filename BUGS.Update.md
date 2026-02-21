# BUGS.md

Track defects/blockers that affect this repo's replay/parity workflows.
Feature work belongs in `FEATURE_REQUESTS.md`.

**Last reviewed:** 2026-02-21 (retested after latest Bus updates).

---

## Active issues
- 2026-02-21: `bus reconcile propose` fails on replay workspaces with period ambiguity (`YYYY` vs `YYYY-12`)
  - Severity: high (blocks deterministic backlog reduction workflow after successful replay).
  - Repro (sanitized, standalone):
    1. `mkdir -p /tmp/repro-reconcile-period-amb && bus -C /tmp/repro-reconcile-period-amb init defaults`
    2. Initialize minimal datasets (`accounts`, `journal`, `bank`, `reconcile`, `period`) and add one bank row + one invoice-payment target setup.
    3. Ensure periods include both year and month-style entries for same year scope (for example `2024` and `2024-12`) as produced in replay-style workspaces.
    4. Run:  
       `bus -C /tmp/repro-reconcile-period-amb reconcile propose --target-kind invoice_payment --exclude-exact-journal --exclude-already-matched --from-date 2024-01-01 --to-date 2024-12-31`
  - Observed:
    - Command aborts with:  
      `journal entry ... is ambiguous across periods 2024 and 2024-12`
  - Expected:
    - Reconcile propose should resolve period deterministically (or accept explicit period-resolution option) and continue proposal generation.

- 2026-02-21: `bus invoices add` accepts unknown flags silently and advertised `--legacy-replay` path is not honored
  - Severity: high (operators can think legacy replay flags are applied when they are ignored).
  - Repro (sanitized, standalone):
    1. `mkdir -p /tmp/repro-invoices-flag-parse && bus -C /tmp/repro-invoices-flag-parse init defaults`
    2. `bus -C /tmp/repro-invoices-flag-parse invoices init`
    3. `bus -C /tmp/repro-invoices-flag-parse invoices add --type sales --invoice-id t1 --invoice-date 2024-01-10 --customer "CUST" --definitely-unknown-flag`
    4. `bus -C /tmp/repro-invoices-flag-parse -f tsv invoices list`
    5. `bus -C /tmp/repro-invoices-flag-parse invoices add --type sales --invoice-id t2 --invoice-date 2024-01-10 --due-date 2024-01-01 --customer "CUST2" --legacy-replay`
  - Observed:
    - Step 3 succeeds and invoice `t1` is created (unknown flag not rejected).
    - Step 5 still fails with message: `invoice ... has due_date before issue_date; rerun with --legacy-replay`.
  - Expected:
    - Unknown flags must fail deterministically.
    - `--legacy-replay` (if documented in diagnostics) must be parsed and change behavior deterministically, or diagnostics must point to the correct actual flag.

- 2026-02-21: `bus bank coverage` does not detect journal linkage from `source_id=bank_row:<id>`
  - Severity: high (coverage report gives false `none/unlinked`, blocks deterministic posting-coverage audit).
  - Repro (sanitized, standalone):
    1. `mkdir -p /tmp/repro-bank-coverage-link && bus -C /tmp/repro-bank-coverage-link init defaults`
    2. `bus -C /tmp/repro-bank-coverage-link accounts init`
    3. `bus -C /tmp/repro-bank-coverage-link accounts add --code 1910 --name "Bank" --type asset`
    4. `bus -C /tmp/repro-bank-coverage-link accounts add --code 3000 --name "Sales" --type income`
    5. `bus -C /tmp/repro-bank-coverage-link bank init`
    6. `bus -C /tmp/repro-bank-coverage-link journal init`
    7. `bus -C /tmp/repro-bank-coverage-link bank import-log add --import-id imp1 --source-path demo.csv --imported-at 2026-02-21T10:00:00Z`
    8. `bus -C /tmp/repro-bank-coverage-link bank add --bank-id b2 --import-id imp1 --booked-date 2024-01-16 --amount 50.00 --currency EUR --counterparty-name "CUSTOMER B" --source-id bank_row:b2`
    9. `bus -C /tmp/repro-bank-coverage-link journal add --date 2024-01-16 --desc "test link" --debit 1910=50.00 --credit 3000=50.00 --source-id bank_row:b2:journal:1`
    10. `bus --format tsv -C /tmp/repro-bank-coverage-link bank coverage --year 2024`
  - Observed:
    - Coverage output reports `none=1`, row `b2 ... coverage_state=none reason_code=unlinked`.
  - Expected:
    - Coverage should report `journal_linked=1` (or `both` if reconcile exists) for bank row `b2`.

- 2026-02-21: `bus invoices list` hard-fails on legacy datasets where `sales-invoices.total_net` stores gross amount
  - Severity: high (read-only invoice audit commands are blocked on replay datasets that `bus validate` accepts).
  - Repro (sanitized, standalone):
    1. `mkdir -p /tmp/repro-invoices-legacy-total && bus -C /tmp/repro-invoices-legacy-total init defaults`
    2. `bus -C /tmp/repro-invoices-legacy-total invoices init`
    3. `bus -C /tmp/repro-invoices-legacy-total data row add sales-invoices --set invoice_id=s1 --set number=1001 --set status=sent --set issue_date=2025-01-01 --set due_date=2025-01-15 --set party_name="CUSTOMER A" --set currency=EUR --set total_net=125.50`
    4. `bus -C /tmp/repro-invoices-legacy-total data row add sales-invoice-lines --set invoice_id=s1 --set line_no=1 --set description="Service" --set quantity=1.0 --set unit_price=100.00 --set vat_rate=0.255`
    5. `bus validate -C /tmp/repro-invoices-legacy-total`
    6. `bus --format tsv -C /tmp/repro-invoices-legacy-total invoices list --type sales`
  - Observed:
    - Step 5 returns success (`validate` passes).
    - Step 6 fails with:
      - `bus-invoices: row 1 in sales-invoices total_net 125.5 does not match sum of line amounts 100 for invoice_id s1`
  - Expected:
    - Either:
      - `validate` and `invoices list` enforce the same invariant consistently, or
      - `invoices list` offers a tolerant legacy mode that still returns rows with diagnostics instead of hard failure.

---

## Recently resolved (retested 2026-02-21)

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

- `bus status` now defaults to the active workspace year correctly.
- `bus bank statement extract` accepts UTF-8 BOM + quoted CSV in raw extraction mode.
- `bus invoices list` applies `--type` and `--status` filters correctly.
