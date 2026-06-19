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
