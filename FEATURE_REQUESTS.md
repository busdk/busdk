# FEATURE_REQUESTS.md

Enhancement requests for BusDK in this repo context.

Privacy rule for request write-ups:
- Keep examples/repro snippets sanitized (no real customer names/emails/IBANs/account numbers/invoice numbers/local paths).
- Prefer placeholders and aggregated outputs over raw customer-linked row dumps.

Last reviewed: 2026-04-05.

Goal note:
- Target workflow is Bus-only for bookkeeping/audit operations.
- Operators should not need shell text pipelines (`grep`/`sed`/`awk`/`column`) to answer accounting control questions.

Active requests:
  - in `balance-sheet` and `profit-and-loss` `*-accounts` outputs, keep `account_code` and `account_name` as their own columns
  - stop repeating the account code in the first visible `section`/label field for account rows
  - keep indentation and subgroup/account structure unchanged across text/csv/markdown/json/pdf
