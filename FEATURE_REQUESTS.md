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
1. Hide redundant `Vienti` from printable ledger/day-book reports when `Tx` and `Rivi` already identify the posting row.
2. Add first-class invoice-link hints to `bus bank add` / `bank-transactions.csv`, distinct from final reconciliation matches.
3. Replace the fragmented Finnish reporting configuration model with a layered, deterministic reporting architecture rooted in canonical account groups, entity context, and explicit overrides.
4. Finish the personal-finance / sole-proprietor reporting surface so non-corporate workspaces can produce native person-appropriate statements and package outputs instead of company-shaped statutory defaults.
5. Remove opening-balance fallback as a comparative source for `profit-and-loss`.
6. Add a first-class prior-year `profit-and-loss` comparative source, including account-drilldown support, for year-split workspaces and imported historical ledgers.
7. Give `bus period close` and year-end close postings short human-facing voucher series instead of exposing technical `cl_<hash>` identifiers as visible vouchers.
