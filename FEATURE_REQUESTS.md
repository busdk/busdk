# FEATURE_REQUESTS.md

Enhancement requests for BusDK in this repo context.

Privacy rule for request write-ups:
- Keep examples/repro snippets sanitized (no real customer names/emails/IBANs/account numbers/invoice numbers/local paths).
- Prefer placeholders and aggregated outputs over raw customer-linked row dumps.

Last reviewed: 2026-02-21 (active rows re-tested against current CLI build).

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
    - Support mixed-source verification flow where extracted statement totals can be validated against imported bank rows for the same account+period.
    - Deterministic warnings for unrecognized numeric tokens in statement evidence (so parser coverage can be extended safely over time).

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

- FR55 - `bus-bank` needs universal statement-evidence parser with deterministic PDF extraction + cross-check engine
  - Symptom:
    - Current statement extraction is format-fragile and often needs bank-specific sidecars/manual mapping before balances can be verified.
    - There is no one deterministic command that:
      - extracts statement facts from PDF evidence,
      - computes expected checkpoints from bank transactions,
      - compares both and explains mismatches.
  - Impact:
    - Statement-level saldo verification remains partially manual and difficult to reproduce across banks.
    - Replay workflows cannot produce uniform evidence-validation proof for non-OP and new bank formats.
  - Expected:
    - New universal command family (example naming):
      - `bus bank statement parse --file <pdf|csv|tsv|txt>`
      - `bus bank statement verify --statement <parsed.json|attachment-id> --bank-rows <...>`
    - Minimum extracted fields (when present):
      - `account_id`, `account_iban`, `period_start`, `period_end`, `opening_balance`, `closing_balance`, `currency`,
      - optional transaction summary fields (row count, debit total, credit total, net change).
    - Deterministic validation rules:
      - opening + period net == closing (with explicit rounding policy),
      - parsed period matches compared bank-row period,
      - currency and account identity consistency checks,
      - optional per-day checkpoint reconciliation when daily balances are present.
    - Deterministic diagnostics:
      - structured mismatch reason codes,
      - confidence score per extracted field with provenance spans,
      - explicit warnings for numeric tokens found in source but not mapped/used (`unknown_numbers` list) to support parser evolution.
    - Safety/portability requirements:
      - no bank-specific hardcoding required in default mode,
      - optional bank profiles can improve confidence but parser must still run in generic fallback mode.

## Resolved / removed from active list (revalidated 2026-02-21)

- FR45 implemented: `bus status readiness --year ... --compliance fi --format json|tsv` returns deterministic gates and regulatory demand sections.
- FR47 implemented: `bus-reconcile propose` supports `--target-kind`, `--exclude-exact-journal`, `--exclude-already-matched`, and scoped selectors.
- FR48 implemented: `bus-journal account-activity` supports `--from/--to` and `--period YYYY-MM` scopes.
- FR49 implemented: `bus-bank add` and `bus-bank import-log add` exist.
- FR50 implemented: `bus-reports mapping add|upsert` exists.
- FR51 implemented: `bus-invoices add` and `<invoice-id> add` now expose replay-needed flags (`--number`, `--status`, `--currency`, `--total-net`, `--line-no`, `--upsert`).
- FR52 implemented: `bus-reconcile post --kind invoice_payment` supports deterministic partial-payment posting with posted/open status tracking.
- FR53 implemented: deterministic posting coverage report exists in `bus-bank coverage`.
- FR54 implemented: legacy-safe replay mode exists in `bus-invoices` (`--legacy-replay`) for add/import flows with deterministic warnings.
- FR55 implemented: universal statement parser + deterministic verification engine exists in `bus-bank statement extract|verify` with provenance and mismatch diagnostics.
