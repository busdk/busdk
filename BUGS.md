# BUGS.md

Track defects/blockers that affect this repo's replay/parity workflows.
Feature work belongs in `FEATURE_REQUESTS.md`.

**Last reviewed:** 2026-02-22 (full revalidation across bus-bank, bus-invoices, bus-reconcile).

---

## Active issues
- None.

---

## Recently resolved (retested 2026-02-22)

- 2026-02-22: `bus reconcile propose` period ambiguity in replay workspaces (`YYYY` vs `YYYY-12`) is resolved.
  - Deterministic behavior now prefers month period rows when the same journal entry appears in both `YYYY` and `YYYY-MM` for the same year scope.
  - Verification:
    1. `GOCACHE=$(pwd)/.cache/go-build go -C bus-reconcile test ./...` (pass)
    2. `bash bus-reconcile/tests/e2e.sh` (pass; includes period-ambiguity regression scenario)

- 2026-02-22: `bus invoices add` unknown-flag acceptance and `--legacy-replay` handling issue is resolved.
  - Unknown flags now fail with usage error and do not mutate datasets.
  - `--legacy-replay` is honored deterministically for due-date legacy replay paths (both before and after `add` subcommand).
  - Verification:
    1. `GOCACHE=$(pwd)/.cache/go-build go -C bus-invoices test ./...` (pass)
    2. `bash bus-invoices/tests/e2e.sh` (pass; includes unknown-flag and legacy-replay regressions)

- 2026-02-22: `bus bank coverage` journal-link detection from `source_id=bank_row:<id>` is resolved.
  - Coverage now links deterministic `bank_row:<id>` and `bank_row:<id>:...` journal source IDs to the bank row.
  - Verification:
    1. `GOCACHE=$(pwd)/.cache/go-build go -C bus-bank test ./...` (pass)
    2. `bash bus-bank/tests/e2e.sh` (pass; includes `bank_row:b2:journal:1` regression coverage)

- 2026-02-22: `bus invoices list` legacy `total_net` mismatch hard-failure is resolved for read-only listing.
  - `list` now returns rows with deterministic warnings for legacy `total_net` mismatches while strict validation remains enforced in `validate` and mutating commands.
  - Verification:
    1. `GOCACHE=$(pwd)/.cache/go-build go -C bus-invoices test ./...` (pass)
    2. `bash bus-invoices/tests/e2e.sh` (pass; includes list-warning + strict validate regression coverage)

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
