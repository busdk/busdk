# BUGS.md

Track defects/blockers that affect this repo's replay/parity workflows.
Feature work belongs in `FEATURE_REQUESTS.md`.

**Last reviewed:** 2026-03-30.

## Active defects

- `bus-reports` `general-ledger` PDF can leave a later page half-empty in long single-account sections and then continue the account on the next page from the wrong row offset, so some rows from the affected page are effectively omitted from the printed output even though the source ledger continues.
