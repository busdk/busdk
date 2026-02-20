# FEATURE_REQUESTS.md

Enhancement and "nice to have" requests for BusDK in this repo context.

Privacy rule for request write-ups:
- Keep examples/repro snippets sanitized (no real customer names/emails/IBANs/account numbers/invoice numbers/local paths).
- Prefer placeholders and aggregated outputs over raw customer-linked row dumps.

Last reviewed: 2026-02-20.

Implemented requests were removed from this file in cleanup passes.

## Active requests
- None.

## Implemented / removed from active list (2026-02-20 re-check)
- FR36 implemented:
  - `bus-status` module added with deterministic readiness/close-state output (`tsv`/`json`), CLI global flags, unit tests, and e2e coverage.
- FR34 implemented:
  - `bus-bank` statement extract supports reusable named profiles and deterministic profile inspection:
    - `bus bank statement profile list`
    - `bus bank statement profile inspect --profile <name>`
- FR32 implemented:
  - `bus-bank` raw statement extraction supports deterministic transaction inference with explicit mapping fields `date`, `amount`, `balance` and constant selectors via `const:` (for example `--map currency=const:EUR`), plus sidecar and summary modes.
- FR29 implemented:
  - `bus-vat --help filed-import` now explicitly documents:
    - required/optional columns,
    - accepted row kind handling (`TOTAL`),
    - validation formula,
    - minimal valid example row.
- FR30 implemented:
  - `bus vat` now supports `--from/--to` date-range mode (`report`, `export`, `filed-import`, `filed-diff` parsing paths).
- FR31 implemented:
  - `bus attachments link` supports deterministic selectors (`--path`, `--desc-exact`, `--source-hash`) and idempotent `--if-missing`.
- FR33 implemented:
  - `bus reports compliance-checklist` exists and is legal-form-aware FI checklist/reporting scope.
- FR35 implemented:
  - `bus journal import --profile fi-ledger-legacy` exists with deterministic mapping/diagnostics behavior.
