# BUGS.md

Track defects/blockers that affect this repo's replay/parity workflows.
Feature work belongs in `FEATURE_REQUESTS.md`.

**Last reviewed:** 2026-04-05.

## Active defects

- `bus memo add` does not support the same row-description and command-local help surface that `bus journal add` supports.
  - Repro:
    - `bus memo add --date 2024-01-01 --desc "Opening balance correction" --debit '2200=3.90=Counter-entry for verified bank-opening corrections' --credit '1910=0.03=Correct OP Päätili / ...846 opening'`
    - `bus memo add --help`
    - `bus memo add -h`
  - Current behavior:
    - posting lines still parse only `ACCOUNT=AMOUNT`, so `ACCOUNT=AMOUNT=ROW_DESCRIPTION` fails with diagnostics such as `bus-memo: debit amount must be a decimal`
    - command-local help paths fail instead of showing the supported `add` flags
  - Expected:
    - `bus memo add` must accept both `ACCOUNT=AMOUNT` and `ACCOUNT=AMOUNT=ROW_DESCRIPTION`, preserving row descriptions in the delegated journal payload
    - `bus memo add --help` and `bus memo add -h` must print usable command-local help that documents row descriptions and related add flags
  - Repo impact:
    - blocks audit-friendly memorandum replay with row-level descriptions
    - forces replay authors to guess the `bus memo add` flag surface instead of discovering it from built-in help
