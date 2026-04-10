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
  - speed up `bus-reports` AI-annotated account report variants further beyond 4-way parallelism
  - expose an explicit fast-model / AI-runtime tuning surface for AI-annotated report generation
  - render AI-generated account summary rows in PDFs without bold emphasis
  - make `bus-reports evidence-pack` include AI-annotated statement artifacts only behind an explicit opt-in flag instead of enabling them by default whenever AI is available
