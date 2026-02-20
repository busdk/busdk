# FEATURE_REQUESTS.md

Enhancement requests for BusDK in this repo context.

Privacy rule for request write-ups:
- Keep examples/repro snippets sanitized (no real customer names/emails/IBANs/account numbers/invoice numbers/local paths).
- Prefer placeholders and aggregated outputs over raw customer-linked row dumps.

Last reviewed: 2026-02-20 (tooling revalidated).

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

- FR47 - reconcile propose needs deterministic invoice-first mode and noise suppression
  - Symptom:
    - `bus-reconcile propose` on active workspaces emits very large proposal sets dominated by `exact_match_journal` rows, including already-posted duplicates.
  - Impact:
    - Hard to use propose/apply as a controlled accounting workflow for backlog resolution.
    - Operators cannot deterministically isolate invoice-payment candidates without manual filtering.
  - Expected:
    - Proposal mode with deterministic selectors and suppression options, for example:
      - `--target-kind invoice_payment`
      - `--exclude-exact-journal`
      - `--exclude-already-matched`
      - account/date/reference filters
    - Stable confidence ordering and bounded output for replay-scale workspaces.

- FR48 - account-activity needs explicit date-range/month scope flags
  - Symptom:
    - `bus-journal account-activity` currently accepts yearly `--period` but not `--from/--to` or `YYYY-MM` period scopes.
  - Impact:
    - Month-level and arbitrary-range audit checks still require external workarounds.
  - Expected:
    - Support `--from YYYY-MM-DD --to YYYY-MM-DD` and `--period YYYY-MM` in addition to yearly scope.
    - Keep current summary output model (opening/non-opening split, counterparts, transaction shapes).

- FR49 - bus-bank needs deterministic single-row add/upsert command for replay scripts
  - Symptom:
    - Replay scripts currently use `bus data row add bank-transactions ...` and `bus data row add bank-imports ...` because `bus-bank` has import/list/backlog/statement/config, but no direct row-level add/upsert commands for these canonical datasets.
  - Impact:
    - Scripted bookkeeping must mix generic `bus data` mechanics into accounting flows for core bank evidence rows.
    - Harder to enforce bank-domain validations and stable idempotency at command level.
  - Repro:
    1. `bus bank --help` (no `add`/`upsert` for transaction rows)
    2. `rg -n "bus data row add bank-transactions" exports/2024 exports/2025 exports/2026`
  - Expected:
    - Native command, for example:
      - `bus bank add --bank-id <id> --booked-date <date> --value-date <date> --amount <decimal> --currency EUR --counterparty ... --reference ... --message ... --source-id ... --if-missing`
      - `bus bank import-log add --import-id <id> --source-path <path> --imported-at <ts> --if-missing`
    - Deterministic primary-key/idempotency semantics and domain validation in `bus-bank`, so replay scripts do not need `bus data row add bank-transactions` or `bus data row add bank-imports`.

- FR50 - bus-reports needs mapping row add/upsert command (avoid `bus data` editing of report-account-mapping)
  - Symptom:
    - Report mapping adjustments in replay currently require `bus data row add report-account-mapping ...`.
  - Impact:
    - Financial statement mapping edits bypass report-domain validation and become generic CSV mutations.
  - Repro:
    1. `bus reports --help` (has `mapping-template`, but no mapping row write command)
    2. `rg -n "bus data row add report-account-mapping" exports/2024 exports/2025`
  - Expected:
    - Native command family, for example:
      - `bus reports mapping add|upsert --statement-target <tase|tuloslaskelma> --layout-id <id> --account <code> --line-id <line> [--normal-side ...]`
    - Same strict mapping validation used by report generation (`unknown target/layout/line` should fail deterministically).

- FR51 - bus-invoices needs full-fidelity replay add/upsert (header + line fields parity with canonical datasets)
  - Symptom:
    - Current `bus invoices add` / `<invoice-id> add` surface is minimal and cannot set key canonical fields used in replay datasets.
  - Gap observed:
    - Header-side missing settable fields for replay parity:
      - `number`, `status`, `currency`, `total_net` (and deterministic explicit `invoice_id` idempotency controls beyond simple create).
    - Line-side missing settable fields for replay parity:
      - explicit `line_no` for deterministic line ordering/index stability in script replays.
  - Impact:
    - Replacing `bus data row add sales-invoices|purchase-invoices|sales-invoice-lines|purchase-invoice-lines` with direct invoice commands would currently lose fidelity or change deterministic parity behavior.
  - Repro:
    1. `bus invoices add --help`
    2. `bus invoices s1 add --help`
    3. Compare fields in `exports/2026/017-erp-invoices-2026.sh` invoice rows.
  - Expected:
    - Native invoice replay command mode (or enhanced add/upsert flags) that can set all canonical invoice header/line fields needed for deterministic parity-preserving replays, including explicit line numbering and idempotent upsert semantics.

- FR52 - bus-reconcile needs deterministic partial-payment posting flow for invoice matches
  - Symptom:
    - In practical replay datasets, one invoice is often paid in multiple bank receipts; current posting flow rejects such rows (`partial posting not supported`) when converting matches to journal sales/VAT postings.
  - Impact:
    - Receivables-clearing balances remain parked even when evidence-backed match rows exist.
    - Operators must handcraft journal postings instead of using deterministic reconcile-post workflow.
  - Expected:
    - `bus reconcile post --kind invoice_payment` should support:
      - partial payments with residual open balance tracking,
      - deterministic idempotent posting per match row,
      - consistent VAT split using invoice-line evidence at payment level,
      - clear output fields for posted-vs-open remainder by invoice.

- FR53 - bus-bank needs deterministic posting-coverage report (bank row -> journal/reconcile state)
  - Symptom:
    - Current `bus bank backlog` reports posted/unposted counts that reflect reconcile state, not full accounting posting state.
    - It does not answer the legal audit question: "does every bank transaction have accounting posting coverage?"
  - Impact:
    - Checklist evidence for "all bank rows classified/posted" still requires external joins over bank rows, journal `source_id`, and matches.
    - Operators can incorrectly assume bookkeeping is complete from backlog alone.
  - Expected:
    - New command (for example `bus bank coverage --year YYYY`) with deterministic buckets per bank row:
      - `journal_linked` (source-id link to journal),
      - `reconcile_linked`,
      - `both`,
      - `none`,
      - optional `suspense_linked`.
    - Machine-readable output with stable IDs (`bank_txn_id`, `source_id`, coverage state, reason code).

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
- FR40 moved to `BUGS.md` as defect:
  - `--strict-fi-eu-rc` is currently advertised but rejected as unknown flag.
