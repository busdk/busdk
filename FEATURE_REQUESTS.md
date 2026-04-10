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
  - add an AI-annotated `*-accounts` report variant in `bus-reports`
  - keep the existing statement/group/account hierarchy and add a third visible level under each posting account
  - render accountant-facing AI summaries of what each account contains, including tabular subtotal rows where useful
  - implement the AI integration through the `bus-agent` Go library surface rather than shelling out through the CLI
