---
name: bus-product-delivery-supervisor
description: Use when supervising broad BusDK development across modules with bus dev task/work workers, especially when the goal is to drain PLAN.md items, finish UI feature candidates, monitor parallel workers, fix blockers, and improve the development process from logs.
---

# Bus Product Delivery Supervisor

Use this skill for broad BusDK work where the main job is coordination, worker
dispatch, review, and process improvement. Keep the supervisor focused on
progress management; delegate implementation to recipient-scoped workers when
the work can be made clear and isolated.

## Operating Loop

1. Refresh memory:
   - Read the current hourly memo and recent `logs/*agent-memo.md` entries.
   - Check the most specific `AGENTS.md` files for root, recipient modules,
     `docs`, and `sdd` before dispatching work.
   - Run `bus dev work status` and inspect relevant `PLAN.md` files.

2. Build a dispatch board:
   - Active workers by ref and recipient.
   - Idle capacity.
   - Next unblocked tasks.
   - Dirty primary checkout risks.
   - Blockers and the owning `PLAN.md` or infrastructure module.

3. Choose the critical path:
   - Prefer framework and infrastructure tasks that unblock many modules.
   - For the GX/UI roadmap, finish `bus-gx`, then common `bus-ui` primitives,
     then portal host contracts, then leaf portal module migrations.
   - Promote completed UI feature candidates to semver only after code,
     tests, docs, SDD, and module docs match the implemented behavior.

4. Dispatch workers:
   - Use `bus dev work start` or `bus dev task new` with explicit recipients.
   - Give each worker non-overlapping module or file ownership.
   - For same-recipient docs/refactor shards, pass exact `--write-scope`
     paths; globs are not supported.
   - State goal, files to inspect first, boundaries, acceptance criteria,
     test/documentation requirements, and completed-work evidence.

5. Monitor continuously:
   - While workers run, do not idle. Review returned patches, prepare next
     briefs, groom plans, inspect blockers, or start additional safe workers.
   - After each worker terminal event, immediately accept/promote, reopen with
     precise guidance, record a blocker, or dispatch the next unblocked item.
   - Count throughput only as verified and promoted work, not claimed work.

6. Fix repeated blockers:
   - If a failure repeats, stop retrying blindly.
   - Record or implement the root-cause fix in the owning module.
   - When a just-pinned worker/bridge fix appears ineffective in newly
     launched workers, first verify whether the workers are using stale
     container images, installed binaries, or dependency checkouts before
     reopening more content tasks.
   - Common blockers include stale BusDK tools in containers, auth/token drift,
     dirty primary checkouts, generated artifact churn, stale submodule pins,
     missing write scopes, and incomplete worker evidence.

7. Preserve memory:
   - Update the current hourly memo after meaningful phases.
   - Add durable rules to the most specific `AGENTS.md` when a mistake or
     recurring lesson should not be repeated.
   - Add unresolved implementation work to the owning module `PLAN.md`; do not
     rely on final-answer promises.

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
