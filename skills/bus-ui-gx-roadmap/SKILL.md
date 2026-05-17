---
name: bus-ui-gx-roadmap
description: Use when planning, reviewing, documenting, or implementing the Bus GX and Bus UI roadmap, including docs/docs/ui feature candidates, semver promotion, bus-gx core work, bus-ui library work, and portal migration prerequisites.
---

# Bus UI GX Roadmap

Use this skill when working on `docs/docs/ui`, `bus-gx`, `bus-ui`, or portal UI
migration planning.

## Core Direction

GX is the Go equivalent of TSX/React for Bus frontends:

- `.gx` source compiles to ordinary `.go`
- templates are Go code with GX markup expressions
- components are ordinary Go functions or methods
- uppercase tags call imported/local Go components
- lowercase intrinsic tags follow safe HTML-like names
- callbacks use HTML/DOM and React-style Go names such as `onClick`,
  `onSubmit`, `onInput`, and `onChange`
- controller, state, data, effects, and resources are ordinary Go libraries,
  not YAML bindings or string event registries

Avoid legacy concepts: no required `<Template>` wrapper, no YAML-first template
trees, no component registration when normal Go imports and functions are
enough, no string event action formats when callback props are simpler.

## Module Layers

`bus-gx` owns the small generic foundation: render tree, source tooling,
compiler, intrinsic validation, callback representation, WASM mount/update, and
minimal browser adapters required by the foundation.

`bus-ui` is the Bus module for UI-related code, not one monolithic framework.
It can host multiple libraries: reusable form/button/table/panel primitives,
state/effect/resource helpers, terminal UI helpers, portal integration helpers,
and other shared UI packages. Keep product-specific behavior out of generic
framework packages.

## Feature Candidates

Unfinished UI docs live under `docs/docs/ui/fc-<id>-<identifier>/`. The number
is a stable identifier for links and review; it is not a linear queue. Process
multiple candidates in parallel when prerequisites, module ownership, and write
scopes are independent.

Promote a completed candidate to `docs/docs/ui/v0.X.Y/` when implementation,
tests, public docs, SDD docs, module docs, and version ordering are complete.
If promotion is blocked, record the concrete blocker in the owning `PLAN.md`.

Implemented version directories must be self-contained packages for that patch:
they may link to current or earlier versions, but not future candidates.

## Documentation Shape

Keep UI docs compact and concrete:

- each concept belongs on its own page
- each version or candidate `index.md` is only a link map
- examples are usually `.gx` or Go, not YAML or JSON unless documenting data,
  fixtures, or configuration
- public docs should not contain agent/process meta commentary
- link the first use of a framework term to the same version, same candidate,
  or latest earlier implemented page that defines it

## Patch Done Definition

For each implemented UI patch:

- code matches the accepted docs, or docs are corrected before implementation
- unit and e2e/browser/CLI tests cover the public contract
- `docs/docs/modules/{module}.md` shows the current implemented version
- `sdd/docs/modules/{module}.md` matches the implemented behavior
- module `PLAN.md` and `FEATURES.md` are updated according to that module's
  rules
- changed Go files receive deterministic checks first and `bus lint` as the
  final slow peer-review pass
