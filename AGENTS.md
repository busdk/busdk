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
14. Permission prompts are exceptional. Supervisors must first use already
    approved commands, remote workers, and configured Bus services. Do not ask
    the operator for permission for routine Markdown edits, worker monitoring,
    SSH status checks, remote dispatch, or deterministic verification. If the
    local sandbox blocks Git metadata writes or another required operation,
    continue independent remote/worktree work where possible and request
    permission only when that exact operation is required to finish an accepted
    change.
15. Do not keep broad, vague checklist items as the active operating plan.
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
16. When the operator corrects the architecture or priority, update durable
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
    Do not request `gpt-5.3-codex-spark` for new workers or app-server-backed
    implementation tasks while the weekly quota is exhausted. Use
    `gpt-5.4-mini` first, escalate to `gpt-5.4` only when mini cannot complete
    the work, and use `gpt-5.5` only as the last resort.
17. Treat important operator corrections, focus reminders, naming lessons, and
    repeated “don’t do that” guidance as durable memory work, not just chat.
    When the lesson is expected to matter again, write it into the most
    specific relevant `AGENTS.md` in the same session, and update the current
    hourly memo to record why it mattered. Use `PLAN.md` alongside `AGENTS.md`
    when the lesson also changes execution order or acceptance criteria.
    Stage and commit `PLAN.md` changes directly on `develop` in the owning
    repository before moving on; do not leave planning edits as uncommitted
    supervisor checkout drift.
18. For the H100/remote-worker goal, prioritize the minimum real-work loop over
    adjacent product polish: one configured model can be enough, private image
    delivery can be deferred when source-checkout/App Server works, and stats
    can be improved while testing instead of blocking the first accepted loop.
    Keep the checklist focused on work that directly makes remote workers
    productive and repeatable.
19. For unfinished BusDK goals, do not report "not proven" or "not done" as a
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
20. At BusDK session closeout, review the current hourly memo against these
    operating rules and the operator corrections recorded during the session.
    If the work drifted from the rules, say so in the memo and improve the
    smallest relevant `AGENTS.md`, `PLAN.md`, or skill runbook before
    finishing the session.
21. Use precise acceptance vocabulary. A worker that is `created`, `claimed`,
    `running`, `done`, or even promoted inside an isolated/remote checkout is
    not accepted project progress until supervisor-side review verifies the
    diff, required checks pass, the owning branch is promoted or repaired, and
    the superproject pin is updated when applicable. Reports and memos must
    distinguish: task created, worker claimed, worker produced a diff, worker
    branch promoted, supervisor accepted, root pinned, pushed, and released.
22. When a worker result is partly useful but fails review, prefer the normal
    iterative production loop: reopen with exact findings, hand the repair to a
    stronger model or reviewer lane when useful, or make the smallest
    supervisor acceptance repair only when delegation is blocked. Do not
    describe a first-attempt failure as H100/model failure when the overall
    attempt-review-repair-promote loop is still producing accepted work.
23. Treat pause/release mode as a hard drain-and-collect workflow. When the
    operator pauses new development or asks for a release, stop scheduling new
    work; inspect local, dev-hg, H100, and other configured environments for
    queued/claimed/running tasks; cancel stale queued or false-active streams
    with evidence; collect useful remote patches/logs before stopping
    services; verify no environment has commits ahead of its upstream that need
    retrieval; verify the root checkout is clean; then run the requested
    release command.
24. Treat worktree cleanup as review-first. Prefer first-class Bus prune
    commands and dry-run reports over manual deletion. Do not run destructive
    cleanup while task refs are active or while Git locks may still represent
    live work; use `--apply`-style cleanup only after reviewing the dry-run
    candidates, active-task refusal evidence, and submodule worktree registry
    behavior.
25. After solving a BusDK infrastructure issue, record the reusable diagnostic
    path in the current memo and the most specific `AGENTS.md`. The note must
    include the original symptom, the wrong or stale assumption, the decisive
    command/log/observation, the invariant that fixed it, the verification
    command or proof, and the first check to run next time. This is required
    for worker launch, App Server, Events relay, service startup, install or
    version skew, route pairing, credential, and local safety-filter failures.
26. When a worker or App Server path fails with a vague execution error such as
    "no such file or directory", do not guess at task/worker architecture
    first. Check the exact service process argv, selected binary path, worker
    workdir, App Server allowed directories, sandbox/network policy,
    environment id, and the installed-vs-source commit. Add narrow diagnostics
    that expose paths, ids, booleans, and command names without secrets; then
    reproduce with a fresh worker message before accepting the fix.
27. When a locally built fix does not affect a service or remote proof, assume
    release skew until disproved. Verify the executable that `bus services up`
    launches, the superproject commit, affected submodule SHA, install target,
    and remote checkout before changing product logic. If `make clean build
    install` or submodule refresh is the intended release step, run it before
    judging runtime behavior.
28. When Events relay behavior surprises task or worker flows, inspect Event
    metadata first: origin environment, destination environment,
    sync-target ids, recipient ids, task ref, worker id, correlation id, route
    owner, and durable cursor namespace. Product relay eligibility must not
    depend on event names. Add hermetic fake-transport tests for the Event
    metadata and cursor behavior that caused the surprise, and use live SSH
    proof only as an end-to-end acceptance layer.
29. After the service-owned Events relay MVP is accepted, BusDK product work
    must use Bus tasks and persistent Bus worker identities as the normal and
    exclusive execution infrastructure. Supervisors define task refs, pick or
    create worker identities, send guidance with `bus workers message`, monitor
    Events/status/log evidence, review diffs, reopen incomplete work, and
    promote accepted branches. Supervisors do not directly implement product
    changes or run direct compile/test/install loops as a substitute for worker
    work.
30. Prefer `gpt-5.3-codex-spark` for BusDK worker identities and dispatches
    unless the operator explicitly requests another model or a task has a
    concrete model-specific requirement. When a worker must use a different
    model, record the reason in the task stream or memo.
31. Use the Services-backed Workers API when listing or controlling persistent
    workers. In the current local Services stack that means
    `bus workers --api-url http://127.0.0.1:8090/local/v1 --token-file
    .bus/tokens/local-events.jwt ...`. A bare `bus workers list` may hit the
    legacy/default surface and print no workers; do not treat that as evidence
    that the persistent worker store is empty without checking the configured
    Workers API.
32. The default local Services stack must not require SSH access to
    `dev.hg.fi` or any other remote worker host. `bus services up` must start
    the local control-plane services needed for task submission, review, and
    local worker orchestration without Events relay credentials. Keep
    `events-relay` and remote sync/proof services optional, for example behind
    `--all` or explicit profile selection, so missing remote host keys or SSH
    credentials cannot block local development.
33. Temporary supervisor, worker, proof, and scratch worktrees must live under
    an ignored scratch path, normally `tmp/worktrees/` in this superproject or
    the Services-owned `.bus/services/workers/...` runtime paths. Do not create
    new temporary worktrees, symlink farms, or proof checkouts under
    `projects/busdk/worktrees`; that path is visible to Git status and should
    stay empty unless a future tracked product feature explicitly owns it.

## Recipient-Scoped Worker Focus

1. Recipient-scoped implementation workers are not supervisors. They should
   follow the recipient-local `AGENTS.md` and the explicit task brief first,
   and should not inherit broad supervisor habits such as repo-wide memo,
   PLAN, README, or throughput review unless the task explicitly asks for
   those.
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

This section is core operating memory for broad BusDK goals. Do not compact it
out of root `AGENTS.md` or move it only to a skill. It exists because repeated
memo evidence showed the supervisor could reach high throughput for one hour
and then fall back to one-worker-at-a-time execution.

1. Broad goals must run from a ready queue, not from a single next task. At any
   time the supervisor should maintain a short list of scoped, unblocked,
   module-owned tasks that can be started as soon as capacity exists.
2. Review is asynchronous work, not a reason to stop dispatch. While accepted
   or terminal worker output is being reviewed, the supervisor must keep
   independent lanes filled unless the checkout is dirty in a way that would
   make dispatch unsafe.
3. Each hour of a broad active goal must record numeric utilization in the
   memo: tasks accepted/promoted, task refs actively worked, peak active worker
   count, environments used, and the reason any available safe environment had
   no workers.
4. Use recent best throughput as a floor to challenge the next hour. If an
   earlier hour achieved multiple accepted items or several useful parallel
   lanes, later hours should either keep comparable independent work moving or
   record the concrete bottleneck that prevents it.
5. Do not let one platform hiccup idle the whole board. A failed token, stale
   checkout, sandbox, Docker, SSH, Events, or model issue should become a
   scoped infrastructure task while unrelated local, dev-hg, H100, or other
   configured lanes continue when safe.
6. Do not confuse "active worker" with throughput. Claimed/running workers are
   only useful capacity when they emit meaningful task-stream progress, produce
   reviewable diffs, or create actionable failure evidence. False-active lanes
   must be routed quickly while other lanes keep moving.
   A queued task, SSH-runner request, container-status event, or stale remote
   process alone is not an active lane. Count it separately as queued,
   request-only, launched-only, stale, or false-active until task Events show
   claim, App Server/model progress, terminal evidence, a commit, or an exact
   failure.
7. When H100 is paused for cost, immediately compensate with local and dev-hg
   worker lanes for work that does not require the GPU. When H100 is approved
   for use, keep it fed with real scoped work and scheduler/backlog tasks
   rather than sequential proof-only attempts.
8. Use delegated supervisor agents as soon as the lead supervisor has more than
   one independent work line to track. At minimum, split review/promote triage,
   remote freshness/readiness, and implementation-lane refill when all are
   active.
9. If an hour ends with zero or one worker despite multiple unblocked topics,
   the memo must call that out as underutilization and must include the next
   dispatch, plan split, or infrastructure fix that will prevent repeating it.
10. Do not report broad-goal status without the numbers. Progress reports must
    include completed task count, active task count, queued/refill candidates,
    environments in use, and blockers with owner tasks. If the numbers are weak,
    say so plainly and change the operating plan before the next report.
11. Compare each hour to the best recent proven throughput, not to a low-effort
    baseline. Memo evidence showed this project can sustain many parallel
    workers when scopes are independent and review is asynchronous; later
    one-lane operation must be justified by concrete constraints such as paused
    H100 cost, dirty checkout, blocked worker substrate, or lack of scoped work.
12. Keep remote proof and product work separate in reports. Testing on H100,
    dev-hg, or another environment is verification of the same product flow
    unless the environment truly needs different implementation. Avoid vague
    "prove H100" checklist items; name the product feature being verified, such
    as scheduler claiming, service readiness, credential resolution, relay
    sync, App Server model switching, or terminal evidence collection.

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

## Repository Identity

1. This repository is the public superproject for `busdk/busdk`.
2. Do not implement accounting logic or BusDK module source code here.
3. Keep BusDK modules as Git submodules at repository root (`bus`, `bus-*`).
4. Treat checked-in submodule commit SHAs as authoritative pins. Do not add
   lockfiles.
5. Use `develop` as the only normal integration and promotion branch for the
   BusDK superproject and Bus modules. Do not merge, fast-forward, push, or
   promote work to `main` unless the operator explicitly asks for `main` in
   that specific request.
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

## Cross-Module Architecture

Before changing module boundaries, command ownership, Events/auth/config,
AI-host behavior, provider/runtime architecture, notes modules, naming, or
private/public coupling, read the relevant module SDD under `/workspace/SDD/docs`
or `./sdd/docs` plus the owning module `AGENTS.md`. If stable architecture still
exists only in agent guidance, record an SDD-recipient follow-up instead of
rewriting public docs in this root file.

Prefer building on existing lower-level architecture over duplicating platform
features in product modules. Before adding any new feature or mechanism to a
module, first check whether Bus Events, Bus Data, Auth, Bus API, worker/task
infrastructure, or another platform layer already owns the needed primitive.
This applies broadly: synchronization, replication, idempotency, cursoring,
storage, credentials, task routing, audit history, metadata, validation,
capability discovery, transport, retries, status reporting, and similar
cross-cutting behavior should be reused from the owning layer or extended there.
Feature modules should stay focused on their domain semantics and projections.
For example, Bus Notes should consume and project `bus.notes.*` operations while
Events owns append-only history, origin metadata, replay, relay, and remote
synchronization.

Keep Bus product families consistent. `bus-{name}` owns the user-facing product
and CLI, `bus-api-provider-{name}` owns API/controller integration with
`bus-api`, and `bus-integration-{name}` owns event/integration-provider runtime
behavior for the `bus-integration` runner. For the workers refactor, the target
family is plural: `bus-workers` provides `bus workers`, local control flows
through `bus-api-provider-workers`, and remote worker/container management
flows through `bus-integration-workers`.

## Product Taxonomy Guidance

Keep `PRODUCTS.md` as a product taxonomy, not a module inventory or agent
process note. It should describe product lines, supporting platform products,
and excluded/not-yet-marketable surfaces in user-facing terms.

Use these rules when editing product taxonomy or public product pages:

- Keep BusDK as the bundle, installer, and shared product-family identity.
- Give primary product pages to user-facing products that buyers, operators,
  developers, or finance users can understand as a complete product.
- Order end-user product lines by strategic public importance, not by command
  or module order. Bus Agentic Development, Bus AI Platform, and Bus Books
  should appear before smaller command-oriented products such as Bus Top and
  Bus Services.
- Present Bus Services as generally useful process-level service stack
  software, not only as BusDK project support. Its public message may compare
  it to Docker Compose for packaging multiple services, especially during
  development, while emphasizing that it does not require containers or
  virtualization and can run inside containers or systemd-managed environments.
  Do not describe Bus Services as a security, sandboxing, or service isolation
  layer; it does not limit access between services.
- Present Bus GX/UI Library as a main product line even though it also supports
  other BusDK products. Teams may want Go-native UI components with TSX-like
  authoring directly, so `bus-gx` and `bus-ui` should be public product
  surfaces for compiled Go render roots, reusable component families, runtime
  bridges, deterministic tests, and policy-free frontend surfaces. Do not
  position it as "React cloned in Go"; React and TSX are useful reference
  points, but the product contract is Go-first and keeps routes,
  authorization, provider semantics, secrets, and business policy in owning
  product modules.
- Group supporting infrastructure under a separate supporting-platform category
  when it exists mainly to build, host, connect, or operate BusDK components.
- Treat dispatcher and host modules such as `bus`, `bus-api`,
  `bus-integration`, `bus-portal`, and `bus-operator` as host products. Their
  child modules belong under the concrete product line they serve.
- Do not duplicate a module across multiple marketed product pages. Cross-link
  when a module participates in more than one workflow.
- Do not market unfinished, research-only, or unclear surfaces as public
  products yet. Document them as research, technical preview, or internal
  modules until their user-facing value is ready.
- Keep the explicit exclusion list in this guidance, not in `PRODUCTS.md`.
  Current exclusions:
  - Bus Filing Finland is a real direction, but not ready for marketing yet.
    This covers `bus-filing`, `bus-filing-prh`, and `bus-filing-vero`.
  - `aiz` is a research project for now.
  - `bus-work` should not be marketed until its status is fully reconciled with
    Bus Agentic Development.
  - Individual `bus-api-provider-*`, `bus-integration-*`, and
    `bus-operator-*` modules should be assigned to the product line they serve
    instead of published as separate product pages.
- Keep Bus Books as the single public accounting and financial-workflow
  product for humans and agentic AI. The deterministic accounting engine, data
  workbench surfaces, Bus Formula Language, and `bus-portal-accounting` are
  proof and feature depth inside Bus Books unless they later become
  independently sellable. The Bus Books product page may explain that human
  apps, agent-facing tools, the UI, CLI, and API operate over the same
  deterministic workspace data for accounting, invoices, and financial
  workflows. Modules
  under Bus Books include `bus-accounts`, `bus-assets`, `bus-attachments`,
  `bus-balances`, `bus-bank`, `bus-bfl`, `bus-budget`, `bus-customers`, `bus-data`,
  `bus-debts`, `bus-entities`, `bus-files`, `bus-inventory`, `bus-invoices`,
  `bus-journal`, `bus-ledger`, `bus-loans`, `bus-memo`, `bus-payroll`,
  `bus-pdf`, `bus-period`, `bus-reconcile`, `bus-replay`, `bus-reports`,
  `bus-sheets`, `bus-validate`, `bus-vat`, and `bus-vendors`.
  `bus-portal-accounting` is the customer-facing portal experience for
  workspace summaries, attachment uploads, evidence packages, and artifact
  preview/download workflows.
  `bus-pdf` is document-rendering infrastructure for Bus Books workflows such
  as invoices, reports, and evidence packs, not a standalone end-user product.
- Keep Bus Auth, Bus Auth Portal, and Bus Billing under Bus AI Platform.
  `bus-auth`, `bus-portal-auth`, `bus-billing`, auth/session providers, usage
  hooks, Stripe integration, and auth/billing operators are platform services
  for login, approval, entitlements, metering, and paid AI hosting. They should
  not be a separate public product page unless the auth/billing experience
  later becomes independently understandable and sellable.
- Keep Bus Notes under Bus Agentic Development. `bus-notes`,
  `bus-portal-notes`, `bus-api-provider-notes`, `bus-integration-notes`, and
  `bus-faq` provide durable project memory, review notes, publishing, search,
  and FAQ-style answer storage for agentic development workflows; they should
  not be a separate public product page unless the notes experience later
  becomes independently understandable and sellable.
- Use Bus AI Platform, not Bus AI API, as the public product line for AI
  hosting services. This product may include OpenAI-compatible model access,
  inference/runtime control, deployment automation, user-owned VMs,
  containers, terminal sessions, node/cloud/database readiness, lifecycle
  events, usage hooks, auth, billing, and future UIs. Bus Deploy, Bus Runtime,
  Bus Auth, and Bus Billing modules belong under Bus AI Platform unless a
  separate deployment, runtime, or auth/billing product becomes independently
  understandable and sellable.
- Keep Bus Agentic Development as the product line for semi-autonomous
  software development. The selling point is integrating autonomous AI worker
  and supervisor agents into a software project so they can operate as
  autonomously as normal human workers, not merely human-supervised AI
  assistance. The market focus should be BusDK's own AI-native development
  workflow: BusDK software, BusDK tools, Go-heavy systems, and adjacent
  projects where the same semi-automatic development loop works seamlessly.
  This is not a strict language boundary, but generic "any kind of software
  development" should not be the first public promise. Human review and
  approval should be presented as an available governance/control layer, while
  the product should also support AI supervisor agents, such as Codex or Claude
  App sessions, that can define work, launch workers, monitor evidence, review
  output, and keep the board moving. Multi-environment execution is a core
  product point: Bus agents can work across local and remote development
  environments, and teams should be able to add multiple SSH-accessible
  environments as work capacity for autonomous agents. Do not split tasks,
  workers, agent runtime, prompts, chat, AI portal, notes, MCP, repository
  workspace contracts, or developer factory UI into separate public product
  pages unless those surfaces later become independently understandable and
  sellable. MCP and repository modules are not one shared product; they are
  supporting capabilities under Bus Agentic Development. That product page
  should explain the full loop: task threads, worker creation and control, the
  lightweight Bus-owned agent runtime, local and remote execution,
  SSH-configured development environments, prompt/script/pipeline workflows,
  chat, durable project notes, approvals, terminal state, repository
  workspaces, MCP capability exposure, quality review, supervisor-agent
  automation, and developer workflow UI.

Canonical task lifecycle Events use `bus.task.*`. Canonical worker
lifecycle/control Events use `bus.workers.*`. Treat `bus.dev.task.*`,
`bus.work.*`, and singular `bus.worker.*` names as legacy, compatibility, or
bootstrap surfaces unless the owning module explicitly documents otherwise.
Do not present singular `bus-worker`, `bus-api-provider-worker`, or
`bus-integration-worker` scaffolding as the final workers product path without
migrating or wrapping it behind the plural API/provider/integration family.

## LLM Tool Prompt Construction

When building or changing any BusDK tool that sends prompts to an LLM, keep the
largest stable prefix first and put changing request data last. Stable prefix
material includes role/task instructions, repository policy, output schema,
rubrics, safety rules, examples, and deterministic completion contracts.
Dynamic material includes timestamps, random or attempt IDs, task refs, file
paths, line-numbered source, diffs, `PLAN.md` contents, current `AGENTS.md`
contents, worktree paths, dependency checkout paths, command output, tool
results, model/runtime observations, and other per-run metadata.

For prompt-template code, prefer this shape:

1. Stable tool identity and task.
2. Stable policy, rubric, and output schema.
3. Stable examples that use placeholders instead of real per-run values.
4. A clearly labeled final dynamic context section containing all changing
   input.
5. The immediate instruction that applies the stable rules to that final
   dynamic context.

Do not prepend dynamic context merely because the model should read it first.
Instead, keep it near the end and explicitly instruct the model, in the stable
prefix, to consult the final dynamic context before acting. Avoid placing
timestamps, task IDs, file-specific paths, command output, or generated tool
results before reusable instructions because that can defeat prompt prefix/KV
cache reuse for local model runners and other providers. Do not claim
OpenAI/Anthropic-style cached-token metrics for providers such as Ollama unless
the provider actually exposes them; use provider-supported keep-alive and cache
configuration instead.

## Worker Backend Policy

Before choosing or changing Bus development worker backend/runtime behavior,
read `skills/bus-dev-task-worker-ops/SKILL.md` and the owning module
`AGENTS.md`/`PLAN.md`. Root policy: Codex App Server is the normal development
worker backend because it supports live steering, approvals, progress events,
structured closeout, and task attempt metadata. One-shot Codex execution is
legacy compatibility, not the default for H100/dev-hg/local worker lanes.
Development worker systems must store Bus Events task history durably, using
PostgreSQL or an explicit repository-file-backed store. The Events `memory`
backend is acceptable only for automated tests, self-tests, or intentionally
disposable smokes, never for local or remote worker lanes whose conversations
should be retained.

## Supervisor Host And Remote Environment

The BusDK superproject is checked out under the supervisor root at
`projects/busdk`. Keep BusDK-specific architecture, command, release, worker,
and module policy in this file or the most specific nested module
`AGENTS.md`; keep supervisor identity and role memory in the parent
`/Users/jhh/git/busdk/agent-supervisor/AGENTS.md`.

The local supervisor host is a macOS virtual server without supported nested
virtualization. Do not plan or diagnose BusDK Docker/container work as if
Docker should run locally here. Container and Docker-specific build,
inspection, smoke, and worker proof should run on the configured remote
environment `coding-agent@dev.hg.fi` unless the operator provides a newer
remote target for that task.

For the current task/worker refactor, the intended operating topology is a
local Bus control plane on the supervisor host for Events/task submission and
review, with Docker/App Server worker execution on `coding-agent@dev.hg.fi`.
Starting work locally should route task Events to the remote worker-side Events
service and import remote claim/progress/terminal evidence back locally; do not
replace this with a local Docker worker attempt on the macOS supervisor host.

When Docker-related proof moves to `dev.hg.fi`, record the remote environment,
checkout commit, relevant submodule SHAs, rebuilt binaries or images, and the
exact verification command or worker evidence. A local Docker failure on this
host is an environment-boundary fact, not by itself a BusDK product failure.

For local ChatGPT/Codex subscription Spark workers, use the exact raw model id
`gpt-5.3-codex-spark`. Do not substitute display-style names such as
`GPT-5.3-Codex-Spark`, and do not add automatic model-name normalization as
part of the current refactor. Prefer exact pass-through of configured model ids
until an explicit later feature adds optional aliasing.

## Commit And Deletion Safety

Read `skills/bus-plan-memory-maintainer/SKILL.md` before tracker-only commits
or memory closeout. Root safety context: commit only when asked or explicitly
allowed, commit staged scope only, never push/tag/sync without request, use
tracked/untracked deletion commands deliberately, and keep tracker-only commits
separate from implementation/docs/test changes.

## Shell And Tool Hygiene

For shell scripts, Docker inspection, readiness probes, search/format commands,
or other repeatable debugging practice, read the owning module `AGENTS.md`
first, then the relevant runbook: `skills/bus-dev-task-worker-ops/SKILL.md`
for worker/remote/container readiness, `skills/bus-docs-quality/SKILL.md` for
docs commands, and `skills/bus-go-quality-review/SKILL.md` for Go test/lint
commands. Keep commands simple, portable, path-correct, bounded, and redacted.

Use `./tmp/worktrees` for disposable supervisor, worker, review, and remote
checkout worktrees. `tmp/` is already ignored, so do not introduce separate
local-only worktree directories such as `./worktrees`.

For historical delivery or behavior claims, verify the relevant Git diff before
writing the claim. For progress, heartbeat, review, and closeout reports, follow
`skills/bus-product-delivery-supervisor/SKILL.md`.

## Simplify Before Building

1. Before implementing a feature, abstraction, workflow, or infrastructure
   change, pause and ask whether the current complexity is actually required.
   Review the real goal first, then choose the smallest shape that would still
   solve it. Prefer removing constraints, assumptions, or moving parts over
   building new machinery around them.
2. When a goal is blocked, find the smallest path that can already do real
   work and use that first. Prefer a narrow working slice over a broader design
   that is still theoretical.
3. Treat temporary/manual supports as acceptable when they unlock immediate
   productive work. A temporary path is good if it is explicit, reversible,
   and keeps the architecture honest; do not wait for full automation when a
   simpler support can get useful work moving now.
4. Only automate what the team has already proven necessary. If a manual step,
   reduced feature set, or simplified runtime is enough to unblock real work,
   defer the generalized version until the simpler path is producing value.
5. When choosing between fixing the whole platform and fixing the next missing
   dependency on the active path, prefer the active path. Record what was
   intentionally deferred so later automation can replace the temporary
   support without pretending it was never temporary.
6. Apply this rule broadly, not only to worker infrastructure. The fastest way
   to finish often is to simplify away unneeded flexibility or complexity so
   there is less to build, less to debug, and less to maintain.
7. During design and implementation, actively look for complexity that can be
   deleted, deferred, narrowed, or moved out of the critical path. Engineers
   often overbuild by default; this rule exists to make simplification a
   deliberate first move instead of an afterthought.
8. Before building a new mechanism, explicitly ask whether the goal can be met
   by removing a requirement, narrowing the problem, reusing a smaller
   existing primitive, or accepting a temporary manual step. Prefer less
   system over more system when both would honestly solve the current need.
9. When an open product, architecture, credential, runner, or proof-shape
   question could materially change the fastest path, stop and ask the
   operator before investing significant implementation time. Treat this as
   part of the supervisor/team-lead role: surfacing consequential ambiguity is
   progress, and guessing through it for hours is not.
10. Prefer a minimal core with optional overlays. Project-specific rituals such
   as Bus Notes usage, PLAN-driven closeout rules, reporting formats, or other
   workflow conventions should be opt-in project policy unless the active proof
   shows they are truly required by the substrate itself. Do not hard-wire
   project process into the core worker/task/event machinery unless that
   dependency is intentional, explicit, and source-backed.
11. For worker infrastructure specifically, prioritize getting one smallest
   useful worker lane running end to end before expanding registry UX, remote
   parity, generalized orchestration, or product polish. Once that lane works,
   use it to help build the fuller system.

## Troubleshooting And Evidence Discipline

1. When troubleshooting infrastructure, worker, runtime, API, sync, or
   cross-module integration issues, turn the lights on first. Enable existing
   verbose logging before guessing, and if current logs do not explain the
   failure, add the smallest useful DEBUG/TRACE instrumentation in the owning
   module before attempting broad behavioral changes.
2. Keep useful observability hooks durable. If a service, CLI, worker, or
   provider needs deeper logs to be supportable, add a real way to enable those
   logs through flags, environment variables, or config instead of relying on
   ad hoc local patches that disappear after the session.
3. DEBUG/TRACE logs should make decisions legible: input identity, event name,
   work ref, recipient, worker lane, backend, remote/environment, chosen code
   path, retry/conflict result, and important external call outcomes. Prefer
   structured logs or stable key/value text that can be searched and compared.
4. Trace the whole failing path, not only one process. For multi-service
   failures, collect or improve logs at each boundary that matters: caller,
   client SDK, API/provider, worker/supervisor, container/runtime, and remote
   transport when present.
5. Verify with proof instead of assuming from symptoms. Reproduce the failure,
   gather direct evidence, and prefer source-level or protocol-level facts over
   impressions from partial output. Do not report a cause as established until
   logs, tests, replay evidence, or code-path inspection support it.
6. Aim for root cause, not just the first visible error. When a problem is
   only understandable after adding logs or collecting better proof, record the
   underlying cause, the evidence that proved it, and the change that prevents
   the same stall from recurring.
7. Never log secrets, raw tokens, passwords, private keys, full `.env`
   contents, or customer-sensitive payloads. When richer logging is needed,
   log source kinds, file paths, presence/absence, IDs, sizes, counts, and
   redacted summaries instead of secret values.
8. For `bus services up` proof, verify the binary the service stack actually
   launches. The normal stack prefixes `dist-bin` on `PATH`, so a module
   `make install` into `~/.local/bin` or `bin/` is not enough evidence. After
   promotion or remote refresh, compare the superproject commit, affected
   submodule SHAs, and an observable marker from `dist-bin/bus`,
   `dist-bin/bus-integration`, or the affected `dist-bin/bus-*` binary before
   declaring the stack updated.
9. For local-plus-remote proof, treat version freshness as a first diagnostic,
   not a late cleanup step. Check local and remote `develop` commits,
   submodule pins, rebuilt installed binaries, and restarted native services
   before spending time debugging behavior that may come from stale software.
10. For Events relay failures, inspect event routing metadata, cursor state,
    import/origin markers, and relay state before changing product modules.
    Relay decisions should be metadata-addressed, not event-name filtered. If
    a fresh addressed event is not moving, look for cursor/window starvation,
    route-pair ownership, import suppression, or stale service binaries before
    adding special-case sync logic to task or worker modules.
    When the relay cursor appears to advance but a specific addressed Event is
    absent on the destination, search both local and remote Events by
    `correlationId` and `bus.destination.environment.id`, then inspect the
    relay status cursor and recent-event set. If the missing Event is older
    than the cursor or surrounded by imported remote Events, treat it as a
    pending-destination scan/window bug until disproved. Fix and test the
    generic Events relay; do not add task, worker, or event-name-specific
    forwarding rules.
11. For worker message delivery failures, compare the user-visible delivery
    result with the lifecycle code path. `delivery=recorded` means the message
    was stored but no live lifecycle messenger accepted it; inspect whether the
    active worker lifecycle implements message delivery. App Server workers
    must use the Codex App Server turn path, not a legacy one-shot exec path.
12. For App Server worker runtime errors, debug the concrete boundary in this
    order: host worktree path and existence, container or App Server process
    status, App Server URL, capability-token file presence, WebSocket
    handshake status, then turn/session response. Log paths, booleans, ids,
    HTTP status codes, and file presence only. A `401 Unauthorized` handshake
    means the messenger/auth path is wrong until the capability token source is
    wired correctly; do not treat it as an unproven worker failure.
13. For local worker/App Server `No such file or directory` failures, search
    recent memos and prior commits for the exact error before designing a new
    worker architecture. Then compare the process argv, configured cwd,
    declared writable roots or `--add-dir` args, materialized submodules, and
    installed binary path. Preserve the successful diagnostic sequence in the
    current memo once the root cause is found.
14. Worker communication and task guidance are allowed to contain token-shaped
    text, model ids, and secret discussion in local or isolated environments.
    Do not use broad substring filters such as matching `sk-` anywhere in a
    message. Secret protection belongs at logging, persistence, export, and
    transport boundaries where values would be exposed unintentionally; if a
    detector produces false positives on normal worker content, narrow or
    remove that detector instead of blocking the worker flow.
15. After fixing a repeated BusDK infrastructure problem, immediately record a
    future-practice note in the current memo and, when reusable, in this file
    or the owning module `AGENTS.md`. Name the original symptom, the mistaken
    assumption that slowed progress, the decisive check, the invariant fixed,
    and the first command or inspection to run next time.
16. For App Server WebSocket `401 Unauthorized` failures, start with the
    capability-token path instead of treating the worker as generally broken.
    Check that the lifecycle created a host-side token file next to the worker
    worktree, the container or App Server process requires WebSocket auth, the
    messenger reads the host token file without logging the value, and the
    client sends `Authorization: Bearer ...` during the WebSocket upgrade. Add
    a protocol-level handshake regression when this path changes.
17. For App Server message deliveries that report `turn/started` but never
    return assistant evidence, compare the configured Services timeout with
    the messenger instance used by the active lifecycle. If `services.yml` or
    a profile already sets a longer evidence timeout, verify the App Server
    lifecycle passes that same value into its messenger instead of silently
    using a constructor default. Prove the fix with both a unit test that
    observes the carried timeout and a fresh worker message through the normal
    `bus workers message` surface.
18. For App Server worker delivery failures after a worker has been created or
    resumed, verify runtime metadata freshness before changing worker routing
    or relay semantics. Compare the user/request intent Event, the persisted
    worker state, lifecycle-owned `meta.env`, the actual container or App
    Server port, and the messenger session cache. If the container is up on a
    fresh port but delivery uses an older `app_server_url`, the lifecycle must
    refresh non-secret runtime facts from `meta.env` before message delivery
    and status reporting, and the messenger must drop cached sessions when the
    App Server URL changes. Preserve this with unit tests for metadata refresh
    and cache invalidation, then verify with a fresh `bus workers message`
    through the normal Services stack.
19. For nested Git write failures in Codex or App Server-backed workers, treat
    the worker launch configuration as an owned repair surface. First compare
    the worktree path, root `.git`, `.git/modules`, and nested submodule
    gitdir paths against the actual `--add-dir` arguments or writable roots
    passed to the Codex process. Fix the worker/App Server launch path before
    relying on escalated Git as a routine promotion mechanism.
20. When a BusDK issue is solved after a long loop, capture the reusable
    method, not only the commit. The memo and durable guidance should preserve
    the symptom, slow assumption, decisive diagnostic, code/config invariant,
    verification command, and the first check to run next time so future
    workers can begin from the proven route.
21. When resuming a BusDK issue that resembles a recent worker, relay,
    service-launch, install, credential, or remote-runtime failure, run a
    recent-fix intake before dispatching or coding: read the current and
    previous hourly memos for future-practice notes, search for the exact
    symptom text, and begin with the last successful diagnostic sequence. If
    the new case differs, record that difference in the memo before choosing a
    new design path.
21. When a solved issue depended on comparing live behavior against the
    intended service path, make that comparison the next default diagnostic.
    For BusDK this often means checking that `bus services up` is launching the
    freshly rebuilt `dist-bin` binaries, that local and remote checkouts share
    the same `develop` commit and submodule pins, that Events are addressed by
    metadata rather than event name, and that App Server workers are using the
    accepted live turn path. Do these checks before adding new synchronization,
    credential, worker, or CLI logic.
22. When a worker or relay fix succeeds, record the exact proof shape that
    closed it: the Bus command or service path used, task ref, worker id, route
    or environment ids, relevant event names and metadata fields, local/remote
    commits, rebuilt binaries, and the verification command. Future workers
    should be able to replay the same first check without reconstructing it
    from chat history.
