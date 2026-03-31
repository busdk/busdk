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

1. Disallow implicit current-period result synthesis in default `fi-kpa-*` statement rendering unless explicit close sourcing or explicit opt-in is present.
   - Current behavior:
     - `fi-kpa-*` balance-sheet rendering can still derive `Tilikauden voitto/tappio` from accumulated P&L activity through `synthetic_current_year_result` even when the accounting material contains no explicit close-source basis for that line.
   - Requested behavior:
     - the default `fi-kpa-*` rendering path should reject that implicit fallback unless the workspace has explicit close-source setup or the operator explicitly opts in for that invocation.
     - first implement one manual Bus-native path where operators can post the close entries themselves with semantic source metadata (for example `--source-kind closing-result --source-id FY2025`) and reports must recognize that semantic source kind without depending on hardcoded raw `source_id` string prefixes.
     - source-kind surfaces that already accept underscore-separated canonical names should also accept the corresponding hyphenated aliases for operator-facing CLI/config input, while preserving one canonical stored semantic interpretation.
     - diagnostics should explain that current-year result has no explicit closing basis and point operators to `statement-explain` / `statement-validate` style reconciliation output.
     - if explicit opt-in is used, the output must still keep synthetic explanation separate from ordinary TASE account drill-down.
   - Why this matters:
     - reports should not silently paper over missing year-end close basis in a way that looks like ordinary balance-sheet accounting.
