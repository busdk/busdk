# Bus Services Marketing Brief

## Working Product Definition

Bus Services is BusDK's product line for predictable project service stacks. It
gives developers and operators a public-safe `services.yml` contract plus CLI,
API, and integration surfaces to validate, plan, start, inspect, and stop the
long-running services a BusDK project needs.

The current market role should be support for the larger BusDK product family,
not a top-priority standalone business product. Bus Services makes Bus AI
Platform, Bus Agentic Development, Bus Books, and other BusDK products easier
to run by turning local and project runtime setup into a repeatable workflow.

## Short Positioning

We help developers and operators run BusDK project dependencies reliably by
offering deterministic `services.yml` stacks with plan, start, status, and stop
workflows, unlike ad hoc shell scripts, drifting README setup steps, or
container-only assumptions, because Bus Services keeps configuration
public-safe, reports non-secret service state, and can model native,
container, managed, system, VM-backed, and future service runtimes.

## Core Questions

### Goal

The immediate goal is activation and trust. Bus Services should help technical
users get a BusDK project running, understand what is running, and shut it down
without guessing.

Primary outcomes:

- A user starts a project stack with `bus services up`.
- A user verifies status with `bus services ps`.
- A user stops the exact running stack with `bus services down`.
- A project replaces manual setup notes with a maintained `services.yml`.
- A larger BusDK product quickstart becomes easier to complete.

This product line should not be measured first by standalone sales. It should
reduce setup friction and increase successful adoption of the larger BusDK
products.

### Audience

Primary audience:

- Developers using BusDK locally.
- Operators running BusDK projects in repeatable environments.
- Technical founders who need project setup to be boring and inspectable.
- Platform engineers maintaining development, staging, or small production-like
  BusDK environments.
- Teams evaluating Bus AI Platform, Bus Agentic Development, or Bus Books who
  need supporting services to start cleanly.

This is not mainly for non-technical business users. It is for people who
understand project services, process status, logs, environment variables, and
runtime choices.

### Problem

Project service setup often becomes fragile:

- Setup docs drift from the real startup process.
- Developers manually start PostgreSQL, APIs, Events, workers, relays, or
  other dependencies in different ways.
- Scripts mix public configuration with private secrets.
- Shell scripts start things but do not clearly show what is running.
- Shutdown does not always target the services that were actually started.
- Docker-only assumptions fail when native, system, managed, VM, or future
  runtime backends are more appropriate.
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
- Start the same stack consistently across project checkouts.
- Inspect status without leaking tokens, DSNs, private keys, or resolved
  secret values.
- Stop the services that were actually started, even if `services.yml` changed
  afterward.
- Keep runtime mechanics behind provider-specific modules instead of mixing
  everything into one script.
- Support different runtime styles without making the public service identity
  depend on the implementation.

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
- Bus Services is BusDK-native and runtime-neutral. A Service can be backed by
  native processes, containers, managed providers, system service managers, VMs,
  or future providers.

Bus Services should not be positioned as a Kubernetes replacement or a full
general-purpose production orchestrator unless the product later proves that
scope.

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
  enough. Bus Services is for BusDK projects that need one service model across
  native, container, managed, system, VM-backed, and future runtimes.
- "Is this production orchestration?"
  It is primarily a BusDK project service-stack workflow. Do not sell it as
  production orchestration until production-grade runtime guarantees are
  documented and proven.
- "Does it leak secrets?"
  The product should emphasize public stack files, secret references, and
  non-secret plan/status output.
- "What happens when the stack file changes?"
  Startup writes the resolved stack that was actually started, and shutdown
  uses that frozen state.
- "Is this only for BusDK?"
  It is BusDK-native first. The generic service model may be useful elsewhere,
  but marketing should lead with BusDK projects and product quickstarts.
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

Avoid:

- magic orchestration
- production-grade cluster management
- effortless infrastructure
- replaces Kubernetes
- universal runtime platform
- full Docker alternative

### Channels

Best channels:

- BusDK docs.
- Bus AI Platform quickstarts.
- Bus Agentic Development setup guides.
- Bus Books local development and deployment guides.
- CLI reference pages.
- Technical blog posts about replacing setup scripts with `services.yml`.
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

> Add a `services.yml` to your BusDK project.

### Success Metrics

Product marketing should be judged by:

- Quickstart completion rate for BusDK products that depend on services.
- Number of projects with a `services.yml`.
- Successful `bus services up` followed by healthy `bus services ps`.
- Repeat usage of `up`, `ps`, and `down`.
- Fewer support issues caused by manual startup steps.
- Fewer docs that require hand-starting local services.
- Reduced time from checkout to running local BusDK stack.

## Page Message

Suggested headline:

> Predictable service stacks for BusDK projects.

Suggested subheadline:

> Bus Services turns project dependencies into public-safe `services.yml`
> stacks you can validate, plan, start, inspect, and stop without leaking
> secrets or hardcoding one runtime style.

Suggested primary sections:

1. Replace drifting setup scripts with a stack contract.
2. Plan before startup.
3. Start, inspect, and stop the resolved stack.
4. Keep secrets out of public configuration and status.
5. Model services by purpose, not by runtime implementation.
6. Built for BusDK product quickstarts and local operations.

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
