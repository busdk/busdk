# FEATURE_REQUESTS.md

Enhancement requests for BusDK in this repo context.

Privacy rule for request write-ups:
- Keep examples/repro snippets sanitized (no real customer names/emails/IBANs/account numbers/invoice numbers/local paths).
- Prefer placeholders and aggregated outputs over raw customer-linked row dumps.

Last reviewed: 2026-02-23 (active rows re-tested against current CLI build).

Goal note:
- Target workflow is Bus-only for bookkeeping/audit operations.
- Operators should not need shell text pipelines (`grep/sed/awk/column`) to answer accounting control questions.

## Active requests

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

- FR56 - `bus period` deterministic reopen/reclose workflow for closed periods
  - Symptom:
    - Current period flow supports `open -> close -> lock`, but does not provide a deterministic/legal-safe reopen path for already closed periods.
    - Replay examples needing a controlled correction cycle (`close -> reopen -> correcting voucher -> reclose`) cannot be modeled natively.
  - Impact:
    - Correction handling must be approximated with ad-hoc workarounds instead of explicit lifecycle controls.
    - Audit trail for post-close corrections is weaker than needed in formal close processes.
  - Expected:
    - Explicit reopen command flow with controls, e.g.:
      - `bus period reopen --period YYYY-MM --reason <code/text> --approved-by <id>`
      - optional `--max-open-days` policy gate.
    - Deterministic status transitions:
      - `closed -> reopened -> closed` (and `locked` handling policy explicit).
    - Built-in audit metadata:
      - reopen timestamp, actor, reason, linked correction voucher IDs, reclose timestamp.
    - Deterministic reporting:
      - period history output includes reopen/reclose events and correction deltas.

- FR57 - `bus-reports` should provide filing-grade `Pääkirja` and `Päiväkirja` outputs with native PDF export
  - Symptom:
    - `bus reports general-ledger` exists, but `--format pdf` is rejected (`format pdf only applies to balance-sheet and profit-and-loss`).
    - There is no dedicated day-book report command/output (`paivakirja`) that can be generated as a filing artifact.
  - Impact:
    - Required Finnish bookkeeping artifacts (`Pääkirja`, `Päiväkirja`) cannot be produced end-to-end inside BusDK in one deterministic workflow.
    - Operators must use external conversion/manual formatting, weakening reproducibility and auditability.
  - Expected:
    - Native ledger report commands/targets for both:
      - general ledger (`Pääkirja`) and
      - day book (`Päiväkirja`).
    - Native output formats include at least `csv`, `markdown`, and `pdf`.
    - Deterministic sort and grouping controls:
      - `Päiväkirja`: by posting date then voucher/transaction id.
      - `Pääkirja`: by account then posting date then voucher/transaction id.
    - Optional headers/footers suitable for statutory archive package:
      - workspace id, fiscal year/period, generation timestamp, page numbering.

- FR58 - `bus` should provide `git log`-style terminal review UX for `Pääkirja` and `Päiväkirja`
  - Symptom:
    - Current CLI can output ledgers as datasets/reports, but interactive human review in terminal is not first-class for day-book workflow and is cumbersome for ledger triage.
  - Impact:
    - Operators must chain shell tools for routine investigation (scrolling, narrowing, grouping), which slows down accounting review and increases command drift.
  - Expected:
    - One-command terminal review mode for both views, e.g.:
      - `bus ledger log --period 2023` (day-book style timeline)
      - `bus ledger log --period 2023 --by-account` (general-ledger style)
    - `git log`-like ergonomics:
      - newest/oldest ordering switches,
      - compact default rows with expandable detail mode,
      - pager integration (`less`) and colorized debit/credit cues,
      - deterministic filters (`--account`, `--counterparty`, `--source-id`, `--from`, `--to`, `--text`),
      - deterministic stable identifiers in each row (`date`, `voucher_id`/`transaction_id`, `entry_id`, `source_id`).
    - Deterministic output presets:
      - `--view paivakirja`
      - `--view paakirja`
      - with machine-readable parity mode (`--format tsv|json`) for automation.

- FR59 - subledger day-book/general-ledger reports are needed for modules (`myyntireskontra`, `ostoreskontra`, `käyttöomaisuus`, inventory, payroll)
  - Symptom:
    - Main ledger reports exist, but there is no unified first-class command family to output osakirjanpito-specific `päiväkirja` and `pääkirja` views per module.
  - Impact:
    - Legal/audit extraction of “osakirjanpidot (jos käytössä)” requires ad-hoc dataset-specific workflows.
  - Expected:
    - Native report commands for each active subledger module with deterministic filters and period slicing.
    - Output formats include terminal review (`text/tsv/json`) and archive output (`csv/pdf`).
    - Deterministic link fields to main ledger (`voucher_id`, `entry_id`, `source_id`).

- FR60 - `bus-accounts` should support filing-grade `tililuettelo` output (including PDF)
  - Symptom:
    - `bus accounts list` supports only TSV output; no first-class `tililuettelo` report output contract or PDF.
  - Impact:
    - 10-year retained `tililuettelo` document needs external conversion/formatting.
  - Expected:
    - Command such as `bus reports chart-of-accounts` (or `bus accounts report`) with deterministic sorting/grouping.
    - Output formats include `text`, `csv`, `markdown`, and `pdf`.
    - Optional classification/group metadata rendering for statutory archive readability.

- FR61 - generate `luettelo kirjanpidoista ja aineistoista` (KPL 2:7a) natively from workspace metadata
  - Symptom:
    - No single command emits the required inventory of bookkeeping sets, material types, storage locations, and cross-links.
  - Impact:
    - Mandatory meta-documentation remains manual and can drift from actual workspace state.
  - Expected:
    - Native command (for example `bus reports materials-register`) that lists:
      - kirjanpidot (main + subledgers),
      - evidence/material classes,
      - dataset/file locations and retention classes,
      - relationship graph (`source_id`/attachment/reconcile/journal link paths).
    - Export formats include `json` (machine-checkable) and `pdf` (human archival).

- FR62 - `bus-reports` needs native `tase-erittely` generation (internal statement verification report) with PDF
  - Symptom:
    - Current report set does not expose a dedicated `tase-erittely` command/output contract.
  - Impact:
    - Internal statutory verification package requires manual assembly from multiple exports.
  - Expected:
    - Command such as `bus reports balance-sheet-specification --as-of YYYY-MM-DD`.
    - Deterministic drill-down from each balance-sheet line to underlying accounts and evidence references.
    - Output formats include `csv/markdown/json` and filing-grade `pdf`.
    - Explicit note that output is internal-only (not PRH attachment).

- FR63 - PRH-ready financial statement package generator with notes/signatures workflow
  - Symptom:
    - BuSDK can render balance sheet/profit and loss PDFs, but complete PRH package assembly (liitetiedot, signature/date block, optional auditor report/annual report/cash-flow/consolidation appendices) is not one deterministic workflow.
  - Impact:
    - Filing package creation requires manual document composition and increases compliance risk.
  - Expected:
    - One command to generate a period-scoped package manifest + output bundle:
      - mandatory: `tuloslaskelma`, `tase`, `liitetiedot`, signature/date section;
      - conditional: `tilintarkastuskertomus`, `toimintakertomus`, `rahoituslaskelma`, `konserniliitteet`.
    - Built-in privacy guardrails for public filing outputs (e.g. reject personal identity numbers in public payloads).
    - Deterministic package outputs as `pdf` bundle + machine-readable manifest (`json`).

- FR64 - VAT and authority-support calculation reports need first-class review UX and PDF export
  - Symptom:
    - `bus vat report` exists, but practical filing-support artifacts are primarily tabular/TSV and lack native PDF outputs and operator-friendly review mode.
  - Impact:
    - 6-year retained authority-support evidence (VAT calculation package) requires manual post-processing for archival and review.
  - Expected:
    - Native commands/presets for VAT filing-support packet generation per period:
      - summary totals,
      - row-level explain trace,
      - coverage diagnostics (especially in cash/reconcile basis mode).
    - Easy terminal review mode for period comparisons and drill-down.
    - Native archive outputs in `pdf` plus machine-readable `csv/json`.

- FR65 - native `seurantakohde`/dimension model for project and cost-center accounting
  - Symptom:
    - There is no first-class dimension model to tag ledger activity with internal tracking contexts (for example project, cost center, customer segment, grant/hanke).
    - Current workflows require ad-hoc conventions in descriptions/source ids instead of structured accounting dimensions.
  - Impact:
    - Internal management accounting (`projektikirjanpito`, `kustannuspaikka` tracking) is not deterministic or machine-checkable.
    - Reporting slices by project/cost center require fragile post-processing.
  - Expected:
    - Native dimension data model with deterministic IDs and values, for example:
      - dimension definitions (e.g. `Projekti`, `Kustannuspaikka`, `Asiakas`),
      - dimension values (e.g. `PROJ-001`, `KONSULT`, `ACME`),
      - posting links from journal rows (and module rows when applicable).
    - CLI ergonomics for posting-time assignment, for example:
      - `bus journal add ... --dim Projekti=PROJ-001 --dim Kustannuspaikka=KONSULT`.
    - Deterministic validation rules (unknown dimension/value rejection in strict mode; optional explicit `--allow-create` flow in setup mode).

- FR66 - dimension-aware reporting and ledger review (`Päiväkirja`/`Pääkirja`/module views)
  - Symptom:
    - Even where base reports exist, there is no first-class way to filter, group, and subtotal by internal dimensions (`seurantakohde`) across ledger and subledger views.
  - Impact:
    - Project/cost-center accounting cannot be reviewed end-to-end in Bus-only workflow.
    - Producing accountant-grade internal follow-up reports requires external spreadsheet tooling.
  - Expected:
    - Dimension filters and grouping across report/review commands, including:
      - `--dim Projekti=PROJ-001`,
      - `--group-by dim:Projekti`,
      - multi-dimension slices (project + cost center).
    - Deterministic outputs for:
      - `Päiväkirja` (date-first) and `Pääkirja` (account-first) with dimension columns,
      - project/cost-center subtotals and drill-down references (`voucher_id`, `entry_id`, `source_id`).
    - Native export support at least `csv/json` and archival `pdf` for dimension-scoped internal reports.

## Resolved / removed from active list (revalidated 2026-02-23)

- FR32 implemented: `bus-bank statement extract` accepts native PDF evidence without sidecar schema files; deterministic error messaging directs to sidecars only when native extraction fails.
- FR44 implemented: `bus-validate evidence-coverage` emits deterministic evidence coverage summaries and missing IDs for journal, bank, sales, and purchase scopes.
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
