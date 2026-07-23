# Worker Delegation Runbook

Read this before any worker dispatch, activation-evidence check, template or
model routing, environment freshness verification, pause/drain, worktree
cleanup, or worker-failure diagnostic in the BusDK superproject. It expands
the binding supervisor/worker boundary in the root `AGENTS.md` section
`Supervisor Worker Delegation`.

Item numbers below are historical identifiers from the original root file and
do not restart from the root section's numbering: this file holds original
items 4-7, 7c, and 17-46. The original file numbered two items 7; the second
is renumbered 7c here for uniqueness. Original items 1-3 remain in root
`AGENTS.md` as items 1-3; original item 16 remains in root as its item 4; root
items 5 and 6 are routing entries, not original items. Original items 7a-15
are in `runbooks/gx-ui-delegation.md`. Items 6, 7, and 7c below carry
GX/UI-specific clauses that also apply to GX/UI lanes.

4. Decompose broad work into the smallest independently implementable,
   testable, reviewable, and promotable increments. Require each active lane to
   publish an ordered commit queue before broad implementation, with one
   focused behavior and gate per commit. Run disjoint source-edit and bounded
   Go-test increments in parallel under the current resource-class admission
   policy; separately serialize heavyweight builds, images, containers, and
   stress. Review and promote each compatible slice as soon as it passes
   instead of waiting for an all-or-nothing module rewrite. Before reusing
   shared mutable resources, prove the prior process tree is quiescent.
5. Codex background threads for BusDK superproject work must make the owning
   repository or module path operationally real before edits. Prefer opening
   the thread on the exact saved module project when available. If only the
   supervisor project is a saved Codex project, the thread may start there
   only when its first product step is to create and use an isolated worktree
   for the single target module. Split broad cleanup or salvage reviews by
   module owner when any follow-up edit may be needed.
6. For local App Server workers on BusDK submodules, send the worker the exact
   absolute product-worktree path as soon as `bus workers status` reports it,
   then tell it to `cd <module>` inside that tree before any file edit. Also
   name the primary checkout path as out of scope. If a worker log or command
   output references the primary checkout path after that, stop the worker,
   preserve any leaked patch, restore only the leaked primary files, and
   relaunch with stricter path guardrails. Do not trust a worker diff until the
   primary checkout for that module has been checked clean.
7. Worker creation is not proof of execution. After creating a worker, send an
   explicit start message unless the worker stream already shows assistant
   output from the intended prompt. Count a lane as active only after three
   signals exist: the assistant/event stream has started, the worker-owned
   worktree has either a diff or a clear no-change diagnosis, and the task
   thread records the current prompt. A `running`/`ready` worker with no
   assistant output, command trace, or diff is queued capacity, not progress;
   inspect session logs and nudge or replace it instead of waiting on elapsed
   time alone. Treat prompt files as supervisor reference artifacts, not as
   the worker's primary task context. For every replacement or implementation
   worker, send a live worker message that includes the complete scoped task,
   exact paths, accepted base pins, DoD checks, and first concrete action; do
   not ask the worker to discover a runtime-local prompt file. The first live
   checkpoint must verify assistant stream, fresh-base/root SHA evidence, and
   either a first diff or a concrete no-change/facade-gap diagnosis within one
   short supervision window. For small implementation-only GX/UI lanes, if a
   worker says it is patching but the owned tree remains clean after the gate,
   stop counting it as active implementation and either send a minimal inline
   patch plan or park/replace the worker. If that minimal inline patch plan
   still leaves the tree clean after the next checkpoint, park or replace the
   worker instead of sending another broad nudge. After two clean-tree
   implementation workers on the same GX/UI slice have received complete live
   context plus a minimal patch plan and still produce no diff or concrete
   missing-facade diagnosis, stop retrying the same runtime/model/prompt shape;
   more identical replacements are not active product progress. Before any
   further implementation retry on that same child slice, simplify first:
   create a supervisor-owned source-map and patch-target table with direct file
   paths, exact symbol lists, and no glob-heavy or regex-heavy discovery
   commands. If a GX/UI micro-slice remains no-diff because it discovers
   package-owned helper or API-shape questions, convert immediately to this
   planning gate before the next implementation attempt. The planning artifact
   must name the exact owner for node types, helper symbols, facade alias
   removals, file targets, and focused tests. If ownership or API shape is
   still conceptually ambiguous, use a configured high-capability planning
   template pass to produce the mechanical patch plan, then delegate that
   simplified implementation to the normal supported worker template first.
   Escalate the implementation worker to a stronger configured template only
   after the simplified task still fails because of reasoning or API-shape
   complexity, not because of checkout materialization, prompt shape, or
   tool-router errors. Otherwise escalate the execution path: choose a
   different runtime known to apply patches, route a narrow worker-infrastructure
   diagnosis for App Server or tool-router clean-tree behavior, or ask the
   operator for a narrow supervisor exception to implement the already-scoped
   patch in a worker-owned worktree with normal review and promotion. Keep the
   product backlog count stable unless a concrete missing facade or
   infrastructure repair task is created with its own definition of done, and
   preserve the accepted table and mechanical patch plan as the next attempt's
   starting material. When using that reviewed worker-owned exception path for
   GX/UI, preflight the exact edit context first: read the current alias/import
   blocks and target helper files, patch new implementation files separately
   from alias removals, verify `git status --short` after each chunk, and only
   then run gofmt, tests, and scoped audits. Do not start a large multi-file
   exception patch before the exact context is known, because one stale hunk
   must not erase otherwise-ready progress.
   For the GX/UI form-controls split, treat `pkg/ui/control_uikit_bridge.go`
   as a temporary split aid, not a durable compatibility layer. Every remaining
   form-controls child review must say whether that child shrinks, deletes, or
   leaves each bridge conversion unchanged; if a conversion remains, name the
   exact not-yet-moved boundary that still requires it. By the final
   form-controls alias-removal/deletion-probe child, the bridge must either be
   gone or explicitly reduced to only still-compiler-derived non-form-control
   work from the latest deletion matrix.
   GX/UI planning/source-map workers must satisfy the same owning-module
   hydration gate before their output counts as evidence: prove `pwd`,
   `git rev-parse --show-toplevel`, `git status --short`, and the target files
   from the planning prompt in the exact module root. If a planning worker has
   an empty module checkout or cannot see the target files, stop it as a
   materialization failure; do not treat its no-file diagnosis as a product
   source-map result.
   Before launching another GX/UI product worker after a worker/service
   execution repair, run a local worker health gate across the full
   storage/control-plane chain: prove there is enough disk for service writes;
   prove Postgres is running or recovered; prove a direct Events publish
   succeeds; prove Repos is running and materializes a product workspace; prove
   Workers and API respond from a live PID rather than only a stale status
   file; prove the launched command resolves to the checked-out BusDK
   dispatcher or module binary and supports the profile flags, especially
   `--token-file`; prove the deployed worker integration code includes any
   required evidence-window repair such as the three-minute direct message
   timeout, or state explicitly that it has not reloaded; and run one tiny
   non-product worker/message smoke that produces assistant output inside the
   evidence window. Until Workers API message projections include assistant
   response text, do not count `message.response` with `status=delivered` as
   assistant progress. For product workers, require assistant text in the
   worker Codex session JSONL, a real worker-owned git diff or commit plus
   required check output, or explicit runtime error evidence; `ready`, a clean
   worktree row, and delivered-only messages are transport evidence only. For
   tonight's GX/UI local App Server work, use `--environment local-dev` only
   unless the worker system is repaired and a smoke proves another environment.
   `--environment local` has accepted create requests that did not materialize
   in the live local pool or produced unusable module roots. Treat an
   accidental `local` create as an environment-routing mistake, stop or ignore
   it immediately, and do not wait on it as product capacity. For tonight's
   GX/UI data/evidence lanes, prefer the configured local mini/evidence worker
   template on the local App Server substrate unless the default implementation
   template first passes a fresh assistant-output smoke; materialization without
   assistant text is false-active capacity.
   For GX/UI render tests, verify the target package's GX intrinsic elements
   or constructors before writing expected markup, or reuse elements already
   proven in neighboring tests. Do not assume generic HTML tags such as
   `strong` or `em` are available in the GX intrinsic table.
7c. Before adopter workers edit against newly accepted shared facades, require a
   fresh-base preflight in the worker message that names the repository root
   for every SHA check. In nested BusDK/product worktrees, BusDK commits,
   module commits, and supervisor commits live in different repositories; a
   correct preflight prints `pwd`, `git rev-parse --show-toplevel`, the BusDK
   superproject HEAD from the worker's product-worktree root, the target module
   root and module HEAD from the module directory, and relevant submodule pins
   from the BusDK root when the task depends on a core facade commit. Do not
   write generic "must include commit X" prompts without stating which repo is
   expected to contain that commit. If a core facade lands while an adopter
   worker is already running, treat stale-base promotion as a review risk and
   rebase, recreate, or explicitly justify acceptance before promoting its
   patch.

17. If the worker substrate is partially usable, prefer dispatching an
   infrastructure worker or reviewer worker over local implementation. Use the
   supervisor checkout for investigation and evidence gathering, not for
   absorbing product implementation.
18. When the supervisor must make an exception, record the reason in the current
   hourly memo, including why worker delegation was unavailable, what exact
   infrastructure path was restored, what verification was run, and which tasks
   should be reopened or dispatched afterward.
19. Periodically compare recent hourly memos, task statistics, and active-worker
   evidence against the active goal. If independent parallel capacity is
   underused, explicitly dispatch/refill unblocked work or record the concrete
   blocker; report utilization truthfully instead of implying full capacity
   when the board is idle or thinly staffed.
20. Treat each periodic memo/task-stat review as an operating-control loop, not
   as a retrospective note. The review must end with one of these concrete
   outcomes: updated PLAN/tasks, new or reopened worker dispatch, promoted or
   rejected worker output, a documented automation improvement, or a specific
   reason why no safe parallel work can be started. If the review finds
   underutilization, stale workers, repeated manual steps, or evidence gaps,
   convert that finding into the next supervisor action before returning to
   ordinary status reporting.
21. For every substantial supervisor session and every progress report on an
   active multi-worker goal, do a compact goal-health review before answering:
   recent memo evidence, active workers per environment, independent unblocked
   work topics, accepted/promoted output since the previous review, current
   bottleneck, and the next dispatch/reopen/promote action. If the review shows
   idle capacity on H100, dev-hg, local, or other configured environments, fill
   it with scoped work unless a concrete blocker prevents it.
22. Measure the supervisor process by accepted work and learning rate, not by
    activity. Record when actual parallelism is materially below available
    capacity, when the supervisor absorbed work that should have been delegated,
    when a worker lane failed because of platform friction, and what guidance,
    PLAN item, automation task, or worker dispatch was created to prevent the
    same stall from recurring.
23. For broad goals, use delegated supervisor agents as the normal scaling
    unit. The lead supervisor should own global priority, acceptance, pinning,
    and operator communication, while sub-supervisors own work lines such as
    remote freshness/proof, parallel lane refill, review/promote triage, or a
    specific module family. A sub-supervisor should not merely write a one-shot
    report: it should start safe workers, monitor them, refill the lane when a
    worker exits, and leave accept/reopen guidance with evidence.
24. Lead supervisors and delegated sub-supervisors must read and apply
    `skills/bus-product-delivery-supervisor/SKILL.md` and
    `skills/bus-dev-task-worker-ops/SKILL.md` before running broad supervisor
    loops, dispatching workers, or reporting progress on multi-worker goals.
    Sub-supervisor prompts must include these skill paths so the scaling loop
    is not lost when work is delegated to another agent.
25. After accepting and pinning changes that affect worker launch, Events sync,
    remote credentials, worker images, model/runtime configuration, or Bus
    developer tooling, update configured remote environments before using them
    as proof. Verify the remote checkout commit, affected submodule SHAs, and
    rebuilt/installed binaries or images. If a remote still runs stale software,
    treat that as an operating issue to fix or delegate, not as product
    evidence.
26. Permission prompts are exceptional. Supervisors must first use already
    approved commands, remote workers, and configured Bus services. Do not ask
    the operator for permission for routine Markdown edits, worker monitoring,
    SSH status checks, remote dispatch, or deterministic verification. If the
    local sandbox blocks Git metadata writes or another required operation,
    continue independent remote/worktree work where possible and request
    permission only when that exact operation is required to finish an accepted
    change.
27. Do not keep broad, vague checklist items as the active operating plan.
    Before reporting a goal checklist or dispatching workers, split fuzzy items
    into module-owned `PLAN.md` entries with concrete DoD: the command or user
    workflow that must work, the service/runtime owner, the required evidence,
    the verification command, and the condition that lets the checkbox be
    closed. Remove or explicitly defer items that are not required for the
    current minimum goal.
    - Do not label general remote-worker features as H100-only unless H100 has
      a genuinely different implementation path. Use H100/dev-hg as test
      environments for the same product feature.
    - Treat configuration/proof work as verification for a feature, not as a
      vague implementation item. If the implementation is really systemd
      service install, remote freshness, credential resolution, or App Server
      model switching, name that feature directly.
    - Split statistics and operator-path work by the exact facts collected or
      command made usable, such as attempt identity, requested/observed model,
      failure reason, recovery/intervention attribution, install command,
      refresh command, status command, or evidence command.
28. When the operator corrects the architecture or priority, update durable
    guidance or the owning `PLAN.md` in the same work session. Do not rely on
    chat memory for repeated lessons such as single-binary/systemd deployment
    shape, per-remote credential sources instead of process-global tokens,
    App Server as the normal worker backend, or H100/dev-hg capacity usage.
    For local Bus worker services, the supported Codex path is the Codex App
    Server protocol, normally launched as a host process so macOS supervisor
    hosts do not require Docker or nested virtualization. Do not reintroduce
    `codex exec`, `direct-exec`, `direct` runner kind, or `codex-direct`
    provider as the operator-facing worker path; add new providers such as
    `bus-agent-runtime` behind the worker provider/App Server-style contract.
    When a normal implementation worker stalls, simplify the task before
    switching templates: split planning from implementation, narrow the files,
    and make the implementation DoD mechanical. For hard or unclear
    architecture/source-map work, use the environment's configured
    high-capability planning template when needed, then delegate the simplified
    implementation to the normal supported implementation template first.
    Escalate implementation to a stronger configured template only after the
    simplified implementation still fails because of reasoning or behavior
    complexity, not because of checkout materialization, unsupported template
    mapping, bad prompt shape, missing hard gates, or quota state.
29. Treat important operator corrections, focus reminders, naming lessons, and
    repeated “don’t do that” guidance as durable memory work, not just chat.
    When the lesson is expected to matter again, write it into the most
    specific relevant `AGENTS.md` in the same session, and update the current
    hourly memo to record why it mattered. Use `PLAN.md` alongside `AGENTS.md`
    when the lesson also changes execution order or acceptance criteria.
    Stage and commit `PLAN.md` changes directly on `develop` in the owning
    repository before moving on; do not leave planning edits as uncommitted
    supervisor checkout drift.
30. For the H100/remote-worker goal, prioritize the minimum real-work loop over
    adjacent product polish: one configured model can be enough, private image
    delivery can be deferred when source-checkout/App Server works, and stats
    can be improved while testing instead of blocking the first accepted loop.
    Keep the checklist focused on work that directly makes remote workers
    productive and repeatable.
31. For unfinished BusDK goals, do not report "not proven" or "not done" as a
    blocker. Before stopping or asking the operator, decompose the remaining
    work into concrete module-owned items with DoD: the command or workflow
    that must succeed, the owner module, required evidence, expected files or
    services touched, and the verification command. For each item, ask whether
    it is truly in the current goal scope or should be deferred. Use the live
    memos to estimate how long the current approach has failed; if the answer
    is hours of unsuccessful work, ask the operator for scope refinement or
    supervisor help with the precise decision needed. When rereading memos,
    check whether the work repeated mistakes the operator had already
    corrected, and immediately improve `AGENTS.md`, `PLAN.md`, or the relevant
    runbook when the instruction was too easy to miss.
32. At BusDK session closeout, review the current hourly memo against these
    operating rules and the operator corrections recorded during the session.
    If the work drifted from the rules, say so in the memo and improve the
    smallest relevant `AGENTS.md`, `PLAN.md`, or skill runbook before
    finishing the session.
33. Use precise acceptance vocabulary. A worker that is `created`, `claimed`,
    `running`, `done`, or even promoted inside an isolated/remote checkout is
    not accepted project progress until supervisor-side review verifies the
    diff, required checks pass, the owning branch is promoted or repaired, and
    the superproject pin is updated when applicable. Reports and memos must
    distinguish: task created, worker claimed, worker produced a diff, worker
    branch promoted, supervisor accepted, root pinned, pushed, and released.
34. When a worker result is partly useful but fails review, prefer the normal
    iterative production loop: reopen with exact findings, hand the repair to a
    stronger model or reviewer lane when useful, or make the smallest
    supervisor acceptance repair only when delegation is blocked. Do not
    describe a first-attempt failure as H100/model failure when the overall
    attempt-review-repair-promote loop is still producing accepted work.
35. Treat pause/release mode as a hard drain-and-collect workflow. When the
    operator pauses new development or asks for a release, stop scheduling new
    work; inspect local, dev-hg, H100, and other configured environments for
    queued/claimed/running tasks; cancel stale queued or false-active streams
    with evidence; collect useful remote patches/logs before stopping
    services; verify no environment has commits ahead of its upstream that need
    retrieval; verify the root checkout is clean; then run the requested
    release command.
36. Treat worktree cleanup as review-first. Prefer first-class Bus prune
    commands and dry-run reports over manual deletion. Do not run destructive
    cleanup while task refs are active or while Git locks may still represent
    live work; use `--apply`-style cleanup only after reviewing the dry-run
    candidates, active-task refusal evidence, and submodule worktree registry
    behavior.
37. After solving a BusDK infrastructure issue, record the reusable diagnostic
    path in the current memo and the most specific `AGENTS.md`. The note must
    include the original symptom, the wrong or stale assumption, the decisive
    command/log/observation, the invariant that fixed it, the verification
    command or proof, and the first check to run next time. This is required
    for worker launch, App Server, Events relay, service startup, install or
    version skew, route pairing, credential, and local safety-filter failures.
38. When a worker or App Server path fails with a vague execution error such as
    "no such file or directory", do not guess at task/worker architecture
    first. Check the exact service process argv, selected binary path, worker
    workdir, App Server allowed directories, sandbox/network policy,
    environment id, and the installed-vs-source commit. Add narrow diagnostics
    that expose paths, ids, booleans, and command names without secrets; then
    reproduce with a fresh worker message before accepting the fix.
39. When a locally built fix does not affect a service or remote proof, assume
    release skew until disproved. Verify the executable that `bus services up`
    launches, the superproject commit, affected submodule SHA, install target,
    and remote checkout before changing product logic. If `make clean build
    install` or submodule refresh is the intended release step, run it before
    judging runtime behavior.
39a. When a Bus tool, service, or worker command behaves inconsistently, check
     freshness in order before adding product workarounds: verify the installed
     CLI/binary was rebuilt from the current owning module source, verify the
     running service process was restarted and is using that installed binary
     and current source config, then inspect or fix the owning Bus module
     source. Treat `dev` or stale version output as a release-skew symptom.
40. When Events relay behavior surprises task or worker flows, inspect Event
    metadata first: origin environment, destination environment,
    sync-target ids, recipient ids, task ref, worker id, correlation id, route
    owner, and durable cursor namespace. Product relay eligibility must not
    depend on event names. Add hermetic fake-transport tests for the Event
    metadata and cursor behavior that caused the surprise, and use live SSH
    proof only as an end-to-end acceptance layer.
41. After the service-owned Events relay MVP is accepted, BusDK product work
    must use Bus tasks and persistent Bus worker identities as the normal and
    exclusive execution infrastructure. Supervisors define task refs, pick or
    create worker identities, send guidance with `bus workers message`, monitor
    Events/status/log evidence, review diffs, reopen incomplete work, and
    promote accepted branches. Supervisors do not directly implement product
    changes or run direct compile/test/install loops as a substitute for worker
    work.
42. Use configured Bus worker templates for all normal BusDK worker identities
    and dispatches. The active environment's template catalog, such as
    `.bus/worker/templates.json`, is the only source of truth for exact
    provider model names, profile names, reasoning effort, verbosity, sandbox,
    runner provider, and identity repo settings. Supervisor goals, PLAN items,
    worker briefs, scripts, and live `bus workers create` commands must select
    a template id discovered from the target environment and describe the
    capability needed; they must not hard-code provider model IDs, assume
    portable template ids across environments, or pass individual model
    settings. Do not compose ad hoc model IDs, template IDs, or command flags to
    encode effort or runtime policy, such as adding `-high` to a model name. If
    a suitable template is missing, add or request the environment template
    first, then dispatch through that template and record the reason in the
    task stream or memo. Reuse
    `docs/docs/research/worker-template-model-selection.md` when choosing
    Codex/Claude profiles or splitting a deep-research workflow across
    extraction, synthesis, implementation, and review phases.
42a. Treat model capability, provider quota, and cost as separate routing
     inputs. Read the dated performance report and Worker-ops skill before
     dispatch, then choose the least expensive available configured template
     whose observed evidence fits the bounded role. Reserve high-cost or
     high-reasoning templates for ambiguous architecture, difficult
     implementation that exceeded a simpler suitable template, or
     acceptance-critical adversarial review. When the operator declares one
     provider pool low, move suitable new work to another provider and record
     that temporary pool policy in Thread 111 and the current memo; do not
     interrupt nearly finished work merely to rebalance quota. When OpenAI
     capacity is the constrained pool, make Claude the first provider for
     suitable new lanes, subject to the Sonnet/Fable/Haiku/Opus role and safety
     boundaries in `skills/bus-dev-task-worker-ops/SKILL.md`.
43. Use the default local dispatch surfaces first. The normal local Services
    stack owns API URLs and generated local Events credentials, so local Bus
    task and worker commands should not need explicit `--api-url`,
    `--token-file`, `BUS_API_URL`, or `BUS_API_TOKEN` arguments. Start or
    refresh the stack with `bus services up`, verify it with `bus services ps`
    and `bus workers list`, and use `bus configure` for `.env` changes. The
    working directory for every `bus ...` command is the BusDK checkout root;
    running it from a supervisor or module root can select the wrong `.env`,
    token directory, and Services runtime and must not be used as evidence of
    an infrastructure failure. The local environment should be the default
    environment; pass `--environment`
    only when targeting another environment or when a temporary diagnostic
    needs explicit disambiguation. Only pass explicit API URLs or token files
    for a documented non-default remote/proof path, and record why the default
    dispatcher settings were insufficient. Live worker prompts must use the
    supported `bus workers message ... --text <prompt>` shape, not guessed
    positional prompt text.
44. The default local Services stack must not require SSH access to
    `dev.hg.fi` or any other remote worker host. `bus services up` must start
    the local control-plane services needed for task submission, review, and
    local worker orchestration without Events relay credentials. Keep
    `events-relay` and remote sync/proof services optional, for example behind
    `--all` or explicit profile selection, so missing remote host keys or SSH
    credentials cannot block local development.
45. Temporary supervisor, worker, proof, and scratch worktrees must live under
    an ignored scratch path, normally `tmp/worktrees/` in this superproject or
    the Services-owned `.bus/services/workers/...` runtime paths. Do not create
    new temporary worktrees, symlink farms, or proof checkouts under
    `projects/busdk/worktrees`; that path is visible to Git status and should
    stay empty unless a future tracked product feature explicitly owns it.
46. `bus-integration-{name}` modules provide their services through the Bus
    Events API only. They may own business logic, durable/runtime state,
    background processing, and integration-side event handling, but they must
    not expose HTTP APIs directly. HTTP/controller surfaces belong in the
    matching `bus-api-provider-{name}` module, which validates API requests,
    publishes canonical Events, and serves projections without taking over
    integration runtime ownership.

## Recipient-Scoped Worker Focus

1. Recipient-scoped implementation workers are not supervisors. They should
   follow the recipient-local `AGENTS.md` and explicit task brief first. This
   does not override the parent supervisor's protected live-memo and closeout
   duties; it only means non-supervisor implementation workers should not
   inherit broad supervisor habits such as repo-wide memo, PLAN, README, or
   throughput review unless the task explicitly asks for those.
2. For minimal implementation or proof lanes, start with the exact failing
   command, named files, stale text, or acceptance surface given in the task.
   Do not spend quota reading root hourly memos, unrelated `README.md` files,
   unrelated `PLAN.md` files, or broad repo guidance unless the named surface
   is insufficient to complete the task honestly.
3. Root supervisor guidance about dispatch boards, throughput reviews, memo
   operating loops, broad plan grooming, and cross-module coordination applies
   to supervisors and sub-supervisors. It is not default required work for a
   recipient-local implementation worker turn.
