# AGENTS.md - Generic Bus Accountant Playbook

Purpose:
- Define a reusable accountant operating model for BusDK workspaces.
- Keep bookkeeping evidence-based, deterministic, and audit-ready.
- Avoid tool/process drift between years.

Scope boundaries:
- `.bus` scripts are authoritative change points.
- `data/` workspaces are replay outputs; do not hand-edit generated datasets.
- `synthetic-evidence/` evidence trees are read-only source material; do not mutate evidence files.

Core principles:
- Evidence-first bookkeeping:
  - Do not invent transactions or tax treatment.
  - Every posting must map to evidence (statement, invoice, receipt, authority file, or internal voucher).
  - If evidence is missing, continue other work and track blockers in `MISSING.md`.
- Bus-first execution:
  - Use Bus module commands for accounting operations.
  - Avoid direct CSV editing and shell text pipelines for accounting decisions.
  - If a needed operation is missing, file a feature request.
- Deterministic replay:
  - Keep scripts explicit, date-ordered, and idempotent where possible.
  - Prefer one contiguous evidence block per business event.
  - Use explicit `--source-id` on journal rows for traceability.

Evidence hierarchy and matching:
- Use bank/invoice reference numbers as primary match keys where available.
- Use amount/date/counterparty only as secondary matching evidence.
- Keep both directions auditable:
  - entry -> evidence
  - evidence -> entry (e.g., bank row id to journal/reconcile links).
- Shared evidence files can legitimately support multiple postings if documented.

Posting and reconciliation rules:
- Every transaction must balance (debit == credit).
- Reconcile bank rows to invoices/journal deterministically.
- For unresolved rows, use explicit suspense/clearing flow; never hide ambiguity.
- Reclassify suspense with explicit reason/evidence once resolved.
- Keep internal transfers directional and non-collapsing between own bank accounts.

VAT operating rules (generic Finland-oriented controls):
- Use configured VAT basis and period profile in commands explicitly.
- Filing chronology: period N filed in next period filing window (commonly day 12).
- VAT comparisons against filed evidence must use true filed period ranges, not month label only.
- Support abnormal period lengths (multi-month periods) in tie-out logic.
- Treat manual VAT summaries as cross-check evidence, not automatic source of truth.

Period and close discipline:
- Open/close/lock states must be controlled and reproducible.
- After replay commands that reset state, re-run required close/lock steps before legal-status checks.
- Capture close controls with evidence and deterministic command history.
- True reopen/reclose correction flow should be explicit when supported by tooling.

Year-end minimum deliverables:
- Validation pass (`bus validate` or equivalent ready target).
- Trial balance.
- Profit/loss statement.
- Balance sheet.
- VAT outputs (period + annual if required).
- Journal balance/control outputs.
- Reproducible replay from scripts only.

Checklist-grade legal controls:
- Verify cut-off, accrual/deferral logic, asset/depreciation consistency, loan/owner classifications.
- Ensure tax bridge/workpaper trace exists (book result -> taxable result) when required.
- Ensure filing/payment confirmation evidence is archived for VAT and other tax filings.
- Respect legal form differences (for example Tmi vs Oy obligations).
- Keep retention baseline visible:
  - accounting books/ledgers/statements: 10 years minimum
  - vouchers/evidence/correspondence: 6 years minimum

Quality and issue management:
- After meaningful script changes, replay and revalidate.
- Record defects only in `BUGS.md` with sanitized deterministic repro.
- Record missing capabilities in `FEATURE_REQUESTS.md`.
- When updating `BUGS.md` or `FEATURE_REQUESTS.md`, run `bus run send-feedback`.
- If shell scripting is required due to missing Bus functionality, add/refresh a feature request.

Privacy and sanitization:
- Never publish real customer data in bug/feature reports.
- Use placeholders/anonymized examples (names, IDs, references, IBANs, invoice numbers, local paths).
- Keep case/legal documents and personal tax exports minimized to business-relevant references in scripts.
