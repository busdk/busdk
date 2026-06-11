# Bus GX/UI Library Marketing Brief

## Working Product Definition

Bus GX/UI Library is BusDK's product line for building Go-native frontend
interfaces with reusable components, deterministic rendering, and testable
runtime bridges.

The product combines two related layers:

- `bus-gx`: the low-level GX source format, compiler, render tree, browser
  runtime, and test utilities for writing TSX-like markup in Go projects.
- `bus-ui`: the reusable Bus UI component library, adapters, CSS hooks,
  mount/runtime helpers, portal integration surfaces, and test harnesses built
  on top of Go and GX.

The public story should not be "React cloned in Go." React and TSX are useful
role models, but the product should be positioned as a Go-first UI framework:
small typed units, explicit policy boundaries, generated Go, deterministic
HTML, and unit-testable components that fit naturally into BusDK services,
portals, agent workflows, and local-first product modules.

This is a developer and platform product line. It is for teams that want
frontend interfaces to be as inspectable, testable, and ownable as the rest of
their Go system.

## Short Positioning

We help Go-heavy product teams build reliable frontend interfaces by offering
TSX-like `.gx` authoring, compiled Go render roots, reusable UI components, and
shared runtime/test harnesses, unlike JavaScript-first frameworks or ad hoc Go
HTML builders, because Bus GX/UI keeps UI structure close to Go code while
preserving deterministic rendering, small component boundaries, and product
policy outside the shared library.

## Core Questions

### Goal

The immediate goal is qualified understanding and adoption among technical
builders, not broad consumer awareness.

Primary outcomes:

- A developer understands why BusDK has a Go-native UI layer.
- A Go-heavy team can evaluate GX as a practical way to write frontend roots.
- BusDK portal and app modules converge on shared reusable UI components.
- New BusDK products use shared UI primitives instead of local string builders.
- A technical evaluator can run examples, inspect generated Go, and trust the
  test story.
- Bus Agentic Development workers can implement UI slices safely because the
  components are small, typed, and covered by deterministic tests.

The product should support sales and adoption of larger BusDK product lines,
especially Bus Agentic Development, Bus AI Platform, Bus Books, and portal
applications. It can later become a standalone developer product if the
examples, docs, and external project story become strong enough.

### Audience

Primary audience:

- Go developers building product UIs, portals, dashboards, admin tools, and
  workflow applications.
- Platform engineers who want frontend code to follow the same ownership and
  test standards as backend Go services.
- Technical founders and small teams building local-first or self-hosted tools.
- BusDK contributors building module UIs across `bus-portal`, `bus-portal-*`,
  `bus-ui`, and AI-assisted workflows.
- AI-native engineering teams that want agents to safely modify UI components
  without losing architecture boundaries.

Secondary audience:

- Teams using React or TSX but wanting more Go-owned rendering and testing for
  specific app surfaces.
- Developers currently using Go templates, manual HTML builders, htmx-style
  server-rendered fragments, or ad hoc component helpers.

This is not primarily for non-technical marketers, pure frontend design teams,
or teams that require a full JavaScript ecosystem as the center of the product.

### Problem

Go product teams often face an awkward frontend tradeoff:

- JavaScript-first frameworks are powerful, but they can split product logic,
  testing, build tooling, and ownership away from the Go system.
- Go templates and manual string builders are simple, but component reuse,
  stateful behavior, test ergonomics, and UI consistency become difficult as
  the product grows.
- Shared UI libraries often mix presentation with product policy, making them
  hard to reuse across modules.
- AI workers can make UI changes quickly, but they need small, typed,
  reviewable boundaries to avoid breaking unrelated surfaces.
- Portal families need consistent shells, status surfaces, forms, lists,
  evidence panels, assistant workbenches, and runtime bridges without each
  module reinventing local helpers.

The underlying problem is not only "write HTML from Go." It is how to build
frontend product surfaces that are reusable, deterministic, testable, and still
feel natural in a Go codebase.

### Offer

Bus GX/UI Library offers:

- TSX-like `.gx` source files for authoring UI roots near Go code.
- A GX compiler that lowers markup into generated Go render functions.
- A small `gx.Node` render tree with deterministic HTML rendering.
- Browser-backed Go/WASM mounting for interactive GX roots.
- Test helpers for compiling GX source, rendering HTML, mounting roots,
  rerendering, dispatching actions, and checking resource handoff.
- Shared `bus-ui` components for shells, status surfaces, actions, forms,
  assistant UI, evidence views, portal host integration, records, tables,
  file drops, image galleries, terminal surfaces, and runtime effects.
- Compatibility adapters that preserve existing public Go APIs while moving
  eligible presentation roots to compiled GX.
- Stable CSS hooks and theme tokens for BusDK applications.
- A component catalog and artifact metadata validation for generated UI
  sources and fixtures.

The offer should emphasize practical developer workflows:

- Write typed Go components.
- Use `.gx` where markup improves readability.
- Keep validation, authorization, provider semantics, workflow policy, and
  secrets in owning modules.
- Render and test deterministic output.
- Share components across portal modules without copying product-specific
  behavior into the UI library.

### Value

The audience should care because Bus GX/UI makes Go product UI easier to build
and maintain:

- Less manual HTML assembly for reusable surfaces.
- More consistent UI across BusDK modules and downstream products.
- Smaller component units that are easier for humans and agents to review.
- Deterministic render output for unit tests and snapshot-style assertions.
- Better separation between shared presentation and product-owned policy.
- Fewer local render helpers duplicated across portal modules.
- A clearer migration path from existing Go APIs to compiled GX roots.
- A UI layer that can support local-first and self-hosted products without
  forcing a separate JavaScript application architecture for every surface.

The strongest value claim is engineering leverage: the UI stays typed,
inspectable, testable, and close to the Go system while gaining a more
expressive component authoring model.

### Differentiation

Against React and TSX:

- React is a mature JavaScript ecosystem.
- Bus GX/UI borrows the readability of TSX-style component authoring but keeps
  the implementation Go-first, generated, and deterministic.
- It is better suited when the product's state, validation, runtime contracts,
  and tests already live primarily in Go.

Against Go templates:

- Templates are useful for server-rendered pages.
- Bus GX/UI gives component authors typed props, Go functions, generated code,
  and a shared render/test model instead of template strings.

Against manual HTML builders:

- Builders can be explicit, but large UI surfaces become hard to scan and hard
  to reuse.
- GX keeps markup structure readable while still compiling to Go.

Against generic design systems:

- Many design systems only provide visual components.
- Bus GX/UI also defines runtime bridges, action/resource handoff tests,
  portal host integration, artifact metadata, and ownership boundaries.

Against no-code or low-code builders:

- Bus GX/UI is code-first and review-first.
- It is designed for serious product code, not for hiding implementation from
  developers.

### Proof

Current proof should be concrete and implementation-backed:

- `bus-gx` can parse, lint, compile, and render GX source into Go.
- `bus-gx` has deterministic HTML rendering and intrinsic element validation.
- `bus-gx` has browser-backed Go/WASM mount and update tests.
- `bus-ui` has reusable checked components with public Go APIs and CSS hooks.
- `bus-ui` has `MountedApp` and `uikittest` harnesses for rerender, action,
  resource, and lifecycle proof.
- Shared status roots such as `StatusPillChecked`, `EmptyStateChecked`, and
  `LoadingStateChecked` now route through compiled GX while preserving
  compatibility APIs.
- `bus-portal-ai` has mounted GX/runtime test evidence for compiled roots and
  provider-bounded action/resource handoff.
- Product modules already use `bus-ui` primitives for assistant, terminal,
  status, evidence, portal, and form-related surfaces.

Evidence to collect next:

- A clean end-to-end demo from `.gx` source to generated Go to rendered portal
  UI.
- Before/after examples replacing string builders with compiled GX roots.
- Component catalog screenshots or rendered examples.
- Test output proving rerender, action dispatch, and resource boundaries.
- A short case study from the portal-family migration.
- Quantitative metrics such as duplicated helper reduction, number of shared
  components adopted, and modules using compiled GX roots.

### Objections

Likely objections and how the message should answer them:

- "Why not just use React?"
  Use React when a JavaScript-first frontend is the right center of gravity.
  Bus GX/UI is for Go-first products that need typed Go ownership,
  deterministic rendering, and tight integration with Go services and tests.

- "Is this a full React clone?"
  No. React is a role model for component authoring, not the implementation
  contract. Bus GX/UI should remain Go-like and avoid copying concepts that do
  not fit Go.

- "Will this lock us into BusDK?"
  The strongest near-term story is BusDK-native. A standalone story is possible
  if public examples, docs, and package boundaries become strong enough.

- "Is it mature?"
  Position it as active, proven inside BusDK, and still growing. Do not claim
  broad ecosystem maturity before external adoption exists.

- "Can designers use it directly?"
  Not as a no-code design surface. It is for developer-owned UI components,
  though stable CSS hooks and examples can help design collaboration.

- "Does it own product policy?"
  No. Shared components should render and validate generic UI contracts.
  Authorization, provider behavior, route ownership, workflow semantics, and
  secrets stay in owning modules.

### Tone

The tone should be technical, clear, and confident. It should feel:

- Go-native
- Practical
- Serious
- Inspectable
- Developer-friendly
- Calm rather than hype-driven
- Precise about what is proven and what is still emerging

Avoid vague "beautiful UI in seconds" claims. The better promise is durable UI
engineering: readable components, deterministic output, and reusable product
surfaces that can survive real maintenance.

### Channels

Best early channels:

- BusDK product page for Bus GX/UI Library.
- Developer documentation and README pages for `bus-gx` and `bus-ui`.
- A focused launch article about Go-native TSX-style UI.
- Code examples showing `.gx` source, generated Go, rendered HTML, and tests.
- Bus Agentic Development demos where workers safely refactor UI surfaces.
- Portal-family migration notes showing shared component adoption.
- Conference or blog content for Go developers interested in frontend
  architecture.

Lower-priority channels until the product is more externalized:

- Paid ads.
- Broad social campaigns.
- Non-technical sales collateral.

### Call To Action

Primary CTAs:

- Read the GX quickstart.
- Build and render a first `.gx` component.
- Inspect generated Go.
- Run the component tests.
- Browse the `bus-ui` component catalog.
- Try a portal module that uses compiled GX roots.

For commercial or serious evaluation:

- Book a technical demo.
- Start a BusDK UI migration pilot.
- Evaluate Bus GX/UI for one Go product surface.

### Success Metrics

Near-term product metrics:

- Number of BusDK modules using compiled GX roots.
- Number of reusable `bus-ui` components adopted across modules.
- Reduction in duplicated Go/uikit render helpers.
- Percentage of eligible UI surfaces covered by deterministic tests.
- Successful quickstart completion for `.gx` compile/render/test flow.
- Number of examples that demonstrate source, generated Go, render output, and
  runtime tests.

Marketing and adoption metrics:

- Product page visits.
- Quickstart starts and completions.
- GitHub stars, forks, or issue engagement for `bus-gx`/`bus-ui`.
- Demo requests from Go-heavy teams.
- External projects attempting a GX component.
- Conversion from BusDK product evaluators into UI library users.

Internal quality metrics:

- Worker success rate on UI refactor slices.
- Review reopen rate for GX/UI component work.
- Test coverage for compiled roots and runtime bridges.
- Number of remaining module-local render helpers after each migration cycle.

## Simple Marketing Brief

We help **Go-heavy product teams and BusDK module authors** solve **the problem
of building reusable, testable frontend surfaces without splitting ownership
away from Go** by offering **Bus GX/UI Library: TSX-like `.gx` authoring,
compiled Go render roots, reusable UI components, runtime bridges, and
deterministic test harnesses**, unlike **JavaScript-first frameworks, Go
templates, or ad hoc HTML builders**, because **Bus GX/UI keeps UI components
typed, inspectable, generated, and policy-free while already powering BusDK
portal and assistant surfaces**. The goal is **qualified developer adoption and
shared component convergence** through **docs, examples, product pages,
quickstarts, and BusDK portal migration proof**.

## Positioning Ideas To Discuss

### Preferred Product Name

Use **Bus GX/UI Library** for now. It clearly includes both layers:

- GX as the source/runtime/compiler layer.
- UI as the reusable component and product-surface layer.

If a shorter public name is needed, use **Bus UI** for the component library
and **Bus GX** for the compiler/runtime. Avoid collapsing everything into
"Bus React" or "Go React"; those names imply the wrong contract.

### Primary Headline Options

- Go-native UI components with TSX-like authoring.
- A Go-first UI framework for BusDK products.
- TSX-style frontend components, compiled to Go.
- Reusable, testable UI surfaces for Go-heavy products.
- UI infrastructure for agent-built Go software.

The strongest headline is probably:

> Go-native UI components with TSX-like authoring.

It is specific, understandable, and avoids overclaiming maturity.

### Message Pillars

1. Go-first authoring and ownership.
2. Reusable component families across real BusDK modules.
3. Deterministic rendering and tests.
4. Clear boundary between shared UI and product policy.
5. Agent-friendly component size and reviewability.

### Best Demo Narrative

The best demo should be concrete:

1. Start with a manual Go render helper.
2. Show the equivalent `.gx` component.
3. Compile it to generated Go.
4. Render deterministic HTML in a unit test.
5. Mount it through a Bus UI runtime harness.
6. Reuse the component in two portal modules without moving product policy into
   `bus-ui`.

That story explains the product better than abstract framework claims.

## Open Questions

- Which audience should lead the public page: Go developers generally, BusDK
  product evaluators, or AI-native engineering teams?
- Should the first CTA be a standalone GX quickstart or a BusDK portal UI demo?
- What proof do we want before making this a headline product line rather than
  a supporting developer platform?
- How much should the page mention React and TSX directly?
- Should the product promise include browser interactivity now, or emphasize
  deterministic rendering and component migration first?
- What is the smallest external example that proves Bus GX/UI outside BusDK
  without creating a maintenance burden?

## Product Boundary

Bus GX/UI Library should own:

- GX source syntax, linting, compilation, render tree, HTML rendering, and
  browser runtime primitives.
- Reusable UI component families.
- Stable CSS hooks and theme tokens.
- Generic runtime, action, resource, and mount test harnesses.
- Compatibility adapters from existing public Go APIs to compiled GX roots.
- Component catalog and UI artifact metadata.

Bus GX/UI Library should not own:

- Product routes.
- Authorization and credential policy.
- Provider-specific workflow semantics.
- Business object meaning.
- Billing or usage policy.
- Secret storage.
- Raw model/provider execution behavior.
- Broad JavaScript ecosystem replacement claims.

Keeping this boundary clear is central to the product: the shared UI library
should make product modules easier to build without absorbing their policy.
