# BUGS.md

Track defects and blockers that affect replay/parity work in this repository.  
Feature requests belong in `FEATURE_REQUESTS.md`.

**Last reviewed:** 2026-02-19.

---

## Active issues
- None currently.

## Resolved issues

### 2026-02-19 — `bus vat --source journal --basis cash` failed on opening vouchers (`opening:*` treated as bank txn ids) (resolved)

**Resolution:**
- Journal-source loader now skips opening rows identified by:
  - opening voucher/source kinds (`opening`, `opening_balance`, `opening-balance`)
  - opening-style source identifiers (`opening:*`, `opening/...`, `opening-...`, `voucher:opening:*`)
- This prevents `--basis cash` from trying to resolve opening references as bank transaction ids.

**Regression coverage:**
- `bus-vat/internal/vat/journal_test.go` — `TestLoadJournalRowsWithBasisCash_skipsOpeningSourceIDRows`
- `bus-vat/internal/app/run_test.go` — `TestRunReportSourceJournalBasisCashSkipsOpeningSourceIDRows`

### 2026-02-19 — `bus vat --source journal --basis cash` failed resolving `bank_row:*:journal:*` references (resolved)

**Resolution:**
- Cash-basis journal date resolution now normalizes bank evidence references (for example `bank_row:26184:journal:1`) to candidate bank transaction ids, including `erp-bank-<id>`, before lookup in `bank-transactions.csv`.
- Bank transaction date index now includes both `bank_txn_id` and `id` columns when present.

**Regression coverage:**
- `bus-vat/internal/vat/journal_test.go` — `TestLoadJournalRowsWithBasisCash_resolvesBankRowJournalRefToERPBankID`
- `bus-vat/internal/app/run_test.go` — `TestRunReportSourceJournalBasisCashResolvesBankRowJournalRef`
- `bus-vat/tests/e2e_bus_vat.sh` — `journal_bankrow_ref_cash` scenario (Jan zero, Feb non-zero after booked-date resolution)

### 2026-02-19 — `bus vat --source journal` could return zero totals for legacy journal VAT rows (resolved)

**Resolution:**
- Added legacy-compatible journal VAT fallbacks:
  - `vat_rate` / `vat_percent` support on journal rows and in `vat-account-mapping.csv`
  - direction-only VAT-account mapping rows treat posting amount as VAT amount (`net_cents=0`)
  - debit/credit amount parsing now uses the non-zero side (instead of blindly preferring debit)
  - inferred VAT-account fallback for likely VAT accounts (for example `293x`) when mapping is absent

**Regression coverage:**
- `bus-vat/internal/vat/journal_test.go` — `TestLoadJournalRows_withVatRateColumn`
- `bus-vat/internal/vat/journal_test.go` — `TestLoadJournalRows_withMappingVatRateColumn`
- `bus-vat/internal/vat/journal_test.go` — `TestLoadJournalRows_directionOnlyMappingTreatsAmountAsVAT`
- `bus-vat/internal/vat/journal_test.go` — `TestLoadJournalRows_debitCreditPrefersNonZeroSide`
- `bus-vat/internal/vat/journal_test.go` — `TestLoadJournalRows_infersVATFor293DebitCreditWithoutMapping`
- `bus-vat/internal/app/run_test.go` — `TestRunReportSourceJournalVatRateColumnDoesNotZeroTotals`
- `bus-vat/internal/app/run_test.go` — `TestRunReportSourceJournalDirectionOnlyMappingDoesNotZeroTotals`
- `bus-vat/internal/app/run_test.go` — `TestRunReportSourceJournalInfersVATFromLegacy293Rows`

### 2026-02-19 — `bus reports trial-balance` CSV awk net-sum instability with comma text fields (resolved)

**Resolution:**
- CSV text fields in trial-balance output are sanitized so naive `awk -F,` field indexing remains stable.

**Regression coverage:**
- `bus-reports/internal/report/report_test.go` — `TestWriteTrialBalanceCSVSanitizesCommaInNameForStableColumns`
