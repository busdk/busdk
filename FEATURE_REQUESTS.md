# FEATURE_REQUESTS.md

Enhancement requests for BusDK in this repo context.

Privacy rule for request write-ups:
- Keep examples/repro snippets sanitized (no real customer names/emails/IBANs/account numbers/invoice numbers/local paths).
- Prefer placeholders and aggregated outputs over raw customer-linked row dumps.

Last reviewed: 2026-03-31.

Goal note:
- Target workflow is Bus-only for bookkeeping/audit operations.
- Operators should not need shell text pipelines (`grep/sed/awk/column`) to answer accounting control questions.

Active requests:

1. Finish the layered Finnish reporting model beyond the currently shipped account-group basics.
   - Remaining request:
     - make Finnish reporting semantics resolve deterministically from statutory taxonomy, canonical account semantics / `account-groups.csv`, workspace entity context, and explicit exceptional overrides.
     - keep layout-keyed mapping/override files as compatibility or migration inputs, not the normal long-term accounting model.
     - ensure `*-accounts` and other drill-down layouts inherit the same effective classification as the base statement instead of redefining report meaning at detail level.

2. Finish the personal-finance / sole-proprietor reporting surface beyond the currently shipped private-capital basics.
   - Remaining request:
     - add first-class personal / sole-proprietor outputs such as net-worth, account-movement summary, transfer-aware presentation, and document metadata that do not assume Y-tunnus or corporate filing context.

3. Allow first-class user-assigned voucher numbers for manually added evidence attachments.
   - Remaining request:
     - support a direct form such as `bus attachments add <file> --desc <text> --voucher <id>`.
     - fail if the chosen visible voucher id is already in use.
     - support unambiguous positional shorthand when one positional token is a file path and the other is a voucher id.
