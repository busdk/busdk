# Delivery Discipline Runbook

Read this before proposing solution options to the operator, composing or
promoting accepted independent fixes, applying the Finish-First delivery gate
in detail, or doing engine-integration architecture work. Each section
expands a binding core rule in the root `AGENTS.md`.

## Operator Solution Briefs And Composition Discipline

Describe proposed solutions to the operator with this compact brief:

1. Current outcome and exact failure.
2. Fixed constraints and applicable decision IDs.
3. Existing usable implementation or evidence.
4. Options, each with capability, limitation, and change required.
5. Recommended smallest path and why it wins.
6. Independent work items, each with one behavior, owner module, branch,
   focused test, and promotion gate.
7. Composition, user-local install, live acceptance check, and explicitly
   deferred scope.

Keep independently useful fixes separate through implementation and review.
Use one branch and focused commit series per behavior, then compose only
accepted tips in a dedicated integration lane. A rejected optional fix must not
hold back unrelated accepted value. Do not report architecture work as complete
until the SDD, implementation, tests, installed composition, and operator brief
describe the same design.

## Finish-First Delivery Gate Details

These bullets expand the Finish-First Delivery Gate core in the root
`AGENTS.md`; the board-intake bullet remains in root.

- Choose the smallest owner module and independently reviewable change. Add no
  provider, protocol, framework, or cleanup without a failing acceptance check
  that requires it.
- Prepare implementation, E2E evidence, and review in parallel when their
  write scopes do not overlap. Count a lane active only from verified runtime
  and turn evidence plus a task-relevant diff, result, or diagnosis.
- After one failed execution and one materially changed retry, stop repeating
  the mechanism. Preserve the handoff and change runtime, model, environment,
  materialization, or task shape.
- Resolve findings with one additive repair and exact delta review, then return
  immediately to the frozen composed E2E instead of reopening architecture.
- When a reviewed composition passes E2E, integration, install, use, and live
  acceptance are the next default actions. Report promoted-but-unused work as
  finishable debt; do not start adjacent source work ahead of it.
- Preflight repository identity, full SHA, writable clean Git metadata, prompt
  boundaries, credential freshness, runtime truth, and durable result paths.
  Keep heavy work admitted and resource-bounded while independent lightweight
  lanes continue.
- Use Thread 111 only for cross-lane dependencies and accepted baselines. Keep
  detailed evidence in the owning feature Thread and use Thread 146 for future
  delivery-process audits.

## Engine-Integration Architecture (Accepted Decision)

Engine-integration architecture (operator, 2026-07-06): each AI engine gets
its own `bus-integration-<engine>` module that OWNS that engine's main App
Server / agent process instance and exposes it to the rest of Bus through the
Bus Events API under a matching `bus.<engine>.*` event namespace
(`bus-integration-codex` -> `bus.codex.*`, `bus-integration-claude` ->
`bus.claude.*`). Naming must stay aligned module <-> namespace. No one-shot
engine turns anywhere in the codebase: sessions are persistent and steerable.
Other modules (workers, chat, LLM API providers) integrate with engines only
through those events, never by spawning or dialing engine processes directly.
The current `bus-integration-codex` `bus.llm.*` one-shot turn path and the
direct per-worker `codex app-server` spawning in `bus-integration-worker`
predate this rule and are refactoring targets, not precedent.

## Architecture Change Control

Name the accepted decision IDs and fixed constraints before dispatch or code.
An implementation problem does not reopen architecture by itself. First repair
the smallest failing behavior inside the accepted design and inventory existing
branches, commits, tests, and primitives that can be reused. Changing an
accepted decision requires all of: the exact failing acceptance evidence, the
current decision that cannot satisfy it, options considered, the smallest
replacement delta, migration and compatibility impact, reusable work retained,
and explicit operator approval when the change alters an operator constraint or
the active product outcome. Do not implement competing architectures while the
decision remains unresolved.

## Experiment And Proof Discipline

For performance, build, boot, sync, or browser-proof goals, size work to the
acceptance path instead of the current session length. Before starting an
experiment, state the expected effect on the gate metric and the mechanism.
Use focused deterministic checks for small questions, reserve expensive
end-to-end proofs for batched changes or gate decisions, and treat a failed
gate as a re-plan point.

Check new work against rejected approaches by mechanism, not by task name.
When one lane is blocked on a long build, browser run, or remote proof, advance
an independent lane from the active plan. When an environment workaround
repeats, promote the first diagnostic and normal handling rule to the nearest
`AGENTS.md`, runbook, or module plan instead of re-explaining it in memos.

## Board Intake Commands

Before each new or resumed BusDK feature turn, read the owning module
portfolio and latest shared baseline from the Bus Thread board. From the
BusDK root, use `bus thread list 231 --depth 2` and
`bus thread show 111 --latest 6`. Place every future canonical BusDK feature
root under exactly one Thread 231 module portfolio. Thread 111 coordination
and Thread 182 active-bug cards remain explicit cross-module navigation
surfaces; product work, including Thread 3 and its descendants, belongs
beneath its semantic product/module hierarchy.

## Root Makefile Contract

When editing the root `Makefile` or adding root orchestration, preserve
superproject-only orchestration: exactly one root `Makefile`, POSIX shell,
`git`, POSIX `make`, deterministic discovery of `bus` and `bus-*` module
Makefiles, delegation via `make -C`, required lifecycle targets, module-local
`./bin` outputs, `PREFIX`/`BINDIR`/`DESTDIR`, Go variable pass-through, and
changed-module-scoped root test/e2e defaults. Do not add lockfiles, alternative
build systems, package-manager integrations, or reimplemented module internals.

## Identities And Authorization Model

For the current identities/auth refactor, authorization is binary resource
access: an identity either has access or not. Defer fine-grained permission
bitmaps until a concrete product need appears.

## Worker Backend Registry Detail

Engine choice is the `(runner_kind, runner_provider)` pair resolved through
the `WorkerRunnerProvider` registry in
`bus-integration-worker/pkg/workersintegration/runner_provider.go`; providers
`codex-direct`, `codex-appserver`, and `bus-agent-runtime` coexist today. For
a Claude-backed provider design (Agent SDK vs persistent stream-json stdio vs
`ModelProvider`, Codex concept mapping, auth policy), read the research note
`docs/docs/research/claude-worker-backend.md` before re-researching.
