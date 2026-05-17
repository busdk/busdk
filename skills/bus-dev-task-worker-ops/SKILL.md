---
name: bus-dev-task-worker-ops
description: Use when operating BusDK dev-task workers: dispatching bus dev work/task jobs, monitoring active refs, reopening blocked workers, reviewing closeout evidence, pinning promoted submodules, and fixing worker infrastructure blockers.
---

# Bus Dev-Task Worker Ops

Use this skill for the concrete worker-control loop under `bus dev work` and
`bus dev task`. Keep module implementation delegated whenever a recipient-scoped
worker can finish the slice with clear ownership.

## Snapshot

Start with a compact board:

- `bus dev work status`
- current hourly memo under `logs/`
- root and recipient `git status --short`
- relevant recipient `PLAN.md`
- active task refs, recipients, write scopes, and last worker evidence

Do not launch commit-enabled workers from dirty primary checkouts unless the
dirty state is the deliberate supervisor work to commit first.

## Dispatch

Brief each worker with recipient, goal, files to inspect first, owned paths,
explicit boundaries, acceptance criteria, tests, documentation, and closeout
evidence. Use exact module recipients such as `@bus-gx`; bare module-like words
can create wrong-owner tasks.

For same-recipient parallel work, use exact non-overlapping `--write-scope`
prefixes relative to the recipient repository, not the superproject path. For
example, an `@docs` scope is `docs/ui/fc-025-product-module-integration`, not
`docs/docs/ui/...`.

When a worker writes Go files, put `bus lint path/to/file.go` in the brief as a
final slow peer-review pass after deterministic checks. Do not let it replace
unit, e2e, format, static, or module Makefile gates.

## Monitor

Poll active workers with short bounded status/snapshot commands while doing
non-overlapping supervisor work. Use long-lived `wait`/`watch` streams only when
live output is needed; if service-backed snapshots are insufficient and force
the supervisor to keep active tool exec streams open, add an owning
`bus-dev`/`bus-integration-dev-task` PLAN item. Route every terminal event
immediately:

- accept and pin when the diff and evidence match the task
- reopen with precise correction when tests, docs, product fit, or evidence are
  incomplete
- convert real blockers into the owning `PLAN.md`
- dispatch the next unblocked slice after accepted promotion

Trust diffs, commands, logs, and artifacts more than summaries.

## Closeout Rules

Good closeouts state changed files, commands run, passed/skipped checks with
valid reasons, notes or evidence IDs, remaining blockers, and cross-module
requests. Future work that belongs to another item is not a blocker for
accepting a completed slice.

For verification-only tasks where no repository change is required, say that in
the worker brief. If no matching PLAN item exists in the declared write scope,
the accepted closeout shape is `task_complete=true`, `plan_closed=true`,
explicit no-matching-PLAN evidence, and `remaining_blockers=[]`.

If a closeout is blocked because a worker skipped a non-existent target or
reported no files changed, inspect whether the bridge classifier needs a
regression test before reopening content work again.

## Frequent Blockers

Treat repeated failures as infrastructure defects:

- stale BusDK tools or container images missing the latest `bus` commands
- missing Events plus domain token scopes
- dirty primary checkouts or stale submodule pins
- generated browser/WASM artifact churn
- wrong Compose project or wrong worker network
- write-scope mistakes
- Codex app-server crashes or process-spawn failures
- same-recipient promotion/rebase metadata defects

`config/dev-task-lifecycle-policy.json` is non-secret worker lifecycle
configuration loaded through `BUS_DEV_TASK_POLICY_FILE`; it controls the active
worker backend, disposable mode, isolated worktrees, progress logging, safe
crash retries, and validated lifecycle expectations.
