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
5. Agent sessions started inside this checkout do not auto-load parent
   guidance: instruction discovery stops at this repository's `.git`
   boundary. When this checkout is nested inside a parent workspace (for
   example an agent-supervisor tree), read `../AGENTS.md` and
   `../../AGENTS.md` before cross-checkout actions such as parent pin
   updates, shared coordination, or supervisor-owned workflows. The same
   applies one level down: sessions started inside a `bus-*` module load only
   that module's guidance and must read this file for superproject rules.

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
  repository, one topic per file. Runbook filenames name their topic and are
  the trigger: before acting on a topic, read the runbook whose filename
  matches the current task, plus any runbook a root section names explicitly.

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
an implementation problem does not reopen architecture by itself. See
`runbooks/architecture-change-control.md` and
`runbooks/operator-solution-briefs.md`.

## Experiment And Proof Discipline

For performance, build, boot, sync, or browser-proof goals, size work to the
acceptance path and state the expected gate-metric effect before starting an
experiment; see `runbooks/experiment-and-proof-discipline.md`.

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

Full rules: `runbooks/public-surface-naming.md` and
`runbooks/communication-style.md`.

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

This root file keeps the binding memo contract; the full style contract is
`runbooks/live-working-memo.md`.

## Supervisor Worker Delegation

This section is core operating memory for Codex supervisor agents in this
repository; the binding supervisor/worker boundary stays here, expanded by
`runbooks/worker-delegation.md` and `runbooks/gx-ui-delegation.md` under the
original rule numbering.

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
5. Before worker dispatch, monitoring, template or model routing, environment
   freshness checks, pause/drain, worktree cleanup, or failure diagnosis,
   read `runbooks/worker-delegation.md` (items 4-7, 7c, 17-46).
6. Before GX/UI cleanup, adopter, facade-parity, or `pkg/uikit`-removal work,
   read `runbooks/gx-ui-delegation.md` (items 7a-15) and
   `skills/bus-ui-gx-roadmap/SKILL.md`.

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

Full standard: `runbooks/parallel-supervision.md`. Service and worker
resource limits: `runbooks/service-resource-isolation.md`.

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
6. Before editing the root `Makefile` or adding root orchestration, read
   `runbooks/root-makefile-contract.md`.
7. Do not add root CLI binaries or network features to this superproject.
8. The `.bus/` directory is a tracked project directory. Never add `.bus` or
   `.bus/` ignore rules. Runtime lock artifacts such as `.bus-dev.lock` may be
   ignored.
9. Do not treat `.bus/`, `Makefile.local`, `./tests`, or `FEATURES.md` as
   temporary files unless a repository explicitly documents an exception.

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

Details: `runbooks/finish-first-delivery-gate.md`. Before each new or
resumed BusDK feature turn, run `runbooks/board-intake-commands.md`.

## Cross-Module Architecture

Before changing module boundaries, command ownership, Events/auth/config,
AI-host behavior, provider/runtime architecture, notes modules, naming,
private/public coupling, or cross-cutting platform behavior, read
`docs/docs/sdd-source-index.md` and the owning module `AGENTS.md`. The
current model is in `runbooks/identities-authorization-model.md`.

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
Registry detail: `runbooks/worker-backend-registry.md`. Before
engine-integration work, read
`runbooks/engine-integration-architecture.md`.

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
