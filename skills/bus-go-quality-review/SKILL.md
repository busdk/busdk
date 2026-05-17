---
name: bus-go-quality-review
description: Use when implementing or reviewing Go code in BusDK modules, including test planning, module quality gates, e2e expectations, and final AI-backed bus lint peer review for changed Go files.
---

# Bus Go Quality Review

Use this skill for Go implementation and review work.

## Fast Gates First

Run deterministic checks before AI-backed review:

- `gofmt` or module `make fmt`
- focused `go test` packages while iterating
- module `make test`, `make test-e2e` or `make e2e`, and `make check` when
  available
- `go vet`, `bus dev quality lint`, or module `make lint` when available
- final root-level `make test` and `make e2e` from the superproject before
  reporting completion, unless the operator explicitly scopes the work narrower
- `git diff --check`

After deterministic checks pass, run the slower AI peer review on newly written
or substantially changed Go files:

```bash
bus lint path/to/file.go
```

Use `bus lint` as a final QA pass, not as the first feedback loop.

## Required Coverage

Production changes require automated tests. Bug fixes require both a unit test
for the defect path and an e2e test for the user-visible failure. New
user-visible CLI, API, validation, migration, replay, or browser behavior also
needs e2e coverage unless the operator explicitly approves an exception.

If a Makefile target is stale or a no-op, run the underlying `go test`, build,
or e2e command directly for that module.

## Review Focus

Review findings should lead with bugs, regressions, missing tests, security or
privacy risks, and product-boundary violations. Summaries are secondary.

Check that module layering is correct. A well-tested patch is still wrong if it
duplicates persistence, business workflow, or product behavior that belongs in a
different Bus module.

## Go Conventions

Keep packages cohesive, exported surfaces small, and errors contextual. Avoid
panic for expected flow. Use `context.Context` for cancelable work, make
resource lifetimes explicit, and add useful package/exported comments.

For fixed string output to stdout-style writers, prefer `io.WriteString` or a
direct writer method over `fmt.Fprint*`.

Update CLI `--help`, OpenCLI/help metadata, README, public docs, and SDD docs in
the same release flow when behavior changes.
