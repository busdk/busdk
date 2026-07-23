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

Name the accepted decision IDs and fixed constraints before dispatch or code;
an implementation problem does not reopen architecture by itself. Before
changing an accepted decision, proposing solution options to the operator, or
composing accepted independent fixes, read the architecture change-control
rules, solution-brief template, and composition discipline in
`runbooks/delivery-discipline.md`.

## Experiment And Proof Discipline

For performance, build, boot, sync, or browser-proof goals, size work to the
acceptance path and state the expected gate-metric effect before starting an
experiment; the full experiment and proof discipline is in
`runbooks/delivery-discipline.md`.

Use the workspace `./tmp` directory for large generated artifacts, copied
rootfs/disk images, browser/QEMU bundles, build evidence, and anything that may
need inspection or promotion. Host `/tmp` is small and should be reserved for
small throwaway files. If a temporary artifact may later become workspace
evidence or an input to a promoted workflow, create it under workspace `./tmp`
from the start instead of moving it from host `/tmp`.

## Public Surface Naming

Name public surfaces (APIs, commands, package sets, artifact IDs, config
schemas, services, events, documented workflows) for the finished BusDK
product, never for temporary milestones or prototype phases.

## Agent Communication Style

Avoid formulaic contrast sentences (`This is X, not Y`) in user-facing replies
and public project text; state the action, evidence, or priority directly.

Before naming any public surface (including browser-OS work) or writing
public project text, read `runbooks/naming-and-communication.md` for the full
naming and style rules.

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

Recipient-scoped implementation workers are not supervisors: follow the
recipient-local `AGENTS.md` and explicit task brief first, start from the
exact named failing surface, and do not spend quota on broad supervisor
habits (repo-wide memos, PLAN grooming, throughput review) unless the task
asks for them. Details are in `runbooks/worker-delegation.md`.

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

Read the relevant skill before detailed operational work. Keep this index
current: whenever a repo-local skill is added, deleted, renamed, moved, or
materially changed, update this index in the same change set.

1. `skills/bus-product-delivery-supervisor/SKILL.md`: broad multi-module
   supervision, dispatch, monitoring, review, throughput, progress and
   closeout reporting. Read before running supervisor mode.
2. `skills/bus-dev-task-worker-ops/SKILL.md`: `bus task`/`bus workers`
   dispatch, event-driven waits, template routing, monitoring, reopen,
   promotion, auth/token handling, worker troubleshooting. Read before
   touching worker ops.
3. `skills/bus-plan-memory-maintainer/SKILL.md`: `PLAN.md`, `AGENTS.md`,
   hourly memos, trackers, durable lessons, closeout. Read before PLAN or
   AGENTS edits, memo closeout, or tracker-only commits.
4. `skills/bus-ui-gx-roadmap/SKILL.md`: GX/Bus UI roadmap, feature
   candidates, semver promotion, portal migration. Read before GX/UI roadmap
   or feature-candidate work.
5. `skills/bus-docs-quality/SKILL.md`: public docs and SDD structure,
   Markdown lint, examples, links. Read before docs or SDD edits.
6. `skills/bus-go-quality-review/SKILL.md`: Go implementation/review gates,
   tests, module Makefile checks, `bus lint` peer review. Read before
   touching Go files.
7. `skills/bus-generated-artifact-hygiene/SKILL.md`: generated WASM/static
   artifact tracking and ignore/clean/regenerate rules. Read before touching
   generated or build-output files.
8. `skills/bus-development-retrospective/SKILL.md`: evidence-based
   retrospectives for releases, incidents, and agent sessions, including
   shareable reports under `docs/docs/reports/`. Read before retrospectives.
9. `skills/bus-llm-tool-prompt-construction/SKILL.md`: prompt-template
   construction for BusDK tools that send prompts to LLMs. Read before
   changing prompt builders or request assembly.

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

Before editing the root `Makefile` or adding root orchestration, read the
Root Makefile Contract in `runbooks/delivery-discipline.md`; keep
superproject-only orchestration and add no lockfiles, alternative build
systems, or reimplemented module internals.

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

Before each new or resumed BusDK feature turn, read the board intake
commands and thread-placement rules in `runbooks/delivery-discipline.md`
(`bus thread list 231 --depth 2`, `bus thread show 111 --latest 6`).

## Cross-Module Architecture

Before changing module boundaries, command ownership, Events/auth/config,
AI-host behavior, provider/runtime architecture, notes modules, naming,
private/public coupling, or cross-cutting platform behavior, read
`docs/docs/sdd-source-index.md` and the owning module `AGENTS.md`. The
current identities/auth authorization model is recorded in
`runbooks/delivery-discipline.md`.

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
lanes must not use the Events `memory` backend for retained task history. The
provider registry detail and Claude-backend research pointer are in
`runbooks/delivery-discipline.md`.

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
