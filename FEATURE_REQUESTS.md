# FEATURE_REQUESTS.md

Enhancement requests for BusDK in this repo context.

Privacy rule for request write-ups:
- Keep examples/repro snippets sanitized (no real customer names/emails/IBANs/account numbers/invoice numbers/local paths).
- Prefer placeholders and aggregated outputs over raw customer-linked row dumps.

Last reviewed: 2026-03-29.

Goal note:
- Target workflow is Bus-only for bookkeeping/audit operations.
- Operators should not need shell text pipelines (`grep/sed/awk/column`) to answer accounting control questions.

Active requests:

1. Give `bus period close` and year-end closing postings short human-facing voucher series instead of exposing technical `cl_<hash>` identifiers as visible vouchers.
   - Current behavior:
     - current close-generated journal rows keep deterministic internal ids such as `cl_<hash>`.
     - in practice the same technical identifier leaks into visible `voucher_id` / printable document-number columns.
     - this is audit-stable but not accountant-friendly, and it does not match how these events are normally presented in bookkeeping.
   - Requested behavior:
     - keep `cl_<hash>` as the technical close transaction identifier if needed for determinism and idempotency.
     - generate a separate short visible `voucher_id` for close postings.
     - the visible series should be semantic and short:
       - automatic period close / monthly close: `KS-1`, `KS-2`, ...
       - year-end close / tilinpäätösvienti: `TP-1`, `TP-2`, ...
     - for this repo context, year or month fragments are not required in the visible voucher because the workspaces are already single-period books and other visible voucher series are also short period-local sequences.
     - if Bus already uses `id_generation` / source-aware series selection internally, period-close and year-end-close flows should expose enough source-kind/prefix metadata that workspaces can map those visible series deterministically without patching reports afterwards.
   - Why this matters:
     - visible accountant-facing voucher numbers should stay short and interpretable.
     - technical deterministic ids and visible voucher numbers are different concerns; the former should not dominate printed accounting reports.
     - this is also closer to the original bookkeeping style, which used human bookkeeping labels for closing entries rather than a visible hash token.

2. Keep printable amount columns on a single line in human-facing accounting reports.
   - Current behavior:
     - printable `day-book` / `general-ledger` amount cells can still wrap into multiple lines when the column gets squeezed, producing values such as `-34` on one line and `118,15` on the next.
     - this makes numeric columns harder to scan and breaks the expectation that a monetary amount is one atomic value.
   - Requested behavior:
     - treat printable amount columns as non-wrapping numeric cells in human-facing PDF/table layouts.
     - page-local column-width resolution should reserve enough minimum width for the widest visible amount on that page before giving extra width to description columns.
     - the same rule should apply consistently anywhere human-facing accounting tables show signed monetary values.
   - Why this matters:
     - accountants read amount columns as one-line numeric fields, not as prose.
     - keeping amount values unbroken improves readability and reduces ambiguity in printable reports.
