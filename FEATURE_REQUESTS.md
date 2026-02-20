# FEATURE_REQUESTS.md

Enhancement requests for BusDK in this repo context.

Privacy rule for request write-ups:
- Keep examples/repro snippets sanitized (no real customer names/emails/IBANs/account numbers/invoice numbers/local paths).
- Prefer placeholders and aggregated outputs over raw customer-linked row dumps.

Last reviewed: 2026-02-20 (update merge + revalidation).

Goal note:
- Target workflow is Bus-only for bookkeeping/audit operations.
- Operators should not need shell text pipelines (`grep/sed/awk/column`) to answer accounting control questions.

## Active requests

- FR32 - bus-bank statement extract/verify should accept raw statement evidence without sidecar schema files
  - Symptom:
    - `statement extract` cannot consume raw bank statement PDF evidence directly in this repo.
  - Impact:
    - Deterministic saldo verification from original evidence is blocked unless extra sidecar files are created.
  - Repro:
    1. `bus bank statement extract --file original/tiliotteet/2024/202402/20240229-sendanor-paatili-Tiliote_2024-02-01_2024-02-29.pdf`
  - Expected:
    - Deterministic direct extraction mode for standard statement PDFs.
    - If summary fields are not present, deterministic transaction-derived checkpoint mode with explicit diagnostics.

- FR34 - configurable mapping profiles for import/extract commands
  - Symptom:
    - Mapping flags are repeated on every run for non-standard source formats.
  - Impact:
    - Drift risk and weak audit readability when mappings are copied manually between commands/scripts.
  - Expected:
    - Workspace-level named mapping profiles reusable by import/extract commands.

- FR44 - deterministic evidence-coverage audit command (replace attachment-shell audits)
  - Symptom:
    - Evidence coverage checks currently require ad-hoc shell workflows to prove whether each posting/bank row/invoice has linked evidence.
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
    - Close-state gating is fragmented and currently not reliable as one deterministic report.
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
  - Additional requirement from replay audit:
    - Add deterministic year-open carry-forward helper that imports prior-year closing balances into opening entry while automatically excluding income/expense accounts (balance-sheet accounts only), with explicit net-result transfer target (for example retained earnings).

## Implemented / removed from active list (2026-02-20 re-check)

- FR38 implemented:
  - `bus-vat fi-file` emits FI VAT filing payload fields directly.
- FR39 implemented:
  - `bus-vat explain` provides row-level FI VAT field trace.
- FR41 command-level support implemented:
  - `bus-vat period-profile` exists (list/import surface available).
  - Remaining runtime defect for date-range path is tracked in `BUGS.md`.
- FR42 implemented:
  - VAT output includes explicit rounding policy metadata (`half-away` / `half-even` support exposed).
- FR43 implemented:
  - `bus-journal account-activity` exists and replaces prior shell account-analysis workflows.
- FR48 implemented:
  - `bus-journal account-activity` supports `--from/--to` and `--period YYYY-MM` month scope, with unit + e2e coverage.
- FR49 implemented:
  - `bus-bank import-log add` and `bus-bank add` provide deterministic row-level add/upsert (`--if-missing`) for `bank-imports.csv` and `bank-transactions.csv`, with schema/domain validation.
- FR50 implemented:
  - `bus-reports mapping add|upsert` writes `report-account-mapping.csv` natively with layout/line/target validation (same constraints as report runtime), avoiding generic `bus data` edits.
- FR40 implemented:
  - `--strict-fi-eu-rc` is accepted for `bus-vat validate` and enforced in subcommand-flag position.
- FR52 implemented:
  - `bus-reconcile post --kind invoice_payment` now supports deterministic partial payments with prorated net/VAT posting and explicit `posted_amount` + `open_amount` status output.
- FR51 implemented:
  - `bus-invoices add`/`<invoice-id> add` support replay-fidelity fields plus deterministic `--if-missing` and `--upsert` semantics (including explicit `--line-no` control for line upsert/idempotency).
- FR47 implemented:
  - `bus-reconcile propose` now supports deterministic proposal suppression/selectors: `--target-kind`, `--exclude-exact-journal`, `--exclude-already-matched`, and bank-row filters (`--bank-id`, `--from-date`, `--to-date`, `--counterparty`, `--reference`, `--amount`) in standard propose mode.
