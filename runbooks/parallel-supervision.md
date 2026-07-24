# Parallel Supervisor Operating Standard

This standard exists because repeated memo evidence showed the
supervisor could reach high throughput for one hour and then fall back to
one-worker-at-a-time execution.

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

