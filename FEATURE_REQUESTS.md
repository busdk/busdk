# FEATURE_REQUESTS.md

Enhancement requests for BusDK in this repo context.

Privacy rule for request write-ups:
- Keep examples/repro snippets sanitized (no real customer names/emails/IBANs/account numbers/invoice numbers/local paths).
- Prefer placeholders and aggregated outputs over raw customer-linked row dumps.

Last reviewed: 2026-02-21 (unit + e2e revalidated).

Goal note:
- Target workflow is Bus-only for bookkeeping/audit operations.
- Operators should not need shell text pipelines (`grep/sed/awk/column`) to answer accounting control questions.

## Active requests

No open feature requests.

## Resolved / removed from active list (revalidated 2026-02-21)

- FR32 implemented: `bus-bank statement extract/verify` supports raw evidence parsing paths (including native PDF extraction, configurable mapping, and transaction-derived checkpoint inference).
- FR34 implemented: configurable mapping profiles exist for import/extract flows (`import-profiles.csv`, `statement-extract-profiles.csv`, and related config commands).
- FR38 implemented: `bus-vat fi-file` emits FI VAT filing payload fields.
- FR39 implemented: `bus-vat explain` provides row-level FI VAT field trace.
- FR41 implemented at command level: `bus-vat period-profile` exists.
- FR42 implemented: VAT output includes explicit rounding policy metadata.
- FR43 implemented: `bus-journal account-activity` exists.
- FR44 implemented: deterministic evidence coverage report exists in `bus-status evidence-coverage`.
- FR45 implemented: deterministic close readiness report exists in `bus-status close-readiness --compliance fi`.
- FR46 implemented: asset lifecycle baseline/rollforward/proposals exist in `bus-assets`, and year-open carry-forward is implemented in `bus-period opening` with balance-sheet account filtering.
- FR47 implemented: `bus-reconcile propose` supports invoice-first selectors and noise suppression flags (`--target-kind`, `--exclude-exact-journal`, `--exclude-already-matched`, bank selectors).
- FR48 implemented: `bus-journal account-activity` supports `--from/--to` and `--period YYYY-MM` scopes.
- FR49 implemented: `bus-bank add` and `bus-bank import-log add` exist.
- FR50 implemented: `bus-reports mapping add|upsert` exists.
- FR51 implemented: `bus-invoices add` and `<invoice-id> add` now expose replay-needed flags (`--number`, `--status`, `--currency`, `--total-net`, `--line-no`, `--upsert`).
- FR52 implemented: `bus-reconcile post --kind invoice_payment` supports deterministic partial-payment posting with posted/open status tracking.
- FR53 implemented: deterministic posting coverage report exists in `bus-bank coverage`.
- FR54 implemented: legacy-safe replay mode exists in `bus-invoices` (`--legacy-replay`) for add/import flows with deterministic warnings.
- FR55 implemented: universal statement parser + deterministic verification engine exists in `bus-bank statement extract|verify` with provenance and mismatch diagnostics.
