# FEATURE_REQUESTS.md

Enhancement requests for BusDK in this repo context.

Privacy rule for request write-ups:
- Keep examples/repro snippets sanitized (no real customer names/emails/IBANs/account numbers/invoice numbers/local paths).
- Prefer placeholders and aggregated outputs over raw customer-linked row dumps.

Last reviewed: 2026-02-25 (active rows re-tested against current CLI build; no open feature backlog).

Goal note:
- Target workflow is Bus-only for bookkeeping/audit operations.
- Operators should not need shell text pipelines (`grep/sed/awk/column`) to answer accounting control questions.

## Active requests

- None.

## Resolved / removed from active list (revalidated 2026-02-25)

- FR45 implemented: `bus status readiness --year ... --compliance fi --format json|tsv` returns deterministic gates and regulatory demand sections.
- FR47 implemented: `bus reconcile propose` includes `--target-kind`, `--exclude-exact-journal`, `--exclude-already-matched`, and scoped selectors.
- FR48 implemented: `bus journal account-activity` accepts explicit date ranges and month-style period values.
- FR52 implemented: `bus reconcile post --kind invoice_payment` supports partial-payment planning/output with `posted_amount` and `open_amount`.
- FR53 implemented: `bus bank coverage --year YYYY` exists and returns deterministic per-row coverage states (current correctness defect tracked in `BUGS.md`).
- FR38 implemented: `bus-vat fi-file` emits FI VAT filing payload fields.
- FR39 implemented: `bus-vat explain` provides row-level FI VAT field trace.
- FR41 implemented at command level: `bus-vat period-profile` exists.
- FR42 implemented: VAT output includes explicit rounding policy metadata.
- FR43 implemented: `bus-journal account-activity` exists.
- FR49 implemented: `bus-bank add` and `bus-bank import-log add` exist.
- FR50 implemented: `bus-reports mapping add|upsert` exists.
- FR51 implemented: `bus-invoices add` and `<invoice-id> add` now expose replay-needed flags (`--number`, `--status`, `--currency`, `--total-net`, `--line-no`, `--upsert`).
- FR46 implemented at command level: `bus assets lifecycle baseline|rollforward|proposals` and deterministic carry-forward helper `bus period opening --from <prior-workspace> --as-of <date> --post-date <date> --period <YYYY-MM>`.
- FR54 implemented: `bus invoices --legacy-replay add ...` preserves legacy source rows while warning about non-normalized date semantics.
- FR55 implemented at command-family level: `bus bank statement extract|parse|verify` now provides parsed statement checkpoints, cross-check verification, confidence/provenance fields, and `unknown_numbers` diagnostics.
- FR56 implemented: `bus period reopen --period YYYY-MM --reason <...> --approved-by <...>` is available (including dry-run support).
- FR57 implemented: `bus reports day-book --period ... -f pdf` and `bus reports general-ledger --period ... -f pdf` generate filing-grade PDF outputs.
- FR58 implemented: `bus reports ledger-log --period ... --view paivakirja|paakirja` with review filters and terminal-friendly output.
- FR59 implemented at command level: ledger reports support module-scoped views and deterministic link fields (`voucher_id`, `entry_id`, `source_id`) via `day-book`/`general-ledger`/`ledger-log` command family.
- FR60 implemented: `bus accounts report -f pdf` provides filing-grade `tililuettelo` output.
- FR61 implemented: `bus reports materials-register` provides native `luettelo kirjanpidoista ja aineistoista` output (`json`/`pdf` supported).
- FR62 implemented: `bus reports balance-sheet-specification --as-of ...` provides native `tase-erittely` output (`csv|json|pdf`).
- FR63 implemented at workflow layer: `bus reports filing-package --period ...` provides deterministic package manifest (including notes/signatures/conditional appendices), and `bus filing-prh` command family is available for bundle generation.
- FR64 implemented: `bus vat review --period ... -f pdf|json` provides first-class authority-support review packet outputs.
- FR65 implemented: first-class dimension model is available in `bus-journal` (`--dim`, strict unknown-dimension rejection, optional `--allow-create` setup flow).
- FR66 implemented: dimension-aware ledger reporting is available (`--dim`, `--group-by dim:<id>`, and exports on `day-book`/`general-ledger`/`ledger-log`).
- FR44 implemented: `bus audit evidence-coverage` provides deterministic scope totals (`journal/bank/sales/purchase`) and machine-readable missing rows with `source_id`/`voucher_id`/`bank_txn_id`/`invoice_id`.
- FR32 treated as resolved upstream per maintainer direction; local runtime verification is currently constrained by non-operational `bus update` path in this environment.
- FR34 treated as resolved upstream per maintainer direction; local runtime verification is currently constrained by non-operational `bus update` path in this environment.
