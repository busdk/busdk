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

Before starting follow-up workers that must build on newly accepted submodule
commits, commit the corresponding superproject submodule pin first. Worker
worktrees treat checked-in submodule SHAs as authoritative, so an uncommitted
primary submodule checkout can make new tasks start from stale module code.

Do not change or commit the superproject or non-recipient repositories while
App Server dev-task workers are actively running unless the change is an urgent
infrastructure fix and you are prepared to reopen affected tasks. Isolation
snapshots intentionally block tasks when non-recipient workspaces change during
a run.

## Dispatch

Brief each worker with recipient, goal, files to inspect first, owned paths,
explicit boundaries, acceptance criteria, tests, documentation, and closeout
evidence. Use exact module recipients such as `@bus-gx`; bare module-like words
can create wrong-owner tasks.

For same-recipient parallel work, use exact non-overlapping `--write-scope`
prefixes relative to the recipient repository, not the superproject path. For
example, an `@docs` scope is `docs/ui/fc-025-product-module-integration`, not
`docs/docs/ui/...`.

Current `--write-scope` values are exact path ownership prefixes with
directory-boundary matching, not glob shorthands. For versioned directories such
as `docs/ui/v0.2.1`, do not use `docs/ui/v0.2` unless that literal directory
exists and owns the files; declare each actual patch directory or wait for
explicit glob/prefix-scope support.

Dev-task execution must follow the recipient-owned writable workspace model.
Each worker gets write access only to the recipient module's isolated Git
worktree, while dependency modules are read-only context. In local task
containers, writable recipient worktrees are under
`/workspace/tmp/bus-dev-task-worktrees/...`; read-only dependency checkouts are
available for inspection at `/workspace/<module>` such as `/workspace/bus-api`.
Worker briefs should state this so agents do not misdiagnose dependencies as
missing. Cross-module edits require separate module-recipient tasks or
supervisor escalation.

If the first unchecked `PLAN.md` item is dependency-blocked, tell workers to
leave it unchecked with a concrete follow-up and continue to the next
recipient-owned item that can be completed now.

Same-recipient parallel work is acceptable for broad docs or mechanical
refactors only when each worker has exact non-overlapping file ownership and
promotion risk is recoverable. Promotion must be serialized with rebase or
fast-forward checks and clear conflict reporting.

When a worker writes Go files, put `bus lint path/to/file.go` in the brief as a
final slow peer-review pass after deterministic checks. Do not let it replace
unit, e2e, format, static, or module Makefile gates.

For read-only live QA smokes, pass explicit `BUS_DEV_TASK_COMMIT=false` while
still passing `BUS_DEV_TASK_POST_COMMAND_JSON=[]`, so tests that ask the agent
not to edit files do not promote or churn task branches. For ad hoc
commit-enabled workers, pass explicit `BUS_DEV_TASK_POST_COMMAND_JSON=[]`,
`BUS_DEV_TASK_COMMIT=true`, and a bridge commit message so stale shell
environment variables cannot re-enable obsolete in-container Git commit hooks.
Feature commits should still be created with `bus dev commit`; raw bridge commit
messages are only a fallback for preserving disposable worker output.

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

Completed or blocked tasks must not sit untriaged. In heartbeat/pulse
supervision, route every terminal or blocked item before quiet reporting: accept
and pin if evidence is sufficient, reopen with precise guidance, record a real
owning `PLAN.md` blocker, or launch the follow-up worker.

If a live Codex App Server exits before producing assistant text with
`signal: bus error` / `Bus error: 10`, treat it as a transient backend crash:
publish the exact failure evidence and retry once automatically when safe.

If several workers can run one or two commands and then all later
`exec_command` or `apply_patch` calls fail with process-spawn or missing
worktree errors, stop content retries. Dispatch an infrastructure worker with
the concrete task refs, first failed commands, recovery diagnostics, and dirty
worktree evidence.

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

Treat `remaining_blockers` as blockers for accepting the completed slice only.
Open work that belongs to other `PLAN.md` items, other modules, root-gate
verification, or future dependency selection belongs in follow-up or
cross-module request fields.

For verification/fix tasks with no matching `PLAN.md` checkbox in the declared
write scope, the accepted closeout form is `task_complete=true`, `plan_closed`
set according to the worker contract, explicit no-matching-PLAN evidence, and
`remaining_blockers=[]`. Do not strand valid small compatibility fixes behind
"PLAN item was not closed".

In structured closeout JSON, required check `status` values should stay on the
documented contract such as `passed`, `failed`, `blocked`, or `skipped`. Put
qualifiers like "no matches" in `test_evidence`, not invented statuses such as
`passed_no_matches`.

If a worker completes a valuable implementation slice but discovers broader
future prerequisites, split the broad `PLAN.md` item before closeout: check the
completed slice, leave a new unchecked follow-up for future work, and keep
`remaining_blockers=[]` for the accepted slice.

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
- e2e suites writing dependency helper binaries into read-only modules
- containers missing Docker CLI/Compose, compression tools, host Docker socket
  access, or the current BusDK Go toolchain
- localhost service probes hanging because `curl` timeouts were omitted

`config/dev-task-lifecycle-policy.json` is non-secret worker lifecycle
configuration loaded through `BUS_DEV_TASK_POLICY_FILE`; it controls the active
worker backend, disposable mode, isolated worktrees, progress logging, safe
crash retries, and validated lifecycle expectations.

## Compose And App Server Operations

For `compose.dev-task-docker.yaml`, scale provider-neutral container/Docker
integration services before creating in-memory dev tasks. Scaling after task
creation can recreate the in-memory `bus-events` service and lose queued tasks.
If scaling an already-running stack, use explicit no-recreate behavior where
practical and verify the Events API was not restarted.

Manual per-recipient worker container starts are a temporary break-glass/debug
path. Prefer `scripts/dev-task-run-worker.sh <container-name> <recipient>` for
ad hoc live worker starts; it pins the active compose file, quotes unsafe
environment values, and passes timeout/sandbox/commit settings explicitly.
Until automation owns startup, manual starts must be sequential with
`docker compose -f compose.dev-task-docker.yaml run --no-deps ...`; do not
launch parallel `docker compose run` commands because Compose can race service
recreation and collapse the scaled pool.

Ad hoc live dev-task workers for this superproject must target the same Compose
project/file that owns the active Events API. Plain `docker compose run ...`
targets `compose.yaml` and can silently attach to a stale Events database.
Verify workers join `busdk_default`.

When passing Docker Compose `-e NAME=value` values that contain spaces, braces,
or shell-significant characters, quote the whole `NAME=value` argument.
Optional flags with empty environment values must be omitted rather than passed
with an empty value.

Commit-enabled `codex-appserver` workers with isolated worktrees require
`BUS_DEV_TASK_CODEX_SANDBOX=workspace-write`; keep Compose defaults aligned so
workers fail before claiming rather than after spending a live Codex turn.
Local App Server workers should keep filesystem isolation and loopback e2e
capability together: `workspace-write` plus turn-level
`sandboxPolicy.networkAccess=true`, not `danger-full-access`.

Worker containers that use the host Docker socket must not assume
Docker-published ports are reachable at `127.0.0.1` inside the container.
Provide a deterministic host-gateway name such as `host.docker.internal` and
pass it to e2e suites through a non-secret environment variable such as
`BUS_E2E_DOCKER_HOST`.

Dev-task worker images should expose current mounted BusDK tools through
script-friendly command wrappers that preserve the caller working directory. On
startup, refresh executable wrappers for `bus` and mounted `bus-*` modules with
`cmd/<module>/main.go`, so commands use the latest mounted checkout rather than
stale host-only installs.

App Server worker paths should default to the real `codex app-server` command
so local runs test production integration. Deterministic smokes may opt into a
protocol-compatible fake when avoiding live model/runtime dependencies is the
point of the test. Live acceptance must prove a real LLM-powered Codex session
can answer runtime-generated questions from the task stream; hardcoded marker
or echo responses are not evidence for the live path.

## Auth And Remotes

Dev-task worker tokens need both Events transport scopes and domain task
scopes: `events:send events:listen dev:task:send dev:task:read
dev:task:reply dev:task:claim`. Missing Events scopes cause
`403 insufficient_scope` and make workers appear idle.

Local `.env` files are supported Bus control-plane configuration sources.
Prefer refreshing `BUS_API_TOKEN`, `BUS_EVENTS_API_URL`, and related local
dev-task values through `bus configure NAME=VALUE` in the workspace `.env`
before falling back to ad hoc token files. Remember an already-exported process
environment variable can still take precedence over `.env` loading.

If `bus dev task` / `bus dev work --remote localhost` reports that
`tmp/local-ai-platform/bus-config/auth/api-token` is expired, refresh that local
compose token with the local development HS256 secret through the documented
Bus operator-token flow, then rerun the normal Bus command without inline-token
workarounds. If plain `bus dev work status` still reports `401 invalid_token`,
check `bus remote resolve` before minting another token; a hosted default
remote can make a fresh local token hit `ai.hg.fi`.

For live operations, prefer the installed `bus` dispatcher after rebuilding or
installing updated subcommands. Direct `bus-dev/bin/bus-dev` execution is
useful for module tests and help checks, but may bypass dispatcher environment
loading and select stale local token files.

## Generated Artifacts And E2E Edges

Tracked generated artifacts, especially browser/WASM assets, are a recurring
promotion hazard. If verification dirties generated artifacts in the primary
checkout, restore or commit that state deliberately before reopening tasks; do
not keep reopening against a dirty primary checkout.

Module e2e scripts that need helper binaries from read-only dependency modules
inside dev-task worktrees must build those helpers into recipient-owned
temporary paths with explicit dependency binary names and without inheriting the
recipient `BINARY` value. Do not write dependency helper binaries into
`../bus-*/bin` from a recipient worker.

When e2e suites depend on external environment capabilities such as loopback TCP
binds, probe that capability once in the suite runner and emit explicit
`SKIP <test>: <reason>` lines for affected cases instead of failing
generically.

Synthetic smoke-task throughput only validates orchestration capacity. Evaluate
worker count with accepted `PLAN.md` closures, review pass rate, rework rate,
and real task-stream timing from `bus dev work stats --all`.
