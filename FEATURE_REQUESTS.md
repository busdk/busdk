# FEATURE_REQUESTS.md

Enhancement requests for BusDK in this repo context.

Privacy rule for request write-ups:
- Keep examples/repro snippets sanitized (no real customer names/emails/IBANs/account numbers/invoice numbers/local paths).
- Prefer placeholders and aggregated outputs over raw customer-linked row dumps.

Last reviewed: 2026-04-05.

Goal note:
- Target workflow is Bus-only for bookkeeping/audit operations.
- Operators should not need shell text pipelines (`grep/sed/awk/column`) to answer accounting control questions.

Active requests:

- Extend `bus journal assert ...` with first-class grouped coverage controls for replay and receipt-split audits.
  - Current behavior:
    - `bus journal assert ...` now supports the main scalar measures `balance`, `debit`, `credit`, and `net`, plus date/range shorthand, explicit subset filters, and comparison operators.
    - summary-level replay checks can therefore already be expressed in Bus, but exact grouped coverage still needs repo-local helper scripts when the audit question is “did every filtered source group replay completely and correctly”.
  - Requested behavior:
    - extend the shipped `bus journal assert ...` family with deterministic grouped coverage controls, for example:
      - assert per `source_id` or per other explicit grouping key
      - assert distinct source-id counts in a filtered set
      - assert that every source in a filtered set has zero net or one expected debit/credit total
    - keep this as a first-class Bus assertion surface instead of requiring shell/Python post-processing for grouped receipt-split or replay coverage checks.
  - Why this matters:
    - replay-side audit work increasingly needs exact grouped coverage questions, and the remaining workaround in this repo exists because grouped journal assertions are still outside the first-class Bus surface.

- Add a first-class filesystem-oriented `bus files` surface for parsing and finding local evidence files.
  - Current behavior:
    - receipt and other evidence-file discovery/parsing needs are still handled ad hoc outside Bus.
    - there is no clean Unix-style Bus surface that separates file parsing, row extraction, and directory scanning from journal creation.
  - Requested behavior:
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
  - Why this matters:
    - Bus needs a first-class file-oriented tool for local evidence parsing and duplicate control without conflating that work with attachments storage or journal posting.
