# FEATURE_REQUESTS.md

Enhancement requests for BusDK in this repo context.

Privacy rule for request write-ups:
- Keep examples/repro snippets sanitized (no real customer names/emails/IBANs/account numbers/invoice numbers/local paths).
- Prefer placeholders and aggregated outputs over raw customer-linked row dumps.

Last reviewed: 2026-02-25 (active rows re-tested against current CLI build).

Goal note:
- Target workflow is Bus-only for bookkeeping/audit operations.
- Operators should not need shell text pipelines (`grep/sed/awk/column`) to answer accounting control questions.

## Active requests

- None.

## Resolved / removed from active list (revalidated 2026-02-24)

- FR44 implemented: native `bus audit evidence-coverage` dispatcher path is available and delegates to deterministic `bus-validate evidence-coverage` reporting.
- FR32 implemented and revalidated (2026-02-25): `bus-bank statement extract/parse` now supports deterministic native PDF extraction in this repo context without requiring summary sidecars, including broader period detection and saldo-date fallback for period derivation.
- FR34 implemented and revalidated (2026-02-25): statement extract parsing hints (`--date-format`, `--decimal-sep`, `--group-sep`, `--unicode-minus`) are applied as deterministic defaults for schema-based summary parsing when schema fields omit explicit formats, and named statement profiles can carry these hints.

Resolved features are tracked in each module's `FEATURES.md`.
