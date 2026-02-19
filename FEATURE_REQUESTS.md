# FEATURE_REQUESTS.md

Enhancement and "nice to have" requests for the BusDK toolset in this repo's replay/parity work. These are requests that are not fully implemented yet. For blocking defects, see `BUGS.md`.

Privacy rule for request write-ups:
- Keep examples/repro snippets sanitized (no real customer names/emails/IBANs/account numbers/invoice numbers/local paths).
- Prefer placeholders and aggregated outputs over raw customer-linked row dumps.

**Last reviewed:** 2026-02-19.

Implemented requests are removed from this file. This file tracks active requests only.

---

## bus-reconcile

### Feature request 18: Settlement-report ingestion for payout allocation (Paytrail-style)

**Target:** [bus-reconcile](https://docs.busdk.com/modules/bus-reconcile) + [bus-journal](https://docs.busdk.com/modules/bus-journal) + [bus-attachments](https://docs.busdk.com/modules/bus-attachments).

**Status:** Not implemented.

**Still to do:**
- Add deterministic settlement evidence ingestion/propose/apply flow (PDF/CSV/XLS).
- Link proposal/apply output to `bank_row:<id>` with explicit source ids.
- Support dry-run, idempotent apply, and period/folder batch mode.

### Feature request 19: Incoming-bank backlog classifier with internal-transfer pairing

**Target:** [bus-reconcile](https://docs.busdk.com/modules/bus-reconcile) + [bus-bank](https://docs.busdk.com/modules/bus-bank) + [bus-journal](https://docs.busdk.com/modules/bus-journal).

**Status:** Not implemented.

**Still to do:**
- Deterministic propose/apply flow for incoming rows.
- Mirror transfer pairing and one-sided no-op policy.
- Configurable owner-loan/investment keyword mapping.
- Unresolved backlog output and idempotent apply.

---

## bus-bank

### Feature request 24: Daily/month-end statement saldo extraction and deterministic balance check

**Target:** [bus-bank](https://docs.busdk.com/modules/bus-bank) + [bus-attachments](https://docs.busdk.com/modules/bus-attachments).

**Status:** Not implemented.

**Still to do:**
- Extract statement opening/closing balances from evidence (PDF/CSV) with provenance.
- Persist checkpoints and compare to workspace running balances.
- Add CI/audit outputs (`tsv/csv/json`) with threshold-based failure.

### Feature request 25: Robust ERP TSV bank import profile (malformed free-text tab tolerance)

**Target:** [bus-bank](https://docs.busdk.com/modules/bus-bank).

**Status:** Not implemented.

**Still to do:**
- Add built-in ERP TSV import profile tolerant to malformed free-text tab-like separators.
- Preserve key fields (`bank_account_row_id`, date, amount, reference, counterparty, message, IBAN).
- Emit deterministic parse diagnostics (`recovered_rows`, `ambiguous_rows`, `dropped_rows`) with optional fail-on-ambiguity mode.

---

## bus-attachments

### Feature request 27: Attachment link graph and filter/list commands

**Target:** [bus-attachments](https://docs.busdk.com/modules/bus-attachments) + [bus-journal](https://docs.busdk.com/modules/bus-journal) + [bus-reconcile](https://docs.busdk.com/modules/bus-reconcile).

**Status:** Not implemented.

**Still to do:**
- Add list filters (`--by-bank-row`, `--by-voucher`, `--by-invoice`, date filters, `--unlinked-only`).
- Add reverse-link graph output (attachment -> linked resources).
- Add link-many behavior (`attachment add` once, then `attachment link` to more resources).
- Add strict audit flags (`--fail-if-unlinked`, `--fail-if-missing-kind ...`).

---

## bus-vat

### Feature request 21: Filed-VAT import and period diff against Bus VAT outputs

**Target:** [bus-vat](https://docs.busdk.com/modules/bus-vat) + [bus-data](https://docs.busdk.com/modules/bus-data).

**Status:** Not implemented.

**Still to do:**
- Import externally filed VAT evidence with provenance.
- Add deterministic period diff command (filed vs replay output/input/net VAT).
- Provide machine-readable output and threshold-based non-zero exit.

---

## bus-journal

### Feature request 20: Bulk journal posting input for replay-scale command streams

**Target:** [bus-journal](https://docs.busdk.com/modules/bus-journal).

**Status:** Not implemented.

**Still to do:**
- Add deterministic bulk posting mode (stdin/file) with current validation/idempotency semantics.
- Preserve source-id traceability while reducing per-process overhead.

### Feature request 23: Configurable suspense/clearing account for unresolved bank allocations

**Target:** [bus-journal](https://docs.busdk.com/modules/bus-journal) + [bus-reconcile](https://docs.busdk.com/modules/bus-reconcile).

**Status:** Not implemented.

**Still to do:**
- Add configurable suspense fallback account (for example `1999`) in reconcile/classify apply flows.
- Require reason metadata and preserve source-id/evidence traceability.
- Add deterministic reclassification workflow from suspense to final account.

### Feature request 26: Deterministic suspense reclassification flow (`1999` backlog)

**Target:** [bus-journal](https://docs.busdk.com/modules/bus-journal) + [bus-reconcile](https://docs.busdk.com/modules/bus-reconcile).

**Status:** Not implemented.

**Still to do:**
- Add propose/apply reclassification for already-posted suspense rows.
- Support selectors (bank row/date/counterparty/reference/amount), dry-run, idempotent apply, and audit export.
