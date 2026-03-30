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

1. Extend the shipped `bus journal balance assert` command with explicit opening/closing semantics for replay control flows.
   - Already shipped:
     - deterministic base assertion forms:
       - `bus journal balance assert ACCOUNT YYYY-MM-DD AMOUNT`
       - `bus journal balance assert ACCOUNT --as-of YYYY-MM-DD --amount AMOUNT`
   - Remaining request:
     - add explicit opening/closing shapes such as:
       - `bus journal balance assert opening 1911 2023-01-01 190.00`
       - `bus journal balance assert 1911 opening 2023-01-01 190.00`
       - `bus journal balance assert 1911 2023-01-01 --opening 190.00 --closing 93.85`
     - keep ambiguous positional forms as deterministic usage errors instead of guessing.

2. Finish the layered Finnish reporting model beyond the currently shipped account-group basics.
   - Remaining request:
     - make Finnish reporting semantics resolve deterministically from statutory taxonomy, canonical account semantics / `account-groups.csv`, workspace entity context, and explicit exceptional overrides.
     - keep layout-keyed mapping/override files as compatibility or migration inputs, not the normal long-term accounting model.
     - ensure `*-accounts` and other drill-down layouts inherit the same effective classification as the base statement instead of redefining report meaning at detail level.

3. Finish the personal-finance / sole-proprietor reporting surface beyond the currently shipped private-capital basics.
   - Remaining request:
     - add first-class personal / sole-proprietor outputs such as net-worth, account-movement summary, transfer-aware presentation, and document metadata that do not assume Y-tunnus or corporate filing context.

4. Allow first-class user-assigned voucher numbers for manually added evidence attachments.
   - Remaining request:
     - support a direct form such as `bus attachments add <file> --desc <text> --voucher <id>`.
     - fail if the chosen visible voucher id is already in use.
     - support unambiguous positional shorthand when one positional token is a file path and the other is a voucher id.

5. Add clearer first-class account-group visual hierarchy to filing-grade chart-of-accounts PDFs.
   - Remaining request:
     - `bus accounts report --format pdf` should show account-group rows as explicit visual section rows between account rows.
     - group rows should be visually distinct from accounts, at minimum by indentation and/or fill styling.
     - the PDF should make it immediately obvious which rows are groups and which are leaf accounts.
     - tililuettelo should keep account-group hierarchy active automatically whenever canonical `account-groups.csv` exists; operators should not need extra flags or manual mode switches to get grouped output.
     - tililuettelo balance columns should be generated automatically from the current workspace period model: the leftmost first balance column must be the requested document date balance, intermediate columns should show prior period-end balances in newest-to-oldest order, and the rightmost last column should be the fiscal-year opening balance.
     - when only one prior opening snapshot is available, preserve the same left-to-right rule: current/requested balance first, oldest opening balance last.
