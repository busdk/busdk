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

- Hide redundant `Vienti` from printable ledger/day-book reports when `Tx` and `Rivi` are already shown.
  - Current behavior:
    - printable `day-book` and `general-ledger` can show `Tx`, `Rivi`, and `Vienti` together even though `Vienti` is redundant once transaction id plus row sequence are already visible.
  - Requested behavior:
    - omit `Vienti` by default whenever both `Tx` and `Rivi` are already present, or add one deterministic report option that removes the redundant column.
  - Why this matters:
    - printable accountant-facing reports should use the smallest identifier set that still preserves audit traceability.

- Allow `bus bank add` rows without mandatory `--counterparty-name` when statement evidence does not provide one.
  - Current behavior:
    - `bus bank add` rejects rows that omit `--counterparty-name`, even when the source statement only gives date, amount, IBAN/reference, and message text without a reliable human-readable counterparty.
  - Requested behavior:
    - allow `bus bank add` without `--counterparty-name`, or accept an explicitly empty value without error, so replay authors do not need to fabricate placeholder names.
  - Why this matters:
    - statement-backed replay should preserve source evidence faithfully instead of forcing invented counterparties into the audit trail.
