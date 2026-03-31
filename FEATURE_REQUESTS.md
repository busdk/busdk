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
   - Current behavior:
     - `bus journal add` treats `(source_system, source_id)` as an idempotency key.
     - when the key already exists, the command skips as a successful no-op.
     - this happens both for truly identical reruns and for accidental key reuse with different posting content.
   - Requested behavior:
     - Bus should expose one universal duplicate-source policy, configured centrally at workspace or runtime level instead of ad hoc per command.
     - strict replay-safe mode should be the normal setting for bookkeeping work:
       - posting the same `(source_system, source_id)` twice fails with a clear non-zero conflict error
       - this applies even if the second posting is byte-for-byte identical
     - if current idempotent convenience remains available, it should be an explicit alternative policy such as `skip-identical` or `skip-existing`, not the silent default.
     - the same policy concept should be reusable across modules that accept canonical source identifiers, not only `bus journal add`.
     - when duplicate content differs, the error message should clearly show conflicting fields such as posting date, debit or credit accounts, amounts, entry sequence or expanded shorthand identity, and description when relevant.
