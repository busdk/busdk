# FEATURE_REQUESTS.md

Enhancement requests for BusDK in this repo context.

Privacy rule for request write-ups:
- Keep examples/repro snippets sanitized (no real customer names/emails/IBANs/account numbers/invoice numbers/local paths).
- Prefer placeholders and aggregated outputs over raw customer-linked row dumps.

Last reviewed: 2026-04-02.

Goal note:
- Target workflow is Bus-only for bookkeeping/audit operations.
- Operators should not need shell text pipelines (`grep/sed/awk/column`) to answer accounting control questions.

Active requests:

- Hide redundant `Vienti` from printable ledger/day-book reports when `Tx` and `Rivi` are already shown.
  - Current behavior:
    - printable `day-book` and `general-ledger` can show `Tx`, `Rivi`, and `Vienti` together even though `Vienti` is redundant once transaction id plus row sequence are already visible.
  - Requested behavior:
    - omit `Vienti` by default whenever both `Tx` and `Rivi` are already present, or add one deterministic report option that removes the redundant column.
  - Why this matters:
    - printable accountant-facing reports should use the smallest identifier set that still preserves audit traceability.
