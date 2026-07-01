# PLAN.md

- [ ] Complete browser-hosted Bus Engine OS `virtual-server` and
  `virtual-desktop` with OPFS-backed persistent storage.
  - Scope: after the `bus-pkg` package-management module is buildable,
    dispatched as `bus pkg`, and connected to Bus Engine OS package metadata,
    continue the QEMU/WASM Linux-in-browser goal for both profiles.
  - Acceptance: `virtual-server` runs as a full single-user Bus Engine OS
    environment in Chromium; `virtual-desktop` adds the graphical desktop and
    a graphical web browser inside the guest; both profiles include working
    Codex CLI installed in the guest and prove a non-networked in-guest smoke
    such as `codex --help`; the browser-hosted VM has working virtio-net
    through a real WASM QEMU network gateway; persistent guest state is backed
    by browser OPFS through a virtio block-device design, with an immutable
    base image separated from a writable persistent user/state disk, flush and
    clean-shutdown semantics, quota/status reporting, and reset/export/import
    behavior documented and tested. Implement this as coordinated work across
    `projects/qemu` and `projects/busdk`: QEMU owns the generic browser/WASM
    virtio-blk and OPFS block backend, while BusDK owns Bus Engine OS profiles,
    package membership, browser harness wiring, UI, documentation, and
    downstream acceptance evidence. Do not archive the goal until full
    system-test evidence proves both profiles boot in Chromium, Codex CLI runs
    in each guest, virtio-net gateway traffic works, OPFS-backed guest writes
    survive a browser reload or restart, and the `virtual-desktop` guest runs a
    graphical web browser inside the browser-hosted VM.
- [ ] Clean up post-deletion Bus UI `uikit` residue without reopening the
  removed package.
  - Scope: current public docs/catalog/PLAN references that still teach
    `pkg/uikit` or name deleted source files, including
    `bus-ui/PLAN.md`, `bus-ui/pkg/uicatalog/component_catalog.go`,
    `bus-ui/pkg/uiartifact/artifact_test.go`, module docs/SDD pages, and
    product docs that are not explicitly historical.
  - Acceptance: docs and catalogs point to public owner packages
    (`pkg/ui`, `pkg/assistantui`, `pkg/terminalui`, `pkg/uiportal`,
    `pkg/uitest`) or are marked historical; no implementation worker is
    dispatched for `pkg/uikit`; static audits distinguish package references
    from accepted `assets/uikit.css` URL strings.
- [ ] Review root-level remote cleanup salvage artifacts under `logs/remote-worktree-salvage-20260610-13`, especially preserved superproject scripts/profiles and unmerged branch archives. Acceptance: route each preserved root-level patch to the owning module or root plan item, apply only still-useful deltas to `develop`, and record discarded superseded worker branches before deleting the archive.
- [ ] Clean up stale local worker registry/projection behavior while removing
  deprecated direct Codex runner support.
  Current local `bus workers list` can still show old `runner_kind=direct` /
  `runner_provider=codex-direct` records as `running` after `bus workers stop`
  returns success, while `bus workers status` reports zero workers and the
  recorded PIDs are no longer alive. Acceptance: lifecycle mutations require
  no hidden direct-exec compatibility path, stopped workers are reflected
  consistently by list/status/show, stale runtime records are marked stopped or
  pruned with auditable events, and new worker creation supports only Codex App
  Server or Bus-owned runtime providers such as `bus-agent-runtime`.
  Reproduced during the Repos materialization normal-services proof on
  2026-06-11: `bus workers stop repos-normal-proof-mini-20260611e` returned
  success and published `bus.workers.stop.request`
  `evt_1781193793271936000`, but no stopped snapshot followed, the App Server
  process remained live until manual teardown, and duplicate parentless
  `bus-integration --provider workers` children reappeared beside the
  Services-owned wrapper/child. Treat that as worker/service lifecycle hygiene,
  not a Repos materialization failure.
This is the active BusDK superproject work tracker.

## Worker/Offload Supervisor Queue, 2026-06-17

Current audit result: do not dispatch from stale proof notes alone. The older
H100/dev-hg smoke transcripts prove useful substrate facts, but they are not
the current next action when H100 is paused, when service-owned relay is still
unchecked, or when a note describes behavior already promoted in module plans.
The accepted `bus-agent-runtime` provider bridge, self-hosted defaulting,
local-supervisor sync bootstrap, task attachment primitive, and first local
App Server materialization fixes are evidence to build on, not lanes to reopen
unless a fresh regression reproduces them.

Run the worker/offload board from this queue until it is superseded by accepted
module commits and updated pins. Product implementation must be delegated to
workers or done in worker-owned Git worktrees; this supervisor checkout may
edit plans, memos, prompts, and review artifacts only.

1. Scheduler/service loop owner: `bus-integration-worker`.
   - Dispatch next: turn the reusable claim/replay/capacity packages into the
     stable worker-owned service loop surface.
   - DoD: one worker-owned branch replaces task-owned worker glue for the
     steady monitor/reconcile/start cycle, preserves `bus.worker.supervisor.*`
     naming, proves mixed environment capacity/routing, and passes focused
     scheduler tests plus `go test ./...`.
   - Stale-note guard: old `bus-integration-task --supervisor-once` proof is a
     fixture, not accepted product ownership.
2. App Server lifecycle productization owner: `bus-integration-worker` with
   `bus-api-provider-worker` projection checks.
   - Dispatch next: drive `appserver-exec` through proxied `bus.workers.*`
     Events on `coding-agent@dev.hg.fi`, including free-port allocation,
     existing-branch reuse, worker-local `CODEX_HOME`, metadata/log files, and
     stop/resume status snapshots.
   - DoD: fresh create/status/message/stop flow produces assistant text or a
     structured runtime failure, a real worker-owned diff or no-change
     diagnosis, and API/CLI projections agree without reading remote files.
   - Stale-note guard: manual dev-hg Spark launcher scripts remain reference
     artifacts only.
3. Runtime parity owner: `bus-agent-runtime`, coordinated through
   `docs/docs/goals/codex-fork.md`.
   - Dispatch next: build the Codex App Server parity matrix and shared
     runtime-adapter contract tests for Codex App Server and `bus-agent-runtime`.
   - DoD: checked-in parity table maps observed worker behavior to
     implemented/missing/non-goal/unknown, and every missing/unknown worker
     behavior has an unchecked owner item and fixture or contract test.
   - Stale-note guard: H100 Gemma real-work proof stays deferred until the
     operator reopens H100 and local parity gates are green.
4. Closeout/status/replay hygiene owners: `bus-integration-worker`,
   `bus-api-provider-worker`, and `bus-worker`.
   - Dispatch next: split three local regressions into separate worker tasks:
     stale runtime session projection after service restart, lifecycle request
     replay creating old workers, and host-side closeout commit when runtime
     sandbox Git metadata prevents commit finalization.
   - DoD: restarted services converge old `running` rows to stopped/failed
     evidence, historical create requests do not relaunch workers, completed
     dirty-tree runtime closeout can commit on the host boundary, and
     list/show/status/logs/attach expose redacted diagnostics.
5. Deterministic evidence/status owner: `bus-dev` with worker integration
   event producers.
   - Dispatch next: define and enforce the task-attempt evidence contract
     across `task show`, `task monitor`, `work status`, and `work stats --all`.
   - DoD: JSON/text surfaces classify evidence as complete, incomplete, or
     legacy partial for success, no-change, failed worker, blocked closeout,
     startup failure, timeout/no-output, stale refusal, and remote launch
     failure, with requested vs observed model/profile/reasoning and remote
     identity visible.
6. Relay/freshness owner: `bus-events`, `bus-remote`, `bus-dev`, root scripts,
   and deployment modules.
   - Dispatch next: service-owned relay status plus make-owned service
     freshness proof, so local/dev-hg work does not depend on `--sync-now`,
     stale installed binaries, or hidden dispatcher paths.
   - DoD: relay cursors/counters/route identity survive restart without replay
     storms, `bus-dev` prefers relay-service health, and the proof gate reports
     live process path/version/commit or explicit inspection-unavailable
     diagnostics.
7. Repeatable dev-hg/H100/offload proof owner: root supervisor after items 1,
   2, 5, and 6 have accepted local or dev-hg evidence.
   - Dispatch next only when prerequisites are green and H100 use is allowed:
     issue a local task, relay it to the selected remote, let remote-local Bus
     services claim/start/complete, sync terminal evidence and artifacts back,
     review through task attachments, then promote/pin accepted work.
   - DoD: proof records task ref, remote id/kind, model/reasoning, worker id,
     branch/commit or structured no-change, verification commands, artifact
     ids/extraction command, cleanup state, and no manual `scp` or ad hoc shell
     correction except recorded break-glass defects.

For the older H100 section below, treat `Current Refined Finish Line` as
historical context plus the eventual proof checklist. Do not spend paid or
fragile remote time until the service-owned queue above has produced the local
or dev-hg evidence needed to make that proof repeatable.

## Codex Fork / Bus Agent Runtime Parity Goal

`docs/docs/goals/codex-fork.md` owns the cross-module goal for the Bus-owned
Go implementation of the headless Codex App Server worker-runtime surface. The
completed worker-provider bridge made `bus-agent-runtime` available through
`bus workers` while keeping explicit Codex providers intact.

- [ ] Promote accepted Bus Agent Runtime Workers branches and sync configured
  environments.
  - Goal: once the module slices are reviewed and verified, their accepted
    commits must land on the relevant module `develop` branches, update the
    BusDK submodule pins, and be synced to the configured development
    environments.
  - Scope:
    - promote only reviewed worker-owned implementation branches
    - pin updated module commits in the BusDK superproject
    - sync local, `coding-agent@dev.hg.fi`, and `coding-agent@ai.hg.fi` as
      required by the goal
    - keep rejected branches, temporary proof worktrees, and stale worker
      attempts out of `develop`
  - Verification: clean module status, pushed `develop` branches, updated
    BusDK pin commit, and environment sync evidence.

## Service Tool Freshness And Runtime Proof Gate

Goal definition: routine local, dev-hg, and H100 service proofs must not waste
time on stale installed BusDK binaries, wrong dispatchers, or sandbox-hidden
service processes. The standard release/proof path is make-owned: build and
install the needed tools, restart Services through the dispatcher-first
profiles, inspect the live process executable path from an environment that can
see the processes, and compare command version/commit metadata against the
expected source commits. `bus services` may report and verify service state, but
must not build product binaries.

Implementation-ready split:

- Root Makefile freshness: worker owns `Makefile` and
  `tests/superproject/test_*freshness*.sh` or a new focused superproject test.
  Reproduce the stale case where `$(BINDIR)/bus-api` is newer than
  `bus-api/bin/bus-api` while `bus-api` source is newer than its bin artifact;
  `make install` must rebuild through the module Makefile before deciding the
  installed binary is current. Checks: `make -s install CHANGED_MODULES=...`
  fixture proof, scoped `SKIP_MODULES` proof, and
  `make superproject-source-selftest` if the new test is included there.
- Service-critical build metadata: workers split by module family. First add a
  shared version metadata contract to the dispatcher/critical binaries, then
  wire `bus`, `bus-api`, `bus-integration`, `bus-worker`/`bus-workers`,
  `bus-services`, `bus-integration-services`, and service-critical integration
  commands. Checks: focused `--version --format json` or equivalent tests in
  each owning module plus a root installed-binary current-commit proof.
- Services liveness and process identity: `bus-integration-services` owns
  native status inspection, child executable/path/version capture, and
  machine-readable inspection diagnostics; `bus-services` owns CLI/status
  projection only. Checks: focused `ESRCH` versus `EPERM`/inspection-denied
  tests, JSON status shape tests, and no secret environment values in state.
- Make-owned proof gate: root owns `make services-refresh-proof` after the
  preceding metadata exists. It must build/install, restart through
  dispatcher-first Services profiles, inspect live PIDs from an environment
  that can see them, compare dispatcher and resolved child identities, and fail
  closed on stale or uninspectable processes unless an explicit diagnostic is
  emitted.

- [ ] Fix root `make install` freshness end to end: remove the root-level
  installed-binary-newer-than-module-bin shortcut or run the module build before
  applying any shortcut, so module Makefiles own source freshness. Add
  superproject regression coverage for the stale case where source is newer
  than `module/bin/<module>` while `$(BINDIR)/<module>` is newer than that bin
  artifact, and verify `make install`, `make build install`, and scoped
  `SKIP_MODULES`/`CHANGED_MODULES` behavior remain deterministic.
- [ ] Add service-critical build metadata end to end across the dispatcher and
  Services stack binaries: reuse the `bus-agent-runtime` pattern so `bus`,
  `bus-api`, `bus-integration`, `bus-worker`/`bus-workers`, `bus-services`,
  `bus-integration-services`, and service-critical integration commands expose
  stable text plus JSON version metadata with module name, version, commit, and
  build time. Add module e2e coverage that packaged and installed binaries
  report the expected current commit, and keep release metadata non-secret.
- [ ] Add a make-owned Services freshness proof gate end to end, for example
  `make services-refresh-proof`: build/install the service-critical binaries,
  restart the root Services stack through the normal dispatcher-first profiles,
  inspect live service PIDs (`/proc/<pid>/exe` on Linux and the macOS
  equivalent such as `lsof`), capture process start times, capture command
  version/commit metadata, and fail when any live process uses the wrong
  dispatcher, stale installed binary, stale module commit, or uninspectable
  process without an explicit inspection-unavailable diagnostic. This target
  must live in the root Makefile or a root script called by make, not in
  `bus services`.
- [ ] Make process-inspection failures explicit end to end: update
  `bus-integration-services` and `bus-services` PID checks so `Signal(0)` or
  platform process inspection distinguishes process-missing (`ESRCH`) from
  inspection denied/unavailable (`EPERM`, sandbox denial, missing `/proc`,
  denied `lsof`), and reports `inspection_unavailable` or an equivalent
  machine-readable status instead of `exited`. Add focused tests for
  permission-denied liveness checks and status output.
- [ ] Preserve dispatcher-first Services profiles while making child resolution
  auditable: continue starting service profiles as `bus api`,
  `bus integration`, and other dispatcher commands, then add dispatcher or
  service-state metadata that records the resolved child executable path and
  version/commit for the dispatched module. The proof gate must catch both a
  wrong `bus` dispatcher and a dispatcher that resolves a stale `bus-*` child
  without switching profiles to direct module binary invocation.

## High-Priority Service-Owned Events Relay Goal

Priority: high. Treat service-owned Events relay as a gating prerequisite for
the trustworthy remote worker lane and for routine H100/dev-hg task routing,
not as medium-priority transport polish.

Goal definition: normal local-to-remote development work must not require a
supervisor to run manual `bus events export`/`import`, SSH sync loops, or
`bus-dev --sync-now` as the daily path. Each configured worker environment
should run a bounded Events relay service that forwards target-marked local
task and Notes operation events to the remote Events API, imports remote-origin
claim/progress/terminal/lifecycle evidence back, persists checkpoints, and
reports enough status for `bus-dev` and supervisors to know whether routing is
healthy.

Implementation-ready split:

- `bus-events`: promote the existing local/testable `bus events relay` command
  into a deployable service mode that reads route definitions derived from Bus
  remote/environment metadata, keeps explicit durable state files, exposes
  status JSON, and proves restart/resume/no-loop behavior.
- `bus-services` plus `bus-integration-services`: make the normal
  `services.yml` profile able to start the relay without proof-specific route
  files or embedded secrets, and expose profile/status metadata for route id,
  local/destination environment ids, state path, credential-source labels, and
  health counters.
- `bus-operator-deploy`: install/update the relay as part of the normal
  user-systemd development-host profile, including config/token-file refs and
  status diagnostics; do not require process-global `BUS_API_TOKEN`.
- `bus-dev`: consume relay health/checkpoints for remote status/start UX and
  treat `--sync-now` as recovery/debug once the service relay is healthy.
- Live proof: one normal local-to-dev-hg or local-to-H100 stack creates a local
  task, relays to remote, sees remote claim/progress/terminal Events, relays
  evidence back, and shows local status/stats without manual import/export or
  proof-only relay config.

Current supervisor-host topology: this macOS supervisor checkout should run the
local Bus control/Event infrastructure used for task submission, status, and
review. Docker-backed worker execution for this goal should happen on
`coding-agent@dev.hg.fi`; local starts should relay task Events to that remote
worker Events service and relay remote worker evidence back for local review.

Minimum completion checklist:

- [ ] Add the owning `bus-events` implementation follow-up for a deployed relay
  service path over the existing local/testable `bus events relay` command.
- [ ] Define route configuration from `bus-remote`/environment metadata without
  operator hand-composition: the normal reusable `services.yml` should be
  shareable across local and dev-hg-style systems, declare only local service
  roles, and not expose proof secrets, token paths, SSH-forward ports,
  duplicate route files, or remote-environment configuration. Once both
  environments are running `bus services up` and one side has the other
  configured as a Bus remote, Services should derive the local/destination
  Events URLs, stable environment IDs, atomic route-pair identity,
  deterministic active/passive relay ownership, credential source, token
  issue/refresh behavior, event filters, and durable state/status paths from
  `bus-remote` and owned Bus configuration.
- [ ] Install/run the relay through the normal service surface for local,
  dev-hg, and H100-style environments, with manual one-shot sync kept only as
  recovery/debug tooling.
- [ ] Expose script-friendly relay status: current cursors, last successful
  iteration, forwarded/imported/skipped/pending counters, pending truncation,
  route IDs, credential-source labels, and last error without token values.
- [ ] Teach `bus-dev` remote status/start paths to prefer relay-service health
  and checkpoints over supervisor-triggered `--sync-now` for normal work.
- [ ] Prove restart/resume and no replay storm: stopping and restarting the
  relay resumes from persisted cursors and does not replay old unrelated task
  history or loop imported remote-origin events back to their origin.
- [ ] Prove one live dev-hg or H100 route from the normal root stack, not a
  temporary proof stack: local task creation, service relay to remote, remote
  claim/progress/terminal evidence, relay back to local, and local `bus task`
  status/stats showing the result without manual import/export or
  proof-specific relay configuration.

## Remote Credential Source Selection Goal

Goal definition: remote worker operations must select controller, remote
Events, and worker-runtime credentials from explicit remote configuration or
token files as the normal path. `BUS_API_TOKEN` remains only a compatibility
fallback after configured sources. Expired, unreadable, unsupported, or missing
credentials must fail before expensive worker/model startup with diagnostics
that name the selected remote id/kind and safe source label, never token
values.

## Prompt Cache Follow-Ups

Goal definition: Bus LLM-facing tools should be structured so repeated runs can
reuse the largest possible stable prompt prefix. Stable policy, role, rubric,
schema, and examples must come first; per-run files, paths, task metadata,
tool results, timestamps, and runtime observations must be appended as final
dynamic context. Local-model infrastructure should keep Ollama runners warm and
surface non-secret cache-related configuration without claiming unsupported
cached-token accounting.

## Deterministic Task Evidence Goal

Goal definition: every development-task worker attempt must produce a
machine-readable evidence bundle that is complete enough for a supervisor to
review, retry, promote, and compare work without inspecting remote shells,
container logs, or prose-only closeout. The required bundle is terminal status,
remote id/kind, requested and observed model/reasoning/profile, attempt id and
sequence, worker id, durable worker log pointer, task branch/worktree identity,
commit or explicit no-change state, validation commands with pass/fail/skip
state, structured closeout state, Bus Notes ids or query metadata, and
non-secret timing/failure classification.

- [ ] Coordinate deterministic task evidence across `bus-dev` and
  `bus-integration-task`.
  - Goal: task replay, status, stats, closeout, and promotion should all use the
    same attempt evidence contract instead of reconstructing partial truth from
    worker prose, raw Events, local logs, or environment-specific conventions.
  - Module slices:
    - `bus-integration-task`: emit the complete attempt evidence envelope on
      claim, running/heartbeat, terminal success, terminal failure, blocked,
      no-change, App Server startup failure, timeout/no-output, and exact-ref
      refusal paths.
    - `bus-dev`: preserve requested versus observed model/profile/reasoning
      metadata across creation, reopen, live guidance, replay, status, monitor,
      stats, and review surfaces; expose missing required evidence as explicit
      incomplete evidence rather than silently treating the task as done.
  - Required fields: terminal status/classification, remote id/kind,
    requested/observed model and reasoning metadata, attempt id/sequence,
    worker id, durable worker log pointer or task attachment id, branch,
    worktree id, commit hash or structured no-change reason, validation command
    records, structured closeout state, Bus Notes ids/query, start/end
    timestamps, and redacted failure/block reason when applicable.
  - Acceptance: fixture tests cover successful commit, verification-only
    no-change, failed worker, blocked closeout, App Server startup failure,
    timeout/no-output, stale/unintended task refusal, and remote launch failure
    before worker claim. `bus dev task show --format json`, `task monitor`,
    `work status`, and `work stats --all` expose the evidence consistently, and
    review/promotion paths refuse or flag terminal work that lacks required
    evidence fields.

## Durable Task And Notes Evidence Goal

Goal definition: normal local, dev-hg, H100, and future remote development
services must preserve task and Notes evidence across restarts and remote sync.
Visible `bus.dev.task.*` Events must be exported before any memory-backed
service restart can discard them; normal development services must run Events
with PostgreSQL or an explicit repository-file-backed store rather than process
memory; and worker Notes must be written through `bus.notes.*` Events, synced by
the Events relay, projected into durable Notes storage, and queryable by module,
task, session, tag, source, and origin environment/system.

- [ ] Coordinate durable task and Notes evidence across module plans.
  - Goal: remove memory-backed or direct-only evidence paths from the normal
    worker lane while keeping explicit test/disposable smokes possible.
  - Module slices:
    - `bus-events`: add the durable Events backend/service contract plus a
      memory-backed restart export guard for visible task and Notes operation
      Events.
    - `bus-api`: require normal development service startup to inject or
      configure a durable EventBus backend instead of silently constructing an
      in-memory bus.
    - `bus-operator-deploy`: make user-systemd install/update/restart paths
      detect memory-backed Events services and export/refuse before restart.
    - `bus-api-provider-notes`: route Notes API mutations through `bus.notes.*`
      operation Events with idempotency and source/origin metadata instead of
      direct-only projection writes.
    - `bus-integration-notes`: run the concrete Notes projection worker over
      Events sync/relay and materialize durable projections, including origin
      environment/system fields.
    - `bus-notes`: expose CLI/API query filters for module, task, session, tag,
      source kind/ref, and origin so worker notes remain discoverable after
      remote sync.
  - Implementation-ready ordering:
    1. `bus-events` adds the durable backend contract plus memory restart export
       guard for visible `bus.dev.task.*` and `bus.notes.*` operation Events.
    2. `bus-api` refuses normal service startup with implicit in-memory Events
       unless explicitly marked disposable/test, and reports storage kind in
       readiness/status.
    3. `bus-operator-deploy` calls the memory export guard before
       user-systemd install/update/restart touches a memory-backed Events
       service, or records an explicit discard decision.
    4. Notes modules move writes/projection/query onto the Events-backed path
       after the storage and relay substrate can preserve operation Events.
  - Acceptance: a local-to-remote fixture or live dev-hg/H100 smoke creates a
    task and worker note, syncs out and back, restarts the relevant Events and
    Notes services, and then proves task Events and Notes can still be queried
    locally by module, task, session, tag, source, and origin without token or
    private body leakage in Events payloads.

## Current Refined Finish Line

The current goal is the smallest real, repeatable H100 offload loop. A
ChatGPT-backed supervisor on the local system can issue a real development
task, route it to an H100/UpCloud-style environment, have environment-local Bus
services start a worker that uses `gpt-oss:120b` or `gemma4:31b`, produce a
real code branch/commit, sync terminal evidence back, and let the local
supervisor review, verify, promote, and pin the result. The loop must be
repeatable after a fresh or non-persistent H100 start without hand-shepherding
every step. Productizing all transport/API boundaries perfectly is follow-up
unless it blocks this loop.

Goal definition: a trustworthy remote worker lane is a configured local,
dev-hg, H100, or UpCloud-style environment where normal Bus services, not a
supervisor's ad hoc shell, launch Codex App Server workers for queued
`bus.dev.task.*` work, bind each launch to the intended task ref, use explicit
token-file or credential-source boundaries, preserve durable Events/Notes
evidence, and return enough task, artifact, model, commit, and status evidence
for local review without environment-specific correction. Manual SSH, `scp`,
process-global token export, one-shot `codex exec` fallback, stale replay claim
cleanup, Git metadata repair, and remote-specific start recipes are break-glass
only; any use must be recorded as a defect or follow-up.

Systemd user deployment goal: the normal readiness path for a local or remote
worker environment is one named `systemd --user` service profile that can start
the required Bus infrastructure as one or a few services. The default target
shape is `bus-events`, one combined `bus-integration` runtime for selected
integration/provider handlers, and optionally one `bus-api` runtime for selected
API providers. Unit files must reference explicit config files and token-file or
credential-source paths, never raw secret values or a process-global
`BUS_API_TOKEN` as the normal credential path. Separate-process and
container-backed handlers remain administrator choices, but dev-hg/H100
readiness must not depend on manually launching each handler.

Execution plan by owner:

- `bus-integration-task`: finish the service-owned App Server scheduler,
  exact work-ref launch binding, stale-claim replay safety, App Server-only
  worker lane, model/profile retry semantics, and structured closeout/status
  evidence.
- `bus-dev`: submit work and display scheduler-owned state without becoming the
  scheduler; status/monitor must distinguish queued, launch-pending,
  request-only, launched-only, meaningful running, stale, false-active,
  terminal, and drain-blocked work.
- `bus-events`: provide bounded relay/sync with durable cursor state and normal
  durable storage for development worker Events; memory-backed services are
  test/disposable only and must export visible task evidence before restart.
- `bus-operator-deploy` plus root scripts: make remote readiness and source
  freshness repeatable by installing/updating user services, refreshing root
  and submodule pins, building required binaries/images, and reporting exact
  non-secret service, token-file, model, and checkout evidence.
- `bus-remote`: keep remote metadata non-secret but complete enough to select
  worker environment, tool paths, credential-source references, capacity, model
  defaults, and service status endpoints.
- `bus-notes` / `bus-integration-notes` / `bus-api-provider-notes`: ensure
  worker Notes flow through `bus.notes.*` Events and remain queryable after
  remote sync by module, task, session, tag, and origin.

Minimum completion checklist:

- [ ] Keep the local checkout clean and pinned after every accepted
  worker/supervisor change.
- [ ] Resolve the current dev-hg freshness issue: its `logs` submodule has an
  uncommitted `20260525-15-agent-memo.md`, so the clean dev-hg checkout did
  not refresh to the intended root pin.
- [ ] Rerun the clean local-issued read-only H100 proof from the current
  authoritative root and submodule pins recorded by `git rev-parse HEAD` and
  `git submodule status bus-dev logs`, with H100 already refreshed to those
  pins. This proof is blocked while H100 is paused and until bounded/cursored
  Events sync is available for the local-to-H100 path. When unblocked, run the
  bounded form of `scripts/h100-offload-runner.sh --mode sync
  --ensure-services --refresh-token --timeout 300` from the local root, then
  watch the task from the local supervisor and record the task ref, remote id,
  model, terminal status, and synced evidence.
- [ ] Verify that the read-only proof creates an H100-tagged local task, syncs
  it to H100, starts/claims a worker there, closes terminally, and syncs
  evidence back locally.
- [ ] If the proof still fails before worker creation, fix the exact remaining
  launch/sync defect with evidence, not another manual retry.
- [ ] Make local-to-H100 task delivery reliable enough that the worker does not
  start before the task event is available in the H100 Events API.
- [ ] Make H100/dev-hg service readiness repeatable for fresh/non-persistent
  hosts through a user-systemd service profile: render/install/update/status the
  required `bus-events`, combined `bus-integration`, optional `bus-api`,
  rootless Docker dependency, model runtime, and token/config file checks
  without manually launching each handler.
- [ ] Keep H100 source freshness automated enough for this goal:
  fast-forward root, hydrate required submodules at pins, build/install needed
  Bus binaries, and record root/submodule SHAs.
  - Owning product goal: `bus-operator-deploy` should provide the remote
    freshness command that updates root/submodules, builds or installs changed
    tools, rebuilds or reloads worker images only when needed, restarts affected
    worker services only when inputs changed, and records source/tool/image
    identity evidence before worker dispatch.
  - Near-term bootstrap compatibility: `scripts/remote-checkout-update.sh` may
    remain the explicit Git freshness helper until the Bus command composes it,
    but H100/dev-hg proof should record the same identity facts the final
    command will report.
- [ ] Launch one real product implementation task on H100, not a
  smoke/read-only/test-file task; the current target is the
  `bus-integration-ssh-runner` health/status slice named in the
  `Current first-priority product lane` below.
- [ ] Use explicit per-task model and reasoning settings for that task,
  starting with `gpt-oss:120b` and retrying with `gemma4:31b` only if useful.
- [ ] Ensure the H100 worker can edit, commit, and report a branch without
  manual Git/worktree repair.
- [ ] Sync the H100 task's terminal evidence, model/reasoning metadata, commit
  hash, and worker logs back to the local supervisor.
- [ ] Retrieve the H100 branch locally or through a clean supervisor review
  lane.
- [ ] Confirm first-class task artifact transfer is the normal remote review
  path: the worker attaches patch/log/evidence files through `bus dev task`, the
  local supervisor extracts them with `bus dev task extract`, and review or
  `git am --3way` happens without `scp` or ad hoc shared paths.
- [ ] Run focused verification for the H100-produced branch: module
  tests/checks, `git diff --check`, and relevant `bus lint`.
- [ ] Promote/pin the accepted H100-produced work into the owning submodule and
  superproject.
- [ ] Record the full proof in memo/task evidence: command, task ref, remote
  id, model, reasoning, duration if available, checks, commit, and any manual
  intervention.
- [ ] Prove the same loop is repeatable at least once after remote
  freshness/readiness automation, not only as a one-off success.
- [ ] Confirm per-remote credential handling is sufficient for this loop:
  local/controller token, remote Events token, and worker runtime credentials
  are not confused.
- [ ] Confirm Bus Notes worker evidence uses the platform architecture rather
  than a separate Notes replication layer: Notes API mutations append/consume
  `bus.notes.*` Events, Events sync/relay moves those operation events between
  local/dev-hg/H100 with origin metadata and cursors, and the Notes projection
  is materialized from Events into durable BusData/Postgres or repository-file
  storage.
- [ ] Confirm model/reasoning selection is normal task UX for this loop, with
  env vars only as defaults.
- [ ] Confirm H100/offload status and stats show useful remote identity: remote
  id/kind, model/reasoning, terminal status, and accepted/failed/blocked
  counts.
- [ ] Keep the temporary SSH/bootstrap scripts only as acceptable bootstrap
  tools for this goal, while tracking product follow-up to move control-plane
  ownership into Bus API/services and environment-local runners.
- [ ] Package the minimum UpCloud/H100 operator path: the remote must have a
  clean BusDK checkout, Docker, the selected model, and an Events token file;
  use `scripts/remote-checkout-update.sh --root <remote-root> --ref
  <current-root-ref> --submodule bus-dev --submodule bus-integration-task
  --submodule logs` on the remote to refresh pins, then use the bounded
  `scripts/h100-offload-runner.sh --mode sync --ensure-services
  --refresh-token --timeout 300` path locally to launch/sync. Passing evidence
  is a terminal task event with remote id, model/reasoning metadata, branch or
  commit when writable, and synced logs; failures must name the missing
  prerequisite or failed command.
- [ ] Decide whether private image/software delivery is required for this
  goal's first repeatable path; if not, explicitly defer it and use
  source-checkout/remote-build for the first loop.

- [ ] Current first-priority product lane: make multi-remote worker execution
  useful enough for real operator testing and daily development. Business/user
  value: Bus operators should be able to send work to `localhost`, `ai.hg.fi`,
  UpCloud, and future worker systems through one natural workflow, compare
  which systems produce accepted work, and avoid wasting hosted quota or cloud
  spend on blind experiments.
  Current action: turn the now-proven H100 worker path into local-supervisor
  routing. The H100 writable model-backed worker proof passed on
  `dev@ai.hg.fi`: `scripts/test-h100-local-model-write-smoke.sh` built
  `bus-integration-task:h100-smoke`, launched
  `bus-h100-write-smoke-20260524061759#1.1`, claimed the task, prepared an
  isolated `bus-dev` worktree, reserved
  `testdata/h100-local-model-write-smoke.txt`, ran an H100-local
  `gemma4:31b` child-container command, published `bus.dev.task.done`, and
  verified branch `codex/h100-local-model-write-smoke-20260524061759` at commit
  `1eb0ea7b6b162eb5365069a73a847050b7e2ced0` with message
  `test: h100 local-model write smoke`. A follow-up flag-based run also proved
  `gpt-oss:120b` with `--reasoning-effort high`: task
  `bus-h100-gpt-oss-120b-write-smoke#1.1` published `bus.dev.task.done` and
  verified branch `codex/h100-local-model-write-smoke-20260524130052` at commit
  `7a974d1fae2967eaf56a5bba95a3600e32beb530`.
  Supporting fixes from this proof: SSH-Docker runner scripts now default to a
  300-second remote script timeout with
  `BUS_DEV_SSH_DOCKER_SCRIPT_TIMEOUT_SECONDS`, trusted image-backed workers can
  mount an explicit remote Docker socket, smoke/debug runs can preserve worker
  containers with `BUS_DEV_SSH_DOCKER_WORKER_KEEP_CONTAINER=1`, local-model
  command JSON correctly escapes multi-line shell commands, and the H100
  harness restores copied source patches after building so recipient checkouts
  are clean before workers edit. The smoke scripts now take normal flags for
  model, reasoning effort, endpoint, branch, file/write scope, timeouts, smoke
  dir, runner log, keep-container, image, Docker socket, and Events URLs while
  retaining env fallbacks, so routine runs use stable approved script prefixes
  instead of env-heavy command shapes.
  2026-05-24 21 EEST update: the latest H100 smoke evidence branch
  `codex/h100-local-model-write-smoke-20260524210440` was preserved on
  `bus-dev` origin after the disposable H100 checkout drifted to the smoke
  commit; diverged H100 logs were preserved on `logs` branch
  `codex/h100-offload-logs-20260524`, then the H100 checkout was returned to
  superproject pins with `scripts/checkout-submodule-branches.sh --mode pins`.
  Cost-control follow-up: the `dev@ai.hg.fi` inner H100 VM booted again at
  2026-05-24 21:20 UTC when the supervisor later ran a plain SSH update
  command. The host idle-shutdown timer only counts boot grace, interactive SSH,
  and active Ollama TCP connections as activity, so it can power off while Bus
  services, Docker workers, or supervisor-assigned work are still meaningful.
  Add an explicit Bus/H100 lease or keepalive signal while continuing H100
  validation, and make idle shutdown consider that lease plus active Bus
  task/worker evidence so accidental reconnects do not burn new billed hours.
  `scripts/h100-offload-runner.sh --mode preflight --timeout 20` now passes for
  both `gemma4:31b` and `gpt-oss:120b`, and the runner has an explicit
  `--ensure-services` option for starting the minimal H100 Events/Docker
  provider control plane before preflight when the host is fresh.
  Next action: make local-supervisor to H100 task routing automatic enough for
  daily use by turning the working SSH Events sync into a bounded loop or Bus
  remote transport, then prove the supervisor can issue a task locally and have
  the H100 worker claim, complete, sync evidence back, and expose promotion
  metadata without manually running the whole smoke on the remote host.
  H100 real-work verification checklist:
  - [ ] Fix the local-supervisor/H100 sync scale defect found on 2026-05-25:
    the SSH transport reached H100 and the remote Events service after
    `--ensure-services` plus token refresh, but replayed thousands of historical
    events and killed the local `bus-dev` proof process. Make the sync path
    cursored, target-state-filtered, or otherwise bounded before treating
    `--sync-now` as a daily operator path.
  - [ ] Automate H100 control-plane readiness for local-issued work: when a
    fresh/non-persistent H100 host is selected, the flow should start or verify
    `bus-events`, `bus-integration-docker`, and
    `bus-integration-containers`, refresh the per-remote token file with the
    configured local-development signing path, and then run the bounded sync
    without requiring supervisor hand steps.
  - [ ] Make dev-hg/local ssh-docker launch requests service-owned instead of
    manually dependent on an ad hoc SSH-runner process. Triggering evidence:
    `busdk#77.1` on 2026-05-26 created and synced a dev-hg task for the
    `bus-dev` artifact-transfer slice, but stayed false-active in
    `awaiting bus.ssh.script.run.response` because no deterministic configured
    service consumed the runner request before the controller timeout.
    Acceptance: a `bus dev work --remote dev-hg start ...` launch either
    starts from an already running configured `bus-integration-ssh-runner` or
    same-process `bus-integration` host using token-file credentials, or
    terminally fails with clear evidence; supervisors should not need to start
    a one-off local runner or inject process-global `BUS_API_TOKEN`.
  - [ ] Use the remote checkout/update helper for the live H100 checkout: push
    current root/submodule commits, fast-forward the remote superproject,
    hydrate only required submodules at pinned commits, build the Bus binaries
    needed by the worker harness, and record root plus touched submodule commit
    ids.
  - [ ] Launch one H100 image-backed worker on a real product task, not a
    smoke-only file edit, using explicit task arguments for model, reasoning
    effort, write scope, branch, Events URL, and commit behavior. The first
    target is a small `bus-integration-ssh-runner` health/status slice using
    `gpt-oss:120b`; if it fails from model quality, retry the same task with
    `gemma4:31b` and record the handoff.
  - [ ] Retrieve and review the H100 branch locally: inspect the diff, run the
    module's focused tests/checks plus `git diff --check`, and either promote
    it, reopen with precise guidance, or mark the platform/model issue in the
    owning module PLAN.
  - [ ] Add deterministic superproject dependency hydration for disposable
    module review/worktree tests: a reviewer or worker should be able to create
    a temporary checkout of one submodule and run its focused Go tests without
    hand-linking sibling `replace` modules from the superproject. Acceptance
    requires a script or Bus command that reads the superproject/submodule
    layout, prepares sibling module paths beside the disposable worktree using
    authoritative pins or configured branches, and documents when to use the
    helper for remote worker review and promotion.
  - [ ] Record proof evidence in the current hourly memo and task event stream:
    model, reasoning effort, runtime duration, terminal status, commit hash,
    checks, whether another model/supervisor fixed the work, and what should
    be automated next.
  - [ ] Prove parallel multi-remote execution with at least two remote
    identities active in the same run, preserving isolated worktrees,
    recipient/write-scope ownership, terminal evidence, and serialized
    promotion.
  - [ ] Add per-remote capacity and throughput reporting so supervisors can see
    accepted/failed/blocked work, tasks/hour, latency, and stale workers by
    remote id/kind and by remote+recipient.
  - [ ] Mature remote default/selection UX so commands that need worker
    systems make `--remote`, configured defaults, and built-in remotes feel as
    predictable as `git remote` rather than special-case local/cloud flags.
  - [ ] Add integrated multi-system worker scheduling: users should be able to
    request work and let Bus choose or fan out across eligible remotes according
    to explicit capacity/cost/policy limits, instead of manually starting a
    separate flow per system.
  - [ ] Prepare the UpCloud manually installed runner path for operator-owned
    live testing. Do not run paid live tests here; instead provide the software
    readiness checklist, expected commands, non-secret evidence to collect, and
    clear pass/fail criteria so the external UpCloud system can test it.
  - [ ] Add GPU/server format switching support from Bus for the single-image
    UpCloud model: support changing the existing VPS format/model on demand
    without reinstalling the image, keeping create/delete/provisioning outside
    the near-term scope unless explicitly approved.
  - [ ] Measure worker throughput and cost by remote, including enough event
    metadata for local Docker, UpCloud, and future remotes to compare accepted
    work per hour and operator-visible cost signals.
  - [ ] Smooth Go agent tooling: make `gopls` MCP and Go debugger support
    usable by Codex/dev-task workers without brittle method errors, surprise
    installs, host attach, or unclear prompt context.
  - [ ] Finish release-quality blockers that directly affect this lane: the
    full all-module `quality-complete` rerun and remaining module help/docs
    cleanup found by the sweep. `busdk#99.1` reclassified the old
    `busdk#86.1` blocker: the exact prior failure command,
    `timeout 10s env -u BINARY bus-configure/bin/bus-configure --help`, now
    exits 0 with deterministic help, and the focused root changed-module
    `quality-complete` run for `bus-configure` passes doc/help lint.
  - [ ] When reporting "release hardening", name the concrete risk, affected
    user/operator workflow, and why the fix matters now; do not use broad
    hardening language without enough detail for the operator to choose.

- [ ] Coordinate oversized module `AGENTS.md` linting and compaction from the
  superproject. Use `bus lint AGENTS.md` in each affected module, review every
  AI-backed agent-guidance finding, and refactor oversized guidance without
  losing useful rules.
  - Goal: keep module guidance useful for workers while reducing repeated,
    stale, or misplaced instructions that waste agent context and make
    supervision less reliable.
  - Supervisor discovery: run `find bus bus-* docs busdk.com sdd logs
    -maxdepth 2 -name AGENTS.md -type f -size +8k -print` from the
    superproject, ignoring `./tmp`, disposable worker homes, generated
    artifacts, and archived logs that are not active instruction surfaces.
    Save the affected path list in the supervisor note/worker brief, not in a
    generated file, unless a later worker owns a real tracker/document update.
  - Initial affected modules/projects for sharding: `bus`, `bus-accounts`,
    `bus-agent`, `bus-api`, `bus-api-provider-books`,
    `bus-api-provider-session`, `bus-assets`, `bus-attachments`,
    `bus-balances`, `bus-bank`, `bus-bfl`, `bus-books`, `bus-budget`,
    `bus-config`, `bus-configure`, `bus-data`, `bus-dev`, `bus-faq`,
    `bus-filing`, `bus-filing-prh`, `bus-filing-vero`, `bus-gateway`,
    `bus-gx`, `bus-help`, `bus-init`, `bus-integration-task`,
    `bus-inventory`, `bus-invoices`, `bus-journal`, `bus-ledger`, `bus-loans`,
    `bus-payroll`, `bus-pdf`, `bus-period`, `bus-preferences`,
    `bus-reconcile`, `bus-replay`, `bus-reports`, `bus-run`, `bus-sheets`,
    `bus-ui`, `bus-validate`, `bus-vat`, `docs`, and `busdk.com`. Re-run
    discovery before dispatch because the affected set may change as shards
    land.
  - Worker shard shape: dispatch one recipient-scoped task per affected module
    or per tightly related small batch only when the recipients share one
    public docs surface and have non-overlapping write scopes. Each worker owns
    exactly that recipient's `AGENTS.md` plus any closer child `AGENTS.md`,
    repo-local `skills/**`, or public docs paths explicitly listed in the
    brief. Do not let a module worker edit the superproject `PLAN.md`, another
    module's `AGENTS.md`, or public docs unless the write scopes name those
    paths.
  - Batching priority: start with the highest worker-context and dispatch-risk
    surfaces: `bus-dev`, `bus-integration-task`, `bus-agent`, `bus-api`,
    `bus-gx`, `bus-ui`, `docs`, `busdk.com`, and root-facing command modules
    such as `bus-configure`, `bus-help`, `bus-run`, and `bus-validate`. Next
    batch private/commercial business-domain modules by shared accounting
    vocabulary (`bus-accounts`, `bus-books`, `bus-journal`, `bus-ledger`,
    `bus-reports`, `bus-vat`, payroll/filing/reconcile/bank flows), then
    compact remaining leaf provider/helper modules. Serialize promotion for
    same-recipient follow-ups.
  - Compaction method: preserve guidance by deduplicating repeated root policy,
    moving long operational runbooks into repo-local skills, moving durable
    public architecture or user-facing behavior into docs/SDD when appropriate,
    and replacing moved detail with compact trigger/index bullets that say
    when to read the new location. Use closer child `AGENTS.md` files only for
    path-specific implementation rules that workers need before editing those
    paths.
  - Public/private boundary: never move private/customer/commercial-module
    rules, customer examples, local deployment details, or secret-handling
    specifics into public docs, `docs`, `busdk.com`, or the public root. Public
    repos may keep generic safety, CLI/API boundary, and release-quality rules;
    private modules keep commercial implementation constraints inside their own
    repository guidance or private repo-local skills.
  - Preservation rules: do not delete guidance merely to reduce byte count.
    Keep module-specific safety, auth/token handling, data/privacy, release,
    generated-artifact, e2e, and lint/test requirements unless they are exact
    duplicates of stronger root guidance. When removing or moving text, record
    the destination or reason in the worker closeout.
  - Required worker loop for each shard: read root `AGENTS.md`, the target
    module `AGENTS.md`, and any existing local skills first; run `bus lint
    AGENTS.md` before editing to capture agent-guidance findings; compact or
    move/reference-index the guidance; then rerun `bus lint AGENTS.md` and the
    module-appropriate Markdown/text gates. Use worker-safe lint mode only for
    deterministic closeout if the AI-backed lint runtime is unavailable, and
    report that limitation explicitly.
  - Acceptance criteria per shard: `AGENTS.md` is smaller or clearly better
    indexed; every moved rule has a reachable destination or trigger; no
    private guidance moved to public surfaces; no module-specific safety/test
    rule silently disappears; `bus lint AGENTS.md` findings are resolved or
    individually deferred with rationale; changed files match declared write
    scopes; closeout lists moved/kept/deferred guidance and exact verification
    commands.
  - Superproject review gates: review each worker diff before promotion with
    `git diff --check`, `bus lint AGENTS.md` in the changed recipient, and any
    module `make`/docs quality target the worker reports as appropriate. Reject
    shards that only delete content for size, blur public/private boundaries,
    add broad public process rules, omit lint evidence, or leave moved guidance
    undiscoverable.

Historical context for the current first-priority worker-offload lane:
  development execution has been shifting toward Bus-owned local and UpCloud AI
  worker infrastructure under hosted Codex budget constraints. The remaining
  concrete follow-ups live under the first lane above; this section records
  accepted state and prior evidence so supervisors do not reopen completed
  broad discovery work.
  Current operator-ready state:
  - H100 host `dev@ai.hg.fi` has been proven reachable through SSH as non-root
    `dev` when the managed GPU runtime is up; in that state it can run
    Docker/Compose, has Ollama with `gemma4:31b`, and can rebuild the dev-task
    worker image from a disposable checkout.
  - `scripts/test-h100-local-model-worker-smoke.sh` is the repeatable setup and
    smoke command. A passing run must rebuild/install the worker image, start
    minimal Events/Docker provider services, run the local-model child
    container, record the model response, and end with `bus.dev.task.done`.
  - SSH local port forwarding is not available; use
    `scripts/sync-events-over-ssh.sh` for bootstrap event/history movement.
    A passing sync reports imported event counts and can be verified by replay
    on the destination Events API.
  Next ordered steps:
  - Convert manual Events sync into an operator UX/loop suitable for local
    supervisor to remote worker task routing.
  - Prove local-supervisor-issued work can sync to H100, run there, sync
    terminal evidence and promotion metadata back, and be reviewed locally.
  - Run a two-remote proof after local-supervisor routing works: one local
    Docker remote plus `ai.hg.fi`, with per-remote status/stat evidence.
  Current UpCloud direction: optimize first for one manually installed
  UpCloud VPS image that can run Bus-owned worker containers and later be
  resized or changed to a different UpCloud GPU/server format on demand without
  reinstalling the virtual server. Bus should eventually be able to request
  that format/model switch, but broad GPU virtual-server creation/provisioning
  is not part of the immediate lane unless existing installation support already
  covers it safely.
  Add Go-aware Codex worker context through `gopls` MCP in this lane: review
  official `gopls` MCP support, use detached `gopls mcp` for saved-file worker
  containers by default, generate the model instructions with
  `gopls mcp -instructions` into task context, expose opt-in policy/config for
  Go workers, and account for security/network/cache behavior before enabling
  it on local or UpCloud worker images.
  Current accepted base: `bus-remote` owns named remotes including
  `localhost`, `localhost:{port}`, URL remotes, and `ai.hg.fi`; `localhost` is a
  Docker Compose remote, not a special local-only shortcut. `bus-dev` resolves
  dev-task/work commands through `bus-remote`, launches Compose remotes through
  `compose.yaml`, uses conditional append for multi-remote
  claiming/group allocation, and has no open local PLAN work. The
  `bus-integration-task` module records remote metadata in worker/App
  Server closeout evidence, consumes worker-start requests, supports
  task-scoped `gopls` MCP context, and supports safe no-install `dlv dap`
  debugger context. `bus-integration-upcloud` supports no-spend
  `existing-only`/`adopt-existing` manually installed runner modes and preserves
  task env/workdir/source metadata. No paid UpCloud provisioning has been
  performed.
  Current shortest path after the external SSH-Docker proof: treat the first
  UpCloud H100 server as an operator-provisioned SSH-Docker remote, install or
  build the worker image on that host from pushed source, run the same
  image-backed self-test smoke there, then add one model-backed worker backend
  that talks to an operator-managed local inference endpoint. Use existing
  inference/UpCloud/Ollama modules and command-line tools; do not build new MCP
  servers for this slice.
  H100 target note: `dev@ai.hg.fi` is a special SSH-gateway target. Current
  operator observation says repeated SSH connections can land on the same live
  system, so it can be used like a normal remote shell while the gateway session
  is alive. The system/storage is still non-persistent, so product automation
  should treat it as session-local compute only: tolerate reconnects and
  scratch loss, avoid SFTP/SCP assumptions, make setup commands repeatable,
  keep durable state in Git/Bus Events/image artifacts, and treat `/workspace`
  as shared scratch rather than permanent storage.
  `scripts/build-ssh-docker-worker-image-remote.sh` now bootstraps a missing
  remote checkout from the configured Git remote before pinned submodule sync
  and image build, so disposable GPU hosts do not need pre-existing source
  state.
  `scripts/prepare-ssh-docker-worker-host.sh` now wraps that into a first-run
  host preparation path: bootstrap/update source, build the worker image, and
  start the Compose services needed by image-backed workers. The H100 gateway
  now lands as non-root `dev` and accepts normal non-interactive SSH commands;
  the remaining gateway limitation is local port forwarding to the remote
  Events API.
  - [ ] Add automatic remote rebuild/upgrade planning for both released and
    development versions. Production operator systems should be able to detect
    newer signed/released Bus artifacts or image bundles, fetch only the needed
    artifacts, rebuild/restart worker services when policy allows, record
    source/image identity, and preserve rollback evidence. Development systems
    should additionally support a Git-based upgrade lane that fetches/pulls the
    superproject and submodules to the requested branch or pinned SHA, rebuilds
    local tools/images directly from source, and restarts the worker stack
    without requiring a GitHub release, GHCR visibility, or published private
    software. Keep secrets out of command arguments, make the upgrade
    idempotent for non-persistent H100/UpCloud hosts, and expose dry-run/status
    output so supervisors know when a remote is stale before dispatching work.
  - [ ] Queued after local-supervisor-to-H100 routing proof: run an
    operator-ready multi-remote dry-run and local proof package from the current
    pinned root,
    covering `bus dev work --remote eligible start --dry-run`, `bus dev work
    stats`, and the no-spend UpCloud existing-runner checklist. Owner modules:
    `bus-dev`, `bus-remote`,
    `bus-integration-upcloud`, `docs`, and `sdd`. Acceptance: commands and docs
    show how an operator can test localhost plus an external manually installed
    runner without provisioning paid resources here. Prerequisites: a clean or
    intentionally dirty-reconciled root checkout, local Events token file,
    configured `localhost` and external SSH-Docker remotes, and no live UpCloud
    create/delete command unless explicitly approved. Expected safe results:
    dry-run emits worker plans only, stats show remote ids/kinds without
    starting paid resources, and the checklist names exact evidence an operator
    should collect from the external runner.
      - [ ] Prove writable edit/commit/promotion on the prepared SSH-Docker
        host with a tiny controlled task, then decide whether GitHub push/pull
        should be part of worker closeout or a separate deterministic sync
        command. Current state: source sync and remote image rebuild are
        deterministic scripts, while worker-authored branch publication through
        GitHub is not yet fully automated in the SSH-Docker smoke path.
        - [ ] Model-backed write proof: `scripts/test-ssh-docker-codex-write-smoke.sh`
          reached the real Codex App Server on `coding-agent@dev.hg.fi` as
          `bus-ssh-docker-smoke#11.1`, but repeated OpenAI websocket
          `401 Unauthorized` diagnostics led to no worktree changes. The bridge
          correctly blocked with `codex app-server task produced no worktree
          changes`; next step is fixing the remote Codex/model auth path or
          running the same writable smoke through the planned local-model
          endpoint.
- [ ] Run and finish the complete superproject quality sweep end to end: use the existing slow `quality-complete` root target to run source/static quality across every buildable `bus` and `bus-*` module, lint each available module `--help` output with `bus lint --type cli-help`, lint each published end-user module page under `docs/docs/modules/{name}.md` with `bus lint --type documentation`, fix source/help/documentation findings in the owning module/docs repo, rerun focused checks while iterating, and close only after the full all-module complete-quality sweep passes with no findings.
  - [ ] `busdk#100.1` remaining module-owned doc/help cleanup from the
    doc/help-only evidence capture: `make quality-complete
    QUALITY_COMPLETE_SOURCE=0 QUALITY_COMPLETE_BUILD=0
    QUALITY_COMPLETE_KEEP_GOING=1 QUALITY_COMPLETE_PROGRESS=1` reported
    `quality-complete: 117 step(s) failed across 114 module(s)` after
    attempting documentation lint for 114 modules and help lint for 107 modules;
    the failing total breaks down to 45 documentation-lint failures and 72
    help-lint failures. Exact focused rerun form for each module:
    `make quality-complete QUALITY_COMPLETE_SCOPE=changed
    CHANGED_MODULES='<module>' QUALITY_COMPLETE_SOURCE=0
    QUALITY_COMPLETE_PROGRESS=1`. Current failing modules and failure classes:
    `bus-accounts` documentation; `bus-api` help;
    `bus-api-provider-billing` help; `bus-api-provider-books`
    documentation/help; `bus-api-provider-cloud` help;
    `bus-api-provider-containers` help; `bus-api-provider-data`
    documentation; `bus-api-provider-database` help;
    `bus-api-provider-events` documentation/help;
    `bus-api-provider-inference` help; `bus-api-provider-llm`
    documentation/help; `bus-api-provider-node` help;
    `bus-api-provider-notes` documentation; `bus-api-provider-session`
    documentation/help; `bus-api-provider-terminal` help;
    `bus-api-provider-usage` help; `bus-api-provider-vm`
    documentation/help; `bus-assets` documentation/help;
    `bus-attachments` documentation/help; `bus-balances` documentation;
    `bus-bank` documentation; `bus-bfl` help; `bus-billing` help;
    `bus-books` help; `bus-budget` help; `bus-chat` help; `bus-config` help;
    `bus-configure` help; `bus-data` documentation/help; `bus-debts`
    documentation; `bus-entities` help; `bus-events` documentation;
    `bus-factory` documentation; `bus-faq` help; `bus-files` documentation;
    `bus-filing-prh` documentation/help; `bus-filing-vero`
    documentation/help; `bus-gateway` documentation/help; `bus-gx` help;
    `bus-help` help; `bus-init` help; `bus-inspection` help;
    `bus-integration-billing` help; `bus-integration-cloud`
    documentation/help; `bus-integration-codex` help;
    `bus-integration-containers` documentation/help;
    `bus-integration-database` help; `bus-integration-task` help;
    `bus-integration-docker` documentation/help;
    `bus-integration-inference` documentation/help;
    `bus-integration-node` documentation/help; `bus-integration-notes`
    documentation; `bus-integration-ollama` help; `bus-integration-podman`
    documentation/help; `bus-integration-postgres` help;
    `bus-integration-ssh-runner` documentation/help;
    `bus-integration-stripe` documentation/help; `bus-integration-upcloud`
    help; `bus-integration-usage` help; `bus-inventory` documentation/help;
    `bus-invoices` help; `bus-journal` documentation; `bus-ledger` help;
    `bus-loans` documentation/help; `bus-memo` help; `bus-notes`
    documentation/help; `bus-operator-auth` help; `bus-operator-billing`
    documentation; `bus-operator-cloud` documentation/help;
    `bus-operator-database` documentation/help; `bus-operator-deploy` help;
    `bus-operator-node` help; `bus-operator-stripe` help;
    `bus-operator-token` help; `bus-payroll` documentation; `bus-pdf`
    documentation/help; `bus-period` help; `bus-portal` help;
    `bus-portal-ai` documentation; `bus-portal-notes` documentation;
    `bus-reconcile` help; `bus-remote-control` documentation; `bus-replay`
    documentation; `bus-secrets` documentation/help; `bus-sheets` help;
    `bus-status` help; `bus-update` help; `bus-validate` documentation/help.
  - [ ] `busdk#109.1` focused root quality reconnaissance follow-up: the worker
    stopped the broad AI-backed quality run early when it was heating the
    operator laptop, but captured enough evidence to route high-value owner
    fixes. Direct isolated worktree discovery found zero buildable modules
    because empty submodules plus the read-only `/workspace/.git/worktrees/...`
    gitdir block `make init`; the disposable `/tmp` copy excluding `.git`,
    `tmp`, and copied `bin` outputs found 114 buildable modules. Source/static
    quality reached all 114 modules and failed on `bus-books`,
    `bus-inspection`, `bus-ledger`, `bus-portal`, and `bus-portal-ai`. Route
    those as first follow-up workers, then continue with AI-platform and
    multi-remote docs/help cleanup, then accounting/filesystem/destructive CLI
    docs/help cleanup. Later `/tmp/.../bus/bin/bus: not found` lines in the
    task evidence were stop artifacts from terminating the expensive run, not a
    separate product finding.
    - [ ] Route AI-platform and multi-remote docs/help cleanup into explicit
      owner tasks for the provider/integration modules that affect operator
      setup confidence for localhost, external Events remotes, and UpCloud
      existing-runner testing.
    - [ ] Route accounting/filesystem/destructive CLI docs/help cleanup into
      explicit owner tasks for the modules whose help/docs affect safe scripted
      release and customer smoke usage.
