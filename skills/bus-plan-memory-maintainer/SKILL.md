---
name: bus-plan-memory-maintainer
description: Use when maintaining PLAN.md queues, AGENTS.md durable guidance, hourly logs, worker lessons, and project memory so repeated BusDK workflow mistakes become reusable process rules.
---

# Bus Plan And Memory Maintainer

Use this skill when turning lessons from logs, workers, or reviews into durable
project memory.

## Hourly Memo

Maintain `logs/{YYYYMMDD}-{HH}-agent-memo.md` during each work session. Write it
as a narrative engineering diary, not a raw checklist. Explain goals, end-user
value, operator capability, product quality, or release confidence being
unlocked, findings, decisions, tests, friction, and handoff state. Do not reduce
value to commercial value; useful software that end users and operators like
using is the primary target.

The hourly memo is a mandatory work log gate, not an optional closeout note.
Before starting substantial supervisor work, compute the current local/project
hour, open or create exactly one memo for that hour, and add a short "started"
or "continued" entry with the current goal, evidence sources checked, and dirty
or active-worker state. Keep updating that same hourly memo after meaningful
phases during the hour. Do not wait until final response time to reconstruct the
hour from memory.

Use the established `logs/{YYYYMMDD}-{HH}-agent-memo.md` filename unless the
repository already has a current-hour memo with a slightly different suffix.
The important invariant is one active memo per hour, updated in place while the
hour is live. Do not create multiple same-hour memo fragments. If a wrong
same-hour memo filename was already created, either continue using that one for
the hour or merge it into the established filename before committing.

Claims in the memo must distinguish evidence from recollection. Whenever a memo
says something was finished, blocked, dispatched, accepted, promoted, or
verified, include the authoritative source used for that claim: task refs,
commit hashes, command/test names with outcomes, worker ids, relevant log files,
or current-state inspections. If the source is only immediate conversation
context or supervisor recollection, label it as such and avoid treating it as
proof.

When the hour changes, add a short handoff to the previous memo and continue in
the new hour.

For supervisor heartbeats and progress reports, first compare the current
local/project hour with the active memo filename. If the memo is stale, roll it
over before reporting or starting substantial new work, and record the
correction in the new memo.

Every hourly memo should contain enough handoff detail that another supervisor
can resume without re-reading the whole conversation. For broad or delegated
work, include the current goal, end-user/operator value or release capability
being pursued, key decisions, modified files or submodule pins, commands and
tests run with outcomes, pending task refs, blockers, active workers, and
important session context.

Include meaningful Git references in each hourly memo: the superproject commit
hash and the commit hashes for submodules modified, pinned, dispatched as
workers, used for verification, or important to the hour's decisions. If a
repository is dirty, say so next to its hash and summarize meaningful dirty
paths.

Treat committed logs and memos as public repository content. Never write
secrets, API keys, passwords, tokens, private customer data, proprietary
customer details, raw environment dumps, or long unredacted command output.
Summarize or redact sensitive evidence. Never print broad `.env` contents; if
you need configuration evidence, query only the exact non-secret key or report
whether a key exists.

Do not edit historical hourly memos after the hour/session has passed except to
remove sensitive information or undo an accidental inappropriate edit. Later
lessons from old memos belong in the current memo, durable tooling changes, or
the relevant `AGENTS.md`.

For delegated `bus dev work` / `bus dev task` workers, the logical `agent_id`
is the recipient module/AGENTS.md instruction identity. Worker notes should be
written through `bus notes` so they become Bus ecosystem data, not hidden local
files. Worker closeout should report `agent_id`, `agent_instruction_path`, and
Bus Notes IDs or query metadata.

If Bus Notes cannot reach the Notes API, report that as a blocker or explicit
fallback; do not silently replace Bus Notes with local files.

Before finishing a session, review the current memo and end it with a concise
final state: what is complete, incomplete, verified, not verified, and what the
next agent or maintainer should do.

## AGENTS Guidance

When the user states durable workflow guidance or a recurring mistake is found,
record the rule immediately in the most specific relevant `AGENTS.md`. Keep
public docs free of agent-only process rules.

Also keep a compact skill index in root `AGENTS.md` so supervisors remember to
use repo-local skills and workers can discover them when `./skills` is mounted.

Use root `AGENTS.md` only for superproject orchestration, cross-module
architecture, family-wide policy, release-quality rules, and skill triggers.
Move detailed supervisor, dev-task worker, and memo/planning runbooks into the
matching repo-local skills. Module-specific implementation rules belong in the
module's own `AGENTS.md`.

Apply mistake-learning rigor to memory updates: if a command, workflow, or
reasoning pattern fails repeatedly, add the smallest durable rule in the most
specific applicable memory surface. Do not add rules for one-off project
commands that are still under active development unless the lesson is a stable
operator constraint.

## PLAN Hygiene

Use module `PLAN.md` files for executable work, not promises in chat. PLAN items
should be small enough for a worker to implement, test, document, and close in a
single task. Avoid splitting implementation, tests, and docs into disconnected
items unless they are genuinely separate follow-ups.

When a worker completes only part of a broad item, split the item: close the
completed slice and leave a new unchecked follow-up for the remaining work.

Feature request implementation order is user-defined and must be followed
unless explicitly revised. Current priority order: FR65, FR66, FR59, FR58,
FR46, FR63.

When a user provides `*.Update.md` tracker files, including `BUGS.Update.md`
and `FEATURE_REQUESTS.Update.md`, merge their contents into the corresponding
canonical tracker files in the same turn, then remove the update files. Always
process `BUGS.Update.md` first. Do not assume every listed item is new; verify
whether each item is already handled, stale, duplicated, or superseded before
copying it into canonical trackers.

Treat every new bug report as a new triage item even if it resembles a
previously fixed issue. Re-verify the original bug path and new reported path
before concluding it is fixed. When a bug report includes explicit repro
instructions or a shell repro script, rerun the provided steps as written, or
the closest deterministic equivalent if paths need sanitization, before
closing or downgrading the bug.

If multiple active bug reports exist and the user refers singularly to "the bug
report" or says to fix "it" without uniquely identifying which bug, ask a
concise clarification question and summarize the active options.

When active entries exist in `FEATURE_REQUESTS.md`, refine them into concrete
module execution checklists in the corresponding `bus-{NAME}/PLAN.md` files in
the same turn. Unchecked feature-oriented plan items must have corresponding
canonical feature-request mentions. Automated tests, e2e coverage, and
documentation updates remain mandatory through the Definition of Done; do not
split them into separate PLAN items unless the implementation already exists
and the missing test/docs work is the remaining follow-up.

When the user changes scope or requests new implementation work, add or update
the affected `PLAN.md`, `BUGS.md`, or `FEATURE_REQUESTS.md` before continuing
substantial work. Keep unfinished earlier work visible instead of dropping it
implicitly.

For code-specific refactoring work, put detailed technical refactor notes in
inline `FIXME(refactor)` comments at the source location. Keep `PLAN.md`
entries file-oriented and concise, referencing the owning file path. Whenever a
`FIXME(refactor)` comment is added, add or reopen a corresponding `PLAN.md`
item in the same change set.

When tracker files change in the same turn as implementation/docs/test files,
only tracker-only commits may be autonomous. Use
`scripts/commit-tracker-only.sh <repo-path> <message> <tracker-file>...` when
available so implementation changes are not accidentally included. Do not make
autonomous commits for non-tracker work unless the user explicitly asks.

Commit only staged changes. If submodules have staged changes, commit them
first depth-first, then the superproject. Do not auto-stage files unless
explicitly asked. Commit messages should be meaningful and imperative; nontrivial
commits need enough body detail for release review, including verification,
compatibility, migration/config impact, and security/privacy notes when
relevant. Never push, tag, or run remote synchronization unless explicitly
requested.

For deletion, use `git rm` for tracked paths and `rm` for untracked paths, then
update references/imports/scripts. When removing tracked inbox/update files that
may already have staged changes, prefer `git rm -f <file>`.

For import/extract/replay data handling, prefer canonical BusDK/master-data
keys. If input structure is non-canonical, require explicit configured column
mapping rather than implicit assumptions. Cross-module data/path/key usage
should resolve through the owning module's Go library/API instead of hardcoding
foreign module names, keys, or paths.

Do not add persistent workspace configuration for previous-year or
cross-workspace inputs. If a tool needs external prior-year data, require it on
the command line for that invocation.

## Logs To Lessons

Periodically review recent `logs/*agent-memo.md` files and worker closeouts for:

- repeated blocked closeouts
- stale tool or container issues
- dirty generated artifacts
- missing test/evidence expectations
- write-scope confusion
- missed parallelism opportunities
- product-layer mismatch

For each repeated pattern, either update the relevant `AGENTS.md`, improve a
repo-local skill, or add a concrete module `PLAN.md` item.

## Historical Verification

Before making a historical claim about what changed on a given date, verify the
actual Git diff first. Do not infer behavior from commit subjects, repository
creation dates, or assumptions about what "must have" happened.

Use `git log --since=... --until=...` to locate the date window, then inspect
the concrete file changes with `git log --stat`, `git show`, or both. If the
claim concerns behavior, open the introduced or changed source, tests, docs, or
help text and confirm the behavior really existed then.

Treat repo initialization, docs-only changes, pin bumps, and scaffolding as
separate from feature delivery unless the diff shows a real user-visible
capability, command surface, workflow, or documentation milestone.

## Checks

For Markdown memory changes, run `bus lint` on changed public-facing or durable
guidance files when practical, plus `git diff --check`.
