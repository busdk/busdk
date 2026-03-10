# FEATURE_REQUESTS.md

Enhancement requests for BusDK in this repo context.

Privacy rule for request write-ups:
- Keep examples/repro snippets sanitized (no real customer names/emails/IBANs/account numbers/invoice numbers/local paths).
- Prefer placeholders and aggregated outputs over raw customer-linked row dumps.

Last reviewed: 2026-03-10.

Goal note:
- Target workflow is Bus-only for bookkeeping/audit operations.
- Operators should not need shell text pipelines (`grep/sed/awk/column`) to answer accounting control questions.

Active requests:

1. Replace the fragmented Finnish reporting configuration model with a layered, deterministic reporting architecture aligned with good accounting practice.
   - Target model:
     - separate statutory taxonomy, account semantics, workspace entity context, and company-specific overrides
   - Main implementation goals:
     - make Finnish defaults good enough that a normal small-company workspace needs only entity context plus a few explicit exceptions
     - provide deterministic explain/validate tooling for how each account lands on a statement line
     - ensure drill-down variants inherit the same effective classification as the base statement
   - Why this matters:
     - the current reporting model duplicates meaning across workspace config, `accounts.csv`, `report-account-mapping.csv`, optional label overrides, and built-in layout logic

2. Extend `bus reports evidence-pack` so it can replace the remaining year-local evidence-pack orchestration.
   - Requested additions:
     - include the remaining close/review artifacts still handled by year-local scripts
     - preserve stable default filenames and target-directory behavior
     - become reliably re-runnable against already exported workspaces once active evidence-pack bugs are fixed
   - Expected package coverage:
     - balance sheet
     - profit and loss
     - balance-sheet reconciliation
     - voucher list
     - bank-transactions review
     - day-book
     - general-ledger
     - account-balances / `tililuettelo`
     - optional filing/compliance manifests where supported

3. Add workspace-level configuration for how Bus generates all bookkeeping-facing IDs.
   - Requested scope:
     - `document_number`
     - `voucher_id`
     - `transaction_id`
     - and other report-visible bookkeeping IDs Bus creates or derives
   - Requested capabilities:
     - configurable generation strategy
     - template/formula-based formatting
     - prefixes/suffixes
     - one or more ranges per series
     - series split by journal/source/channel or fiscal scope
     - readable external numbering separate from immutable internal IDs when needed
   - Why this matters:
     - current timestamp-based IDs are hard to read in accountant-facing reports and PDFs

4. Add a deterministic `bus reports mapping init` / `bus reports mapping seed` command that writes the current built-in default mapping into `report-account-mapping.csv`.
   - Requested behavior:
     - one native command to materialize explicit starter rows from the built-in default mapping logic
     - deterministic, rerunnable output
     - explicit append/replace/upsert semantics
   - Why this matters:
     - operators should not have to reverse-engineer default mappings from templates or older workspaces
