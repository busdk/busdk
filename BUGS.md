# BUGS.md

Track defects/blockers that affect this repo's replay/parity workflows.
Feature work belongs in `FEATURE_REQUESTS.md`.

**Last reviewed:** 2026-03-30.

## Active defects

- `bus-reports` `fi-kpa-tuloslaskelma-full` / `fi-kpa-tuloslaskelma-full-accounts` collapse deeper canonical `account-groups.csv` descendants back to visible ancestors instead of rendering the documented deeper grouped rows in statutory full profit-and-loss outputs.
- `bus-reports` grouped/full profit-and-loss outputs, including `*-accounts`, render expense-side child rows with positive visible statement amounts even when the parent expense section is shown negative.
- `bus-reports` `fi-kpa-tuloslaskelma-full-accounts` omits per-account drill-down rows for some visible statement lines even though `statement-explain` resolves those accounts to the same visible lines.
- `bus-reports` `fi-kpa-tase-full-accounts` omits part of the underlying account drill-down rows even when those accounts resolve cleanly to visible TASE lines.
- `bus-reports` `day-book` and `general-ledger` still expose long internal `transaction_id` / `entry_id` values directly in human-facing columns and still behave too whole-document-like in printable page-local column balancing.
- `bus-reports` printable table layout still fails to keep row height synchronized across cells when one cell wraps, so dense ledger rows stop reading as one coherent table row.
- `bus-reports` `day-book` and `general-ledger` do not preserve journal append order for same-day postings; same-date rows still sort by internal/string identifiers instead of business append order.
