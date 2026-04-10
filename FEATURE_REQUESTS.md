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
- Always render visible zero amounts as explicit zeroes in reports
  - in report outputs, render numeric zeroes as `0`/`0.00` instead of empty amount cells whenever the row is a numeric statement, subtotal, result, or account row
  - keep truly structural heading rows visually blank only when they are non-numeric section headings
  - make CSV and PDF follow the same zero-value visibility contract as text/markdown/json
