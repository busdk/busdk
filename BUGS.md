# BUGS.md

Track **defects and blockers** that affect this repo's replay or parity work: actual bugs in our software or in BusDK/tooling when they block us. **Nice-to-have features and enhancement requests** are in **[FEATURE_REQUESTS.md](FEATURE_REQUESTS.md)**.

**Last reviewed:** 2026-02-21 (retested; reconcile cash purchase-side VAT signed-evidence fix merged).

---

## Active issues

- None currently tracked.

## Implemented / removed from active list (2026-02-20 re-check)

- `bus vat report --source reconcile --basis cash` purchase-side input VAT drop fixed:
  - Reconcile cash allocation now normalizes signed purchase invoice evidence when purchase invoice gross is encoded negative (line-level outflow sign convention), so matched purchase cash events contribute deductible input VAT instead of being rejected/skipped as non-positive gross.
  - Covered by `bus-vat/internal/vat/reconcile_test.go` (`TestLoadReconcileRows_NormalizesSignedPurchaseInvoiceEvidence`) and `bus-vat/tests/e2e_bus_vat.sh` (`reconcile_purchase_line_signed` scenario).

- `bus status readiness` period-state gate false-negative fixed:
  - `latest_period` / `latest_state` now supports both legacy `period,state` rows and append-only `bus-period` rows (`period_id,state,recorded_at,...`).
  - Effective state is selected per period by latest `recorded_at`, then latest period is selected for requested year.
  - Covered by `bus-status/internal/status/status_test.go` and `bus-status/tests/e2e_bus_status.sh` (append-only history case).

- `bus status readiness --compliance` silent no-op fixed:
  - Non-compliance mode now emits legal gates as `not_applicable` with explicit `"compliance mode disabled"` observed value and empty `regulatory_demands`.
  - Compliance mode (`--compliance`) actively evaluates legal gates and populates `regulatory_demands`.
  - Covered by `bus-status/internal/status/status_test.go` and `bus-status/tests/e2e_bus_status.sh` (compliance vs non-compliance JSON assertions).

- `bus invoices list` filter regression fixed:
  - `list` now honors list filters both before and after subcommand token:
    - `bus-invoices --type sales list`
    - `bus-invoices list --type sales`
    - `bus-invoices list --status paid`
  - Existing permissive `--` passthrough behavior for list remains intact.
  - Covered by `bus-invoices/cmd/bus-invoices/run_test.go` and `bus-invoices/tests/e2e_bus_invoices.sh`.

- `bus bank statement extract` BOM regression fixed:
  - Raw statement parsing now strips UTF-8 BOM bytes before delimiter detection and CSV decode.
  - BOM-prefixed quoted headers (for example `"Date","Amount","Balance"`) now parse normally with mapped transaction inference.
  - Covered by `bus-bank/internal/bank/statement_checkpoints_test.go` and `bus-bank/tests/e2e_bus_bank.sh`.

- `bus status` default-year regression fixed:
  - `readiness`, `evidence-coverage`, and `close-readiness` now infer year deterministically when `--year` is omitted:
    - workspace directory year (`.../2023`),
    - `journal-YYYY.csv` presence,
    - `periods.csv` period years,
    - fallback to current UTC year only when no workspace year signal exists.
  - Covered by `bus-status/internal/status/year_infer_test.go`, `bus-status/internal/status/status_test.go`, and `bus-status/tests/e2e_bus_status.sh` (year-scoped workspace regression check).

- `bus status readiness` `--year`/`--format`/`--compliance` semantics:
  - Verified in `bus-status` tests:
    - `bus-status/tests/e2e_bus_status.sh` checks JSON output and compliance fields for both pre-subcommand and post-subcommand flags.
    - `bus-status/internal/app/run_test.go` includes both pre- and post-subcommand strict/year/compliance parsing paths.
- `bus-vat --strict-fi-eu-rc` advertised but rejected:
  - Verified in `bus-vat` tests:
    - `bus-vat/tests/e2e_bus_vat.sh` validates both `--strict-fi-eu-rc validate` and `validate --strict-fi-eu-rc`.
    - `bus-vat/internal/app/run_test.go` includes strict FI EU RC flag handling tests.
- `bus-vat report --from/--to` fails when `datapackage.json` lacks `busdk.accounting_entity`:
  - Verified in `bus-vat/tests/e2e_bus_vat.sh` (`report --from/--to` succeeds and does not emit `missing busdk.accounting_entity`).
- `bus bank backlog -f json` after subcommand silently ignored:
  - Verified in `bus-bank/tests/e2e_bus_bank.sh` and `bus-bank/internal/app/run_test.go` (misplaced global flag now returns explicit error).
- `bus-reconcile post --kind invoice_payment` rejects partial payments:
  - Verified in `bus-reconcile/tests/e2e_bus_reconcile.sh` FR52 section (deterministic partial posting with open-balance tracking).
- `bus reconcile propose` missing monthly schema in consolidated-journal workspace:
  - Verified in `bus-reconcile/tests/e2e_bus_reconcile.sh` consolidated-year schema fallback section.
- `bus reports annual-validate` / `trial-balance` missing monthly schema in consolidated-journal workspace:
  - Fixed with yearly-schema fallback when `journals.csv` points to monthly files; covered by `bus-reports/internal/workspace/load_test.go`.
- `bus journal account-activity` (and validate path) missing monthly schema in consolidated-journal workspace:
  - Fixed with yearly-schema fallback in journal validation loader; covered by `bus-journal/internal/journal/validate_test.go`.
- `sales-invoices.total_net` net/gross semantics mismatch between `bus-invoices` validation and `bus-reconcile match`:
  - `bus-invoices` enforces `total_net` equals line-net sum.
  - `bus-reconcile match` compares bank amount to computed invoice evidence gross (not header `total_net`), covered by `bus-reconcile/internal/app/run_test.go` (`TestMatchUsesInvoiceEvidenceGrossInsteadOfHeaderTotalNet`).
