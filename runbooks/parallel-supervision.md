# Parallel Supervision Runbook

Read this before running broad multi-worker goals, sizing parallel lanes,
judging utilization or throughput, or designing service and worker resource
limits. It carries the full Parallel Supervisor Operating Standard and the
Service Resource Isolation Standard, expanding the binding core in the root
`AGENTS.md`. This standard exists because repeated memo evidence showed the
supervisor could reach high throughput for one hour and then fall back to
one-worker-at-a-time execution.

## Service Resource Isolation Standard

Bus Services must prevent any one service, worker, tenant, task, container, or
descendant process tree from exhausting host resources or denying service to
the rest of the control plane. Enforce this deterministically in service and
worker infrastructure rather than through agent prompts.

- Put every service and worker execution tree in an owned resource domain;
  Docker or other delegated runtimes must not escape that ownership boundary.
- Protect control-plane capacity and apply per-domain memory high/max, swap,
  CPU, I/O, process-count, and concurrency limits. Allow bounded idle-capacity
  bursts without allowing aggregate host exhaustion.
- Admit heavyweight work through a host/environment-wide lease and resource
  preflight. Queue competing heavyweight jobs fairly instead of starting them
  concurrently; interactive and control-plane work outrank background builds.
- Apply backpressure at request and task boundaries, with per-identity and
  per-service budgets so one hot resource cannot fan out into dependent-service
  overload.
- Treat OOM, swap exhaustion, admission failure, or limit breach as terminal
  evidence for that attempt. Do not retry until the resource plan changes.
- Record the owner, resource class, cgroup/container identity, configured
  limits, peak CPU/RSS/swap/I/O/process count, throttle events, OOM/exit reason,
  and cleanup result in lifecycle evidence.
- Provide separate quiesce, drain, and emergency-stop semantics. Normal service
  shutdown must stop new dispatch, allow only its bounded grace period, and
  then terminate the complete Bus-owned resource domain: every service process,
  worker, task process, descendant, and container launched through that service,
  including detached processes re-parented to PID 1. A successful shutdown must
  verify that the domain is empty; report surviving owned work as a shutdown
  failure. Only an explicit drain operation may let existing owned work continue.

Resource scheduling must use explicit policy and measured state, not LLM
judgment. Resource isolation is an availability and correctness requirement,
not an optional performance optimization.

## Parallel Supervisor Operating Standard

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

