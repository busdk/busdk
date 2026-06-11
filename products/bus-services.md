# Bus Services Marketing Brief

## Working Product Definition

Bus Services is BusDK's product line for predictable process-level service
stacks. It gives developers and operators a public-safe `services.yml` contract
plus CLI, API, and integration surfaces to validate, plan, start, inspect, and
stop the long-running processes a project needs.

The product is generally useful beyond BusDK. A project can use it to run
services such as PostgreSQL, Redis, local APIs, workers, relays, or development
helpers under ordinary user-land process control. It is similar to Docker
Compose in the sense that it packages multiple services into one project-level
stack, but it does not require containers or virtualization. That matters
because it can also run inside containers, inside a systemd-managed service, or
in other environments where nested virtualization is unavailable or unwanted.

The current market role should still be a supporting product rather than a
top-priority headline product. Bus Services makes Bus AI Platform, Bus Agentic
Development, Bus Books, and other BusDK products easier to run, but its core
offer is broader: repeatable service stacks for development and operations.

## Short Positioning

We help developers and operators run project service stacks reliably by
offering deterministic `services.yml` stacks with plan, start, status, and stop
workflows, unlike ad hoc shell scripts, drifting README setup steps, or
container-only assumptions, because Bus Services can package multiple
process-level services without requiring virtualization while still keeping
configuration public-safe and status output non-secret.

## Core Questions

### Goal

The immediate goal is activation and trust. Bus Services should help technical
users get a project service stack running, understand what is running, and shut
it down without guessing.

Primary outcomes:

- A user starts a project stack with `bus services up`.
- A user verifies status with `bus services ps`.
- A user stops the exact running stack with `bus services down`.
- A project replaces manual setup notes with a maintained `services.yml`.
- A developer runs services such as PostgreSQL, a local API process, an event
  relay, or a worker without requiring Docker or nested virtualization.
- A larger BusDK product quickstart becomes easier to complete.

This product line should not be measured first by standalone sales. It should
reduce setup friction for development and operations, while also increasing
successful adoption of the larger BusDK products.

### Audience

Primary audience:

- Developers running local project dependencies.
- Operators running repeatable project service stacks.
- Technical founders who need project setup to be boring and inspectable.
- Platform engineers maintaining development, staging, or small production-like
  environments.
- Teams that need process-level service stacks inside containers, CI jobs,
  systemd-managed units, or other environments where virtualization is not
  available or not desirable.
- Teams evaluating Bus AI Platform, Bus Agentic Development, or Bus Books who
  need supporting services to start cleanly.

This is not mainly for non-technical business users. It is for people who
understand project services, process status, logs, environment variables, and
runtime choices.

### Problem

Project service setup often becomes fragile:

- Setup docs drift from the real startup process.
- Developers manually start PostgreSQL, APIs, Events, workers, relays, Redis,
  queues, helper processes, or other dependencies in different ways.
- Scripts mix public configuration with private secrets.
- Shell scripts start things but do not clearly show what is running.
- Shutdown does not always target the services that were actually started.
- Docker-only assumptions fail when containers are unavailable, nested
  virtualization is not allowed, or native/system/user-land process execution
  is the simpler fit.
- Operators cannot easily see service ids, runtime kinds, process ids, log
  paths, or status without exposing private values.

### Offer

Bus Services offers a project service-stack workflow:

- Public `services.yml` stack files.
- Runtime profiles for service definitions.
- `bus services up` for normal startup.
- `bus services ps` for non-secret service status.
- `bus services down` for stopping the resolved running stack.
- Lower-level `bus-services stack validate`, `plan`, `up`, and `down` commands
  for explicit stack-file workflows and test smoke checks.
- Runtime labels such as `native`, `container`, `managed`, `system`, and `vm`.
- Process-level service execution for development and other user-land
  environments where virtualization is unnecessary or unavailable.
- Public-safe secret references through `.env`, `value_from: env:KEY`, and
  carefully scoped process environment references.
- State and resolved-stack evidence under `.bus/services`.
- API and integration boundaries through `bus-api-provider-services` and
  `bus-integration-services`.

### Value

The buyer or evaluator should care because Bus Services makes project runtime
setup repeatable and inspectable:

- Onboard faster without copying fragile manual startup steps.
- See a non-secret plan before starting services.
- Start the same stack consistently across project checkouts, containers, CI
  jobs, or systemd-managed environments.
- Inspect status without leaking tokens, DSNs, private keys, or resolved
  secret values.
- Stop the services that were actually started, even if `services.yml` changed
  afterward.
- Keep runtime mechanics behind provider-specific modules instead of mixing
  everything into one script.
- Support different runtime styles without making the public service identity
  depend on the implementation.
- Run useful services without requiring containers, VMs, or nested
  virtualization.

### Differentiation

Bus Services should be positioned against three common alternatives.

Shell scripts:

- Shell scripts are flexible, but they rarely provide structured validation,
  non-secret plans, service status, or a durable record of the resolved stack.
- Bus Services gives the project a declared service model and an operator
  workflow.

README setup steps:

- README steps are useful, but they drift and leave too much to the operator.
- Bus Services turns those steps into a stack file and repeatable commands.

Docker Compose:

- Docker Compose is strong for container-only stacks.
- Bus Services can fill a similar project-stack role without requiring
  containers or virtualization. A Service can be backed by native user-land
  processes, containers, managed providers, system service managers, VMs, or
  future providers.

System service managers:

- systemd, launchd, and similar tools are strong host service managers.
- Bus Services is a project-level stack contract that can run inside or
  alongside those managers. It should not pretend to replace host-level service
  policy.

Bus Services should not be positioned as a Kubernetes replacement or a full
general-purpose production orchestrator unless the product later proves that
scope.

Bus Services is also not a security or isolation tool. It starts and observes
services; it does not sandbox them, isolate networks, restrict filesystem
access, or limit service-to-service access. Security boundaries must come from
the operating system, container runtime, VM, network policy, systemd sandboxing,
or another explicit security layer.

### Proof

Current proof should stay close to implemented or documented behavior:

- `bus services up`, `bus services ps`, and `bus services down` are the normal
  operator entrypoints.
- `bus-services stack validate --file services.yml` validates syntax and
  references.
- `bus-services stack plan --file services.yml` prints a non-secret plan.
- `bus-services stack up --file services.yml` starts selected services through
  the integration daemon.
- `bus-services stack down --file services.yml` uses the frozen resolved stack
  state.
- Status output includes non-secret service ids, running/exited state, runtime
  kind/provider, process id when available, start time, and log path.
- Public configuration stays in `services.yml`; private values stay in `.env`
  or another secret boundary and are referenced by name.
- Service state is stored under `.bus/services`.
- `bus-api-provider-services` owns the API/controller surface, validation,
  Events publication, and bounded read projections.
- `bus-integration-services` owns runtime integration, provider dispatch,
  lifecycle reconciliation, and status snapshots.

Avoid claims that every runtime kind can already be fully started and stopped.
Some runtime kinds may be represented in plans before their owning integration
modules provide executable lifecycle support.

### Objections

Likely objections and honest answers:

- "Why not just use Docker Compose?"
  Use Docker Compose when the stack is purely container-oriented and that is
  enough. Bus Services is for projects that need a stack model that can run
  process-level services without requiring containers or virtualization.
- "Does this isolate services from each other?"
  No. Bus Services is not a sandbox, firewall, or security boundary. It does
  not limit access between services. Use OS, container, VM, network, or systemd
  security features when isolation is required.
- "Is this production orchestration?"
  It is primarily a project service-stack workflow, especially useful during
  development. Do not sell it as production orchestration until
  production-grade runtime guarantees are documented and proven.
- "Does it leak secrets?"
  The product should emphasize public stack files, secret references, and
  non-secret plan/status output.
- "What happens when the stack file changes?"
  Startup writes the resolved stack that was actually started, and shutdown
  uses that frozen state.
- "Is this only for BusDK?"
  No. It is BusDK-native and powers BusDK product quickstarts, but the product
  should be explained as generally useful for project-level service stacks.
- "Is this another config language?"
  The message should be that `services.yml` replaces scattered manual setup
  instructions with one explicit project contract.

### Tone

The tone should be practical, technical, and calm.

Use:

- predictable service stacks
- public-safe configuration
- non-secret status
- runtime-neutral services
- plan before startup
- stop the resolved stack
- local and project runtime setup
- process-level services
- works without virtualization
- can run inside containers or systemd-managed environments

Avoid:

- magic orchestration
- production-grade cluster management
- effortless infrastructure
- replaces Kubernetes
- security sandbox
- isolates services from each other
- universal runtime platform
- full Docker alternative

### Channels

Best channels:

- Bus Services product page.
- BusDK docs.
- Bus AI Platform quickstarts.
- Bus Agentic Development setup guides.
- Bus Books local development and deployment guides.
- CLI reference pages.
- Technical blog posts about replacing setup scripts with `services.yml` and
  running process-level service stacks without virtualization.
- Example repositories that include real stack files.

Bus Services can have a public page, but it should usually sit after the more
important product lines in navigation and homepage priority.

### Call To Action

Primary CTA:

```sh
bus services up
bus services ps
```

Secondary CTAs:

```sh
bus-services stack validate --file services.yml
bus-services stack plan --file services.yml
bus services down
```

Page CTA:

> Add a `services.yml` to your project.

### Success Metrics

Product marketing should be judged by:

- Quickstart completion rate for projects and BusDK products that depend on
  services.
- Number of projects with a `services.yml`.
- Successful `bus services up` followed by healthy `bus services ps`.
- Repeat usage of `up`, `ps`, and `down`.
- Fewer support issues caused by manual startup steps.
- Fewer docs that require hand-starting local services.
- Reduced time from checkout to running local service stack.

## Page Message

Suggested headline:

> Predictable service stacks without requiring virtualization.

Suggested subheadline:

> Bus Services turns project dependencies into public-safe `services.yml`
> stacks you can validate, plan, start, inspect, and stop as ordinary
> user-land services, without leaking secrets or hardcoding one runtime style.

Suggested primary sections:

1. Replace drifting setup scripts with a stack contract.
2. Plan before startup.
3. Start, inspect, and stop the resolved stack.
4. Keep secrets out of public configuration and status.
5. Model services by purpose, not by runtime implementation.
6. No sandbox claim: use explicit OS, container, VM, network, or systemd
   security when isolation matters.

## Current Module Ownership

Primary modules:

- `bus-services`
- `bus-api-provider-services`
- `bus-integration-services`

Related runtime/provider modules may participate when a stack uses their
service type, but they should stay owned by their product or platform boundary.
For example, container, VM, database, cloud, and AI platform runtime modules
should not be duplicated as Bus Services product ownership unless the product
taxonomy changes.
