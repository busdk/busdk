# FEATURE_REQUESTS.md

Enhancement requests for BusDK in this repo context.

Privacy rule for request write-ups:
- Keep examples/repro snippets sanitized (no real customer names/emails/IBANs/account numbers/invoice numbers/local paths).
- Prefer placeholders and aggregated outputs over raw customer-linked row dumps.

Last reviewed: 2026-04-03.

Goal note:
- Target workflow is Bus-only for bookkeeping/audit operations.
- Operators should not need shell text pipelines (`grep/sed/awk/column`) to answer accounting control questions.

Active requests:

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
    - CLI ergonomics should stay lightweight like `bus journal add`:
      - `bus files parse receipt.pdf`
      - `bus files parse a.pdf b.pdf`
      - with one file, default human output may be one readable block
      - with many files, default human output may be one block per file separated by blank lines, or one line per file when that is clearer for the chosen subcommand
    - duplicate detection in `find` should be deterministic, for example via exact file hashes and other explicit non-fuzzy identity signals.
  - Why this matters:
    - Bus needs a first-class file-oriented tool for local evidence parsing and duplicate control without conflating that work with attachments storage or journal posting.

- Add a first-class generic native bank-statement PDF parse/extract surface without mandatory sidecar files.
  - Current behavior:
    - direct PDF statement handling exists in `bus-bank`, but the remaining gap is broad generic coverage for ordinary text-extractable statement PDFs without falling back to sidecar-only workflows.
    - the desired capability should not be hardcoded around one bank or one statement layout family.
  - Requested behavior:
    - make `bus bank statement parse|extract --file <statement.pdf>` work directly on common statement PDFs through deterministic native parsing, without requiring manually prepared `.statement.csv` or similar sidecar files.
    - keep the implementation generic and reusable:
      - prefer shared statement-extraction primitives and profile/layout hints over one-vendor hardcoding
      - allow deterministic explicit hints when needed, but do not make sidecars the normal prerequisite
      - preserve stable diagnostics when a PDF still cannot be parsed confidently
    - extracted output must be good enough to drive opening/closing balance checks, deterministic bank-row replay support, and statement reconciliation workflows.
  - Why this matters:
    - bank statements are primary bookkeeping evidence in these workspaces, so Bus should remove manual sidecar preparation work instead of depending on it for common PDF inputs.

- Add a first-class deterministic `bus journal match ... [apply ...]` surface for rule-based split postings.
  - Current behavior:
    - recurring split logic for bank, clearing, and similar source-account rows still requires hand-authored `journal add` postings.
    - Bus lacks one simple Unix-style surface that first shows matched rows and then, optionally, creates the corresponding new journal rows.
  - Requested behavior:
    - add one `bus journal match <selector...> [apply <action...>]` command surface.
    - without `apply`, the command only lists matched journal rows.
    - with `apply`, the command creates new journal rows from those matches.
    - `apply --print` must print the exact journal-add style rows it would create, without attempting to execute them.
    - `apply --dry-run` must run the same validation, resolution, and error path as a real apply, but stop before any persistent write.
    - shorthand parsing must stay user-friendly but strictly deterministic:
      - before `apply`, accept one or many exact input accounts plus deterministic `x`-wildcard account selectors such as `1xxx`, `19xx`, and `191x`
      - after `apply`, accept either one target account for a `100 %` move, repeated split targets like `50%=4000`, or a trailing fallback/remainder account
      - any ambiguous interpretation must fail as a usage error instead of guessing
    - example accepted shapes:
      - `bus journal match 1910 apply 1920`
      - `bus journal match 1910 apply --print 1920`
      - `bus journal match 1910 apply --dry-run 1920`
      - `bus journal match 1910 1920 'K-Market|Prisma' apply --desc 'Kauppakuitti' 50%=4000 50%=4010 1790`
  - Why this matters:
    - operators need a very simple way to express repeatable automatic handling for matched journal rows without shell pipelines or long manual posting blocks.
