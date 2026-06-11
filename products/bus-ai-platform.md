# Bus AI Platform Marketing Brief

## Working Product Definition

Bus AI Platform is BusDK's product line for running, deploying, and
productizing AI services on infrastructure the user controls. It combines
OpenAI-compatible model access, inference backends, runtime environments,
deployment automation, auth, usage metering, billing, and future operator UIs.

The current market focus should be AI product infrastructure for technical
teams. This product should not be positioned as a generic AI cloud or a vague
agent platform. It is the BusDK-owned layer that helps teams run AI services,
wrap them with product controls, and deploy them from local development to
real service environments.

## Short Positioning

We help technical founders, SaaS developers, and platform teams ship AI
features on infrastructure they control by offering a self-hostable AI platform
with model APIs, inference runtime control, deployment automation, auth, usage,
and billing, unlike raw model runners or cloud-only AI APIs, because Bus AI
Platform turns AI backend plumbing into a self-hostable BusDK service stack.

## Core Questions

### Goal

The immediate goal is qualified adoption by technical users, not broad AI
awareness. The product page should convert serious visitors into one of these
outcomes:

- Run a local AI service.
- Connect or configure an inference backend.
- Deploy a first AI endpoint.
- Add auth, usage, or billing around an AI service.
- Book a technical walkthrough for a self-hosted or managed deployment.

Later goals may include paid support, hosted platform revenue, usage-based AI
services, and managed deployment contracts.

### Audience

Primary audience:

- Technical founders building AI-enabled products.
- SaaS developers who need AI APIs, auth, usage tracking, and billing.
- Platform engineers who want local or self-hosted AI infrastructure.
- Privacy-conscious businesses that want more control over where AI workloads
  run.
- Teams that already use OpenAI-compatible APIs, Ollama, containerized
  inference, or cloud GPU nodes and need a product platform around them.

Early adopters should be technical enough to understand APIs, runtimes,
containers, deployment environments, auth, billing, and operational tradeoffs.

### Problem

AI product infrastructure is fragmented. A team can often run a model or call a
cloud API, but turning that into a reliable product surface requires many
separate pieces:

- Model API compatibility.
- Inference runtime selection.
- Local and remote execution.
- VM, container, terminal, and node management.
- Deployment readiness.
- Auth and session handling.
- Entitlements and service tokens.
- Usage metering.
- Billing and Stripe integration.
- Lifecycle events and service hooks.
- Operator or admin UI surfaces.

Without a platform layer, teams rebuild this plumbing repeatedly or become
locked into a single vendor's control plane.

### Offer

Bus AI Platform offers a self-hostable AI service platform:

- OpenAI-compatible model API surfaces.
- Local and remote inference backend integration.
- Ollama, Codex, and other inference/runtime integrations where supported.
- VM, container, terminal, and node runtime support.
- Deployment automation for cloud, database, inference, node, and SSH-runner
  workflows.
- Auth, session, approval, entitlement, usage, billing, and Stripe-backed
  platform services.
- Lifecycle events and integration hooks for BusDK components.
- Future frontend and operator UIs for managing AI services.

### Value

The buyer should care because Bus AI Platform reduces the amount of custom
platform work needed before AI features can become real products:

- Start locally and move toward deployed service environments.
- Keep control over runtime, infrastructure, and data placement.
- Use OpenAI-compatible interfaces while retaining backend choice.
- Add login, metering, entitlements, and billing around AI usage.
- Connect AI hosting to Bus Agentic Development and other BusDK products.
- Avoid building a one-off pile of scripts, gateways, billing hooks, and
  deployment glue.

### Differentiation

Bus AI Platform should be positioned against four alternatives:

- Cloud-only AI APIs: easy to call, but less self-hostable and often disconnected
  from local, self-hosted, or customer-controlled runtime needs.
- Hyperscaler AI platforms: powerful, but broad, complex, and tied to a large
  cloud control plane.
- Raw model runners: useful for local inference, but not a complete product
  platform for auth, usage, billing, deployment, and service lifecycle.
- Custom glue: flexible at first, but expensive to maintain once the product
  needs auth, billing, deployments, and multiple runtime backends.

BusDK's differentiators:

- Self-hostable and local-to-remote by design.
- OpenAI-compatible without being cloud-only.
- AI runtime, deployment, auth, usage, and billing are treated as one product
  line.
- The platform can support Bus Agentic Development, Bus Books, and future BusDK
  AI features.
- The system is modular: API providers, integrations, operators, events, and
  portal surfaces can be composed as needed.

### Proof

Avoid unsupported claims. The marketing page should lead with evidence BusDK
can actually show:

- A local AI service running through a Bus-managed API surface.
- An OpenAI-compatible request flowing through Bus AI Platform.
- A deployment walkthrough from local setup to a remote service environment.
- Runtime control over an inference backend or containerized service.
- Authenticated access to an AI endpoint.
- Usage metering and billing hooks around AI service calls.
- A demo where Bus Agentic Development uses Bus AI Platform infrastructure.

Evidence to collect later:

- Supported model/runtime matrix.
- Deployment environment matrix.
- Cold-start and request latency measurements.
- Cost-per-request examples.
- Usage and billing screenshots.
- Security and permission model notes.
- Case studies from BusDK's own usage.

### Objections

Likely objections and how the page should answer them:

- "Why not just use OpenAI?"
  Bus AI Platform is for teams that want OpenAI-compatible access plus more
  control over runtime, deployment, auth, usage, billing, and data placement.
- "Why not use Azure, Vertex, Bedrock, or another hyperscaler platform?"
  Those are strong managed platforms. Bus AI Platform should be presented as a
  smaller, self-hostable BusDK-native layer for teams that want local or
  local-to-remote AI infrastructure.
- "Why not just use Ollama or another model runner?"
  Model runners are runtime pieces. Bus AI Platform should provide the product
  layer around them: API surfaces, deployment, auth, usage, billing, and
  service lifecycle.
- "Is this production-ready?"
  The page should be specific about what is ready, what is technical preview,
  and what evidence exists. Do not imply enterprise maturity before it is
  proven.
- "Who operates it?"
  The product should explain local operation, self-hosted operation, and any
  future managed support separately.
- "Will it lock me into BusDK?"
  The best answer is OpenAI-compatible APIs, modular backends, and clear
  workspace/service contracts where those are true.

### Tone

The tone should be technical, premium, and sober. It should feel like
infrastructure for product builders, not generic AI hype.

Use:

- self-hostable AI platform
- self-hostable AI infrastructure
- OpenAI-compatible model access
- inference runtime control
- local-to-remote deployment
- auth, usage, and billing
- service lifecycle
- productized AI backend

Avoid:

- magic AI cloud
- enterprise-grade without proof
- deploy any AI anywhere
- no-code AI platform
- autonomous agent platform unless the page is specifically about agent
  workflows

### Channels

Initial channels:

- Product page on `busdk.com`.
- End-user docs page under BusDK docs.
- Quickstart for running the first local AI service.
- Tutorial for deploying a first AI endpoint.
- Architecture page for API providers, integrations, operators, runtime,
  auth, usage, and billing.
- Demo showing an authenticated OpenAI-compatible request with usage tracking.

Later channels:

- Comparison page against cloud-only APIs, hyperscaler AI platforms, raw model
  runners, and custom glue.
- Sales deck for technical founders and platform teams.
- Case studies from BusDK internal usage.
- Launch article about self-hostable AI product infrastructure.

### Call To Action

Primary CTA:

- Run your first Bus AI service.

Secondary CTAs:

- Deploy an AI endpoint.
- Add auth and usage tracking.
- Connect an inference backend.
- Read the architecture.
- Book a technical walkthrough.

### Success Metrics

Product marketing should be judged by:

- Visits to the product page.
- Quickstart starts and completions.
- First local AI service started.
- First OpenAI-compatible request completed.
- First inference backend configured.
- First remote AI endpoint deployed.
- First authenticated request.
- First usage-metered request.
- Demo requests and qualified pilots.
- Paid support or deployment conversations.

## Page Message

Suggested headline:

> Self-hostable AI infrastructure for product builders.

Suggested subheadline:

> Bus AI Platform gives technical teams OpenAI-compatible model access,
> inference runtime control, local-to-remote deployment, auth, usage, and
> billing so AI services can become real product infrastructure instead of
> custom glue.

Suggested primary sections:

1. Run AI services on infrastructure you control.
2. Use OpenAI-compatible APIs without giving up backend choice.
3. Move from local inference to deployed service environments.
4. Add auth, usage, entitlements, and billing around AI features.
5. Connect AI hosting to Bus Agentic Development and other BusDK products.
6. Keep the platform modular: providers, integrations, operators, events, and
   future UIs.

## Naming Notes

Use **Bus AI Platform** for this product line. It is broader and clearer than
Bus AI API because the product includes deployment, runtime, auth, usage,
billing, and future UIs.

Do not rename this product to Bus Agentic Platform unless the primary public
offer becomes building, deploying, and governing agents. Agentic workflows
belong under Bus Agentic Development or a future Bus Agents product line.

Use "AI" for the infrastructure/platform layer and "agentic" or "agents" for
autonomous workflows that do work.

## Current Module Ownership

Bus AI Platform currently owns these product-facing module families:

- Model and inference API/provider modules: `bus-api-provider-llm`,
  `bus-api-provider-inference`, `bus-integration-inference`,
  `bus-integration-codex`, `bus-integration-ollama`.
- Runtime modules: `bus-vm`, `bus-containers`, `bus-api-provider-vm`,
  `bus-api-provider-containers`, `bus-api-provider-terminal`,
  `bus-integration-containers`, `bus-integration-docker`,
  `bus-integration-podman`, `bus-integration-upcloud`.
- Deploy and infrastructure modules: `bus-operator-deploy`,
  `bus-operator-cloud`, `bus-operator-database`,
  `bus-operator-inference`, `bus-operator-node`,
  `bus-api-provider-cloud`, `bus-api-provider-database`,
  `bus-api-provider-node`, `bus-integration-cloud`,
  `bus-integration-database`, `bus-integration-node`,
  `bus-integration-postgres`, `bus-integration-ssh-runner`.
- Auth, usage, and billing modules: `bus-auth`, `bus-portal-auth`,
  `bus-billing`, `bus-api-provider-auth`, `bus-api-provider-session`,
  `bus-api-provider-billing`, `bus-api-provider-usage`,
  `bus-integration-billing`, `bus-integration-usage`,
  `bus-integration-stripe`, `bus-operator-auth`,
  `bus-operator-billing`, `bus-operator-stripe`.

Do not split Bus Deploy, Bus Runtime, Bus Auth, or Bus Billing into separate
public product pages unless their offers become independently understandable,
usable, and sellable.
