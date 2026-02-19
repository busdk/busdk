# BUGS.md

Track **defects and blockers** that affect this repo's replay or parity work: actual bugs in our software or in BusDK/tooling when they block us. **Nice-to-have features and enhancement requests** are in **[FEATURE_REQUESTS.md](FEATURE_REQUESTS.md)**.

**Last reviewed:** 2026-02-19.

---

## Active issues

None currently.

## Resolved issues

### 2026-02-19 — `bus vat --source reconcile --basis cash` failed on valid `matches.csv` rows with negative/reversal lines (resolved)

**Resolution (2026-02-19):**
- `bus-vat` reconcile allocation now supports signed weights, so invoice lines with negative quantities/reversal amounts are processed deterministically.
- Added unit coverage in `bus-vat/internal/vat/reconcile_test.go` and e2e coverage in `bus-vat/tests/e2e_bus_vat.sh`.

### 2026-02-19 — `bus vat --source reconcile --basis cash` hard-failed on over-allocation matches (resolved)

**Resolution (2026-02-19):**
- Reconcile cash mode now caps each match allocation to remaining invoice gross instead of hard-failing.
- Added unit/report coverage in `bus-vat/internal/app/run_test.go` and e2e coverage in `bus-vat/tests/e2e_bus_vat.sh`.

### 2026-02-19 — `bus vat --source reconcile --basis cash` hard-failed when `matches.csv` was absent (resolved)

**Resolution (2026-02-19):**
- Missing `matches.csv` is now treated as an empty match set, producing deterministic zero/empty report output.
- Added unit/report coverage in `bus-vat/internal/app/run_test.go` and e2e coverage in `bus-vat/tests/e2e_bus_vat.sh`.

### 2026-02-19 — `bus vat --source journal` hard-failed on mixed opening/non-tax rows without mapping or cash payment evidence (resolved)

**Resolution (2026-02-19):**
- Journal source now skips non-VAT rows (computed VAT `0`) when direction or cash payment evidence is missing, while still failing on VAT-bearing rows with missing required evidence.
- Added unit coverage in `bus-vat/internal/vat/journal_test.go` and e2e coverage in `bus-vat/tests/e2e_bus_vat.sh`.

### 2026-02-19 — `bus vat report` accepted unknown flags silently (resolved)

**Resolution (2026-02-19):**
- Added strict subcommand-argument parsing for `validate`, `report`, and `export`; unknown flags now return usage error (exit 2).
- Added unit coverage in `bus-vat/internal/app/run_test.go` and e2e coverage in `bus-vat/tests/e2e_bus_vat.sh`.

### 2026-02-19 — `bus vat report/export` invoice-source VAT scaling bug (resolved)

**Original issue:** VAT values were previously observed at 100x too small scale.

**Resolution verification (2026-02-19):** Re-ran isolated repro in fresh workspace:
- one sales line `100.00` at `24%`
- `bus vat report --period 2024-01 -f tsv` now returns `TOTAL ... output_vat=2400`
- `vat-returns-2024-01.csv` now has `TOTAL,...,output_vat_cents=2400,...`

**Conclusion:** The cent-scaling defect is fixed in current CLI used in this workspace.

### 2026-02-18 — `make export` duplicate account key on seeded workspaces (resolved)

**Resolution (2026-02-18):** `make export` now enforces clean-workspace replay by running `clean` first in both `data/2023/Makefile` and `data/2024/Makefile`.
