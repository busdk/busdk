---
name: bus-product-delivery-supervisor
description: Use when supervising broad BusDK development across modules with bus dev task/work workers, especially when the goal is to drain PLAN.md items, finish UI feature candidates, monitor parallel workers, fix blockers, and improve the development process from logs.
---

# Bus Product Delivery Supervisor

Use this skill for broad BusDK work where the main job is coordination, worker
dispatch, review, and process improvement. Keep the supervisor focused on
progress management; delegate implementation to recipient-scoped workers when
the work can be made clear and isolated.

## Related Repo Skills

Use narrower skills alongside this one when the work has a focused shape:

- `bus-dev-task-worker-ops` for concrete worker dispatch, monitoring, reopen,
  closeout, promotion, and infrastructure blocker handling.
- `bus-ui-gx-roadmap` for GX, Bus UI, feature-candidate, semver promotion, and
  portal migration planning.
- `bus-docs-quality` for public docs, SDD docs, Markdown linting, examples,
  navigation, and duplicate-content cleanup.
- `bus-go-quality-review` for Go code gates, tests, e2e coverage, and final
  `bus lint path/to/file.go` peer review.
- `bus-generated-artifact-hygiene` for generated WASM/static asset tracking,
  ignore, clean, regenerate, and dirty-checkout prevention.
- `bus-plan-memory-maintainer` for `PLAN.md`, `AGENTS.md`, hourly memo, worker
  log lessons, and durable process memory.

## Operating Loop

1. Refresh memory:
   - Before dispatching, editing, or reporting substantial work, open or create
     the current hourly memo under `logs/` and add/update the live entry for
     this hour. Treat this as a gate, not a final-answer cleanup step.
   - Read the current hourly memo and recent `logs/*agent-memo.md` entries.
   - Check the most specific `AGENTS.md` files for root, recipient modules,
     `docs`, and `sdd` before dispatching work.
   - Run `bus dev work status` and inspect relevant `PLAN.md` files.
   - Use `rg --files -g 'PLAN.md'` for broad plan discovery. Avoid broad
     repository walks from the superproject unless there is no narrower path.
   - When hosted Codex/cloud usage is constrained, shift attention to Bus-owned
     local and UpCloud execution infrastructure before broad content batches.
     Preserve hosted budget for high-leverage review, unblock local/container
     workers, and require operator approval before provisioning paid cloud
     resources or changing cost posture.

2. Build a dispatch board:
   - Active workers by ref and recipient.
   - Idle capacity.
   - Next unblocked tasks.
   - Dirty primary checkout risks.
   - Blockers and the owning `PLAN.md` or infrastructure module.

3. Choose the critical path:
   - Prefer framework and infrastructure tasks that unblock many modules.
   - For the GX/UI roadmap, respect real prerequisites but do not treat
     feature-candidate numbers as a linear queue. FC identifiers are stable
     candidate IDs, not required implementation order. Run multiple FC workers
     in parallel when their code ownership and dependency prerequisites do not
     overlap.
   - Finish prerequisite `bus-gx` capabilities before the `bus-ui` primitives
     that consume them, then portal host contracts, then leaf portal module
     migrations.
   - Promote completed UI feature candidates to semver only after code,
     tests, docs, SDD, and module docs match the implemented behavior.

4. Dispatch workers:
   - Use `bus dev work start` or `bus dev task new` with explicit recipients.
   - Give each worker non-overlapping module or file ownership.
   - Use the documented local development system as the default execution path
     for broad module work. Prefer automation-owned worker provisioning over
     manual container/script starts.
   - Treat `bus dev task` as the durable two-way task communication channel.
     `bus dev work` may compose user-defined workflows, but task state,
     worker replies, reopen guidance, and closeout evidence belong in the task
     stream.
   - Keep worker-facing briefs free of supervisor-only benchmark numbers,
     throughput experiments, and worker-count comparisons. Put that context in
     supervisor notes or task metadata.
   - Keep Codex `spawn_agent` subagents separate from Bus dev-task workers. Use
     Codex subagents only when explicit parallelism is useful, and run them in
     bounded batches, normally no more than 8 at a time.
   - After `wait_agent` returns and results are summarized, close every
     completed Codex subagent with `close_agent`. Never leave completed Codex
     subagents open across turns.
   - If an agent thread limit is reached, do not raise the limit blindly. First
     close completed subagents and continue with the current session when
     possible. Treat `agents.max_threads` as unreliable in long-lived sessions
     because completed subagents may continue counting against the quota unless
     closed.
   - When a worker writes or substantially edits Go files, include
     `bus lint path/to/file.go` on the changed Go files as a final slow
     AI-backed peer-review step after deterministic unit, e2e, formatting, and
     static checks pass.
   - For same-recipient docs/refactor shards, pass exact `--write-scope`
     paths; globs are not supported.
   - State goal, files to inspect first, boundaries, acceptance criteria,
     test/documentation requirements, and completed-work evidence.

5. Monitor continuously:
   - While workers run, do not idle. Review returned patches, prepare next
     briefs, groom plans, inspect blockers, or start additional safe workers.
   - Prefer short service-backed status/snapshot calls over long-lived local
     `wait`/`watch` exec streams when a snapshot gives enough evidence. If
     missing non-streaming observability forces active supervisor tool streams,
     record a `bus-dev` or `bus-integration-dev-task` PLAN item; worker
     throughput should not be capped by the supervisor process/session limit.
   - After each worker terminal event, immediately accept/promote, reopen with
     precise guidance, record a blocker, or dispatch the next unblocked item.
   - Count throughput only as verified and promoted work, not claimed work.
   - Treat a "running" or "claimed" worker as untrusted until task-stream
     evidence shows a real bridge claim, App Server/container progress, or
     meaningful worker output for the intended work ref. If only container
     status exists, inspect logs promptly and route the task as false-active,
     blocked, reopened, or fixed; do not let board counts substitute for
     progress.
   - Keep parallelism high when scopes are independent and review capacity
     exists. Do not assume one worker per module is the ceiling; increase
     concurrency until write-scope conflicts, dirty primary checkouts, resource
     saturation, or review bandwidth becomes the real limit.
   - Compare each long-running supervisor pulse against recent best accepted
     work per hour. Look for safe scaling improvements: more independent
     workers, narrower shards, faster review/pin/reopen routing, stronger
     automation, or removal of the current bottleneck.
   - Periodically audit recent hourly memos and task statistics against the
     active goal. If safe parallel capacity is underused, dispatch/refill
     independent work immediately or record the specific blocker that prevents
     refill, and report the utilization level truthfully in heartbeat or
     progress updates.
   - Continuously ask progress-improvement and bottleneck questions, then
     answer them from evidence: what would increase accepted work per hour, is
     final AI review the limit, does five versus fifteen parallel workers
     change accepted commits per hour, is promotion or reopen latency
     dominating wall time, are dirty checkouts causing most stalls, would an
     infrastructure fix unblock more work than another content worker, or is a
     shared module write scope the real constraint?

6. Fix repeated blockers:
   - If a failure repeats, stop retrying blindly.
   - Record or implement the root-cause fix in the owning module.
   - When a proof loop is not verified yet, do not leave the status as a vague
     complaint. Investigate the exact next steps, write a short pass/fail
     checklist in the owning `PLAN.md`, then dispatch or run the first item.
   - If a blocker might be solvable by the operator, ask for the exact help
     needed instead of silently working around it with a hack. Continue
     parallel useful work only when it is real product work or safe
     infrastructure repair, not a way to hide that the intended path is
     blocked.
   - When a clear operator-facing blocker is stopping the active goal, say it
     plainly and visibly in user-facing reports. Start the relevant sentence or
     bullet with `**Clear blocker:**` so the operator can notice it and decide
     whether to help, fix infrastructure, or redirect the work.
   - If the delegation substrate itself is broken and a worker cannot patch the
     defect because of that same failure, stop the batch, fix the launcher or
     bridge locally through the narrowest path, verify it, pin it, and reopen
     affected work.
   - When worker closeout classification repeats, copy the exact terminal
     closeout wording into a regression test. Check both the structured JSON
     path and any plain-text evidence scanner; many failures come from one path
     accepting evidence while the other still blocks promotion.
   - For file-scoped docs or SDD tasks, tell workers up front that a `PLAN.md`
     outside the declared single-file write scope is not a remaining blocker
     when the requested file is updated and checks pass. They should close with
     `task_complete=true`, `remaining_blockers=[]`, and explicit evidence that
     no matching PLAN file/item exists inside the declared write scope.
   - In structured closeout JSON, required check `status` values should stay
     on the documented contract such as `passed`, `failed`, `blocked`, or
     `skipped`. Put qualifiers like "no matches" in `test_evidence`, not in
     invented statuses such as `passed_no_matches`.
   - For no-change compatibility checks, describe the task as
     `verification-only` and say `no repository changes are required if all
     gates pass` in the initial worker brief. Otherwise the bridge may
     correctly reject a clean worktree as "no files changed" even though the
     verification result is useful.
   - If a worker completes a valuable implementation slice but discovers
     broader future prerequisites, split the broad PLAN item before closeout:
     check the completed slice, leave a new unchecked follow-up for the future
     work, and keep `remaining_blockers=[]` for the accepted slice. Put future
     prerequisites in `cross_module_requests`, follow-up PLAN items, or
     `test_evidence`, not in `remaining_blockers`.
   - For verification/fix tasks that have no matching PLAN checkbox in the
     declared write scope, use the accepted no-plan closeout form:
     `task_complete=true`, `plan_closed=true`, explicit evidence that no
     matching checkbox exists, and `remaining_blockers=[]`. Do not let a valid
     small compatibility fix strand itself behind "PLAN item was not closed".
   - When a worker promotes a submodule change while other workers are still
     active, pin that submodule in the superproject immediately after a quick
     evidence review. Leaving the root dirty can block unrelated worker
     promotions or reopen paths.
   - When a just-pinned worker/bridge fix appears ineffective in newly
     launched workers, first verify whether the workers are using stale
     container images, installed binaries, or dependency checkouts before
     reopening more content tasks.
   - If several workers can run one or two commands and then all later
     `exec_command` or `apply_patch` calls fail with process-spawn or missing
     worktree errors, stop content retries. Dispatch an infrastructure worker
     with the concrete task refs, first failed commands, recovery diagnostics,
     and any dirty worktree evidence.
   - If Codex App Server workers report `Failed to create unified exec process`
     while `CODEX_HOME/tmp/arg0` still exists, inspect the Codex app-server
     arguments and the unified-exec setting before assuming the worker task or
     content patch is at fault.
   - Keep the primary checkout clean enough for worker launches. Commit or
     otherwise settle supervisor-only memo changes before starting a new batch.
   - Common blockers include stale BusDK tools in containers, auth/token drift,
     dirty primary checkouts, generated artifact churn, stale submodule pins,
     missing write scopes, and incomplete worker evidence.
   - Do not prioritize replacing the human/Codex supervisor loop with an
     always-on Bus supervisor service unless the operator asks for that product
     direction. Near-term value is worker execution that is scalable,
     observable, and easy to operate.

7. Preserve memory:
   - Update the current hourly memo after meaningful phases in the same hour;
     do not create a second memo for the same hour unless merging/correcting an
     accidental filename.
   - Memo claims about finished work, blockers, dispatches, and verification
     should cite the evidence source used: task refs, commits, command/test
     results, active-worker snapshots, or relevant log files. Mark recollection
     as recollection instead of proof.
   - Add durable rules to the most specific `AGENTS.md` when a mistake or
     recurring lesson should not be repeated.
   - Add unresolved implementation work to the owning module `PLAN.md`; do not
     rely on final-answer promises.

## Supervisor Implementation Boundary

Follow the root `AGENTS.md` `Supervisor Worker Delegation` section as the
authoritative supervisor/worker boundary. In supervisor mode, do not absorb
product/module implementation locally when a clean recipient-scoped worker can
do it with clear acceptance criteria. The supervisor may edit `PLAN.md`, memo,
`AGENTS.md`, skills, and urgent coordination artifacts, but feature
implementation should be assigned to recipient-scoped workers unless the
operator explicitly asks the supervisor to make the code change directly.

If the delegation substrate itself is broken and a worker cannot patch the
defect because of that same failure, stop the affected batch, fix the launcher
or bridge through the narrowest safe path, verify it, pin it, and reopen
affected work.

Review and progress-audit outsourcing should exercise the Bus dev-task worker
system whenever practical. Codex subagents can help with bounded local
assistance when explicitly authorized, but scalable implementation and
verification belongs in Bus worker agents so the substrate is tested and
improved.

## Business-Value Reporting

When reporting feature progress, translate technical status into the business
capability the user cares about. For each unfinished feature, state what is
still unavailable to users/operators, what the remaining work will unlock, and
why it is or is not worth spending development capacity on next. Avoid reports
that only list commits, task refs, tooling names, or implementation mechanics.
Also distinguish what actually changed from the previous baseline: net-new
capability, hardening, release proof, wider coverage, safer defaults, easier
operation, recovery of a failed path, documentation, or observability. Do not
describe an existing workflow as newly created when the real value was making it
more reliable, automated, measurable, or release-ready.

Use readable Markdown for non-trivial progress reports, rendered directly in
the assistant message. Do not put Markdown inside heartbeat XML or CDATA; the
app displays that as literal text. For heartbeat responses, keep the required
XML `<message>` to one short plain-text status sentence. If a user-facing
notification is warranted, put the readable Markdown report before the XML
envelope and keep the XML as a compact machine-readable summary.

A good default shape is:

- `Report Time`: UTC and local project time.
- `What Changed`: accepted, pinned, reopened, started, or fixed work since the
  previous report.
- `Done / Usable`: features or workflows that are now complete enough for
  users/operators to use, especially fully completed items, with credible
  evidence such as commits, pins, tests, docs, or release versions.
- `Current Work`: active task refs with purpose and latest meaningful evidence.
- `Open Next`: the next unfinished features or work items, what value each
  would unlock, and whether each is active, queued, blocked, or deliberately
  deferred.
- `Value`: user/operator/release value, including what changed from the prior
  baseline.
- `Evidence`: commits, tests, logs, or resource signals.
- `Risks / Blockers`: only remaining issues that affect decisions or next work.
- `Next Action`: the concrete supervisor action already being taken or next in
  line.

Keep each bullet short enough to scan. Avoid burying task identities, evidence,
open work, or blockers in a single paragraph. The `Done / Usable` section
should prevent ambiguity about what can be used now. The `Open Next` section
should make scope guidance easy: the reader should see what remains valuable,
what is being worked now, and what can safely wait.

## Worker Brief Shape

Use compact, concrete briefs:

```text
Recipient: @module-name
Goal: <one complete outcome>
Inspect first: <files/directories>
Scope: <owned files/behavior>
Do not change: <boundaries>
Acceptance: <tests/docs/evidence>
Closeout: list changed files, commands run, remaining blockers.
```

## UI Roadmap Done Definition

For work under `docs/docs/ui/fc-*` and corresponding `bus-gx` or `bus-ui`
implementation:

- Implementation matches the feature-candidate docs or the docs are corrected
  before implementation.
- Unit tests and e2e/CLI/browser tests cover user-visible behavior.
- `docs/docs/modules/{module}.md` and `sdd/docs/modules/{module}.md` state the
  current implemented version and actual behavior.
- Module `FEATURES.md` or equivalent inventory is updated when required.
- The owning `PLAN.md` item is removed or checked only after verification.
- Completed candidates are promoted to the next semver patch when no ordering
  blocker remains; otherwise the blocker is recorded.

## Step-By-Step Delivery Cycle

Use this cycle repeatedly until the requested PLAN and feature-candidate work is
done or a real operator decision is needed:

1. Snapshot the system.
   - Check `bus dev work status`.
   - Inspect active task refs before reading broad files.
   - Check root and recipient `git status --short`.
   - Read the current hourly memo and the latest worker closeouts.

2. Protect the launch surface.
   - Do not start workers from dirty primary checkouts unless the dirt is the
     intentional work to be committed first.
   - Pin accepted submodule commits in the superproject before dispatching
     follow-up work that depends on them.
   - If worker images, installed tools, auth, or Codex startup look stale, fix
     that infrastructure path before scaling content work.

3. Build a small live board.
   - Active workers: ref, recipient, goal, last evidence.
   - Ready work: open `PLAN.md` items and `docs/docs/ui/fc-*` candidates.
   - Blocked work: blocker owner and next unblock task.
   - Parallel slots: independent modules, exact non-overlapping file scopes,
     and independent FCs whose prerequisites are already satisfied.

4. Dispatch for throughput.
   - Start workers for independent ready items instead of doing module work in
     the supervisor checkout.
   - Use exact recipients and write scopes.
   - Start later-numbered FCs before earlier-numbered FCs when the later
     candidate is independent or already unblocked; record actual blockers in
     PLAN rather than preserving artificial numeric order.
   - Keep briefs narrow enough that the worker can finish, test, document, and
     close out without a second planning pass.
   - Prefer framework/runtime blockers that unlock many portal or docs tasks.

5. Monitor while work runs.
   - Poll task status and inspect active worker logs with bounded commands
     where possible; reserve streaming waits for cases that need live output.
   - Send short corrective guidance when a worker drifts, searches too broadly,
     misses acceptance criteria, or discovers a blocker.
   - While waiting, prepare the next safe brief, review completed diffs, or
     groom PLAN items. Avoid idle waiting when there is non-overlapping work.

6. Route every terminal worker.
   - Accept/promote only after inspecting the diff and evidence.
   - Reopen with precise correction when evidence is incomplete or the product
     shape is wrong.
   - Convert real blockers into the owning module `PLAN.md` or a new
     infrastructure task.
   - After accepting a feature candidate, promote it to semver when it is
     complete and ordering allows it.

7. Improve the process.
   - Treat repeated failures as product defects in the development system.
   - Update `AGENTS.md`, this skill, or module plans with the lesson before
     launching the same pattern again.
   - Record the narrative in the hourly memo so the next supervisor can resume
     without rediscovering context.
