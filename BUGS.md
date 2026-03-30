# BUGS.md

Track defects/blockers that affect this repo's replay/parity workflows.
Feature work belongs in `FEATURE_REQUESTS.md`.

**Last reviewed:** 2026-03-31.

## Active defects

- `bus reports evidence-pack` can hang indefinitely on large real workspaces because the shared `day-book --format pdf` path no longer completes in practical time after recent PDF text-emission changes.
  - Scope:
    - reported against real Sendanor 2023/2024 workspaces
    - isolates to the shared printable `day-book` PDF path rather than generic report loading
  - Expected:
    - `day-book --format pdf` and therefore `evidence-pack` complete in practical time on large yearly workspaces.
