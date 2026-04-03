# FEATURE_REQUESTS.md

Enhancement requests for BusDK in this repo context.

Privacy rule for request write-ups:
- Keep examples/repro snippets sanitized (no real customer names/emails/IBANs/account numbers/invoice numbers/local paths).
- Prefer placeholders and aggregated outputs over raw customer-linked row dumps.

Last reviewed: 2026-04-03.

Goal note:
- Target workflow is Bus-only for bookkeeping/audit operations.
- Operators should not need shell text pipelines (`grep/sed/awk/column`) to answer accounting control questions.

Active requests:

- Add a first-class deterministic journal account-sorting surface.
  - Current behavior:
    - `bus journal` preserves explicit CLI posting-line order and has fixed command-specific review ordering, but there is no explicit first-class user surface for account-ordered journal presentation when operators want the same posting grouped or sorted by account deterministically.
  - Requested behavior:
    - add one explicit, deterministic journal account-sorting surface instead of forcing operators to pre-sort input manually or rely on downstream shell processing.
  - Why this matters:
    - replay, review, and audit work sometimes need the same journal content in a stable account-oriented order, and that ordering should be a Bus feature rather than an operator-side workaround.

- Hide redundant `Vienti` from printable ledger/day-book reports when `Tx` and `Rivi` are already shown.
  - Current behavior:
    - printable `day-book` and `general-ledger` can show `Tx`, `Rivi`, and `Vienti` together even though `Vienti` is redundant once transaction id plus row sequence are already visible.
  - Requested behavior:
    - omit `Vienti` by default whenever both `Tx` and `Rivi` are already present, or add one deterministic report option that removes the redundant column.
  - Why this matters:
    - printable accountant-facing reports should use the smallest identifier set that still preserves audit traceability.
