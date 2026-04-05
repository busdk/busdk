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

- Extend `bus journal assert ...` with grouped coverage controls for receipt-split audits.
  - classification-style scalar assertions already exist (`balance`, `debit`, `credit`, `net`, `match count`)
  - remaining gap is grouped auditability without shell/Python post-processing
  - needed first-class checks include:
    - distinct filtered `source_id` count
    - per-`source_id` grouped totals
    - assertions that every grouped source in one filtered set satisfies one expected debit/credit/net condition
