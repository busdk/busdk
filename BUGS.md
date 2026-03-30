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

- `bus reports profit-and-loss` `fi-kpa-tuloslaskelma-full` / `fi-kpa-tuloslaskelma-full-accounts` do not render visible deeper descendant rows from canonical `account-groups.csv` even though `statement-explain` resolves accounts into those descendants and module docs promise `*-full` expansion.
  - Expected:
    - canonical descendant rows from `account-groups.csv` are shown visibly in Finnish `*-full` profit-and-loss layouts, with child rows before subtotal rows.

- `bus reports profit-and-loss` prints expense-side child rows in grouped/full layouts, including `*-accounts`, with positive visible amounts even when the parent expense statement rows are shown negative.
  - Expected:
    - expense-side child rows follow the same negative statement-sign presentation as the parent expense rows.

- `bus reports profit-and-loss` `fi-kpa-tuloslaskelma-full-accounts` omits per-account drill-down rows for some visible statement lines even when `statement-explain` resolves accounts to those exact visible lines.
  - Expected:
    - every visible non-zero statement line in `*-accounts` variants shows deterministic per-account drill-down rows beneath that same visible line.
