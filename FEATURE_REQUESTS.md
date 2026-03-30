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
1. Add a first-class `bus journal balance assert` command for `.bus` replay flows.
   - Current behavior:
     - Bus already supports:
       - reading statement checkpoints from source evidence
       - verifying statement checkpoints against bank transactions
       - generic dataset assertions via `bus data table assert`
       - printing effective balances from journal/reporting data, for example:
         - `bus journal balance --as-of <date>`
         - `bus reports account-balances --as-of <date>`
     - what is missing is a direct replay-time assertion of the effective ledger balance at one cut-off date without shell glue.
   - Requested behavior:
     - add a first-class assertion surface on `bus journal balance`, suitable for `.bus` replay scripts, with a natural shell syntax such as:
       - `bus journal balance assert 1911 2023-12-31 93.85`
       - explicit flags may still be accepted, for example:
         - `bus journal balance assert 1911 --as-of 2023-12-31 --amount 93.85`
     - shorthand parsing should remain deterministic:
       - one account code
       - one ISO date
       - one decimal amount
       - ambiguous positional usage must fail clearly instead of guessing
   - Why this matters:
     - replay files become clearer when each month can state beginning/end saldo expectations directly at the point where those expectations belong.
     - statement extraction and statement-vs-bank verification remain useful, but they solve a different problem than asserting the expected Bus-side saldo at a chosen cut-off date.
