# BUGS.md

Track defects/blockers that affect this repo's replay/parity workflows.
Feature work belongs in `FEATURE_REQUESTS.md`.

**Last reviewed:** 2026-03-30.

## Active defects

- `bus-reports` comparative fallback logic for annual statements is semantically wrong for the normal Bus workspace model. A Bus workspace usually covers one fiscal year, so same-workspace prior-year journal rows rarely exist. Balance-sheet comparatives may in some cases derive from first-day opening balances, but profit-and-loss comparatives must not be synthesized from those opening rows because opening balances do not contain prior-year income-statement detail. The current current-workspace/opening-balance fallback therefore produces a wrong product model for tuloslaskelma comparatives and must be corrected so P&L comparatives require explicit prior-year source data instead of inferring them from opening entries.
