# AGENTS.md

## Highest-Priority Rule: Precise Language And Precise Reasoning

Precise language is part of precise reasoning. Before acting or reporting, name
the exact object, action, scope, evidence, and uncertainty. State what changed
and what did not change. Never use a broader claim than the evidence supports.
If an exact, unambiguous sentence cannot be written, inspect the evidence or
ask for clarification before proceeding.


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
5. Instruction discovery stops at each repository's `.git` boundary. Nested
   inside a parent workspace, read `../AGENTS.md` and `../../AGENTS.md`
   before cross-checkout actions; sessions inside a `bus-*` module load only
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
  architecture candidates, leave compact triggers and follow-up notes in the
  owning module `AGENTS.md` or `PLAN.md` unless a task explicitly asks for
  public documentation edits.
- Keep detailed, conditional operating guidance in `runbooks/*.md` in this
  repository, one topic per file. Runbook filenames name their topic and are
  the trigger: before acting on a topic, read the runbook whose filename
  matches the current task, plus any runbook a root section names explicitly;
  when unsure, list `runbooks/` and match filenames against the task.

## Architecture Stability And Decision Briefs

Before planning or implementing a change that affects module ownership,
deployment authority, process lifecycle, resource control, provider/runtime
boundaries, cross-module contracts, command ownership, Events/auth/config,
AI-host behavior, notes modules, naming, private/public coupling, or
cross-cutting platform behavior, read
`sdd/docs/architecture/architecture-decision-register.md` (the cross-module
authority), `docs/docs/sdd-source-index.md`, and the owning module SDD and
`AGENTS.md`. Goal pages, plans, threads, memos, rejected branches, and
historical reports are evidence, not architecture authority. Identities/auth
model: `runbooks/identities-authorization-model.md`.

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

## Candidate Review Calibration

Before issuing or consuming a `REVISE` review, Lead Supervisors, Feature
Managers, and independent reviewers must apply the confidence bands, blocker
threshold, and useful-follow-up Thread workflow in
`skills/bus-product-delivery-supervisor/SKILL.md`. A non-blocking improvement
must not reopen an otherwise acceptable candidate.

## Live Working Memo

Maintain a live hourly working memo during every substantial session in
`./logs/{YYYYMMDD}-{HH}-agent-memo.md` (current local/project time, same file
while the hour is unchanged), written as a truthful editorial engineering
diary in Markdown narrative form. When the hour changes, finish the memo with
a handoff note and continue in the new hourly file; end every session with a
concise final state. Never write secrets, tokens, private customer data, or
raw environment dumps into memos or committed logs.

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
2. The supervisor's default job: define work, dispatch workers with clear
   scopes and acceptance criteria, monitor, review, reopen, promote, and
   keep the board moving.
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
recipient-local `AGENTS.md` and explicit task brief, start from the exact
named failing surface, and skip broad supervisor habits unless the task asks
(`runbooks/worker-delegation.md`).

## Parallel Supervisor Operating Standard

Broad goals run from a ready queue of scoped, unblocked, module-owned tasks;
review is asynchronous and must not stop dispatch; workers count as capacity
only with meaningful progress, diffs, or exact failure evidence; hourly memos
record numeric utilization and the concrete bottleneck when capacity idles.
Full standard: `runbooks/parallel-supervision.md`; resource limits:
`runbooks/service-resource-isolation.md`.

## Repo-Local Skills Index

Read the relevant skill before detailed operational work. Keep this index
current: whenever a repo-local skill is added, deleted, renamed, moved, or
materially changed, update this index in the same change set.

1. `skills/bus-product-delivery-supervisor/SKILL.md`: supervisor mode —
   multi-module supervision, dispatch, monitoring, confidence-calibrated
   review routing, throughput, reporting.
2. `skills/bus-dev-task-worker-ops/SKILL.md`: worker ops — dispatch, waits,
   template routing, reopen, promotion, auth, troubleshooting.
3. `skills/bus-plan-memory-maintainer/SKILL.md`: PLAN/AGENTS edits, memos,
   trackers, durable lessons, closeout.
4. `skills/bus-ui-gx-roadmap/SKILL.md`: GX/UI roadmap, feature candidates,
   semver promotion, portal migration.
5. `skills/bus-docs-quality/SKILL.md`: public docs and SDD structure, lint,
   examples, links.
6. `skills/bus-go-quality-review/SKILL.md`: Go files — implementation and
   review gates, tests, Makefile checks, `bus lint` peer review.
7. `skills/bus-generated-artifact-hygiene/SKILL.md`: generated or
   build-output files — tracking and ignore/clean/regenerate rules.
8. `skills/bus-development-retrospective/SKILL.md`: retrospectives for
   releases, incidents, and agent sessions.
9. `skills/bus-llm-tool-prompt-construction/SKILL.md`: prompt builders and
   request assembly; keep stable prompt instructions before per-run dynamic
   context unless a narrower exception is documented.

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
9. Do not treat `.bus/`, `Makefile.local`, `./tests`, or FEATURES.md files
   as temporary unless a repository explicitly documents an exception.

## Repository Visibility And Secrets

The superproject, `./bus`, `./docs`, and `./busdk.com` are public; every
`./bus-*` module is private unless its own repository documents otherwise,
and public repos couple to private modules only through stable
CLI/library/API boundaries. Never put real secrets in public repos, docs,
examples, memos, logs, or notes; never accept secrets as command-line
arguments; never auto-write tokens or auth files under `.bus/` or any
working-tree path; never print broad `.env` contents. Full rules:
`runbooks/repository-visibility-and-secrets.md`.

## Definition Of Done

Production, bug-fix, and user-visible behavior changes require deterministic
automated tests, appropriate e2e coverage, formatting/lint/static/security
checks, docs/help/SDD updates when behavior changes, backward compatibility
unless explicitly approved, and tracker follow-up for any approved exception.
Before module command, test, runtime, CLI, docs, restricted API, or Go
changes, read the owning module guidance, the matching Repo-Local Skills
Index entry, and `docs/docs/sdd-source-index.md`.

### Finish-First Delivery Gate

Before new or resumed source work, name one user/operator outcome and freeze
the exact local composed E2E command; bug fixes also freeze the identical
parent-fail and candidate-pass scenario. Keep unfinished source on immutable
feature refs. Do not merge, pin, install as accepted, or call the feature
complete until that E2E passes against the exact composition.

Details: `runbooks/finish-first-delivery-gate.md`. Before each new or
resumed BusDK feature turn, apply `runbooks/board-intake-commands.md`.

## Product Taxonomy Guidance

Before editing `PRODUCTS.md`, public product pages, product-line module
mappings, or taxonomy exclusions, read
`docs/docs/product-taxonomy-guidance.md`. Root policy: keep `PRODUCTS.md` as a
user-facing product taxonomy, not a module inventory or agent process note.

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
or memory closeout. Root safety context: commit only with direct operator
authorization (or a guidance rule naming the exact repository and scope),
commit staged scope only, never push, tag, or sync without a direct operator
request, use tracked/untracked deletion commands deliberately, and keep
tracker-only commits separate from implementation/docs/test changes.

## Shell And Tool Hygiene

Keep commands simple, portable, path-correct, bounded, and redacted. The
Repo-Local Skills Index rows above own the detailed shell, Docker, probe,
worktree, and reporting workflows; module shell scripts follow the owning
module's `AGENTS.md`.

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
the reusable diagnostic sequence in the memo and the owning module's
`AGENTS.md` or matching skill after a fix.
