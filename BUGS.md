# BUGS

Track defects and blockers that affect replay/parity work in this repository.
Enhancement requests belong in [FEATURE_REQUESTS.md](FEATURE_REQUESTS.md).

**Last reviewed:** 2026-02-20.

---

## Active issues

None currently tracked.

## Resolved issues

### 2026-02-20 - FR28 runtime mismatch (`--explain-mapping` unknown) in local `bus-reports` (resolved)
- Current local runtime now supports `--explain-mapping` and emits mapping diagnostics.

### 2026-02-20 - `bus reports` PDF Unicode extraction mojibake in metadata/labels (resolved)
- Resolution was verified in this workspace by regenerating 2023 report PDFs and extracting text with `pdftotext`.
- Current extracted text is correct (`Entity: —`, `Oma pääoma`).

### 2026-02-20 - `bus period close` `journal date parse failed` in replay/index-layout workspaces (resolved)
- `bus-period close` now supports both legacy single-file journal rows (`date`, `debit`, `credit`, `amount`) and bus-journal index rows (`posting_date`, `account_id`, `debit`, `credit`) for deterministic close processing.
- Verification in this workspace:
  - unit tests: `go test ./...` in `bus-period` passed
  - e2e: `bus-period/tests/e2e_bus_period.sh` passed, including an index-layout close regression case
  - close output now generates deterministic closing leg IDs in `journal-<period>.csv` for index layout.
