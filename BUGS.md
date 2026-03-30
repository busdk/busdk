# BUGS.md

Track defects/blockers that affect this repo's replay/parity workflows.
Feature work belongs in `FEATURE_REQUESTS.md`.

**Last reviewed:** 2026-03-30.

## Active defects

- `bus-reports` `general-ledger` PDF still has an active long same-account pagination defect: within one multi-page account section, a later page can end up visibly half-empty and the following page can continue from too far ahead, so some expected rows from the middle of the same account section are effectively missing from the printed output.
