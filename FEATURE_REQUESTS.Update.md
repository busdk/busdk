# FEATURE_REQUESTS.md

Enhancement requests for BusDK in this repo context.

Privacy rule for request write-ups:
- Keep examples/repro snippets sanitized.
- Prefer placeholders and aggregated outputs over raw customer-linked row dumps.

Last reviewed: 2026-04-06.

Goal note:
- Target workflow is Bus-only for bookkeeping/audit operations.
- Operators should not need shell text pipelines (`grep`/`sed`/`awk`/`column`) to answer accounting control questions.

## Active requests

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
