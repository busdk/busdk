# Finish-First Delivery Gate Details


These bullets expand the Finish-First Delivery Gate core in the root
`AGENTS.md`; the board-intake commands are in
`runbooks/board-intake-commands.md`.

- Choose the smallest owner module and independently reviewable change. Add no
  provider, protocol, framework, or cleanup without a failing acceptance check
  that requires it.
- Prepare implementation, E2E evidence, and review in parallel when their
  write scopes do not overlap. Count a lane active only from verified runtime
  and turn evidence plus a task-relevant diff, result, or diagnosis.
- After one failed execution and one materially changed retry, stop repeating
  the mechanism. Preserve the handoff and change runtime, model, environment,
  materialization, or task shape.
- Resolve findings with one additive repair and exact delta review, then return
  immediately to the frozen composed E2E instead of reopening architecture.
- When a reviewed composition passes E2E, integration, install, use, and live
  acceptance are the next default actions. Report promoted-but-unused work as
  finishable debt; do not start adjacent source work ahead of it.
- Preflight repository identity, full SHA, writable clean Git metadata, prompt
  boundaries, credential freshness, runtime truth, and durable result paths.
  Keep heavy work admitted and resource-bounded while independent lightweight
  lanes continue.
- Use the shared co-work coordination thread only for cross-lane dependencies
  and accepted baselines. Keep detailed evidence in the owning feature Thread
  and keep delivery-process retrospective evidence on its own thread.

