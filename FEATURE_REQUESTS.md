# FEATURE_REQUESTS.md

Enhancement requests for BusDK in this repo context.

Privacy rule for request write-ups:
- Keep examples/repro snippets sanitized (no real customer names/emails/IBANs/account numbers/invoice numbers/local paths).
- Prefer placeholders and aggregated outputs over raw customer-linked row dumps.

Last reviewed: 2026-02-24 (active rows re-tested against current CLI build).

Goal note:
- Target workflow is Bus-only for bookkeeping/audit operations.
- Operators should not need shell text pipelines (`grep/sed/awk/column`) to answer accounting control questions.

## Active requests

- FR32 - `bus-bank statement extract/verify` should accept raw statement evidence without sidecar schema files
  - Symptom:
    - Standard OP statement PDFs in this repo context can still fail PDF-only extraction with `native PDF extraction failed: could not derive statement period from PDF text`.
  - Impact:
    - Deterministic saldo verification from original evidence is blocked unless extra sidecar/conversion artifacts are created.
  - Expected:
    - Deterministic direct extraction mode for standard statement PDFs.
    - If summary fields are not present, deterministic transaction-derived checkpoint mode with explicit diagnostics.
    - Support mixed-source verification flow where extracted statement totals can be validated against imported bank rows for the same account+period.
    - Deterministic warnings for unrecognized numeric tokens in statement evidence.

- FR34 - configurable mapping profiles for import/extract commands
  - Symptom:
    - Even with explicit profile/`--map` fields, raw statement extract can reject localized mapped dates (for example `12/31/2024`) with `date must be date`.
    - No accepted profile/map field currently allows explicit date-format hinting for statement extract (for example `M/D/YYYY`) or equivalent deterministic parser override.
  - Impact:
    - Drift risk and weak audit readability when mappings are copied manually between commands/scripts.
    - Deterministic saldo verification remains blocked for formats where date parsing needs an explicit format hint.
  - Expected:
    - Workspace-level named mapping profiles reusable by import/extract commands.
    - Mapping profiles include parsers/normalizers for date and number formats (for example date-format hint and unicode-minus normalization).

## Resolved / removed from active list (revalidated 2026-02-24)

- FR44 implemented: native `bus audit evidence-coverage` dispatcher path is available and delegates to deterministic `bus-validate evidence-coverage` reporting.

Resolved features are tracked in each module's `FEATURES.md`.
