# PLAN.md

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

## Durable Task And Notes Evidence Goal

Goal definition: normal local, dev-hg, H100, and future remote development
services must preserve task and Notes evidence across restarts and remote sync.
Visible `bus.dev.task.*` Events must be exported before any memory-backed
service restart can discard them; normal development services must run Events
with PostgreSQL or an explicit repository-file-backed store rather than process
memory; and worker Notes must be written through `bus.notes.*` Events, synced by
the Events relay, projected into durable Notes storage, and queryable by module,
task, session, tag, source, and origin environment/system.

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
