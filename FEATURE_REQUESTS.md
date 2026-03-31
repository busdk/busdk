# FEATURE_REQUESTS.md

Enhancement requests for BusDK in this repo context.

Privacy rule for request write-ups:
- Keep examples/repro snippets sanitized (no real customer names/emails/IBANs/account numbers/invoice numbers/local paths).
- Prefer placeholders and aggregated outputs over raw customer-linked row dumps.

Last reviewed: 2026-03-31.

Goal note:
- Target workflow is Bus-only for bookkeeping/audit operations.
- Operators should not need shell text pipelines (`grep/sed/awk/column`) to answer accounting control questions.

Active requests:

1. Disallow implicit current-year-result synthesis in default `fi-kpa-*` statement rendering unless explicit close sourcing or explicit opt-in is present.
   - Current behavior:
     - `fi-kpa-*` balance-sheet rendering can still derive `Tilikauden voitto/tappio` from accumulated P&L activity through `synthetic_current_year_result` even when the accounting material contains no explicit close-source basis for that line.
   - Requested behavior:
     - the default `fi-kpa-*` rendering path should reject that implicit fallback unless the workspace has explicit close-source setup or the operator explicitly opts in for that invocation.
     - diagnostics should explain that current-year result has no explicit closing basis and point operators to `statement-explain` / `statement-validate` style reconciliation output.
     - if explicit opt-in is used, the output must still keep synthetic explanation separate from ordinary TASE account drill-down.
   - Why this matters:
     - reports should not silently paper over missing year-end close basis in a way that looks like ordinary balance-sheet accounting.

2. Provide a Bus-native human-friendly source-id surface for explicit current-year-result close postings instead of forcing operators to handcraft verbose custom ids such as `closing:2023-12-31:current-year-result:1`.
   - Current behavior:
     - when operators intentionally add explicit close-source postings to satisfy strict `fi-kpa-*` balance-sheet semantics, the canonical way to identify those postings is still a manually invented free-form `--source-id` string.
     - in practice this leads to long ad hoc values such as `closing:2023-12-31:current-year-result:1`, which are awkward to type, easy to vary between workspaces, and easy to get wrong during replay.
   - Requested behavior:
     - `bus-journal` should expose one deterministic Bus-native way to express explicit current-year-result close-source ids without requiring operators to handcraft the full opaque string themselves.
     - the resulting stored `source_id` should be stable, readable, and short enough for normal CLI use while preserving duplicate-source safety.
     - documentation for strict `fi-kpa-*` close-source workflows should point operators to that Bus-native source-id surface instead of leaving the naming scheme implicit.
   - Why this matters:
     - explicit close-source postings should be reproducible and reviewable without inventing per-user custom naming conventions.
