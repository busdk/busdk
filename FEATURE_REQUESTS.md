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
- Uniform TASE / tuloslaskelma subtotal presentation in CSV and PDF
  - make main groups and subgroups follow the same visible subtotal contract
  - when a statement subgroup has rendered descendant rows between its label and its total, render the total on its own indented `yhteensä` row after those descendants
  - when no descendant rows are rendered, keep the current inline total presentation
