# FEATURE_REQUESTS.md

Enhancement requests for BusDK in this repo context.

Privacy rule for request write-ups:
- Keep examples/repro snippets sanitized.
- Prefer placeholders and aggregated outputs over raw customer-linked row dumps.
- This public superproject must not contain real secrets. Local Docker Compose examples must use non-secret development defaults only and read any real SMTP, database, JWT, or AI Platform credentials from operator-provided environment/config outside git.

Last reviewed: 2026-05-03.

Goal note:
- Target workflow is Bus-only for bookkeeping/audit operations.
- Operators should not need shell text pipelines (`grep`/`sed`/`awk`/`column`) to answer accounting control questions.

## Active requests
- add first-class Bus worker identity templates so worker creation can choose a reusable identity repo/base ref by template, model, profile, or environment, for example mapping GPT-5.4 workers to an `agents/worker:gpt54` base, while preserving old runtime `AGENTS.md`, prompts, metadata, logs, and failure traces as run history instead of cloning or discarding them
- finish the remaining Bus Events ecosystem route-discovery and delivery-policy work: wire declared event capabilities into `bus-api` REST-to-event route validation/discovery, then define terminal-failure, dead-letter, and operator-diagnostic semantics for work-queue delivery while keeping the current memory/Redis/PostgreSQL backend set until a concrete new backend is requested

### Add reusable worker identity templates and model/profile-based identity base selection

Problem:
- Bus direct worker creation already has the low-level ability to initialize a
  worker identity checkout from a configurable identity repository and base
  ref.
- Today that identity repo/base ref is service-profile-wide configuration,
  not a per-worker or per-template choice.
- The current runtime tree shows many task-shaped worker directories whose
  `AGENTS.md`, prompts, metadata, logs, and failure traces contain useful
  lessons. They are not garbage, but they are also not safe clone sources for
  new durable identities because they mix reusable guidance with per-run
  paths, prompts, tokens, app-server state, and worktree details.

Requested capability:
- Add a first-class worker identity template contract that can select:
  - template id and label
  - worker profile, model, runner kind/provider, sandbox, capabilities, and
    eligible environments
  - worker identity repository reference and base ref/branch, such as
    `agents/worker:gpt54`
  - optional product base defaults and module-family hints
  - durable guidance/memory policy for what may be copied into new workers
- Allow `bus workers create` and the workers API to choose a template
  explicitly, for example `--template gpt54`, or infer one from model/profile
  when unambiguous.
- Support multiple worker identity repositories and multiple base branches
  without requiring a separate workers service process per model family.
- Record the selected template, identity repo, and identity base ref in worker
  metadata/status snapshots for audit, reuse, and later merge decisions.
- Preserve completed worker run records separately from identity templates:
  prompts, `AGENTS.md` snapshots, `meta.env`-style metadata, logs, failure
  traces, task refs, model/runtime facts, and extracted lessons should be
  archived or indexed before bulky runtime cache cleanup.

Acceptance:
- `bus workers create` and the Workers API can select a template explicitly
  and can infer one from model/profile/environment only when the match is
  unambiguous; ambiguous inference fails with a stable diagnostic.
- Worker status/list/show surfaces record the selected template id, model,
  profile, identity repository reference, and identity base ref without
  leaking local paths, tokens, prompts, or task-specific runtime state.
- A fixture or e2e flow proves at least two templates can use different
  identity repositories or base refs in the same Workers service without
  requiring separate service processes.
- Completed worker runtime records remain inspectable as run history while new
  identities are initialized only from the configured durable template source,
  not by cloning old task runtime directories.
- Module tests cover the template contract across `bus-worker`,
  `bus-api-provider-worker`, `bus-integration-worker`, and any shared
  repository-reference helper package.

Why this matters:
- Operators need a small standing team of reusable worker identities instead
  of always creating one-off workers.
- Different model families can need different durable identity guidance, for
  example GPT-5.4 using a `gpt54` base branch while Spark or local runtimes use
  another base.
- A template/base-ref approach keeps worker creation clean and repeatable
  without losing the learning value in old worker directories.
- This is safer than cloning an existing runtime directory because templates
  copy only durable identity defaults, not transient task execution state.

### Finish Bus Events route discovery and delivery-policy diagnostics

Problem:
- Bus providers already declare capability documents, but the aggregate
  `bus-api` HTTP/Event routing layer still needs to use those declarations as
  the authoritative source for REST-to-event route validation and discovery.
- Work-queue delivery has basic backend support, but operators still need
  deterministic terminal-failure, dead-letter, and diagnostic semantics when a
  request cannot be delivered, is abandoned, or repeatedly fails.

Requested capability:
- Teach `bus-api` to expose and validate discovered provider routes from the
  declared capability set. Unknown, unsafe, disabled, or backend-unavailable
  routes should fail with stable machine-readable diagnostics rather than
  falling through to ad hoc provider behavior.
- Define work-queue terminal states for retry exhaustion, handler rejection,
  malformed payloads, authorization failures, and backend errors. Include a
  dead-letter or equivalent operator-readable record with event id, route id,
  provider/source labels, safe failure code, timestamps, retry count, and
  correlation id, without leaking token values or request secrets.
- Expose script-friendly operator diagnostics through existing Bus API/Events
  discovery or status surfaces so supervisors can tell whether a missing route,
  failed delivery, or dead-letter record is a routing/configuration issue, an
  auth issue, or a provider/runtime issue.

Acceptance:
- Unit and e2e coverage proves dynamic provider capability additions appear in
  discovery and route validation without changing `bus-api` routing code.
- Tests cover missing route, unauthorized route, unsafe/disabled route,
  terminal worker failure, dead-letter replay/listing, and operator diagnostic
  output across the currently supported memory, Redis, and PostgreSQL Events
  backends, with explicit skips for unavailable external services.
- Documentation explains the route-discovery contract and delivery terminal
  state vocabulary without requesting a new Events backend.

## Implemented requests

- add a first-class `bus reports closing-review` report: `bus-reports` now owns the deterministic markdown/json closing-review command with unit/e2e coverage and documentation
- improve AI-annotated `bus-reports` `*-accounts` report usability and throughput: PDF AI child-row emphasis was removed, fast-model/runtime tuning is exposed, bounded parallelism and measured speedups are implemented, and same-run PDF/CSV AI result reuse is covered
- extract a reusable shared AI host library in `bus-agent`/`bus-ui`: shared approval handling, terminal-session state, thread-isolation/lock reporting, streamed agent event propagation, runtime auth/login handling, and host migrations for `bus-chat`, `bus-ledger`, `bus-factory`, and `bus-portal` are tracked as completed in owning module plans
- add a first-class configurable Codex local-model contract across BusDK AI hosts: `bus-agent` owns the runtime/model preference contract and host modules such as `bus-ledger` and `bus-factory` document/use it while preserving hosted defaults
- add `bus-chat` as a supported optional service in `bus-gateway`: the gateway catalog, launcher visibility, trusted proxy launch flow, docs, unit tests, and e2e coverage are implemented
- complete shared `bus-auth` AI Platform session support as a `bus-agent` provider/auth option for OpenAI-compatible `/v1/*` host modules, with reusable token/session loading, redaction helpers, docs, tests, and local OpenAI-compatible stub e2e coverage
- support native statutory profit-and-loss placement for nonstandard tax-like adjustments without legacy mapping: `bus-reports` now handles cases such as `Aiempien tilikausien verot` through native account-group/statutory-line behavior with FR-REP-007/FR-REP-010 coverage
- add metadata-driven Bus help and configuration discovery: `bus-help` owns shared OpenCLI-compatible metadata structs and live discovery, `bus-configure` consumes command stdout for metadata-driven `.env` workflows, and representative module-owned metadata including `bus-journal` is implemented with module/unit/e2e coverage
- add `bus-work` as the generic Bus Events-backed durable work-stream module: the module owned `new/list/next/show/watch/wait/say/close/fail/block`, multi-recipient fan-out, human refs, replay/follow behavior, dedicated `bus.work.*` scopes, and generic protocol docs while keeping `bus dev task` separate; this implementation has since been retired and removed in favor of `bus-task` and `bus-worker`
- add opt-in/operator-friendly normalized text matching for `bus files assert cell` and related assertion surfaces: string matching now trims and normalizes whitespace by default, with strict flags for exact whitespace and case-sensitive behavior
- extend `bus journal assert ...` with grouped receipt/source coverage controls and command-local help: grouped `source-id` assertions, assert/match syntax help, and docs are implemented in `bus-journal`
- add Bus-native deployment automation for installing and operating Bus cloud platform components: `bus operator deploy`, provider-neutral cloud/database/node/inference operators and API providers, integration workers, direct bootstrap paths, UpCloud/PostgreSQL/SSH-runner/billing/Stripe/Ollama integrations, docs, and module coverage are tracked as completed in the owning module plans
- delivered the main local Docker Compose Bus platform stack as a complete
  development task test environment: the portal-enabled stack runs
  `bus-integration-task`, routes `bus dev task` events through the
  PostgreSQL-backed Events API, executes the task through provider-neutral
  containers and local Docker, and verifies the result through `bus dev task
  watch` from the testing agent
- verify and harden the local Docker Compose development-task stack so `bus dev task` can create a task, execute it through the Docker-backed Codex container profile, and replay/follow the result deterministically through `bus dev task watch`; the stack now builds a Codex CLI image, protects backend `bus.docker.*` Events API access with `container:*` scopes, supports optional Codex home/workspace host mounts for live `codex exec`, and includes a repeatable Docker Compose smoke test
- refine Bus configure command shape so common dotenv access is top-level and concise: `bus configure KEY=VALUE [KEY2=VALUE2]` writes values, `bus configure KEY [KEY2]` reads values, and older `edit`/`--set` forms remain compatibility paths
- clarify README module invocation guidance so standalone `bus-*` binaries are described as available for direct/debug use while the intended user-facing command form remains dispatcher-first, for example `bus journal ...`
- refine Bus configure examples and command guidance so dotenv assignment uses the concise `bus configure edit KEY=VALUE` form, with the older `edit --set KEY=VALUE` treated as compatibility syntax rather than the primary documented path
- refine the local Docker Compose setup examples so `bus configure` relies on the default `.env` file in the working directory instead of repeating `--env-file .env` in every command
- refine the local Docker Compose Bus cloud platform README setup so operators use `bus configure` to create, diagnose, and update `.env` values instead of hand-copying or editing raw environment variables, while keeping the local stack guidance complete for Docker-backed containers, ChatGPT/Codex-backed LLM use, and mounted portal modules
- enable all Bus portal UI modules in the local Docker Compose Bus cloud platform stack: the stack now runs `bus-portal` with `bus-portal-auth`, `bus-portal-ai`, and experimental `bus-portal-accounting` mounted, exposes it through nginx at `/portal/local-dev/`, keeps business logic behind existing API-provider routes, documents the local portal URL and module set, and the compose smoke test verifies portal health plus `auth`, `ai`, and `accounting` module metadata
- add a local-only Docker Compose Bus cloud platform stack that mirrors the UpCloud/Stripe tutorial without provisioning cloud resources: `docker compose up` from the BusDK superproject root reads local `.env` configuration, starts PostgreSQL, MailHog, nginx, Events, Auth, LLM, Usage, Billing, Stripe webhook, VM/static provider, Containers/events provider, and Docker-backed container execution; exposes the same local route families as the tutorial where practical; keeps secrets out of git through `.env.example` non-secret defaults; documents local smoke commands; and avoids requiring UpCloud, systemd, public DNS, or real TLS for local validation
- add a root Docker Compose testing environment for `bus dev task` backed by on-demand local Docker container execution: the environment brings up local Events and container API surfaces with deterministic non-secret defaults, runs local macOS Docker containers through the dedicated `bus-integration-docker` worker behind the existing `bus.containers.*` event contract, provides a testing-agent shell with `bus dev task` and `bus containers` command access, documents JWT/token generation and smoke-test commands, and avoids requiring a full production Bus deployment for initial bridge testing
- make Stripe catalog sync own Billing Meter provisioning: `bus operator stripe catalog sync --file <catalog.json>` now creates Stripe Products, Prices, and Billing Meters from one operator-managed catalog with deterministic idempotency keys, validated meter schema/defaults, safe Product/Price/Meter output IDs, README/help/public docs/SDD coverage, local and opt-in live Stripe e2e coverage, and the full billing e2e now provisions Stripe objects through catalog sync instead of a separate helper script path
- add multi-file support to `bus-lint` so documentation rechecks can run as one deterministic invocation such as `bus lint file1.md file2.md ...` instead of shell `for` loops, with argument-order processing, aggregated findings, preserved stdin behavior for `-`, README/help documentation, unit tests, e2e coverage, and normal module/root quality gates
- add secure Stripe HTTP webhook ingress in `bus-integration-stripe`: the command now serves `POST /api/internal/stripe/webhook` with `--webhook-addr`, preserves raw Stripe request bodies, verifies `Stripe-Signature` with `BUS_STRIPE_WEBHOOK_SECRET` before acknowledging, publishes `bus.billing.subscription.update` through Bus Events for supported checkout/subscription webhooks, supports `--webhook-only` for ingress-only deployments, documents Stripe CLI/dashboard forwarding in README/public docs/SDD/help, and covers missing/invalid signatures plus Events publication with unit and e2e tests
- add capability-driven Bus MCP support through `bus-mcp`, `bus-api-provider-mcp`, and `bus-api`: Bus API now exposes aggregate provider capability documents; `bus-mcp` owns only shared MCP mapping/types/policy code plus the CLI entrypoint, with concrete discovery/backend sources owned by `bus-api-provider-mcp`; `bus-mcp` maps discovered Bus capabilities, AsyncAPI/event contracts, schemas, and safety metadata into generic MCP tools/resources with generated tools disabled by default; `bus-api-provider-mcp` exposes hosted MCP catalog/doctor/capability endpoints without importing provider-specific packages; `bus-mcp tools` and `bus-mcp doctor` are capability-driven; synthetic dynamic provider tests prove new provider capabilities appear without MCP code changes and unsafe writes are hidden by default
- split `bus-operator` into shallow focused operator modules using Go-library umbrella dispatch: `bus-operator-auth` owns auth operations, `bus-operator-token` owns token operations, `bus-operator-billing` owns provider-neutral billing administration, and `bus-operator-stripe` owns Stripe-specific operator diagnostics/catalog sync, while keeping `bus-operator` as a dispatcher-only umbrella with no duplicated command implementation or fallback behavior and avoiding deep `bus-operator-billing-*` module chains
- restore direct first-word dispatch in `bus` for nested command families so `bus operator billing ...` runs `bus-operator billing ...`; focused operator family logic is reached from `bus-operator` through Go library imports rather than root-dispatcher longest-prefix execution of nested child binaries
- standardize `bus-integration-*` and `bus-api-provider-*` README reference sections so integrations document each listened/sent event in compact per-event sections, API providers document each endpoint in compact per-endpoint sections, every provider endpoint states whether it triggers Bus Events, and root `make test`, root `make e2e`, and changed-module `make quality` pass
- add `bus-integration-usage` as the event-listening usage business/storage worker: providers publish record/list/delete requests through Bus Events instead of writing the usage database directly, the worker owns usage DB credentials and correlated responses, recording is retry-safe through caller-provided `event_id` idempotency, and the module supports both standalone execution and shared `bus-integration` hosting with unit/e2e tests plus README, end-user docs, SDD coverage, root `make test`, root `make e2e`, and changed-module `make quality`
- split generic SSH execution out of `bus-integration-upcloud` into `bus-integration-ssh-runner`: `bus-integration-ssh-runner` owns SSH connection handling, known_hosts validation, private-key loading, timeout and output-limit behavior, and execution of caller-supplied scripts only; `bus-integration-upcloud` keeps UpCloud provisioning plus bootstrap/Podman script construction and now triggers SSH work through `bus.ssh.script.run.*` events using shared DTOs and `bus-integration` request/reply helpers; both standalone worker binaries and shared `bus-integration` worker registrations are supported with docs, unit tests, and e2e self-tests
- finish the deployment-grade AI Platform event integration layer: `bus-api-provider-vm` and `bus-api-provider-containers` use managed Bus Events request/reply listeners with goroutine ownership at the command/service boundary; `bus-integration-upcloud` now ports UpCloud VM lifecycle calls plus container runner create/start/bootstrap/delete and emits SSH runner events for remote bootstrap/container scripts, while `bus-integration-ssh-runner` owns SSH known-hosts handling, remote execution, and output limiting; credentials are supplied only through deployment configuration with opt-in real-cloud e2e coverage
- extract the cloud-neutral AI Platform provider layer into Bus modules: `bus-api-provider-vm` now serves JWT-scoped `/api/v1/vm/status`, `/api/v1/vm/start`, and `/api/v1/vm/stop`; `bus-api-provider-containers` now serves JWT-scoped `/api/v1/containers/status`, foreground `POST /api/v1/containers/runs`, and `DELETE /api/v1/containers/runs/{run_id}` with account IDs derived from JWTs; `bus-api-provider-llm` now serves OpenAI-compatible `/v1/*` proxying with `aud=ai.hg.fi/api`, `scope=llm:proxy`, UUID `sub`, backend auth stripping, and usage capture through `bus-api-provider-usage`; `bus-integration-upcloud` now provides the event worker boundary, deterministic static provider, real UpCloud HTTP API provider, and event-composed container runner execution through `bus-integration-ssh-runner`; README, `docs/docs`, `sdd/docs`, unit tests, e2e tests, root `make test`, root `make e2e`, and changed-module `make quality` cover these implemented slices
- extract the AI Platform internal usage-events API into `bus-api-provider-usage`, including a reusable Go handler, HS256 internal JWT validation with default `aud=ai.hg.fi/internal`, scoped `usage:read` and `usage:delete` endpoints at `/api/internal/usage-events`, a PostgreSQL usage store that auto-creates a minimal disposable schema, a standalone provider binary, README plus `docs/docs` and `sdd/docs` documentation, hermetic unit tests, optional PostgreSQL e2e coverage with explicit skip behavior, Docker test coverage, root `make test`, root `make e2e`, and changed-module `make quality`
- add the MVP Bus Events domain CLI/SDK and public Events API provider: `bus-events` owns the CLI plus HTTP-independent event contracts and API client SDK; `bus-api-provider-events` owns JWT scope-gated publish/listen endpoints; memory and Redis backends support broadcast fan-out and work-queue consumer-group delivery; Redis uses Streams with atomic `XADD`/`XREADGROUP` operations; docs, unit tests, e2e coverage, Docker tests, root test/e2e, and focused root quality gates cover the implementation
- add Bus Events discovery foundations: `bus-events` defines AsyncAPI-aligned capability documents, Go library discovery APIs, reusable script-friendly CLI introspection output for `--events` and `--event-help`, AsyncAPI 3.0 export, and CloudEvents-compatible structured boundary helpers without replacing the native Bus event envelope
- add a disposable durable PostgreSQL backend for `bus-api-provider-events` that auto-creates a minimal event-log schema at startup, supports broadcast and work-queue delivery, uses `LISTEN/NOTIFY` for wake-up with SQL polling fallback, uses transaction-locked group cursors for work claims, has no migration system, and is documented as safe to destroy and recreate from scratch
- add a local Docker Compose integration environment for `bus-api-provider-auth` and `bus-auth` with PostgreSQL persistence, MailHog SMTP delivery, MailHog HTTP email inspection in e2e tests, no checked-in secrets, published BusDK release images/binaries as the preferred default for runnable services when available, local-build overrides for development, documented environment-variable overrides for real deployments, optional AI Platform `https://ai.hg.fi/v1` smoke usage using the token obtained through local `bus auth` login/token flow, and full module/root quality coverage
- standardize documentation for the remaining Bus API-related modules (`bus-api`, `bus-api-provider-books`, `bus-api-provider-data`, and `bus-api-provider-session`) across README, `docs/docs`, `sdd/docs`, and CLI `--help`, with deterministic help-format validation included in normal quality gates
- standardize `bus-api-provider-auth` and `bus-auth` documentation across `sdd/docs`, `docs/docs`, README, and CLI `--help`, with Git-style help sections and automated deterministic help-format validation in the normal quality gates
- add a development OTP sender for `bus-api-provider-auth` that writes dummy OTP codes to the console log, can be enabled without SMTP, and acts as the example/template for future OTP provider implementations
- extend the Bus auth platform for AI Platform access registration: end users register by email, verify with OTP, remain waitlisted until admin approval/rejection, and only approved users receive `aud=ai.hg.fi/api` `scope=llm:proxy` JWTs; auth-service/admin tokens use `aud=ai.hg.fi/auth` with scope-only powers such as `waitlist:read`, `waitlist:approve`, and `admin:manage`, while Bus model/runtime providers validate signed JWTs and read `sub` as the stable AI Platform account UUID
- add a reusable Bus auth platform split into `bus-api-provider-auth` and `bus-auth`: the provider exposes pluggable passwordless OTP authenticators, stable account UUID identities, short-lived JWT issuing for internal Bus AI Platform jobs, secret-backed signer abstraction for future key rotation/JWKS algorithms, rate limiting by email/IP, file-backed and in-memory stores, SMTP and in-memory senders, and fuzz/property test coverage for token and request parsing; the CLI is a thin script-friendly client for `bus auth login/logout/whoami/refresh`
