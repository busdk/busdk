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

1. Add one universal Bus policy for duplicate source identifiers, with strict conflict failure as the normal replay-safe mode.
   - Already shipped / partly solved:
     - `bus journal add` and related `bus-journal` posting flows now fail by default on duplicate `(source_system, source_id)` and only skip duplicates explicitly with `--if-missing`.
   - Remaining gap:
     - duplicate-source handling is still primarily a `bus-journal` runtime policy, not one universal Bus-level policy reused consistently across every module that accepts canonical source identifiers.
     - there is still no central workspace/runtime policy surface for choosing strict failure vs explicit alternative modes in one place.
   - Requested behavior:
     - expose one universal duplicate-source policy, configured centrally and reused across modules that accept canonical source identifiers.
     - strict replay-safe conflict failure should remain the normal default.
     - any convenience mode such as skip-identical / skip-existing must stay explicit rather than silent.
     - conflict diagnostics should remain deterministic and show the conflicting posting or object shape clearly enough for replay debugging.
   - Why this matters:
     - silent or module-specific duplicate behavior is too dangerous for accounting replay; operators need one predictable Bus-wide rule.
