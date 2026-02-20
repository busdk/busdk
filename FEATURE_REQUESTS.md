# FEATURE_REQUESTS.md

Enhancement requests for BusDK in this repo context.

Privacy rule for request write-ups:
- Keep examples/repro snippets sanitized (no real customer names/emails/IBANs/account numbers/invoice numbers/local paths).
- Prefer placeholders and aggregated outputs over raw customer-linked row dumps.

Last reviewed: 2026-02-20 (tooling revalidated and merged `FEATURE_REQUESTS.Update.md`).

Goal note:
- Target workflow is Bus-only for bookkeeping/audit operations.
- Operators should not need shell text pipelines (`grep/sed/awk/column`) to answer accounting control questions.

## Active requests

- No currently confirmed active feature requests after 2026-02-20 implementation pass in this workspace.

## Implemented / removed from active list (2026-02-20 re-check)

- FR46 implemented:
  - `bus-assets lifecycle` provides native fixed-asset continuity flow:
    - `lifecycle baseline import --file <csv>` (deterministic baseline merge by `asset_id`),
    - `lifecycle baseline list --year YYYY` (year-open baseline register),
    - `lifecycle rollforward --year YYYY` (opening/additions/disposals/depreciation/closing rollforward),
    - `lifecycle proposals --year YYYY` (deterministic posting proposals for acquisitions plus generated depreciation/disposal rows).
  - Additional carry-forward requirement is covered by existing `bus-period opening` workflow:
    - imports prior-year closing balances into a new opening entry,
    - excludes income/expense by design (balance-sheet accounts only),
    - supports explicit result transfer target via `--equity-account`.
  - Covered by `bus-assets/cmd/bus-assets/run_test.go`, `bus-assets/tests/e2e_bus_assets.sh`, and existing `bus-period` opening coverage.
- FR51 implemented:
  - `bus-invoices add` supports replay-fidelity header fields (`--number`, `--status`, `--currency`, `--total-net`) and idempotent semantics (`--if-missing`, `--upsert`) with explicit `--invoice-id`.
  - `bus-invoices <invoice-id> add` supports explicit line numbering (`--line-no`) and line idempotency/upsert semantics (`--if-missing`, `--upsert`).
  - Covered by `bus-invoices/cmd/bus-invoices/run_test.go` and `bus-invoices/tests/e2e_bus_invoices.sh` (FR51 checks).
- FR45 implemented:
  - `bus-status close-readiness` provides deterministic machine-readable close status with:
    - required artifacts present/missing,
    - evidence coverage summary,
    - period close/lock state,
    - VAT filing parity state (`vat-filed.csv` vs `vat-returns.csv` period set for selected year),
    - unresolved blocker list with deterministic reason codes.
  - Supports `--year <YYYY>`, `--compliance fi`, `tsv|json|text`, and `--strict` failure on unresolved blockers.
  - Covered by `bus-status/internal/status/close_readiness_test.go`, `bus-status/internal/app/run_test.go`, and `bus-status/tests/e2e_bus_status.sh`.
- FR44 implemented:
  - `bus-status evidence-coverage` provides deterministic evidence-link coverage across `journal`, `bank`, `sales`, and `purchase`.
  - Output includes summary counts per scope (`total_rows`, `linked_rows`, `missing_rows`) and machine-readable missing rows with stable IDs (`source_id`, `voucher_id`, `bank_txn_id`, `invoice_id`) in TSV/JSON.
  - `--strict` fails when missing evidence links remain.
  - Covered by `bus-status/internal/status/evidence_coverage_test.go`, `bus-status/internal/app/run_test.go`, and `bus-status/tests/e2e_bus_status.sh`.
- FR32 implemented:
  - `bus-bank statement extract` supports raw statement evidence flows without mandatory sidecar schemas when data is inferable:
    - raw CSV/TSV/TXT summary header auto-detect,
    - transaction-derived checkpoint inference (`date` + `amount` + `balance`),
    - native PDF extraction path (via `pdftotext`) plus deterministic sibling-text fallback and explicit sidecar diagnostics when needed.
  - Covered in `bus-bank/internal/bank/statement_checkpoints_test.go` and `bus-bank/tests/e2e_bus_bank.sh`.
- FR34 implemented:
  - `bus-bank` provides reusable workspace mapping profiles for both extract and import:
    - `statement profile list|inspect|export|set|delete` backed by `statement-extract-profiles.csv`,
    - `config import-profile list|inspect|set|delete` + `import --profile-name` backed by `import-profiles.csv`.
  - Covered in `bus-bank/internal/app/run_test.go`, `bus-bank/internal/bank/statement_extract_profiles_test.go`, `bus-bank/internal/bank/import_profiles_test.go`, and `bus-bank/tests/e2e_bus_bank.sh`.
- FR38 implemented:
  - `bus-vat fi-file` emits FI VAT filing payload fields directly.
- FR39 implemented:
  - `bus-vat explain` provides row-level FI VAT field trace.
- FR41 command-level support implemented:
  - `bus-vat period-profile` exists (list/import surface available).
  - Date-range runtime defect is fixed in current module e2e coverage.
- FR42 implemented:
  - VAT output includes explicit rounding policy metadata (`half-away` / `half-even` support exposed).
- FR43 implemented:
  - `bus-journal account-activity` exists and replaces prior shell account-analysis workflows.
- FR40 implemented:
  - `--strict-fi-eu-rc` is accepted and enforced in validate/report/export paths.
- FR47 implemented:
  - `bus-reconcile propose` supports deterministic invoice-first selectors and noise suppression (`--target-kind`, `--exclude-exact-journal`, selectors).
- FR48 implemented:
  - `bus-journal account-activity` supports `--from/--to` and `--period YYYY-MM` scopes.
- FR49 implemented:
  - `bus-bank add` and `bus-bank import-log add` provide deterministic row-level write/idempotency flows.
- FR50 implemented:
  - `bus-reports mapping add|upsert` exists with strict mapping validation.
- FR52 implemented:
  - `bus-reconcile post --kind invoice_payment` supports deterministic partial-payment posting with open balance output.
- FR53 implemented:
  - `bus-bank coverage` provides deterministic bank-row posting coverage with summary buckets and machine-readable row output (`bank_txn_id`, `source_id`, `coverage_state`, `reason_code`) in TSV/JSON.
