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

## Resolved / removed from active list (revalidated 2026-02-23)

- FR56 implemented: `bus-period reopen` supports deterministic closed → reopened → closed transitions with audit metadata (`reopened_at`, `reopen_reason`, `reopen_approved_by`, `reopen_voucher_ids`, `reclosed_at`) plus `--max-open-days` policy checks and updated list/history outputs.
- FR54 implemented: `bus-invoices --legacy-replay` allows deterministic replay of non-normalized legacy rows with strict-mode failure guidance, warnings, and e2e/unit coverage.
- FR55 implemented: `bus-bank statement parse` and `statement verify --statement` provide canonical JSON parsing, confidence metadata, unknown-number warnings, and deterministic cross-check diagnostics.
- FR64 implemented: `bus-vat review` emits authority-support review packets (summary, explain, coverage diagnostics) with TSV/JSON/CSV/PDF outputs and deterministic PDF metadata.
- FR32 implemented: `bus-bank statement extract` accepts native PDF evidence without sidecar schema files; deterministic error messaging directs to sidecars only when native extraction fails.
- FR34 implemented: statement extract profiles support date/number parsing hints (`date_format`, `decimal_char`, `group_char`, `unicode_minus`) with CLI overrides, plus deterministic diagnostics, tests, and docs updates.
- FR44 implemented: `bus-validate evidence-coverage` emits deterministic evidence coverage summaries and missing IDs for journal, bank, sales, and purchase scopes.
- FR57 implemented: `bus reports general-ledger` and `bus reports day-book` support filing-grade outputs with deterministic ordering and PDF export alongside CSV/Markdown/text.
- FR60 implemented: `bus accounts report` renders a filing-grade tililuettelo with text/tsv/csv/markdown/pdf outputs and deterministic ordering.
- FR61 implemented: `bus reports materials-register` emits a deterministic materials register with linkage metadata and JSON/PDF outputs.
- FR62 implemented: `bus reports balance-sheet-specification` outputs deterministic tase-erittely drill-downs with CSV/Markdown/JSON/PDF and internal-only labeling.
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
