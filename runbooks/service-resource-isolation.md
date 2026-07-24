# Service Resource Isolation Standard


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

