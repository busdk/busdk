# FEATURE_REQUESTS.md

Enhancement requests for BusDK in this repo context.

Privacy rule for request write-ups:
- Keep examples/repro snippets sanitized (no real customer names/emails/IBANs/account numbers/invoice numbers/local paths).
- Prefer placeholders and aggregated outputs over raw customer-linked row dumps.

Last reviewed: 2026-02-20 (tooling revalidated).

Goal note:
- Target workflow is Bus-only for bookkeeping/audit operations.
- Operators should not need shell text pipelines (`grep/sed/awk/column`) to answer accounting control questions.

## Active requests

- FR32 - `bus-bank statement extract/verify` should accept raw statement evidence without sidecar schema files
  - Symptom:
    - `statement extract` still cannot consume standard bank-statement PDF evidence directly in this repo.
  - Impact:
    - Deterministic saldo verification from original evidence is blocked unless extra sidecar/conversion artifacts are created.
  - Expected:
    - Deterministic direct extraction mode for standard statement PDFs.
    - If summary fields are not present, deterministic transaction-derived checkpoint mode with explicit diagnostics.

- FR34 - configurable mapping profiles for import/extract commands
  - Symptom:
    - Mapping flags are repeated on every run for non-standard source formats.
    - Even with explicit `--map` fields, raw statement extract cannot parse localized mapped dates (for example `M/D/YYYY`) in some statement exports.
  - Impact:
    - Drift risk and weak audit readability when mappings are copied manually between commands/scripts.
    - Deterministic saldo verification remains blocked for formats where date parsing needs an explicit format hint.
  - Expected:
    - Workspace-level named mapping profiles reusable by import/extract commands.
    - Mapping profiles should include parsers/normalizers for date and number formats (for example date format hint and unicode-minus normalization).

- FR44 - deterministic evidence-coverage audit command (replace attachment-shell audits)
  - Symptom:
    - Evidence coverage checks still require ad-hoc shell workflows to prove whether each posting/bank row/invoice has linked evidence.
  - Impact:
    - Hard to produce repeatable legal/audit proof without manual shell logic.
  - Expected:
    - Native command (for example `bus audit evidence-coverage`) that outputs:
      - total rows per scope (journal/bank/sales/purchase),
      - rows with evidence links,
      - rows missing links,
      - machine-readable missing-list with deterministic IDs (`source_id`, `voucher_id`, `bank_txn_id`, `invoice_id`).

- FR45 - deterministic close-readiness command with legal/compliance gates
  - Symptom:
    - Close-state gating is fragmented and current `status readiness` behavior is not sufficient as one deterministic report.
  - Impact:
    - Legal readiness must be assembled manually from multiple commands.
  - Expected:
    - One command (for example `bus close readiness --year YYYY --compliance fi`) returning machine-readable close status:
      - required artifacts present/missing,
      - evidence coverage summary,
      - period close/lock state,
      - VAT filing parity state,
      - unresolved blockers with deterministic reason codes.

- FR46 - asset-register lifecycle command set from prior-year baseline + current-year evidence
  - Symptom:
    - Building correct fixed-asset continuity (opening baseline, additions, disposals, depreciation) still needs manual script orchestration.
  - Impact:
    - High risk of omission between years (for example missing 2021-2022 additions when baseline source ends earlier).
  - Expected:
    - Native Bus asset lifecycle flow:
      - import/list baseline register,
      - apply year additions/disposals from deterministic selectors,
      - produce opening/closing asset rollforward and posting proposals.
    - Additional requirement:
      - deterministic year-open carry-forward helper that imports prior-year closing balances into opening entry while excluding income/expense accounts (balance-sheet accounts only), with explicit net-result transfer target.

- FR47 - `bus-reconcile propose` needs deterministic invoice-first mode and noise suppression
  - Symptom:
    - `bus-reconcile propose` on active workspaces emits very large proposal sets dominated by non-target rows (e.g. exact journal matches), including already-posted duplicates.
  - Impact:
    - Hard to use propose/apply as controlled accounting workflow for backlog resolution.
  - Expected:
    - Proposal mode with deterministic selectors and suppression options, for example:
      - `--target-kind invoice_payment`
      - `--exclude-exact-journal`
      - `--exclude-already-matched`
      - account/date/reference filters
    - Stable confidence ordering and bounded output for replay-scale workspaces.
    - Additional deterministic purchase-payment matching mode for real bank evidence where exact gross equality fails:
      - `--match-mode invoice-number-hint` (or equivalent) that prioritizes explicit invoice-number hints from bank metadata,
      - explicit parser support for ERP-style bank message tokens (for example `ERP <invoice_id>`) into deterministic candidate links,
      - controlled amount tolerance / residual handling for small payment-provider/card rounding differences,
      - proposal output that includes residual delta reason code (for example `provider_fee_delta`, `rounding_delta`) so apply flow stays auditable.

- FR48 - `bus-journal account-activity` needs explicit date-range/month scope flags
  - Symptom:
    - `bus-journal account-activity` accepts yearly `--period` but not `--from/--to` or `YYYY-MM` period scopes.
  - Impact:
    - Month-level and arbitrary-range audit checks still require external workarounds.
  - Expected:
    - Support `--from YYYY-MM-DD --to YYYY-MM-DD` and `--period YYYY-MM` in addition to yearly scope.

- FR52 - `bus-reconcile post` needs deterministic partial-payment flow for invoice matches
  - Symptom:
    - One invoice is often paid in multiple bank receipts; current posting flow rejects such rows (`partial posting not supported`) when converting matches to journal sales/VAT postings.
  - Impact:
    - Receivables-clearing balances remain parked even when evidence-backed match rows exist.
    - Operators must handcraft journal postings instead of using deterministic reconcile-post workflow.
  - Expected:
    - `bus reconcile post --kind invoice_payment` should support:
      - partial payments with residual open balance tracking,
      - deterministic idempotent posting per match row,
      - consistent VAT split using invoice-line evidence at payment level,
      - clear output fields for posted-vs-open remainder by invoice.

- FR53 - `bus-bank` needs deterministic posting-coverage report (bank row -> journal/reconcile state)
  - Symptom:
    - `bus bank backlog` reflects reconcile state, not full accounting posting state.
    - It does not directly answer: "does every bank transaction have accounting posting coverage?"
  - Impact:
    - Checklist evidence for "all bank rows classified/posted" still requires external joins.
  - Expected:
    - New command (for example `bus bank coverage --year YYYY`) with deterministic buckets per bank row:
      - `journal_linked`,
      - `reconcile_linked`,
      - `both`,
      - `none`,
      - optional `suspense_linked`.
    - Machine-readable output with stable IDs (`bank_txn_id`, `source_id`, coverage state, reason code).

- FR54 - `bus-invoices` needs legacy-safe replay mode for ERP datasets with non-normalized dates/validation edge cases
  - Symptom:
    - Direct `bus invoices add` replay can fail on legacy ERP rows (for example due-date earlier than issue-date in source), even when those rows exist in canonical datasets used for parity replay.
  - Impact:
    - Replacing `data row add sales-invoices|purchase-invoices|...` with native invoice commands is not always possible without mutating source semantics.
    - Blocks deterministic migration away from `data row` in replay scripts.
  - Expected:
    - Explicit replay/profile mode in `bus-invoices` that can ingest legacy rows deterministically while:
      - preserving raw source values,
      - emitting structured diagnostics/warnings for non-normalized rows,
      - allowing strict validation mode for normalized datasets.

## Resolved / removed from active list (revalidated 2026-02-20)

- FR38 implemented: `bus-vat fi-file` emits FI VAT filing payload fields.
- FR39 implemented: `bus-vat explain` provides row-level FI VAT field trace.
- FR41 implemented at command level: `bus-vat period-profile` exists.
- FR42 implemented: VAT output includes explicit rounding policy metadata.
- FR43 implemented: `bus-journal account-activity` exists.
- FR49 implemented: `bus-bank add` and `bus-bank import-log add` exist.
- FR50 implemented: `bus-reports mapping add|upsert` exists.
- FR51 implemented: `bus-invoices add` and `<invoice-id> add` now expose replay-needed flags (`--number`, `--status`, `--currency`, `--total-net`, `--line-no`, `--upsert`).
