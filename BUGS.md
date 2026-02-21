# BUGS.md

Track defects/blockers that affect this repo's replay/parity workflows.
Feature work belongs in `FEATURE_REQUESTS.md`.

**Last reviewed:** 2026-02-21 (retested after latest Bus updates).

---

## Active issues
- None currently.

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
