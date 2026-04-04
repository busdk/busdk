# BUGS.md

Track defects/blockers that affect this repo's replay/parity workflows.
Feature work belongs in `FEATURE_REQUESTS.md`.

**Last reviewed:** 2026-04-05.

## Active defects

- `bus journal add` row descriptions still break when free-text `ACCOUNT=AMOUNT=DESCRIPTION` content contains continuation tokens that begin with `-`, even though ordinary multi-word row descriptions now otherwise work.
  - Repro verified locally on 2026-04-05:
    - `bus-journal add --date 2024-04-19 --desc test --debit 1911=25.00=Bank row --credit 9290=25.00=Muistutusmaksutulot viidestä Reminder Fee -rivistä`
  - Current behavior:
    - exits with `bus-journal: add accepts only long flags`
    - ordinary continued row descriptions without a leading-dash continuation token still work, so the remaining parser bug is specifically tied to continuation tokens that start with `-`
  - Expected:
    - once the third `=DESCRIPTION` component is being consumed as free text, a continuation token like `-rivistä` must remain ordinary description text instead of being reinterpreted as a flag
  - Repo impact:
    - replay authors cannot yet use natural free-text row descriptions when one of the continued words begins with `-`, which still blocks some real Sendanor replay labels
