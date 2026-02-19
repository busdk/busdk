# FEATURE_REQUESTS.md

Enhancement and "nice to have" requests for the BusDK toolset in the context of this repo's replay and parity work. **These do not block core work.** For actual bugs or issues that block our work, see **BUGS.md**.

**Last reviewed:** 2026-02-19.

---

## bus-bfl

### Feature request 3b: Formula metadata/evaluation for workbook extraction

**Target:** [bus-bfl](https://docs.busdk.com/sdd/bus-bfl). SDD FR-DAT-025 / formula evaluation.

**Status (re-checked 2026-02-19):** Implemented in current `bus-data`. `bus data table workbook` supports `--formula`, `--formula-source`, locale flags, and `--formula-dialect`; formula evaluation and locale-aware normalization are covered in README and tests.

**Still to do (optional enhancement):** Expand dialect/function coverage for broader spreadsheet parity scenarios if needed by specific replay datasets.

**Example:**
```bash
bus data table workbook source.csv A1:C10 --formula --decimal-sep "," --thousands-sep " " -f tsv
# Output: evaluated numeric values for formula cells; locale-aware normalization for "1 234,56" → 1234.56
```

**Verify (example):** In a workspace with a CSV that has formula cells and a schema defining formula fields: (1) `bus data table workbook <path> A1:C3 --formula -f tsv`; (2) assert output contains evaluated numeric values, not formula text. With locale: (3) same with `--decimal-sep "," --thousands-sep " "` and a cell "1 234,56"; (4) assert normalized value 1234.56 in output.

---

## bus-journal

### Feature request 11: Posting templates with automatic VAT split for bank-driven entries

**Target:** [bus-journal](https://docs.busdk.com/modules/bus-journal).

**Status (re-checked 2026-02-19):** Implemented in current `bus-journal`. `template post` and `template apply` are first-class, documented in module README/help, and covered by e2e tests.

**Still to do (optional enhancement):** Add richer template predicates or profile ergonomics if replay scripts require more matching dimensions.

**Example:**
```bash
bus journal template post --template-file posting-templates.yaml --template office-supplies --date 2026-01-15 --gross 124.00
bus journal template apply --bank-csv bank-rows.csv --config posting-templates.yaml
```

**Verify (example):** In a workspace with accounts and a template file: (1) run `bus journal template post --template-file posting-templates.yaml --template office-supplies --date 2026-01-15 --gross 124.00`; (2) assert output or posted lines show base + VAT split and balance. For apply: (3) create a minimal bank CSV with one row; (4) run `bus journal template apply --bank-csv bank-rows.csv --config posting-templates.yaml`; (5) assert one or more balanced journal entries posted and linked to the bank row.

### Feature request 16: Loan-payment classifier with principal/interest split

**Target:** [bus-journal](https://docs.busdk.com/modules/bus-journal).

**Status (re-checked 2026-02-19):** Implemented in current `bus-journal` classify flow. Loan-profile aware proposal/apply exists via `classify bank --loan-profiles`, plus `classify loan-propose` and `classify loan-apply` aliases.

**Still to do (optional enhancement):** Additional policy modes or deeper integration with external amortization sources can be added if required.

**Example:**
```bash
bus loans profile add --id lender-qred --liability-account 2641 --interest-account 9480 --reference-prefix "QRED"
bus journal classify loan-propose   # or: bus reconcile propose --source bank (with loan profile)
bus journal classify loan-apply --dry-run
bus journal classify loan-apply
```

**Verify (example):** (1) register a lender payment profile (liability account, interest account, reference pattern or loan id); (2) add a bank row that matches the lender (e.g. amount -500, reference "LOAN-1"); (3) run loan propose/classify command for loan payments; (4) assert output contains at least two lines (principal and interest/fee) with explicit split amounts and balanced total; (5) run apply (or dry-run) and assert journal has liability and finance-cost lines.

---

## bus-reconcile

### Feature request 18: Settlement-report ingestion for payout allocation (Paytrail-style)

**Target:** [bus-reconcile](https://docs.busdk.com/modules/bus-reconcile) + [bus-journal](https://docs.busdk.com/modules/bus-journal) + [bus-attachments](https://docs.busdk.com/modules/bus-attachments).

**Status (re-checked 2026-02-19):** Not implemented. 2024 replay currently requires manual extraction of settlement PDF totals (gross, base, VAT, transaction fee, provision, net payout) and manual journal posting for payout bank rows.

**Why this is needed:** Evidence-first replay can already store settlement PDFs as attachments, but there is no CLI flow to parse/ingest settlement breakdowns and produce deterministic payout postings/allocation proposals. This forces manual scripting and increases risk in high-volume payout months.

**Still to do:** Add a deterministic command to ingest settlement evidence (PDF/CSV/XLS), link it to `bank_row:<id>`, and generate:
- payout journal proposal: bank debit, fee debit, sales credit, VAT credit (using evidence totals)
- optional allocation proposal from settlement order/invoice references to invoice ids
- idempotent apply mode with explicit source ids
- dry-run/report mode for audit.
- batch mode for a full period/folder (`original/paytrail/YYYYMM/*`) that auto-maps settlement reference -> bank row and emits deterministic replay-ready command output.

**Example (when implemented):**
```bash
bus reconcile settlement propose --bank-id erp-bank-26859 --file original/paytrail/202411/8843961.pdf --provider paytrail
bus reconcile settlement apply --bank-id erp-bank-26859 --if-missing
```

**Verify (example):** (1) run propose against a known settlement report with totals and line breakdown; (2) assert output matches evidence totals exactly (gross/base/vat/fees/net); (3) apply and assert balanced journal lines with source-id traceability to bank row + settlement reference; (4) rerun with `--if-missing` and assert idempotent skip.

### Feature request 17: Post reconciled invoice payments to journal with evidence-native VAT split

**Target:** [bus-reconcile](https://docs.busdk.com/modules/bus-reconcile) + [bus-invoices](https://docs.busdk.com/modules/bus-invoices) + [bus-journal](https://docs.busdk.com/modules/bus-journal).

**Status (re-checked 2026-02-19):** Implemented in current `bus-reconcile` (initial scope) via `bus reconcile post`. The command converts existing `matches.csv` rows (`kind=invoice_payment`) into balanced journal postings using invoice evidence (headers + line rows), with VAT split, `--dry-run`, and idempotent skip behavior via `--if-missing`.

**Why this is needed:** In 2024 replay scripts we need explicit VAT-split postings for reconciled sales receipts while keeping replay deterministic and evidence-first. Without a dedicated command, implementers must perform manual/auxiliary arithmetic (for example gross bank amount minus invoice net), which is error-prone and should be owned by BusDK.

**Still to do (remaining scope):** Extend and harden the current implementation for full replay coverage:
- input: existing `matches.csv` rows (`invoice_payment`) + invoice datasets + bank rows
- output: balanced journal entries with explicit source-id contract (current implementation uses `voucher_id=bank:<bank_txn_id>`)
- sales: debit bank/cash account, credit sales account + VAT payable account using invoice-native totals/rates
- purchase: debit expense/asset + VAT receivable, credit bank/cash account (supported; requires purchase account flags)
- partial payments and rounding/conflict policy (current implementation rejects `match amount != invoice evidence gross`)
- broader e2e coverage and documentation sync across module/docs pages.

**Example:**
```bash
bus reconcile post --kind invoice_payment --bank-account 1910 --sales-account 3000 --sales-vat-account 2931 --purchase-account 4000 --purchase-vat-account 2930 --if-missing
```

**Verify (example):** In a workspace with invoices, invoice line rows, bank rows, and exact `bus reconcile match` rows: (1) run `bus reconcile post ... --dry-run`; (2) assert status output contains planned rows and no journal writes; (3) run without `--dry-run` and assert balanced journal rows with VAT split; (4) re-run with `--if-missing` and assert skipped/idempotent no-op for already posted vouchers; (5) verify voucher traceability `bank:<bank_txn_id>`.

### Feature request 6: Deterministic reconciliation candidate + batch apply commands

**Target:** [bus-reconcile](https://docs.busdk.com/modules/bus-reconcile).

**Status (re-checked 2026-02-19):** Implemented in current `bus-reconcile`. `propose` and `apply` are first-class with deterministic output, dry-run/idempotence, and CI-friendly flags (`--fail-if-empty`, `--fail-if-partial`). `match`, `allocate`, `list` remain available for one-off use.

**Still to do (docs alignment):** Ensure external docs reflect implemented state. Note: `-o/--output` is a global flag and must be placed before subcommand (`bus reconcile -o proposals.tsv propose`); `propose -o ...` is intentionally invalid.

**Example:**
```bash
bus reconcile propose > proposals.tsv
bus reconcile propose --fail-if-empty   # exit 1 when no proposals (CI)
bus reconcile apply --dry-run
bus reconcile apply
```

**Verify (example):** In a workspace with bank and invoice data: (1) `bus reconcile -o proposals.tsv propose` (global `-o` before subcommand) or `bus reconcile propose > proposals.tsv`; (2) note exit code; (3) if proposals exist, `bus reconcile apply --dry-run` then apply for real; (4) re-run propose and assert exit code is 0 when backlog is empty. For CI: (5) `bus reconcile propose --fail-if-empty` and assert exit 1 when no proposals (backlog or misconfiguration).

### Feature request 15b: Use extracted reference keys in reconciliation

**Target:** [bus-reconcile](https://docs.busdk.com/modules/bus-reconcile).

**Status (re-checked 2026-02-19):** Implemented in current `bus-reconcile`. `--match-by-reference` is accepted/documented, and extracted-key semantics (`erp_id` / `invoice_number_hint`) are active when fields are present.

**Still to do (optional clarity):** Keep precedence/diagnostic examples explicit in docs for conflicting-key scenarios.

**Example:**
```bash
# After bus-bank exposes erp_id / invoice_number_hint (Feature request 15a)
bus reconcile propose --match-by-reference   # proposals prefer bank invoice_number_hint → invoice number
bus reconcile apply
```

**Verify (example):** In a workspace where reconcile runtime is healthy and bank rows include extracted hints: (1) ensure a bank row has `invoice_number_hint` matching a sales invoice number; (2) run `bus reconcile propose --match-by-reference`; (3) assert at least one proposal matches that bank row to the invoice by extracted key (not only by amount); (4) run `bus reconcile apply` and assert match row references the invoice id.

### Feature request 19: Incoming-bank backlog classifier with internal-transfer pairing

**Target:** [bus-reconcile](https://docs.busdk.com/modules/bus-reconcile) + [bus-bank](https://docs.busdk.com/modules/bus-bank) + [bus-journal](https://docs.busdk.com/modules/bus-journal).

**Status (re-checked 2026-02-19):** Not implemented in current workflow. We can list unposted outgoing rows (`032`), but high-volume incoming backlog still requires manual triage between:
- true sales receipts,
- internal mirror transfers between own accounts (already posted on one side),
- owner funding/owner-loan inflows,
- refunds/reversals.

**Why this is needed:** 2024 replay still contains incoming rows where bank evidence alone is insufficient to post deterministically without manual pairing/classification work. A dedicated classifier would reduce manual ambiguity and avoid double-posting mirrored internal transfers.

**Still to do:** add deterministic propose/apply flow for incoming rows:
- detect mirror transfers by amount/date/counterparty/own-account metadata and mark one-sided no-op policy,
- detect owner-loan/owner-investment keywords (for example `Osakaslaina`, `Yksityissijoitus`) with configurable account mapping,
- emit unresolved evidence backlog report for rows needing human evidence decisions,
- support idempotent apply with explicit `--source-id`.

**Example (when implemented):**
```bash
bus reconcile incoming-propose --policy incoming-policy.yaml -o incoming-proposals.tsv
bus reconcile incoming-apply --proposal-file incoming-proposals.tsv --if-missing
```

**Verify (example):** (1) feed bank rows containing mirrored own-account transfers, owner-loan messages, and unresolved incoming receipts; (2) run propose and assert transfer pairs are identified and owner-loan proposals contain mapped accounts; (3) apply and assert deterministic journal rows are created only for resolved classes; (4) rerun with `--if-missing` and assert idempotent no-op.

---

## bus-reports

## bus-bank

### Feature request 24: Daily/month-end statement saldo extraction + deterministic balance check

**Target:** [bus-bank](https://docs.busdk.com/modules/bus-bank) + [bus-attachments](https://docs.busdk.com/modules/bus-attachments).

**Status (re-checked 2026-02-19):** Implemented in current `bus-bank`. `bus bank statement extract` ingests statement summary CSVs (or PDF evidence with sidecar `.statement.csv` + `.statement.schema.json`) into `bank-statement-checkpoints.csv` with provenance. `bus bank statement verify` compares checkpoints against `bank-transactions.csv` running balances and supports `--fail-if-diff-over` plus `tsv/csv/json` output.

**Why this is needed:** Evidence-based bookkeeping requires confirming that statement saldos match replay data, not only transaction row counts/sums. Today this requires ad-hoc scripting and filename heuristics, especially with mixed statement formats (OP CSV/PDF variants and account-specific files).

**Still to do (optional enhancements):**
- Add account-specific transaction filtering once bank datasets carry explicit account identifiers or a stable mapping layer.
- Expand PDF extraction beyond sidecar CSV conventions if needed for new statement formats.

**Example (when implemented):**
```bash
bus bank statement extract --file original/tiliotteet/2024/202412/202412-OP-Sendanor-Tiliote_2024-11-30_2024-12-31.pdf --account 10001
bus bank statement verify --year 2024 --format tsv --fail-if-diff-over 0.01
```

**Verify (example):** (1) extract balances from one known statement PDF and one CSV; (2) assert output includes opening balance, closing balance, and covered date range; (3) run verify for full year; (4) assert zero differences when replay data matches statement checkpoints; (5) modify one bank row amount in test fixture and assert verify exits non-zero with explicit period/account diff.

### Feature request 4: TASE / tuloslaskelma layout parity

**Target:** [bus-reports](https://docs.busdk.com/sdd/bus-reports). SDD FR-REP-004 defines configurable layout (hierarchy, labels, account→line mapping); no SDD change needed.

**Status (re-checked 2026-02-19):** Implemented in current `bus-reports` for built-in Finnish full layouts and custom layout files. Full line-by-line parity is achievable when workspace mapping (`report-account-mapping.csv`) is aligned with source line structure.

**Still to do (workspace-specific):** Ship/curate parity mapping profiles for target source datasets (for example replay-specific 2023 mapping), since line parity depends on account-to-line mapping quality.

**Example:**
```bash
bus reports balance-sheet --as-of 2023-12-31 --layout-id fi-pma-tase-full -f csv -o tase.csv
bus reports profit-and-loss --period 2023 --layout-id fi-kpa-tuloslaskelma-full -f csv -o tuloslaskelma.csv
# Or: --layout path/to/custom-layout.yaml with same line structure as original 2023 reports
```

**Verify (example):** In a workspace with 2023 data (e.g. `cd data/2023`): (1) `bus reports balance-sheet --as-of 2023-12-31 --layout-id pma-full -f csv -o balance.csv`; (2) `bus reports profit-and-loss --period 2023 --layout-id kpa-full -f csv -o pl.csv`; (3) diff line count and section order/labels against `original/2023/data/` TASE and TULOSLASKELMA exports; (4) assert each account from chart appears under the same Finnish line label as in the original, or document layout file that achieves parity. (Note: trial-balance accepts `-f csv` or `-f text`, not `tsv`.)

---

## bus-validate

### Feature request 14b: Class-aware gap validation thresholds

**Target:** [bus-validate](https://docs.busdk.com/modules/bus-validate).

**Status (re-checked 2026-02-19):** Implemented in current `bus-validate`. `journal-gap` supports per-bucket thresholds via `--bucket-thresholds` and per-bucket flags, with documented schema/examples and tests.

**Still to do (optional enhancement):** Expand curated real-world threshold presets if teams want standard policy bundles.

**Example:**
```bash
# Current: global threshold only
bus validate journal-gap --source imports/source-summary.tsv --exclude-opening --max-abs-delta 0.01

# Bucket-thresholds flag is accepted in current CLI; finalize and document contract:
bus validate journal-gap --source imports/source-summary.tsv --bucket-thresholds thresholds.yaml --exclude-opening
# thresholds.yaml: operational: 0, financing: 100, transfer: 50
```

**Verify (example):** (1) run `bus validate journal-gap --source <source-summary> --exclude-opening --max-abs-delta 0.01`; (2) assert exit 1 when absolute gap exceeds 0.01; (3) add config e.g. bucket `operational: 0`, `financing: 100`; (4) run validate with `--bucket-thresholds <config>`; (5) assert exit 1 when operational bucket exceeds 0 and exit 0 when only financing exceeds 0 but is under 100.

---

## bus-vat

### Feature request 2: Journal-driven VAT mode (legacy direction / non-P&L accounts)

**Target:** [bus-vat](https://docs.busdk.com/sdd/bus-vat). SDD FR-VAT-004; implementation status documents direction fallback.

**Status (re-checked 2026-02-19):** Implemented in current `bus-vat`. Journal-driven mode (`--source journal`) is supported with documented direction fallback (row direction -> `vat-account-mapping.csv` -> `accounts.csv` type) and coverage for legacy/non-P&L account mappings.

**Still to do (optional enhancement):** Add additional migration playbooks/presets for common country-specific account plans if needed.

**Example:**
```bash
# Add vat-account-mapping.csv with: account_id,direction (e.g. 1057,purchase and 2931,purchase)
bus vat report --period 2023-01 --source journal -f tsv
bus vat export --period 2023-01 --source journal
```

**Verify (example):** In a workspace with journal that posts to asset account 1057 (or 293x): (1) add `vat-account-mapping.csv` with header and row e.g. `account_id,direction` and `1057,purchase` (or per documented format); (2) run `bus vat report --period 2023-01 --source journal -f tsv`; (3) assert exit 0 and report shows period totals. Alternatively: (4) run in `data/2023` after adding only the mapping file; (5) assert no "missing direction" error for account 1057.

### Feature request 21: Filed-VAT import + period diff against Bus VAT outputs

**Target:** [bus-vat](https://docs.busdk.com/sdd/bus-vat) + [bus-data](https://docs.busdk.com/sdd/bus-bfl).

**Status (re-checked 2026-02-19):** Not implemented. We can produce VAT totals from replay (`bus vat report/export`), but there is no first-class CLI flow to import externally filed/manual ALV return values and diff them period-by-period against Bus outputs.

**Why this is needed:** Evidence-based bookkeeping requires deterministic reconciliation between replayed VAT and filed declarations. Current workflow requires ad-hoc parsing of external CSV/PDF exports, which is error-prone and not standardized in BusDK.

**Still to do:**
- add a normalized import command for filed VAT evidence (CSV/TSV and optionally OCR/PDF-assisted pipeline),
- store imported filed totals per period with provenance (source file, import timestamp),
- add deterministic diff command showing output VAT, deductible VAT, and net VAT deltas by period,
- support machine-readable output for CI (`tsv/csv/json`) and non-zero exit on configurable threshold.

**Example (when implemented):**
```bash
bus vat filed import --file original/alv/vero-summary.csv --format fi-oma-alo-summary --year 2024
bus vat filed diff --year 2024 --source journal -f tsv
```

**Verify (example):** (1) import a known filed VAT summary with at least 12 periods; (2) run diff against `--source journal`; (3) assert period-level columns include filed vs replay output/input/net VAT and deltas; (4) assert deterministic rerun produces identical diff; (5) assert `--fail-if-delta-over 0.01` exits non-zero when any period exceeds threshold.

### Feature request 22: Finnish cash-basis (`maksuperusteinen`) VAT mode from payment evidence

**Target:** [bus-vat](https://docs.busdk.com/sdd/bus-vat) + [bus-reconcile](https://docs.busdk.com/modules/bus-reconcile) + [bus-journal](https://docs.busdk.com/modules/bus-journal).

**Status (re-checked 2026-02-19):** Implemented in current `bus-vat` as first-class cash-basis mode for reporting/export.

**Current implementation:** `bus vat` supports `--basis cash` with `--source reconcile` (payment-evidence engine from `matches.csv` + `bank-transactions.csv`) and `--source journal` (payment-date evidence or bank transaction lookup). Partial payments are allocated proportionally with deterministic cent handling and auditable source refs.

**Still to do (remaining scope):**
- keep external docs fully aligned with implemented CLI/runtime details,
- improve operator ergonomics for required country context in EU/reverse-charge treatments,
- keep cross-module default-country behavior documented (`bus-preferences` + `bus-entities`/`bus-invoices` setters).

**Example:**
```bash
bus vat report --period 2024-08 --basis cash --source reconcile -f tsv
bus vat export --period 2024-08 --basis cash --source reconcile
```

**Verify (example):** (1) create invoices across multiple months with payments in different months (including partial payments); (2) run accrual mode and cash mode; (3) assert cash mode allocates VAT to payment month(s) and totals across year match evidence-backed payments; (4) assert deterministic rerun with same inputs yields identical output and source refs.

---

## bus-journal / Replay performance

### Feature request 20: Bulk journal posting input for replay-scale command streams

**Target:** [bus-journal](https://docs.busdk.com/modules/bus-journal) (performance ergonomics for deterministic replay).

**Status (re-checked 2026-02-19):** Not implemented as a first-class bulk replay command in current scripts. Large year replays execute thousands of individual `bus journal add` invocations.

**Why this is needed:** Full-year deterministic replays are command-heavy and can become slow in iterative bookkeeping loops. A bulk input mode would keep explicit command provenance while reducing per-process overhead.

**Still to do:** add a deterministic bulk mode (stdin/file) that accepts explicit journal rows with source IDs and preserves current validation/idempotency semantics.

**Example (when implemented):**
```bash
bus journal add-batch --input journal-commands.tsv --if-missing
```

**Verify (example):** (1) run baseline replay with existing per-row command stream and record wall-clock time; (2) run equivalent replay with `add-batch`; (3) assert identical journal rows and source-id behavior; (4) assert measurable runtime improvement on replay-scale datasets.

### Feature request 23: Configurable suspense/clearing account for unresolved bank allocations

**Target:** [bus-journal](https://docs.busdk.com/modules/bus-journal) + [bus-reconcile](https://docs.busdk.com/modules/bus-reconcile).

**Status (added 2026-02-19):** Not implemented as a configurable first-class fallback policy in current replay tooling.

**Why this is needed:** In evidence-first bookkeeping, some bank rows are known and valid but lack final allocation evidence at posting time (for example debt-collection remittance without line-level specification). A deterministic fallback to a configured suspense account (for example `1999 Selvittelytili`) is needed so replay can stay complete without ad-hoc script choices.

**Still to do:**
- add explicit configurable suspense account option in classify/reconcile apply flows,
- add configurable default account profile for related automatic posting cases, e.g.:
- `bank_account` (example `1910`)
- `internal_transfer_counter_account` (example `1911`)
- `receivables_settlement_account` (example `1700`)
- `customer_advance_account` / overpayment holding (example `2950`)
- `owner_loan_account` / owner funding fallback (example `2250`)
- `expense_refund_account` fallback for return/refund postings (example `8584`)
- require reason code/metadata when suspense fallback is used,
- keep source-id and evidence traceability,
- support deterministic reclassification workflow from suspense to final accounts when evidence arrives.

**Example (when implemented):**
```bash
bus reconcile apply --suspense-account 1999 --allow-unallocated --bank-account 1910 --receivables-account 1700 --advance-account 2950
bus journal reclassify --from-account 1999 --bank-row-id erp-bank-26277 --debit 1999=5.70 --credit 1700=5.70 --if-missing
```

**Verify (example):** (1) run apply on a bank row lacking final allocation evidence; (2) assert balanced posting to configured suspense account with reason metadata; (3) rerun idempotently and assert no duplicate posting; (4) run reclassification command with new evidence and assert suspense balance clears exactly.
