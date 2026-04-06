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

- extend `bus files assert` with expression-based aggregate CSV/TSV assertions
  - auto-detect `csv` / `tsv` by file extension or file contents unless `--format` overrides it
  - header-based row selection bindings such as `--select-one`, `--select-many`, and flexible `--select`
  - arithmetic assertions over selected row/column values such as `sum(...)`, `avg(...)`, `min(...)`, `max(...)`, `count(...)`, and addition/subtraction between selected values and sets
  - deterministic pass/fail output that shows the expression, matched filters, included values, computed result, and expected result

- first-class `bus files` surface
  - `bus files parse <file...>`
  - `bus files parse rows <file...>`
  - `bus files find <dir...>`
  - includes generic local evidence parsing and deterministic duplicate detection
