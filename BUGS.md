# BUGS.md

Track defects/blockers that affect this repo's replay/parity workflows.
Feature work belongs in `FEATURE_REQUESTS.md`.

**Last reviewed:** 2026-04-05.

## Active defects

- `bus` `.bus` replay preflight still rejects documented `bus journal add` row-description syntax `ACCOUNT=AMOUNT=ROW_DESCRIPTION`.
  - Reproduced:
    - create a `.bus` file line such as:
      - `journal add --date 2024-10-31 --desc test --debit '1911=924.10=Asiakkaan maksusuoritus pankkiin' --credit '3001=924.10=Oma hostingpalvelu HG-asiakkaalle'`
    - run:
      - `bus --check <file.bus>`
  - Current behavior:
    - dispatcher preflight fails before `bus-journal` runs with:
      - `validation error: journal add invalid amount "924.10=Asiakkaan maksusuoritus pankkiin"`
  - Expected:
    - `.bus` replay and `--check` must accept the same documented `ACCOUNT=AMOUNT=ROW_DESCRIPTION` syntax that direct `bus journal add` already accepts, including ordinary quoted UTF-8 text with spaces.
  - Notes:
    - this is a dispatcher-side preflight/parser bug in `bus`, not a `bus-journal` direct CLI parsing bug
    - it blocks real replay/export flows from using the shipped row-level description feature
