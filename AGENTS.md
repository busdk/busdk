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
- Use repo-local skills in `./skills` for detailed operational runbooks. Mount
  those skills into worker containers when practical.
- Keep public docs free of agent-only process rules. For SDD/public-doc
  architecture candidates, leave compact triggers and follow-up notes unless a
  task explicitly asks for public documentation edits.

## Live Working Memo

This section is core operating memory for Codex agents in this repository. Do
not compact it out of root `AGENTS.md`, move it only to a less visible skill, or
replace it with a pointer. Other guidance may summarize it, but this root file
must preserve the live memo contract itself.

1. Maintain a live working memo during every substantial work session. The memo
   is hourly based.
2. At the start of work, create or update
   `./logs/{YYYYMMDD}-{HH}-agent-memo.md`, where `YYYYMMDD` is the current
   local/project date and `HH` is the zero-padded 24-hour hour when that memo
   period starts. Create `./logs` if it does not exist.
3. Use the current local/project time when naming memo files. Continue writing
   to the same memo only while the current hour remains the same.
4. When the hour changes, finish the current memo with a short handoff note
   explaining the current state of the work, what is complete, what is still in
   progress, what was verified, what remains uncertain, and what should happen
   next. Then create or continue the next hourly memo for the new hour.
5. Write each memo as an editorial engineering diary in story form. It should
   read like a clear narrative of the work session, not like a checklist,
   changelog, or raw activity dump.
6. The memo should let a future maintainer, human reviewer, or AI agent
   understand the flow of work: what the agent was trying to accomplish, what
   it found, why it made certain choices, where it hesitated, what changed,
   what went wrong, what worked well, and what could be improved next time.
7. Use Markdown. Prefer narrative paragraphs over lists. Headings may be used
   when helpful, such as `## Session Context`, `## Work Narrative`,
   `## Observations`, `## Decisions`, `## Tests and Checks`,
   `## Problems and Friction`, `## Improvement Ideas`, `## Hourly Handoff`,
   and `## Final State`.
8. Lists are allowed only when they genuinely improve readability, for example
   for compact test results or final next steps.
9. Update the current hourly memo throughout the hour after meaningful phases
   of work. Add a short narrative note explaining what just happened and what
   it means.
10. Do not merely write "ran tests" or "updated parser." Explain why tests were
    run, what the result suggested, why a change was needed, whether the change
    felt clean, and whether any concern remains.
11. If work changes direction, describe the reason. If an assumption turns out
    to be wrong, record how that changed the approach. If a command fails,
    explain the failure, likely cause, and next action.
12. Before making a risky, broad, or hard-to-reverse change, write a short note
    explaining the intended change, why it seems necessary, and what risk it
    carries. After making the change, update the memo with what actually
    happened.
13. If no code changes were made during an hour, still write the story of that
    hour: what was examined, what was learned, what remains uncertain, and what
    the next useful action would be.
14. Keep the memo truthful, concise, and useful for later learning. Do not
    claim planned work as completed. Do not invent successful results. Clearly
    separate facts from interpretation. Mark uncertainty, failed attempts,
    skipped checks, and assumptions honestly.
15. Avoid blame-oriented language. Focus on what the project, tooling,
    architecture, process, tests, or prompts can learn from the session.
16. Summarize long command outputs instead of pasting them in full, and mention
    how the result can be reproduced when useful.
17. Treat committed logs and memos as public repository content. Never write
    secrets, API keys, passwords, tokens, private customer data, proprietary
    customer details, raw `.env` contents, or other sensitive values into memos
    or committed logs. Summarize or redact sensitive evidence instead.
18. When investigating environment variables or config files, query only the
    exact non-secret key needed, or report whether a key exists without
    displaying unrelated values.
19. Do not edit historical hourly memos after the hour/session has passed
    except to remove sensitive information or undo an accidental inappropriate
    edit. Later lessons from old memos should be captured in the current memo
    or in durable project guidance.
20. Before finishing a session, review the current hourly memo. Make sure it
    explains not only what changed, but how the work unfolded and what can be
    learned from it.
21. End the final memo for the session with a concise final state: what is
    complete, what remains incomplete, what was verified, what was not
    verified, and what the next agent or maintainer should probably do next.
22. Every hourly memo should contain enough handoff detail that another agent
    can resume without re-reading the whole conversation. For broad work,
    include compact coverage of the current goal, key decisions, modified
    files, commands and tests run with outcomes, blockers, active follow-ups,
    and important context.
23. When Bus Notes is available and configured, delegated workers or
    long-running agents may also publish concise notes through `bus notes` so
    the work becomes searchable and attributable. Local
    `./logs/*-agent-memo.md` files remain the canonical session diary unless
    this repository explicitly chooses Bus Notes as the primary store.
24. If Bus Notes is unavailable, unconfigured, or inappropriate for the current
    repository, continue with local memo files only and mention that limitation
    in the memo or final handoff when relevant.

## Supervisor Worker Delegation

This section is core operating memory for Codex supervisor agents in this
repository. Do not compact it out of root `AGENTS.md`, move it only to a less
visible skill, or replace it with a pointer. Other guidance may expand it, but
this root file must preserve the supervisor/worker boundary itself.

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
5. If the worker substrate is partially usable, prefer dispatching an
   infrastructure worker or reviewer worker over local implementation. Use the
   supervisor checkout for investigation and evidence gathering, not for
   absorbing product implementation.
6. When the supervisor must make an exception, record the reason in the current
   hourly memo, including why worker delegation was unavailable, what exact
   infrastructure path was restored, what verification was run, and which tasks
   should be reopened or dispatched afterward.
7. Periodically compare recent hourly memos, task statistics, and active-worker
   evidence against the active goal. If independent parallel capacity is
   underused, explicitly dispatch/refill unblocked work or record the concrete
   blocker; report utilization truthfully instead of implying full capacity
   when the board is idle or thinly staffed.
8. Treat each periodic memo/task-stat review as an operating-control loop, not
   as a retrospective note. The review must end with one of these concrete
   outcomes: updated PLAN/tasks, new or reopened worker dispatch, promoted or
   rejected worker output, a documented automation improvement, or a specific
   reason why no safe parallel work can be started. If the review finds
   underutilization, stale workers, repeated manual steps, or evidence gaps,
   convert that finding into the next supervisor action before returning to
   ordinary status reporting.
9. For every substantial supervisor session and every progress report on an
   active multi-worker goal, do a compact goal-health review before answering:
   recent memo evidence, active workers per environment, independent unblocked
   work topics, accepted/promoted output since the previous review, current
   bottleneck, and the next dispatch/reopen/promote action. If the review shows
   idle capacity on H100, dev-hg, local, or other configured environments, fill
   it with scoped work unless a concrete blocker prevents it.
10. Measure the supervisor process by accepted work and learning rate, not by
    activity. Record when actual parallelism is materially below available
    capacity, when the supervisor absorbed work that should have been delegated,
    when a worker lane failed because of platform friction, and what guidance,
    PLAN item, automation task, or worker dispatch was created to prevent the
    same stall from recurring.
11. For broad goals, use delegated supervisor agents as the normal scaling
    unit. The lead supervisor should own global priority, acceptance, pinning,
    and operator communication, while sub-supervisors own work lines such as
    remote freshness/proof, parallel lane refill, review/promote triage, or a
    specific module family. A sub-supervisor should not merely write a one-shot
    report: it should start safe workers, monitor them, refill the lane when a
    worker exits, and leave accept/reopen guidance with evidence.
12. Lead supervisors and delegated sub-supervisors must read and apply
    `skills/bus-product-delivery-supervisor/SKILL.md` and
    `skills/bus-dev-task-worker-ops/SKILL.md` before running broad supervisor
    loops, dispatching workers, or reporting progress on multi-worker goals.
    Sub-supervisor prompts must include these skill paths so the scaling loop
    is not lost when work is delegated to another agent.
13. After accepting and pinning changes that affect worker launch, Events sync,
    remote credentials, worker images, model/runtime configuration, or Bus
    developer tooling, update configured remote environments before using them
    as proof. Verify the remote checkout commit, affected submodule SHAs, and
    rebuilt/installed binaries or images. If a remote still runs stale software,
    treat that as an operating issue to fix or delegate, not as product
    evidence.

## Repo-Local Skills Index

Read the relevant skill before doing detailed operational work:

1. `skills/bus-product-delivery-supervisor/SKILL.md`: broad multi-module
   supervision, worker dispatch, monitoring, review, process improvement,
   throughput analysis, heartbeat/progress/closeout reporting, and GX/UI
   roadmap coordination. Use it before running supervisor mode.
2. `skills/bus-dev-task-worker-ops/SKILL.md`: concrete `bus dev work` /
   `bus dev task` dispatch, Compose/App Server workers, monitoring, reopen,
   closeout, promotion, auth/token handling, write scopes, worker infrastructure
   troubleshooting, and generated-artifact promotion hazards. Use it before
   touching worker ops.
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
6. `skills/bus-go-quality-review/SKILL.md`: Go implementation/review gates,
   unit/e2e expectations, module Makefile checks, and final `bus lint
   path/to/file.go` peer review. Use it before touching Go files.
7. `skills/bus-generated-artifact-hygiene/SKILL.md`: generated WASM/static
   artifact tracking, ignore/clean/regenerate rules, and dirty-checkout
   prevention. Use it before touching generated browser, WASM, static, build
   output, or other artifact files, and before deciding whether generated
   changes should be committed, regenerated, ignored, or cleaned.

## Repository Identity

1. This repository is the public superproject for `busdk/busdk`.
2. Do not implement accounting logic or BusDK module source code here.
3. Keep BusDK modules as Git submodules at repository root (`bus`, `bus-*`).
4. Treat checked-in submodule commit SHAs as authoritative pins. Do not add
   lockfiles.
5. Keep orchestration in exactly one root `Makefile` using POSIX shell, `git`,
   and POSIX `make`.
6. Do not add alternative build systems, package-manager integrations, network
   features, or CLI binaries in this superproject.
7. The `.bus/` directory is a tracked project directory. Never add `.bus` or
   `.bus/` ignore rules. Runtime lock artifacts such as `.bus-dev.lock` may be
   ignored.
8. Do not treat `.bus/`, `Makefile.local`, `./tests`, or `FEATURES.md` as
   temporary files unless a repository explicitly documents an exception.

## Root Makefile Contract

When editing the root `Makefile`, preserve superproject-only orchestration:
deterministic discovery of `bus` and `bus-*` module Makefiles, delegation via
`make -C`, POSIX shell/make, required lifecycle targets, module-local `./bin`
outputs, `PREFIX`/`BINDIR`/`DESTDIR`, Go variable pass-through, and
changed-module-scoped root test/e2e defaults. Do not add lockfiles or reimplement
module internals.

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

## Cross-Module Architecture

Before changing module boundaries, command ownership, Events/auth/config,
AI-host behavior, provider/runtime architecture, notes modules, naming, or
private/public coupling, read the relevant module SDD under `/workspace/SDD/docs`
or `./sdd/docs` plus the owning module `AGENTS.md`. If stable architecture still
exists only in agent guidance, record an SDD-recipient follow-up instead of
rewriting public docs in this root file.

## Commit And Deletion Safety

Read `skills/bus-plan-memory-maintainer/SKILL.md` before tracker-only commits
or memory closeout. Root safety context: commit only when asked or explicitly
allowed, commit staged scope only, never push/tag/sync without request, use
tracked/untracked deletion commands deliberately, and keep tracker-only commits
separate from implementation/docs/test changes.

## Shell And Tool Hygiene

For shell scripts, Docker inspection, readiness probes, search/format commands,
or other repeatable debugging practice, read the owning module `AGENTS.md` and
the most relevant repo-local skill first. Use
`skills/bus-dev-task-worker-ops/SKILL.md` for worker/Compose/App Server,
Docker, SSH worker, or readiness debugging; use
`skills/bus-product-delivery-supervisor/SKILL.md` for supervisor progress and
dispatch loops; use `skills/bus-go-quality-review/SKILL.md` for Go
format/test/lint gates; use `skills/bus-generated-artifact-hygiene/SKILL.md`
for generated outputs. Root safety context: keep commands simple, portable,
path-correct, and redacted.

Use `./tmp/worktrees` for disposable supervisor, worker, review, and remote
checkout worktrees. `tmp/` is already ignored, so do not introduce separate
local-only worktree directories such as `./worktrees`.

For historical delivery or behavior claims, verify the relevant Git diff before
writing the claim. For progress, heartbeat, review, and closeout reports, follow
`skills/bus-product-delivery-supervisor/SKILL.md`.
