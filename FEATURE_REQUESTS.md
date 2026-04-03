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
