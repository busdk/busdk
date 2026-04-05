# BUGS.md

Track defects/blockers that affect this repo's replay/parity workflows.
Feature work belongs in `FEATURE_REQUESTS.md`.

**Last reviewed:** 2026-04-05.

## Active defects

- `bus reports profit-and-loss` still counts explicit `prior-year-correction` / `opening-adjustment` rows in period activity even though FR-REP-010 reconciliation excludes them. Current state: `bus-journal` stores and normalizes the source kinds correctly, and statutory reconciliation delta filtering already excludes them, but `computeProfitLoss(...)` still skips only opening and closing-result rows. Result: the visible tuloslaskelma can still include prior-year correction memorandum rows such as `prior_year_correction:...`, and `make -C exports/sendanor/2024 reports` can still fail with an FR-REP-010 mismatch because P&L period result and balance-sheet delta use different exclusion scopes.
