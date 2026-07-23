# AGENTS.md

Merged guidance from `.cursor/rules/*.mdc`.

## Scope And Precedence

1. Apply this file to the whole BusDK superproject.
2. If instructions conflict, use this order:
   1. Repository identity, security, privacy, and safety constraints.
   2. Definition of done and quality gates.
   3. Module boundaries and architecture contracts.
   4. Repo-local skill runbooks and task-specific instructions.
3. Prefer minimal, deterministic, script-friendly behavior.
4. For module work, read this file plus the most specific local `AGENTS.md`
   under the target subtree before changing files.

## Guidance Layout

- Keep this root file limited to superproject orchestration, cross-module
  architecture, family-wide policy, safety, release-quality rules, and skill
  triggers.
- Put module-specific implementation, command behavior, and local workflow
  rules in the owning module's `AGENTS.md`; those files must stand alone for
  independently checked out modules.
- Keep module README files focused on simple end-user orientation and default
  use. Put fuller end-user module documentation under `docs/docs/modules/`,
  and put implementation contracts, boundaries, and design traceability under
  `sdd/docs/modules/` or the owning module's `AGENTS.md`.
- Use repo-local skills in `./skills` for detailed operational runbooks. Mount
  those skills into worker containers when practical.
- Bus CLI implementers and reviewers should read `docs/docs/cli/output-style.md`
  for the shared human/structured output conventions before adding or changing
  a command's rendering.
- Keep public docs free of agent-only process rules. For SDD/public-doc
  architecture candidates, leave compact triggers and follow-up notes unless a
  task explicitly asks for public documentation edits.
- Keep detailed, conditional operating guidance in `runbooks/*.md` in this
  repository. Each root section below names its runbook trigger; read a
  runbook when its trigger matches the current task instead of loading it by
  default.

## Architecture Stability And Decision Briefs

Before planning or implementing a change that affects module ownership,
deployment authority, process lifecycle, resource control, provider/runtime
boundaries, or cross-module contracts, read
`sdd/docs/architecture/architecture-decision-register.md` and the owning module
SDD. The register is the current cross-module architecture authority. Module
SDDs refine it; module `AGENTS.md` files provide operational rules; public docs
describe user-visible behavior. Goal pages, plans, threads, memos, rejected
branches, and historical reports are evidence and history, not architecture
authority.

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

Before proposing solution options to the operator or composing accepted
independent fixes, read the solution-brief template and composition discipline
in `runbooks/delivery-discipline.md`.

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

Use the workspace `./tmp` directory for large generated artifacts, copied
rootfs/disk images, browser/QEMU bundles, build evidence, and anything that may
need inspection or promotion. Host `/tmp` is small and should be reserved for
small throwaway files. If a temporary artifact may later become workspace
evidence or an input to a promoted workflow, create it under workspace `./tmp`
from the start instead of moving it from host `/tmp`.

## Public Surface Naming

Public API names, command names, package-set names, artifact IDs, config schema
names, service names, event names, and documented user workflows must be named
for the finished BusDK product, not for temporary milestones or prototype
phases. Do not put terms such as `mvp`, `prototype`, `temporary`, or
`experimental` into public surfaces that would become stale or deprecated once
the product is complete. Milestone wording may appear in planning notes or
historical evidence, but active user-facing interfaces should use durable
product concepts such as package, image, profile, release, task, worker,
service, event, artifact, or acceptance.

For the browser-hosted operating system work, use product names that describe
the actual shipped shape: QEMU/WASM port, Bus Engine OS, and the
`virtual-server` or `virtual-desktop` profiles. Do not introduce or revive
`browser lab` / `browser-lab` as a product, page, artifact, or workflow name;
that term may appear only when rejecting or migrating an obsolete compatibility
alias.

## Agent Communication Style

Avoid formulaic contrast sentences in user-facing replies and public project
text, especially the pattern `This is <classification>, not <contrast>`.
Rewrite those statements as direct guidance that says what action, evidence,
or priority matters. For example, prefer "Handle this as a packaging-policy
decision after the runtime package work is stable" over "This is a policy
decision, not a runtime file." Apply the same rule to close variants such as
`That is ... not ...`, `<thing> is ... rather than ...`, and other phrasing
that reads like a generated classification followed by a negated contrast.

## Live Working Memo

Maintain a live hourly working memo during every substantial session in
`./logs/{YYYYMMDD}-{HH}-agent-memo.md`, using the current local/project time
and continuing the same file while the hour is unchanged. Write it as a
truthful editorial engineering diary in Markdown narrative form, not a
checklist: what was attempted, found, decided, and verified, plus what remains
uncertain. When the hour changes, finish the memo with a handoff note and
continue in the new hourly file; end every session with a concise final state.
Never write secrets, tokens, private customer data, or raw environment dumps
into memos or committed logs. Do not edit historical memos after their hour
except to remove sensitive information or undo an accidental inappropriate
edit.

This root file keeps the binding memo contract above. Before substantial
sessions, memo closeout, or Bus Notes use, read
`runbooks/live-working-memo.md`; it carries the full memo style contract,
which expands this core without replacing it.

## Supervisor Worker Delegation

This section is core operating memory for Codex supervisor agents in this
repository. The supervisor/worker boundary below is binding and stays in this
root file. `runbooks/worker-delegation.md` and `runbooks/gx-ui-delegation.md`
expand it with the detailed operating rules and keep the original rule
numbering; they must be read when their triggers below match.

1. In supervisor mode, all implementation work that can be delegated must be
   done through Bus task/work workers, not by the supervisor directly editing
   product or module code in the primary checkout.
2. The supervisor's default job is to define work, update PLAN/memo guidance,
   dispatch workers with clear scopes and acceptance criteria, monitor
   progress, provide guidance, review results, reopen incomplete work, promote
   accepted commits, and keep the board moving.
3. The supervisor may edit repo guidance, `PLAN.md`, live memos, and narrow
   coordination artifacts when those edits are themselves supervision work.
4. The only normal exception for direct implementation edits is when there is a
   real blocker and the infrastructure needed to run Bus task workers is not
   available, and the direct edit is the narrowest safe change to restore that
   worker infrastructure.
5. For any worker dispatch, activation-evidence check, template or model
   routing, environment freshness verification, pause/drain, worktree cleanup,
   or worker-failure diagnostic decision, read
   `runbooks/worker-delegation.md` before acting; it continues these rules as
   items 4-7 and 17-46.
6. Before any GX/UI cleanup, adopter migration, facade-parity, assistantui,
   terminalui, or `pkg/uikit`-removal work, read
   `runbooks/gx-ui-delegation.md` (items 7a-15) together with
   `skills/bus-ui-gx-roadmap/SKILL.md` from the skills index.

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

## Parallel Supervisor Operating Standard

This standard is core operating memory for broad BusDK goals: broad goals run
from a ready queue of scoped, unblocked, module-owned tasks; review is
asynchronous work and must not stop dispatch; claimed or running workers count
as capacity only when they emit meaningful task-stream progress, reviewable
diffs, or exact failure evidence; and hourly memos for broad goals record
numeric utilization and name the concrete bottleneck whenever safe capacity
sits idle.

Before running a broad multi-worker goal, sizing parallel lanes, judging
utilization or throughput, or designing service and worker resource limits,
read `runbooks/parallel-supervision.md`; it carries the full numbered standard
and the Service Resource Isolation Standard, both of which remain binding.

## Repo-Local Skills Index

Read the relevant skill before doing detailed operational work:

Keep this index current. Whenever adding a new repo-local skill, deleting a
skill, renaming a skill, moving a skill file, or materially changing a skill's
purpose, trigger conditions, or operating scope, update this root index in the
same change set with the skill path, basic purpose, and when agents should read
it. Do not leave skill discovery dependent on memory, chat history, or scanning
the `skills/` directory.

1. `skills/bus-product-delivery-supervisor/SKILL.md`: broad multi-module
   supervision, worker dispatch, monitoring, review, process improvement,
   throughput analysis, heartbeat/progress/closeout reporting, and GX/UI
   roadmap coordination. Use it before running supervisor mode.
2. `skills/bus-dev-task-worker-ops/SKILL.md`: concrete `bus task` / `bus
   workers` dispatch, event-driven wait, evidence-based template routing,
   Compose/App Server workers, monitoring, reopen, closeout, promotion,
   auth/token handling, write scopes, worker infrastructure troubleshooting,
   and generated-artifact promotion hazards. Use it before touching worker ops.
3. `skills/bus-plan-memory-maintainer/SKILL.md`: `PLAN.md`, `AGENTS.md`,
   Bus Notes/hourly memo practice, tracker-file processing, durable lessons,
   historical verification, commit/tracker closeout, and planning granularity.
   Use it before `PLAN.md` or `AGENTS.md` edits, memo closeout, tracker-only
   commits, or durable lesson capture.
4. `skills/bus-ui-gx-roadmap/SKILL.md`: GX and Bus UI feature-candidate
   planning, docs, implementation, semver promotion, and portal migration
   prerequisites. Use it before planning, dispatching, reviewing, or reporting
   GX/UI roadmap work, feature-candidate implementation, portal migration, or
   semver promotion.
5. `skills/bus-docs-quality/SKILL.md`: public docs and SDD structure, Markdown
   linting, UI docs page shape, examples, links, and duplicate-content cleanup.
   Use it before editing public docs, SDD docs, README-style documentation,
   Markdown examples, docs navigation, or docs lint fixes.
6. `skills/bus-go-quality-review/SKILL.md`: Go implementation/review gates,
   unit/e2e expectations, module Makefile checks, and final `bus lint
   path/to/file.go` peer review. Use it before touching Go files.
7. `skills/bus-generated-artifact-hygiene/SKILL.md`: generated WASM/static
   artifact tracking, ignore/clean/regenerate rules, and dirty-checkout
   prevention. Use it before touching generated browser, WASM, static, build
   output, or other artifact files, and before deciding whether generated
   changes should be committed, regenerated, ignored, or cleaned.
8. `skills/bus-development-retrospective/SKILL.md`: evidence-based
   development retrospectives for releases, incidents, agent-worker sessions,
   difficult implementation periods, and public docs reports under
   `docs/docs/reports/` when the retrospective should be shareable. Use it when
   source changes, worker performance, `bus dev task` conversations/events,
   human orchestration, stale next-step claims, and durable guidance/test/doc
   updates all need review.
9. `skills/bus-llm-tool-prompt-construction/SKILL.md`: prompt-template
   construction for BusDK tools that send prompts to LLMs, especially
   local-model, worker, reviewer, and prompt-sending code. Use it before
   changing LLM prompt builders or request assembly.

## Repository Identity

1. This repository is the public superproject for `busdk/busdk`.
2. Do not implement accounting logic or BusDK module source code here.
3. Keep BusDK modules as Git submodules at repository root (`bus`, `bus-*`).
4. Treat checked-in submodule commit SHAs as authoritative pins. Do not add
   lockfiles.
5. Use `develop` as the only normal integration and promotion branch for the
   BusDK superproject and Bus modules. Do not merge, fast-forward, push, or
   promote work to `main` unless the operator explicitly asks for `main` in
   that specific request. GitHub default branches remain `main` by design:
   `main` is the stable previous-release branch, not the normal active
   promotion target.
6. Before editing the root `Makefile` or adding root orchestration, read the
   `Root Makefile Contract` below.
7. Do not add root CLI binaries or network features to this superproject.
8. The `.bus/` directory is a tracked project directory. Never add `.bus` or
   `.bus/` ignore rules. Runtime lock artifacts such as `.bus-dev.lock` may be
   ignored.
9. Do not treat `.bus/`, `Makefile.local`, `./tests`, or `FEATURES.md` as
   temporary files unless a repository explicitly documents an exception.

## Root Makefile Contract

When editing the root `Makefile` or adding root orchestration, preserve
superproject-only orchestration: exactly one root `Makefile`, POSIX shell,
`git`, POSIX `make`, deterministic discovery of `bus` and `bus-*` module
Makefiles, delegation via `make -C`, required lifecycle targets, module-local
`./bin` outputs, `PREFIX`/`BINDIR`/`DESTDIR`, Go variable pass-through, and
changed-module-scoped root test/e2e defaults. Do not add lockfiles, alternative
build systems, package-manager integrations, or reimplemented module internals.

## Repository Visibility And Secrets

1. Public/open-source repos: `./` (superproject), `./bus`, `./docs`,
   `./busdk.com`.
2. Private/commercial-customer repos: every `./bus-*` module unless explicitly
   documented otherwise.
3. In public repos, do not introduce in-process coupling to private module
   internals; use stable CLI/library/API boundaries only.
4. This public superproject and its public docs/examples must never contain real
   SMTP, database, JWT, API, AI provider, webhook, signing, password, private
   key, DSN-with-password, or customer secrets.
5. Do not accept secret values as command-line arguments in BusDK tools or
   services. Secrets must come from environment variables, user config secret
   files, deployment secret files, OS credential storage, or standard input
   where explicitly designed.
6. Treat committed `AGENTS.md`, docs, and examples as public unless they are
   explicitly inside a private repository. Logs, memos, and notes are internal
   operator records, but still avoid writing secrets unless the owning
   repository explicitly documents a private secret-handling surface.
7. Never print broad `.env` contents. Query only exact non-secret keys or report
   key presence with values redacted.
8. Never auto-write JWTs, API tokens, refresh tokens, or auth-session files
   under repository-local `.bus/` paths or any other working-tree-relative
   default. Use the unified user config root, explicit operator-supplied paths,
   environment variables, or OS credential storage.
9. For multi-remote worker credential design, keep root metadata non-secret and
   read `skills/bus-dev-task-worker-ops/SKILL.md`.

## Definition Of Done

Production, bug-fix, and user-visible behavior changes require deterministic
automated tests, appropriate e2e coverage, formatting/lint/static/security
checks, docs/help/SDD updates when behavior changes, backward compatibility
unless explicitly approved, and tracker follow-up for any approved exception.
Before module command, test, runtime, CLI, docs, restricted API, or Go changes,
read the owning module guidance and the relevant skill or SDD source.

### Finish-First Delivery Gate

Thread 146 is the process-retrospective reference for this gate. Before new or
resumed source work, name one user/operator outcome and freeze the exact local
composed E2E command; bug fixes also freeze the identical parent-fail and
candidate-pass scenario. Keep unfinished source on immutable feature refs.
Do not merge, pin, install as accepted, or call the feature complete until that
E2E passes against the exact composition.

For the detailed gate bullets on lane admission, mechanism-change retries,
additive repair, promoted-but-unused debt, preflight scope, and Thread 111
usage, read `runbooks/delivery-discipline.md`.

- Before each new or resumed BusDK feature turn, read the owning module
  portfolio and latest shared baseline from the Bus Thread board. From the
  BusDK root, use `bus thread list 231 --depth 2` and
  `bus thread show 111 --latest 6`. Place every future canonical BusDK feature
  root under exactly one Thread 231 module portfolio. Thread 111 coordination
  and Thread 182 active-bug cards remain explicit cross-module navigation
  surfaces; product work, including Thread 3 and its descendants, belongs
  beneath its semantic product/module hierarchy.

## Cross-Module Architecture

Before changing module boundaries, command ownership, Events/auth/config,
AI-host behavior, provider/runtime architecture, notes modules, naming,
private/public coupling, or cross-cutting platform behavior, read
`docs/docs/sdd-source-index.md` and the owning module `AGENTS.md`.
For the current identities/auth refactor, authorization is binary resource
access: an identity either has access or not. Defer fine-grained permission
bitmaps until a concrete product need appears.

## Product Taxonomy Guidance

Before editing `PRODUCTS.md`, public product pages, product-line module
mappings, or taxonomy exclusions, read
`docs/docs/product-taxonomy-guidance.md`. Root policy: keep `PRODUCTS.md` as a
user-facing product taxonomy, not a module inventory or agent process note.

## LLM Tool Prompt Construction

Before changing BusDK tools that build or send LLM prompts, read
`skills/bus-llm-tool-prompt-construction/SKILL.md`. Root reminder: keep stable
prompt instructions before per-run dynamic context unless the skill or owning
module documents a narrower exception.

## Worker Backend Policy

Before choosing or changing Bus development worker backend/runtime behavior,
read `skills/bus-dev-task-worker-ops/SKILL.md` and the owning module
`AGENTS.md`/`PLAN.md`. Root policy: Codex App Server is the normal development
worker backend, one-shot Codex is legacy compatibility, and durable worker
lanes must not use the Events `memory` backend for retained task history.
Engine choice is the `(runner_kind, runner_provider)` pair resolved through
the `WorkerRunnerProvider` registry in
`bus-integration-worker/pkg/workersintegration/runner_provider.go`; providers
`codex-direct`, `codex-appserver`, and `bus-agent-runtime` coexist today. For
a Claude-backed provider design (Agent SDK vs persistent stream-json stdio vs
`ModelProvider`, Codex concept mapping, auth policy), read the research note
`docs/docs/research/claude-worker-backend.md` before re-researching.

Before engine-integration work — `bus-integration-<engine>` module boundaries,
engine process ownership, engine event namespaces, or one-shot turn removal —
read the accepted engine-integration architecture decision in
`runbooks/delivery-discipline.md`.

## Supervisor Host And Remote Environment

When operating BusDK from the parent supervisor host, read the parent
`AGENTS.md` and the parent checkout's
`runbooks/supervisor-host-troubleshooting.md`. Root BusDK
policy: environment names, remote ids, and host aliases are deployment data,
not product constants; do not hardcode SSH usernames, ports, gateway details,
keys, host-key policy, or environment-specific names into product code, tests,
profiles, or product documentation.

## Commit And Deletion Safety

Read `skills/bus-plan-memory-maintainer/SKILL.md` before tracker-only commits
or memory closeout. Root safety context: commit only when asked or explicitly
allowed, commit staged scope only, never push/tag/sync without request, use
tracked/untracked deletion commands deliberately, and keep tracker-only commits
separate from implementation/docs/test changes.

## Shell And Tool Hygiene

Keep commands simple, portable, path-correct, bounded, and redacted. For
Docker inspection, readiness probes, worker monitoring, and disposable
worktrees, read `skills/bus-dev-task-worker-ops/SKILL.md` and
`runbooks/worker-delegation.md`. For historical delivery claims and progress
reports, read `skills/bus-product-delivery-supervisor/SKILL.md` and
`runbooks/parallel-supervision.md`. For shell scripts inside a module, follow
the owning module's `AGENTS.md` and `skills/bus-go-quality-review/SKILL.md`
when the script supports Go checks.

## Simplify Before Building

Before building new feature, infrastructure, or workflow machinery, first look
for the smallest honest path that solves the active goal. For detailed
supervisor decision rules and worker-infrastructure simplification, read
`skills/bus-product-delivery-supervisor/SKILL.md`.

## Troubleshooting And Evidence Discipline

For infrastructure, worker, runtime, API, sync, App Server, Events relay,
service-freshness, credential, or remote-runtime failures, read
`skills/bus-dev-task-worker-ops/SKILL.md` before changing product behavior.
Root evidence policy: enable enough non-secret observability to prove the
failing boundary, never log secrets or raw customer-sensitive data, and record
the reusable diagnostic sequence in the memo and owning guidance after a fix.
