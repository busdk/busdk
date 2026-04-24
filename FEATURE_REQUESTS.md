# FEATURE_REQUESTS.md

Enhancement requests for BusDK in this repo context.

Privacy rule for request write-ups:
- Keep examples/repro snippets sanitized.
- Prefer placeholders and aggregated outputs over raw customer-linked row dumps.

Last reviewed: 2026-04-12.

Goal note:
- Target workflow is Bus-only for bookkeeping/audit operations.
- Operators should not need shell text pipelines (`grep`/`sed`/`awk`/`column`) to answer accounting control questions.

## Active requests

- add a first-class `bus reports closing-review` report that assembles tilinpäätös preparation and review findings into one deterministic markdown/json review artifact without changing existing statutory statement commands
- speed up `bus-reports` AI-annotated account report variants further beyond 4-way parallelism
- expose an explicit fast-model / AI-runtime tuning surface for AI-annotated report generation
- render AI-generated account summary rows in PDFs without bold emphasis
- add opt-in normalized text matching for `bus files assert cell` so report assertions can trim/collapse presentation whitespace while preserving exact matching by default
- extend `bus journal assert ...` with grouped receipt/source coverage controls for first-class receipt-split audit parity
- expand `bus journal --help` and command-local help so assert/match date, account, source, description, and comparison syntax is discoverable from built-in help
- extract a reusable shared AI host library in `bus-agent` and/or `bus-ui` for approval handling, terminal-session state, thread-isolation/lock reporting, streamed agent event propagation, and runtime auth/login handling, then migrate `bus-chat`, `bus-ledger`, `bus-factory`, and `bus-portal` to consume that shared implementation instead of keeping per-host copies
- add a first-class configurable Codex local-model contract across BusDK AI hosts so modules such as `bus-ledger`, `bus-portal`, and other `bus-agent` consumers can target operator-selected local models like Gemma 4 without losing current hosted-model defaults
- add `bus-chat` as a supported optional service in `bus-gateway`, including service-catalog setup, launcher visibility, and authenticated proxy launch flow

### Support native statutory profit-and-loss lines for nonstandard tax-like adjustments without legacy mapping

Problem:
- This repo no longer wants to use legacy `report-account-mapping`.
- Current Bus statutory profit-and-loss generation is expected to rely on native account groups (`accounts.group_id` plus `account-groups.csv`).
- We have a real sole-proprietor source case on `9950 Aiempien tilikausien verot` where the ledger posting should remain as source parity, but the account should not be shown under `pl_income_taxes / Tuloverot`.

What fails today:
- If `9950 Aiempien tilikausien verot` stays on `pl_income_taxes / Tuloverot`, Bus generates a visible `TULOVEROT` subtotal in the statutory profit-and-loss even when the desired presentation is different.
- If the account is moved to a custom native group such as `pl_prior_year_tax_adjustments`, statutory profit-and-loss generation fails with `FR-REP-007` because the custom group has no visible statutory line.
- If the account is moved to some other existing visible line such as `pl_other_operating_income`, statutory profit-and-loss generation can fail `FR-REP-010` because the profit-and-loss presentation no longer reconciles cleanly to the balance-sheet equity change.

Requested capability:
- Allow native account-group based statutory profit-and-loss layouts to expose an explicit visible line for these nonstandard tax-like adjustments without requiring legacy `report-account-mapping`.
- In practice Bus needs one of these native solutions:
  - a supported standard statutory line id for cases like `Aiempien tilikausien verot ja palautukset`, or
  - a way to mark a custom native account group as a visible statutory line in the profit-and-loss layout, or
  - a first-class native classification layer that is not the removed legacy mapping model but still lets operators place exceptional accounts on a specific visible statutory line.

Why this matters:
- In this repo, the accounting source should stay unchanged, but the statutory presentation should still be controllable without legacy report-mapping debt.
- The current gap forces an unacceptable choice between:
  - wrong presentation under `Tuloverot`
  - hidden/unmapped groups that fail `FR-REP-007`
  - or repointing the account to an unrelated visible line and risking `FR-REP-010`.
