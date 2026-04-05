# FEATURE_REQUESTS.md

Enhancement requests for BusDK in this repo context.

Privacy rule for request write-ups:
- Keep examples/repro snippets sanitized (no real customer names/emails/IBANs/account numbers/invoice numbers/local paths).
- Prefer placeholders and aggregated outputs over raw customer-linked row dumps.

Last reviewed: 2026-04-05.

Goal note:
- Target workflow is Bus-only for bookkeeping/audit operations.
- Operators should not need shell text pipelines (`grep`/`sed`/`awk`/`column`) to answer accounting control questions.

## Active requests

### Add first-class classification for prior-year correction / opening-adjustment vouchers in report reconciliation

Problem:
- Current Bus reporting distinguishes opening entries from ordinary journal/memo entries, but it does not appear to support a third class for vouchers that are posted in the current workspace and dated on the first day of the year while semantically correcting prior-year balances.
- In Sendanor 2024 we needed a memorandum dated `2024-01-01` titled `Vuoden 2023 korjaukset` to correct carried balances from 2023 without treating those corrections as 2024 operating performance.
- When those corrections are modeled as ordinary `memo add` postings to balance-sheet/equity accounts, `bus reports evidence-pack --period 2024` fails `FR-REP-010` even though the intent is clearly a prior-year/opening adjustment, not a 2024 profit-impacting business event.

Current real-workspace repro:
- Source files:
  - `exports/sendanor/2024/2024-01-01-opening.bus`
  - `exports/sendanor/2024/2024-01-01.bus`
  - `exports/sendanor/2024/2024-00-00-accounts.bus`
  - `exports/sendanor/2024/2024-00-00-group-membership.bus`
- The workspace contains a `2024-01-01` memorandum `Vuoden 2023 korjaukset` that corrects prior-year carry-forward balances, for example:
  - `7611 / 2880`
  - `7611 / 2870`
  - `2210 / 2215 / 2200 / 2299`
  - `1920 / 1940 / 1999 / 8564`
- Then run:
  - `make -C exports/sendanor/2024 export`
  - `make -C exports/sendanor/2024 reports`

Current behavior:
- Before mapping `2299`, reports fail with unmapped-balance-sheet-account `FR-REP-007`.
- After mapping `2299` into equity, `evidence-pack` still fails all profit-and-loss artifacts with:
  - `bus-reports: income-result reconciliation failed (FR-REP-010): period result from profit-and-loss (13235.77) does not equal balance-sheet equity change for period 2024-01-01 to 2024-12-31 after excluding opening entries ...`
- This indicates that the `2024-01-01` prior-year-correction memorandum is being counted as ordinary 2024 equity movement instead of as an opening/prior-year adjustment.

Why current behavior is not sufficient:
- Opening balances are excluded from period-result reconciliation.
- Ordinary memoranda are included in period-result reconciliation.
- Real bookkeeping needs an intermediate class:
  - a voucher exists in the current workspace for auditability
  - but it semantically belongs to prior-year correction / opening-state normalization
  - and therefore should not be treated as current-year result/equity movement in `FR-REP-010`

Requested capability:
- Add first-class support for prior-year correction / opening-adjustment vouchers, for example one of:
  - a dedicated voucher class or command such as `opening-adjustment add` / `prior-year-correction add`
  - a flag on `memo add` / `journal add` that marks the voucher as excluded from current-period result reconciliation
  - report logic that recognizes a canonical source classification for opening/prior-year correction vouchers and excludes them from `FR-REP-010` period movement while still keeping them visible in the journal and balance sheet

Expected behavior:
- A voucher explicitly marked as prior-year correction / opening adjustment should:
  - remain visible and auditable in the current workspace journal
  - affect the balance-sheet state from the start of the year onward
  - not be treated as current-year equity movement when reconciling profit-and-loss against the balance-sheet result
- In other words, `FR-REP-010` should continue to measure current-year result, not opening-state repair work that happens to be recorded on `YYYY-01-01`

Why this matters in this repo:
- Sendanor 2024 needs to carry forward corrected 2023 balances transparently and auditably.
- Hiding the corrections by silently mutating opening rows is undesirable.
- But keeping them as ordinary memoranda breaks report reconciliation even though the accounting intent is sound.

### Extend `bus journal assert ...` with grouped coverage controls for receipt-split audits

Status now:
- The main `bus journal assert ...` family has shipped locally and is in use here:
  - `balance`, `debit`, `credit`, `net`
  - positional day/range shorthand such as `2026-01-01` and `2026-01-01..2026-03-31`
  - `account`, exact/prefix `source_id`, and description filters
  - comparison operators such as `>=1000` and `<=0`
- This repo now uses those commands directly in `exports/jhh-meri-laskelmat/data/Makefile`.

Remaining gap:
- We still do not have a Bus-native way to assert grouped receipt coverage such as:
  - every distinct `receipt-split:meri:...` source id exists in the exported journal exactly as replayed
  - grouped receipt totals match expected per-receipt control amounts
  - whole receipt gross totals can be checked deterministically even when only Jaakko's share is journaled for shared rows

Current workaround in this repo:
- `make -C exports/jhh-meri-laskelmat/data check-meri-receipts`
- It now uses shipped Bus-native summary asserts first, then a repo-local parity script for exact per-row source-id coverage.

Requested capability:
- Add first-class grouped/assertable journal coverage controls on top of the shipped `bus journal assert ...` family.
- The missing part is not generic `debit` / `credit` / `net` filtering anymore; it is deterministic grouped auditability, for example:
  - assert per `source_id`
  - assert distinct source-id count
  - assert that every source in a filtered set has zero net or an expected debit/credit total

Why this matters:
- The high-level summary asserts are now available.
- The remaining shell/Python workaround exists only because exact grouped receipt replay coverage is still outside first-class Bus assertions.

### Expand `bus journal --help` to document assert/match syntax in a complete operator-facing way

Problem:
- Even after `bus journal assert ...` shipped, the practical discovery surface is still too thin.
- `bus journal --help` mentions `assert` and `match`, but it does not document their real shorthand and filter vocabulary well enough for everyday replay authoring.
- Operators should be able to learn the supported syntax from built-in help without reading code or external docs first.

Requested improvement:
- Expand `bus journal --help` and the command-local help texts so they document the most important operator-facing shapes explicitly, including:
  - positional date shorthand such as `2026-01-01`
  - positional date ranges such as `2026-01-01..2026-02-01`
  - account selectors / masks such as `1701`, `1xxx`, and similar human-typed patterns
  - exact and prefix filters for `source_id` and description
  - comparison arguments such as `123.45`, `>=1000`, and `<=0.00`
  - at least one practical `journal match` example and one practical `journal assert` example

Why this matters:
- In this repo the preferred workflow is Bus-only replay and audit control.
- Good built-in help reduces avoidable trial-and-error when adding replay-side assertions and ledger triage commands.

### Add a first-class filesystem-oriented `bus files` surface for parsing and finding local evidence files

Current behavior:
- receipt and other evidence-file discovery/parsing needs are still handled ad hoc outside Bus.
- there is no clean Unix-style Bus surface that separates file parsing, row extraction, and directory scanning from journal creation.

Requested behavior:
- add a `bus files` module for local filesystem work on evidence files.
- support at least these command shapes:
  - `bus files parse <file...>`
  - `bus files parse rows <file...>`
  - `bus files find <dir...>`
- keep parsing and journal creation clearly separate:
  - `parse` extracts file-level metadata/content from one or many files
  - `parse rows` extracts line/item rows when the file type supports it
  - `find` scans directories, fingerprints files, and reports duplicates
- this surface should also own generic native parsing of common bank-statement PDFs and similar evidence files, so statement-file parsing is not a separate sidecar-oriented special case in `bus-bank`
- CLI ergonomics should stay lightweight like `bus journal add`:
  - `bus files parse receipt.pdf`
  - `bus files parse a.pdf b.pdf`
  - with one file, default human output may be one readable block
  - with many files, default human output may be one block per file separated by blank lines, or one line per file when that is clearer for the chosen subcommand
- duplicate detection in `find` should be deterministic, for example via exact file hashes and other explicit non-fuzzy identity signals.

Why this matters:
- Bus needs a first-class file-oriented tool for local evidence parsing and duplicate control without conflating that work with attachments storage or journal posting.
