# FEATURE_REQUESTS.md

Enhancement requests for BusDK in this repo context.

Privacy rule for request write-ups:
- Keep examples/repro snippets sanitized.
- Prefer placeholders and aggregated outputs over raw customer-linked row dumps.
- This public superproject must not contain real secrets. Local Docker Compose examples must use non-secret development defaults only and read any real SMTP, database, JWT, or AI Platform credentials from operator-provided environment/config outside git.

Last reviewed: 2026-04-25.

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
- align Bus-owned AI Platform API planning with the in-progress AI Platform docs: keep OpenAI-compatible model calls under `/v1/*` and support `bus-auth` AI Platform sessions as one `bus-agent` provider/auth option without removing existing providers; make domain modules own their API clients and Go libraries (`bus-vm` for `/api/v1/vm/status`, `bus-containers` for user-owned `/api/v1/containers/status` and `/api/v1/containers/runs*` lifecycle APIs); make `bus-status` an aggregate status UX that calls those domain libraries instead of owning the APIs; `bus-api-provider-auth` owns the auth service implementation; `bus-auth` owns the auth client CLI; leave `/api/internal/usage-events` as api-proxy/internal infrastructure with no Bus CLI module for now; and keep final auth/admin service paths pending final API docs

## Implemented requests

- add a local Docker Compose integration environment for `bus-api-provider-auth` and `bus-auth` with PostgreSQL persistence, MailHog SMTP delivery, MailHog HTTP email inspection in e2e tests, no checked-in secrets, published BusDK release images/binaries as the preferred default for runnable services when available, local-build overrides for development, documented environment-variable overrides for real deployments, optional AI Platform `https://ai.hg.fi/v1` smoke usage using the token obtained through local `bus auth` login/token flow, and full module/root quality coverage
- standardize documentation for the remaining Bus API-related modules (`bus-api`, `bus-api-provider-books`, `bus-api-provider-data`, and `bus-api-provider-session`) across README, `docs/docs`, `sdd/docs`, and CLI `--help`, with deterministic help-format validation included in normal quality gates
- standardize `bus-api-provider-auth` and `bus-auth` documentation across `sdd/docs`, `docs/docs`, README, and CLI `--help`, with Git-style help sections and automated deterministic help-format validation in the normal quality gates
- add a development OTP sender for `bus-api-provider-auth` that writes dummy OTP codes to the console log, can be enabled without SMTP, and acts as the example/template for future OTP provider implementations
- extend the Bus auth platform for AI Platform access registration: end users register by email, verify with OTP, remain waitlisted until admin approval/rejection, and only approved users receive `aud=ai.hg.fi/api` `scope=llm:proxy` JWTs; auth-service/admin tokens use `aud=ai.hg.fi/auth` with scope-only powers such as `waitlist:read`, `waitlist:approve`, and `admin:manage`, while api-proxy remains outside Bus and only validates signed JWTs and reads `sub` as the stable AI Platform account UUID
- add a reusable Bus auth platform split into `bus-api-provider-auth` and `bus-auth`: the provider exposes pluggable passwordless OTP authenticators, stable account UUID identities, short-lived JWT issuing for api-proxy/internal jobs, secret-backed signer abstraction for future key rotation/JWKS algorithms, rate limiting by email/IP, file-backed and in-memory stores, SMTP and in-memory senders, and fuzz/property test coverage for token and request parsing; the CLI is a thin script-friendly client for `bus auth login/logout/whoami/refresh`

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
