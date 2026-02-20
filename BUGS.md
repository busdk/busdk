# BUGS.md

Track **defects and blockers** that affect this repo's replay or parity work: actual bugs in our software or in BusDK/tooling when they block us. **Nice-to-have features and enhancement requests** are in **[FEATURE_REQUESTS.md](FEATURE_REQUESTS.md)**.

**Last reviewed:** 2026-02-20 (retested in current workspace after replay updates).

---

## Active issues

### 2026-02-20 - `bus status readiness` ignores `--year`, `--format`, and `--compliance` semantics

Symptom:
- `bus status readiness` returns the same TSV output regardless of year/format/compliance flags.

Impact:
- Cannot use `bus status readiness` as deterministic close-state gate per fiscal year.
- Legal/compliance status cannot be machine-read in requested format.

Repro:
1. `cd data/2024 && bus status readiness --year 2024 --format json --strict`
2. `cd data/2024 && bus status readiness --compliance --year 2024 --format json`

Observed:
- Both commands return identical TSV with `year=2026` and no JSON/compliance object output.

Expected:
- `--year` scopes checks/output to the requested fiscal year.
- `--format json` returns JSON.
- `--compliance` returns compliance-demand output (or a clear not-implemented error), not silently ignored behavior.

### 2026-02-20 - `bus-vat --strict-fi-eu-rc` is advertised but rejected as unknown flag

Symptom:
- `bus-vat --help` advertises `--strict-fi-eu-rc`, but commands reject it.

Impact:
- FI reverse-charge strict gate cannot be used deterministically in VAT validation/reporting flows.
- Operators may assume strict checks are active when they are not.

Repro:
1. `bus-vat --help`
2. `cd data/2024 && bus-vat validate --strict-fi-eu-rc`

Observed:
- Help includes `--strict-fi-eu-rc`.
- Runtime exits with: `bus-vat: unknown flag: --strict-fi-eu-rc`.

Expected:
- Either:
  1. Flag is accepted and enforced as documented, or
  2. Flag is removed from help until implemented.

### 2026-02-20 - `bus-vat report --from/--to` path fails with accounting-entity error in replay workspace where `--period` works

Symptom:
- Date-range mode (`--from/--to`) fails in `data/2024`, while period mode works in the same workspace.

Impact:
- Abnormal VAT period workflows cannot rely on date-range execution.
- Blocks deterministic filed-period alignment without shell-based workarounds.

Repro:
1. `cd data/2024 && bus-vat report --period 2024-01`
2. `cd data/2024 && bus-vat report --from 2024-01-01 --to 2024-01-31`

Observed:
- Step 1 runs.
- Step 2 fails with: `bus-vat: datapackage.json missing busdk.accounting_entity`.

Expected:
- `--from/--to` should run under the same workspace preconditions as `--period` mode, or provide a deterministic migration hint if stricter requirements are intentional.

### 2026-02-20 - `bus bank backlog -f json` (flag after subcommand) silently returns TSV instead of error or JSON

Symptom:
- `bus bank backlog -f json` outputs TSV while `bus bank -f json backlog` outputs JSON.

Impact:
- Easy to produce wrong-format output in scripts/automation without noticing.
- CLI behavior is non-obvious because the same `-f json` intent yields different output depending on flag position.

Repro:
1. `cd data/2025 && bus bank backlog -f json`
2. `cd data/2025 && bus bank -f json backlog`

Observed:
- Step 1 returns TSV table.
- Step 2 returns JSON object.
- No explicit warning/error in step 1 that `-f` was ignored as a global flag.

Expected:
- Either:
  1. reject step 1 with clear error (`global flags must appear before subcommand`), or
  2. accept it consistently and return JSON.

### 2026-02-20 - Inconsistent `sales-invoices.total_net` semantics between `bus-invoices list` validation and `bus-reconcile match` amount checks

Symptom:
- If `sales-invoices.total_net` is set to line-net sum (field name suggests net), `bus-invoices list` accepts it but `bus-reconcile match` rejects real bank receipts that match invoice gross.
- If `sales-invoices.total_net` is set to gross, `bus-reconcile match` accepts but `bus-invoices list` fails with total-vs-lines mismatch.

Impact:
- Replay cannot satisfy both invoice validation and reconciliation posting workflows with one canonical value model.
- Blocks deterministic evidence-first flow for VAT/payment posting on invoices.

Repro (sanitized pattern):
1. Prepare one sales invoice with taxable line(s):
   - line net sum = `N`
   - gross = `G` (`G != N`)
2. Set `sales-invoices.total_net = N`; run:
   - `bus invoices list --type sales` (passes for this invoice)
   - `bus reconcile match --bank-id <incoming G> --invoice-id <invoice>` (fails: amount/currency mismatch)
3. Set `sales-invoices.total_net = G`; run:
   - `bus reconcile match ...` (passes)
   - `bus invoices list --type sales` (fails: `total_net does not match sum of line amounts`)

Observed in repo:
- `cd data/2025 && bus invoices list --type sales` fails on invoice `s6929` when header is gross-style.
- Changing those headers to net-style caused `exports/2025/009-journal-2025-06.sh` reconcile match to fail (`amount or currency does not match invoice s6931`) during replay.

Expected:
- One deterministic, consistent invoice amount model across modules:
  - Either reconcile compares against computed gross from lines independently of `total_net`,
  - or invoice header has separate explicit net/gross fields and all modules use them consistently.

### 2026-02-20 - `bus-reconcile post --kind invoice_payment` rejects all matched rows in real replay flow (`partial posting not supported` + gross mismatch)

Symptom:
- `bus-reconcile post --kind invoice_payment` rejects matched payment rows in replay workspaces, including practical partial-payment cases and rows that were accepted by `bus reconcile match/allocate`.

Impact:
- Cannot deterministically convert match rows to sales/VAT journal postings in normal cash-receipt workflows.
- Leaves receivables-clearing (`1700`) parked with no native posting flow for many matched bank receipts.

Repro (current repo state):
1. `cd data/2025 && make export && make ready`
2. `cd data/2025 && bus reconcile list`
3. `cd data/2025 && bus reconcile post --kind invoice_payment --bank-account 1911 --sales-account 3001 --sales-vat-account 2931`

Observed:
- Every row is returned as `rejected`.
- Typical rejection message:
  - `match amount does not equal invoice evidence gross (partial posting not supported)`.
- Rejections include both explicitly allocated partial payments (for example invoice `s6929`) and rows that were matched as reference-exact.

Expected:
- Deterministic posting flow should support normal business cases:
  1. full-payment invoice matches,
  2. partial payments (with remaining open balance),
  3. consistent gross/net handling with invoice-line VAT semantics used by `bus-invoices`.

### 2026-02-20 - `bus reconcile propose` fails on missing monthly journal schema in workspace where validation passes

Symptom:
- `bus reconcile propose` fails with missing file error for `journal-<year>-12.schema.json` even when workspace validates and uses consolidated `journal-<year>.csv`.

Impact:
- Cannot generate deterministic proposal backlog for further invoice/purchase matching.
- Blocks reconciliation improvement workflow in active 2025 close work.

Repro:
1. `cd data/2025 && make export && make ready`
2. `cd data/2025 && bus reconcile propose`

Observed:
- Command exits with:
  - `bus-reconcile: failed to open schema .../journal-2025-12.schema.json: ... no such file or directory`
- Same workspace passes `bus validate`.

Expected:
- `bus reconcile propose` should follow the active workspace journal model (consolidated `journal-2025.csv` in this replay) and not require nonexistent monthly journal schema side-files.

### 2026-02-20 - Multiple Bus commands fail on missing `journal-YYYY-12.schema.json` in consolidated-journal workspaces

Symptom:
- Commands that should work on consolidated year journal files fail by requiring a nonexistent monthly schema file:
  - `bus reports annual-validate`
  - `bus reports trial-balance`
  - `bus journal account-activity`
  - `bus reconcile propose`

Impact:
- Blocks deterministic annual legal-readiness checks in active close workflows.
- Breaks account-audit controls (`account-activity`) and report generation gates in workspaces that otherwise pass `bus validate`.

Repro:
1. `cd data/2025 && make export && make ready`
2. `cd data/2025 && bus reports annual-validate --period 2025 -f json`
3. `cd data/2025 && bus reports trial-balance --as-of 2025-12-31 -f csv`
4. `cd data/2025 && bus journal account-activity --account 1700 --period 2025 --opening all`
5. `cd data/2025 && bus reconcile propose`

Observed:
- All above commands fail with missing monthly schema errors, for example:
  - `... missing journal-2025-12.schema.json`
- Same workspace still passes `bus validate` and can replay successfully.

Expected:
- Commands should operate against the active workspace journal model (consolidated `journal-YYYY.csv`) without requiring nonexistent monthly journal schema files.
