# BUGS.md

Track **defects and blockers** that affect this repo's replay or parity work: actual bugs in our software or in BusDK/tooling when they block us. **Nice-to-have features and enhancement requests** are in **[FEATURE_REQUESTS.md](FEATURE_REQUESTS.md)**.

**Last reviewed:** 2026-02-20.

---

## Active issues
- None currently tracked.

## Resolved issues
- 2026-02-20 — `bus period lock` failed after close with `journal row ... missing required "currency"` (resolved)
  - Fix:
    - `bus-period` validation now tolerates legacy blank `currency` values in bus-journal index rows even when schema marks `currency` required, so close/lock flows remain operable on historical datasets.
  - Coverage:
    - unit: `bus-period/internal/validate/validate_test.go` (`TestValidateAll_AcceptsIndexRowsWithBlankCurrency`)
    - e2e: `bus-period/tests/e2e_bus_period.sh` (`index_lock_legacy_blank_currency`)
  - Re-test status:
    - `cd bus-period && go test ./... && make e2e` passes.

- 2026-02-20 — `bus bank statement extract --file <statement.csv>` blocked on sidecars for raw evidence (resolved)
  - Fix:
    - `bus-bank` raw extract now supports transaction-export inference when `date + amount + balance` columns are available, in addition to existing summary-column auto-detect and sidecar mode.
    - `--map`/profile mapping now supports `amount` and `balance` fields for raw extraction.
    - diagnostics now explicitly guide summary mapping vs transaction-inference mapping when opening/closing columns are missing.
  - Coverage:
    - unit: `bus-bank/internal/bank/statement_checkpoints_test.go`
      - `TestExtractStatementCheckpointsRawTransactionInference`
      - `TestExtractStatementCheckpointsRawEvidenceMissingSummaryAndInferenceColumns`
    - e2e: `bus-bank/tests/e2e_bus_bank.sh` (`raw-transactions-no-schema.csv` dry-run extract)
  - Re-test status:
    - `cd bus-bank && go test ./... && make e2e` passes.

- 2026-02-20 — `bus period close` previously failed with `journal date parse failed` in clean replay workspaces (resolved)
  - Re-verified in fresh repro workspace:
    - `bus period close --period 2023-12 --post-date 2023-12-31` exits `0`
    - `periods.csv` gains `2023-12 ... closed` row
- 2026-02-20 — FR28 runtime mismatch (`--explain-mapping` unknown) in local `bus-reports` (resolved)
  - Current local runtime now supports `--explain-mapping` and emits mapping diagnostics.
- 2026-02-20 — `bus reports` PDF Unicode extraction mojibake in metadata/labels (resolved)
  - Resolution was verified in this workspace by regenerating 2023 report PDFs and extracting text with `pdftotext`.
  - Current extracted text is correct (`Entity: —`, `Oma pääoma`).
