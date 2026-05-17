---
name: bus-plan-memory-maintainer
description: Use when maintaining PLAN.md queues, AGENTS.md durable guidance, hourly logs, worker lessons, and project memory so repeated BusDK workflow mistakes become reusable process rules.
---

# Bus Plan And Memory Maintainer

Use this skill when turning lessons from logs, workers, or reviews into durable
project memory.

## Hourly Memo

Maintain `logs/{YYYYMMDD}-{HH}-agent-memo.md` during each work session. Write it
as a narrative engineering diary, not a raw checklist. Explain goals, findings,
decisions, tests, friction, and handoff state.

When the hour changes, add a short handoff to the previous memo and continue in
the new hour.

## AGENTS Guidance

When the user states durable workflow guidance or a recurring mistake is found,
record the rule immediately in the most specific relevant `AGENTS.md`. Keep
public docs free of agent-only process rules.

Also keep a compact skill index in root `AGENTS.md` so supervisors remember to
use repo-local skills and workers can discover them when `./skills` is mounted.

## PLAN Hygiene

Use module `PLAN.md` files for executable work, not promises in chat. PLAN items
should be small enough for a worker to implement, test, document, and close in a
single task. Avoid splitting implementation, tests, and docs into disconnected
items unless they are genuinely separate follow-ups.

When a worker completes only part of a broad item, split the item: close the
completed slice and leave a new unchecked follow-up for the remaining work.

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

## Checks

For Markdown memory changes, run `bus lint` on changed public-facing or durable
guidance files when practical, plus `git diff --check`.
