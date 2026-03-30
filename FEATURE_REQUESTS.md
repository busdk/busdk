# FEATURE_REQUESTS.md

Enhancement requests for BusDK in this repo context.

Privacy rule for request write-ups:
- Keep examples/repro snippets sanitized (no real customer names/emails/IBANs/account numbers/invoice numbers/local paths).
- Prefer placeholders and aggregated outputs over raw customer-linked row dumps.

Last reviewed: 2026-03-30.

Goal note:
- Target workflow is Bus-only for bookkeeping/audit operations.
- Operators should not need shell text pipelines (`grep/sed/awk/column`) to answer accounting control questions.

Active requests:
- `bus-reports` needs a first-class explicit comparative-data input model for annual statements. When prior-year comparatives are not already present in the current workspace, operators must be able to provide them explicitly for that invocation from either a prior Bus workspace or another deterministic source such as an imported account-trial/chart snapshot. This must not rely on hidden persistent cross-workspace configuration; the command surface should require an explicit prior-data input and diagnostics must clearly report which comparative source was used.
