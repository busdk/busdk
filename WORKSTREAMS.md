# BusDK Workstreams

Reviewed: 2026-06-11.

This file groups the active unchecked `PLAN.md` and `BUGS.md` items by
meaningful operator-visible use case. The owning `PLAN.md` and `BUGS.md` files
remain the source of truth for exact acceptance criteria and checkbox closeout.

Scope reviewed: the BusDK root `PLAN.md`/`BUGS.md` plus module-level
`PLAN.md` and `BUGS.md` files. The active backlog spans 39 planning/bug files
and 163 unchecked checkbox lines, including nested subitems.

## Recommended Implementation Order

1. Restore the substrate used by every remote-worker proof: local Events API,
   durable Events storage, Services process inspection/freshness proof, and
   service-owned relay status.
2. Move task/worker execution onto worker-owned services with deterministic
   attempt evidence, autonomous `bus-agent-runtime` execution, and normal
   artifact transfer.
3. Make dev-hg/H100/remote execution repeatable through deploy/status/refresh
   commands and one live product-task proof.
4. Complete durable Notes evidence over Events so worker/supervisor evidence is
   queryable after remote sync and restarts.
5. Run the small security-hardening bug lanes in parallel because they are
   bounded, high-signal, and largely independent.
6. Then spend worker capacity on separable product surfaces: portal `.gx`/Go
   adoption, ledger shared UI primitive migration, and `bus-top` diagnostics.

## Workstream 1: Events Durability And Relay Substrate

Use case: a local supervisor can create task and Notes Events, remote services
can claim or project them, relays can move evidence both directions, and restarts
do not silently discard history.

Best next slice: restore the local Events API gate, then durable storage, then a
service-owned relay with restart/resume proof.

Owning items:

- `bus-events/PLAN.md`: local Events API gate, durable backend contract,
  event signatures/environment identity, memory-backed restart export guard,
  and deployed service-owned relay.
- `bus-integration-events/PLAN.md`: review relay salvage patches and implement
  the service-owned Events relay MVP.
- `PLAN.md`: high-priority service-owned Events relay goal, route derivation
  from `bus-remote`, relay install/status, `bus-dev` relay health usage,
  restart/resume proof, and one live dev-hg/H100 route.
- `bus-api/PLAN.md`: require durable Events storage for normal API/service
  startup.
- `bus-operator-deploy/PLAN.md`: memory-backed Events restart/export guard for
  service deployment.

## Workstream 2: Services Hosting, Freshness, And Runtime Profiles

Use case: Bus services start through normal profiles, report what is actually
running, prove installed binaries are fresh, and support a combined runtime
shape instead of one daemon per provider.

Best next slice: add build/version metadata and explicit process-inspection
states, then wire the make-owned freshness proof gate.

Owning items:

- `bus-services/PLAN.md`: first Services contract, CLI skeleton, liveness
  handling, dispatcher-first freshness observability, provider boundaries, and
  PostgreSQL service design.
- `bus-integration-services/PLAN.md`: runtime provider interface, command
  skeleton, native process status inspection, non-secret process identity
  evidence, runtime-kind contract tests, and PostgreSQL design proof.
- `bus-api-provider-services/PLAN.md`: canonical `bus.services.*`
  API/Event contracts, provider skeleton, projection replay, and redaction
  safety tests.
- `bus-api/PLAN.md`: administrator-selectable multi-provider API hosting.
- `bus/PLAN.md`: dispatcher release metadata and child-resolution audit.
- `PLAN.md`: root `make install` freshness, service-critical build metadata,
  make-owned Services freshness proof gate, process-inspection failures, and
  dispatcher-first child resolution.
- `bus-operator-deploy/PLAN.md`: replace placeholder deploy semantics, add a
  single-runtime user-systemd profile, add development-host refresh/status.
- `bus-integration-docker/PLAN.md`, `bus-integration-containers/PLAN.md`,
  `bus-integration-podman/PLAN.md`: provider-neutral environment service
  ensure/status support for container runtimes.

## Workstream 3: Worker Runtime, Claims, Capacity, And Remote Execution

Use case: `bus workers` and task APIs can start real autonomous workers across
local/dev-hg/H100 environments, avoid duplicate claims, expose capacity and
status, and produce reviewable evidence without shell spelunking.

Best next slice: promote the worker integration service loop as product
surface, then wire `bus-agent-runtime` create-only autonomous task execution
and evidence projection.

Owning items:

- `bus-integration-worker/PLAN.md`: salvage review, Codex App Server container
  lifecycle productization, stable claim contract, worker-start ownership,
  atomic claim/capacity orchestration, worker-owned service loop,
  autonomous `bus-agent-runtime` task runs, runtime logs/tool/evidence
  projection, and self-hosted runtime/H100 regression coverage.
- `bus-agent-runtime/PLAN.md`: salvage review and autonomous task execution.
- `bus-api-provider-worker/PLAN.md`: mount workers provider through real
  `bus-api` and define the task-to-worker API boundary.
- `bus-worker/PLAN.md`: salvage review and active-work stats/API/provider
  surfaces.
- `bus-dev/PLAN.md`: remove or tombstone old dev-only task/work surfaces,
  self-healing workflow locks, safe prune, move control plane behind Bus API
  services, consume scheduler status, first-class artifact transfer,
  deterministic attempt evidence, requested/observed model metadata, recovery
  stats, environment defaults as defaults only, real `ssh-docker` proof, launch
  option parsing, and legacy slow-lint hardening.
- `bus-agent/PLAN.md`: Codex App Server profile/model diagnostics and explicit
  turn-model contract.
- `docs/PLAN.md`: keep the Bus-owned runtime worker goal and public docs
  aligned.
- `bus-remote/PLAN.md`: consume resolved remote contracts in task/worker
  integrations and document the `ssh-docker` remote contract.
- `PLAN.md`: Bus Agent Runtime Workers promotion/sync goal, current H100/dev-hg
  finish-line checklist, source freshness, product-task proof, artifact
  transfer, credential handling, model/reasoning UX, remote identity/stats, and
  minimum UpCloud/H100 operator path.

## Workstream 4: Repositories And Worktree Materialization

Use case: repository and worktree materialization is a service-owned capability
that workers can rely on without blocking behind old replay history or moving
Git execution into API providers.

Best next slice: make Repos recovery bounded/current-work safe, then mount the
provider through the normal API host.

Owning items:

- `bus-integration-repos/PLAN.md`: bounded current-work-safe recovery for
  worker materialization and later repository lifecycle operations.
- `bus-api-provider-repos/PLAN.md`: mount provider through `bus-api` and add
  future routes only after integration ownership exists.
- `bus-repos/PLAN.md`: expand the client as API provider routes are accepted.

## Workstream 5: Durable Notes And Worker Evidence

Use case: worker notes and review evidence flow through Events, survive remote
sync/restart, and are queryable by module, task, session, tag, source, and
origin.

Best next slice: route Notes API mutations through `bus.notes.*` Events, then
run the production projection worker and add origin-aware query filters.

Owning items:

- `bus-api-provider-notes/PLAN.md`: route mutations through the Bus Events
  operation contract and expose worker-evidence query filters.
- `bus-integration-notes/PLAN.md`: production Notes projection worker over
  Events and origin-aware projections.
- `bus-notes/PLAN.md`: CLI worker-evidence query filters.
- `PLAN.md`: durable task and Notes evidence goal.

## Workstream 6: Portal Family `.gx`/Go Runtime Adoption

Use case: portal modules share the accepted Go/GX runtime and mounted app
contracts while keeping product DTOs, authorization, copy, Markdown safety, and
provider semantics in the owning modules.

Best next slice: extract the shared portal-family adoption pattern in
`bus-ui`, then finish pre-bridge readiness in accounting/auth/Notes before any
final compiled-root migration.

Owning items:

- `bus-ui/PLAN.md`: migrate AI portal to compiled `.gx` roots, extract the
  shared portal-family adoption pattern, coordinate accounting/auth/Notes
  adoption readiness, and extend adoption to other `bus-portal-*` frontends.
- `bus-portal-accounting/PLAN.md`: keep-vs-migrate decisions, pre-GX
  snapshots, WASM/mounted metadata, candidate surface classification, and
  blocked final migration.
- `bus-portal-auth/PLAN.md`: keep-vs-migrate decisions, pre-GX snapshots,
  WASM/mounted metadata, candidate surface classification, and blocked final
  migration.
- `bus-portal-notes/PLAN.md`: keep-vs-migrate decisions, pre-GX snapshots,
  WASM/mounted metadata, candidate surface classification, and blocked final
  migration.
- `bus-ui/PLAN.md` also owns the `bus-portal-ai` compiled-root coordination
  item.

## Workstream 7: Ledger Assistant/UI Primitive Migration

Use case: ledger AI panels migrate from compatibility renderers to checked
shared assistant, drop-zone, terminal, and future declarative UI contracts only
after parity is proven.

Best next slice: do not start final migration until shared adapters cover the
ledger-specific host integration state; keep parity tests as the acceptance
gate.

Owning items:

- `bus-ledger/PLAN.md`: migrate AI panel to FC-009 through FC-013 primitives,
  migrate AI drop wiring to FC-021, migrate terminal-session normalization to
  FC-017, and keep ledger panels off declarative GX/UI artifacts until a real
  renderable shared contract exists.

## Workstream 8: `bus-top` Operator Diagnostics

Use case: operators can inspect host pressure, process identity, AI-backed
process explanations, terminal behavior, and macOS policy-service storms from
one safe TUI/CLI tool.

Best next slice: split into independent workers: AI provider proof,
process-identity signals, focused view/export UX, soak/terminal cleanup, and
host-pressure/policy diagnostics.

Owning items:

- `bus-top/PLAN.md`: AI provider proof/status/prompt quality; local process
  identity and necessity guidance; Linux sampler parity; focused process view,
  browse, and export modes; live TUI soak/readability/cleanup; host-pressure
  summary; macOS file descriptor pressure; policy-service diagnostics; app
  attribution; guided remediation; post-fix verification; install/dispatch
  freshness; privacy/token docs; and worker-sized briefs.

## Workstream 9: API And Event Security Hardening

Use case: public/internal APIs fail closed on malformed JSON/JWTs and hosted
discovery/webhook paths require the intended authorization or configured
secret source.

Best next slice: run as parallel bounded fixes with module-local tests and e2e
coverage.

Owning items:

- `bus-api-provider-auth/BUGS.md`: reject trailing JSON on bounded JSON
  handlers.
- `bus-api-provider-billing/BUGS.md`: reject JWTs missing `iat` and trailing
  JSON.
- `bus-api-provider-containers/BUGS.md`: reject JWTs missing `iat`/`exp` and
  trailing run-body JSON.
- `bus-api-provider-mcp/BUGS.md`: require explicit Bus API read authorization
  for hosted MCP discovery.
- `bus-integration-stripe/BUGS.md`: ignore or reject caller-supplied webhook
  secrets in Events verification requests.

## Workstream 10: Workspace Hygiene, Salvage, Guidance, And Quality

Use case: the supervisor checkout stays reviewable, old salvage patches are
routed or retired, worker registries do not lie, generated artifacts do not
dirty primary checkouts during normal review, and quality/guidance checks can
run across the superproject.

Best next slice: resolve salvage archives first so old patches do not keep
polluting priority, then close the WASM dirty-primary bug and worker registry
cleanup.

Owning items:

- `PLAN.md`: root remote cleanup salvage review, stale local worker
  registry/projection cleanup, keep checkout clean and pinned, dev-hg freshness
  issue, oversized module `AGENTS.md` compaction, and full
  `quality-complete` sweep.
- `bus-agent-runtime/PLAN.md`, `bus-worker/PLAN.md`,
  `bus-integration-worker/PLAN.md`, `bus-integration-events/PLAN.md`: module
  salvage patch reviews.
- `bus-dev/PLAN.md`: safe large-checkout prune and legacy workflow hardening.
- `BUGS.md`: host-side verification can dirty tracked WASM artifacts in
  primary module checkouts.

## Parallel Candidates

The following lanes are safe to staff in parallel once the current branch/pin
state is clean:

- Security hardening bug fixes across auth, billing, containers, MCP, and
  Stripe.
- `bus-top` feature-set briefs and worker-sized implementation slices.
- Portal-family pre-GX readiness work, as long as final compiled-root migration
  remains blocked on the accepted shared bridge.
- Salvage review for one module at a time, with explicit apply/reject evidence.

The following lanes should not be treated as independently complete until the
substrate they depend on is healthy:

- H100/dev-hg product-task proof depends on bounded Events relay, service
  freshness/readiness, and deterministic task evidence.
- Notes evidence depends on Notes-over-Events and durable Events storage.
- Worker scheduler/capacity proof depends on a healthy local Events API and
  worker-owned service loop.
- Services freshness proof depends on dispatcher/build metadata and explicit
  process-inspection status.
