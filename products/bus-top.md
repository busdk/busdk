# Bus Top Marketing Brief

## Working Product Definition

Bus Top is BusDK's friendly local process monitor. It helps developers,
operators, technical founders, and power users understand what is running on a
machine, why it is running, whether its current behavior looks ordinary, and
what to inspect next.

The product should stay local-first and deterministic. AI explanations are an
optional annotation layer over sampled process facts, cached process-family
records, and privacy-redacted prompts. Bus Top must remain useful without AI.

Bus Top is not one of BusDK's main strategic product lines right now, but it is
a strong trust-building product: it gives a new user an immediately useful
command, shows BusDK's taste for practical tools, and connects naturally to Bus
AI Platform, Bus Agentic Development, and local operator workflows.

## Short Positioning

We help developers and operators understand their local machine by offering a
friendly process monitor with privacy-aware AI explanations, unlike raw process
monitors or pasted chatbot prompts, because Bus Top is deterministic,
local-first, inspect-only, cache-aware, and useful even when AI is disabled.

## Core Questions

### Goal

The immediate goal is awareness, trust, and product adoption. Bus Top should
make BusDK feel useful within minutes of installation:

- Install BusDK.
- Run `bus top`.
- Understand a confusing process, helper, service, or resource spike.
- Build confidence that BusDK makes technical work clearer instead of noisier.

Secondary goals:

- Introduce users to BusDK's local-first AI approach.
- Create a lightweight entry point into Bus AI Platform.
- Demonstrate that BusDK can combine deterministic tooling with optional AI
  interpretation without becoming opaque.

Bus Top should not be treated as the primary paid product line before Bus
Agentic Development, Bus AI Platform, or Bus Books.

### Audience

Primary audience:

- Software developers running many local tools, agents, servers, browsers,
  language servers, build systems, package managers, containers, and databases.
- Technical founders and small-team operators who need to understand their own
  development machines without becoming OS internals experts.
- Support engineers and operations-minded developers who inspect local process
  behavior during debugging.
- BusDK users who want a human-readable view of local workloads and Bus-related
  background processes.

The best early audience is technical enough to use a terminal, but not
necessarily expert enough to recognize every process name, macOS helper,
language server, or runtime worker by sight.

### Problem

Traditional process monitors show raw facts: PID, CPU, memory, command name,
user, and sometimes parent process. Those facts are necessary, but they do not
answer the user's real questions:

- What is this process?
- Why is it running?
- Is it normal for it to use this much CPU or memory?
- Is this process part of my editor, browser, container runtime, AI worker, or
  operating system?
- What changed since the machine started feeling slow?
- What should I inspect next without killing the wrong thing?

Users often end up searching process names manually or pasting process lists
into a chatbot, which is slow, repetitive, and risky for privacy.

### Offer

Bus Top offers a terminal process monitor with:

- Live process and system pressure view.
- CPU, memory, swap, load, process count, and battery-impact style signals.
- Process-family grouping so repeated helper processes share one explanation.
- Sorting, filtering, search, grouping, and focused process details.
- Deterministic snapshots for scripts, tests, and support evidence.
- Optional AI explanations for process families.
- Cache-first AI behavior so repeated rows do not trigger repeated requests.
- Privacy redaction by default before AI requests.
- Self-check mode that reports Bus Top's own resource use.
- Host diagnosis mode for bounded host-health evidence and one compact AI
  interpretation when configured.
- Inspect-only behavior: Bus Top should not kill, renice, or signal processes
  without a later explicit action design.

### Value

The buyer or user should care because Bus Top reduces uncertainty:

- Understand local process behavior faster.
- See process families instead of a wall of repeated helper rows.
- Read plain-language explanations without leaving the terminal.
- Use local deterministic process facts even when AI is disabled.
- Avoid exposing full local process commands to a model by default.
- Keep monitoring cheap enough to leave open while working.
- Export deterministic JSON snapshots for debugging and automation.

The practical outcome is calmer local operations: fewer mystery processes,
less guessing, and better next-step diagnosis.

### Differentiation

Bus Top should be positioned against three alternatives:

- Raw terminal monitors such as `top` or `htop`: powerful, but mostly metric
  oriented and not explanatory.
- GUI activity monitors: approachable, but often disconnected from developer
  context, terminals, scripts, and BusDK workflows.
- Chatbot-based diagnosis: flexible, but usually manual, privacy-risky, and
  disconnected from live process sampling and cached local context.

Bus Top's differentiators:

- Local process facts remain the source of truth.
- AI is optional and annotation-only.
- Explanations are generated by process family, not every row.
- Prompts are privacy-redacted by default.
- Cached explanations make the live view cheaper and more stable.
- The tool is inspect-only and conservative about advice.
- JSON snapshot output supports testing, automation, and support handoffs.
- Resource self-checks make the monitor accountable for its own overhead.

### Proof

Claims should stay tied to evidence BusDK can show:

- `bus top` opens a live process TUI.
- `bus top --snapshot --format json` emits deterministic process data.
- `bus top --ai off` remains useful without model access.
- `bus top --warm-ai` prepares process-family explanations when a backend is
  configured.
- `bus top --diagnose host --ai auto` collects bounded host evidence and can
  produce one compact diagnosis.
- `bus top --self-check --self-check-duration 5s` reports Bus Top's own CPU and
  RSS against the resource budget.
- The design target is below 1% idle self CPU and below 50 MiB RSS on a typical
  developer laptop.

Marketing-grade proof still needed:

- Real screenshots or terminal captures.
- Short demo video or GIF.
- Before/after examples of confusing process families.
- Example AI explanation cache entries with redacted prompts.
- Measured self-check results from a normal developer workstation.
- Linux support status and limitations once native parity is stronger.

### Objections

Likely objections and how the product page should answer them:

- "Why not just use top or htop?"
  Bus Top adds process-family grouping, focused explanations, privacy-aware AI,
  deterministic snapshots, and host diagnosis while preserving local facts.
- "Can I trust AI with my process list?"
  AI is optional, cache-first, family-scoped, and privacy-redacted by default.
  Bus Top remains useful with `--ai off`.
- "Will it leak secrets?"
  Full command paths and arguments should not be sent by default. The default
  privacy mode is redacted, and local process facts remain local unless the
  operator enables AI.
- "Will it slow down the machine?"
  Bus Top has an explicit resource budget and self-check mode. The product
  should publish measured overhead instead of asking users to trust vague
  claims.
- "Can it kill processes?"
  The first product version is inspect-only. It can suggest what to inspect,
  but it should not terminate or renice processes.
- "Does it work outside macOS?"
  Be honest about current platform proof. Linux should be presented only to the
  extent native sampler parity and tests support it.
- "Is this worth paying for?"
  Bus Top alone may not be the paid product. Its job is to make BusDK useful,
  trusted, and understandable, and to support broader BusDK product lines.

### Tone

The tone should be calm, practical, and technically credible.

Use:

- friendly process monitor
- ordinary-language explanations
- local-first
- deterministic facts
- privacy-redacted AI
- inspect-only guidance
- process families
- resource budget
- cached explanations

Avoid:

- magic system doctor
- AI knows everything
- kill mystery processes automatically
- fully autonomous operations
- vague productivity claims without a demo or measurement

### Channels

Initial channels:

- Product page on `busdk.com`.
- End-user docs page under BusDK docs.
- Install/getting-started flow as an immediately useful first command.
- Short demo video or GIF showing a confusing process family explained.
- Blog post about privacy-aware AI process monitoring.

Secondary channels:

- Developer social posts.
- Support/debugging examples.
- BusDK bundle overview as a trust-building utility.
- Bus AI Platform page as an example of local AI-assisted operator tooling.

### Call To Action

Primary CTA:

- Install BusDK and run `bus top`.

Secondary CTAs:

- Try `bus top --snapshot --format json`.
- Run `bus top --ai off` to see the deterministic local view.
- Configure AI and run `bus top --warm-ai`.
- Run `bus top --self-check --self-check-duration 5s`.

### Success Metrics

Bus Top marketing should be judged by:

- Product page visits.
- Install clicks from the Bus Top page.
- Docs page engagement.
- Demo video completion.
- First `bus top` run after install, if telemetry is ever added and explicitly
  accepted.
- Repeat `bus top` use.
- `--warm-ai` or AI configuration attempts.
- Click-through from Bus Top into BusDK, Bus AI Platform, or Bus Agentic
  Development pages.
- Support/demo conversations where Bus Top helped explain BusDK's practical
  value.

## Page Message

Suggested headline:

> Understand what your machine is doing.

Suggested subheadline:

> Bus Top is a friendly local process monitor that groups related processes,
> shows deterministic system facts, and can add privacy-aware AI explanations
> when you want plain-language help.

Suggested primary sections:

1. A process monitor for humans, not just PIDs.
2. Local facts first, AI explanations optional.
3. Process families instead of repeated helper noise.
4. Privacy-redacted prompts and cached explanations.
5. Inspect safely before taking action.
6. Snapshot, diagnose, and self-check when you need evidence.

## Naming Notes

Use **Bus Top** for the public product page and `bus top` for the command.
Avoid renaming it into a broad AI operations product. It is a focused,
trust-building utility that belongs later in the product list than Bus Agentic
Development, Bus AI Platform, and Bus Books.

## Current Module Ownership

- `bus-top`
- `bus-status`

`bus-status` supports status/readiness style workflows and is currently grouped
with Bus Top in the public taxonomy, but the Bus Top page should focus on the
process monitor experience and cross-link status/readiness content only where
it helps the user.
