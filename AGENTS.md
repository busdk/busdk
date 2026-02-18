# AGENTS.md

Merged guidance from `.cursor/rules/*.mdc`.

## Scope And Precedence

1. Apply this file to the whole repository.
2. If instructions conflict, use this order:
   1. Repository identity and safety constraints.
   2. Definition of done and quality gates.
   3. Language and implementation conventions.
   4. Task-specific rules (README, commit workflow, test amplification).
3. Prefer minimal, deterministic, script-friendly behavior.

## Repository Identity (BusDK Superproject)

1. This repository is a superproject only for `busdk/busdk`.
2. Do not implement accounting logic or BusDK module source code here.
3. Keep BusDK modules as Git submodules at repository root (`bus`, `bus-*`).
4. Treat checked-in submodule commit SHAs as authoritative pins. Do not add lockfiles.
5. Keep orchestration in exactly one root `Makefile` using POSIX shell, `git`, and POSIX `make`.
6. Auto-discover modules from top-level directories:
   1. Include `bus` if present.
   2. Include directories matching `bus-*` if present.
   3. Only treat directories containing a `Makefile` as buildable.
   4. Use deterministic sorted order.
7. Delegate build/install/clean to module Makefiles via `make -C`; do not reimplement module internals.
8. Root Makefile contract:
   1. Default target prints concise help and key variables with example usage.
   2. Required targets: `init`, `update`, `upgrade`, `status`, `build`, `install`, `clean`, `distclean`, `bootstrap`.
   3. `bootstrap` runs `init`, `build`, `install` only.
9. Paths and variables:
   1. `BIN_DIR` defaults to `./bin`.
   2. `PREFIX ?= $(HOME)/.local`
   3. `BINDIR ?= $(PREFIX)/bin`
   4. Pass through `GO ?= go`, `GOFLAGS`, `CGO_ENABLED`.
10. Do not add alternative build systems, package-manager integrations, network features, or CLI binaries in this superproject.

## CLI Global Flag Standard (When Implementing `bus-*` CLI Modules)

Apply this section only when editing CLI module repositories or shared CLI parsing code.

1. Support global flags before subcommand; `--` terminates flag parsing.
2. Required semantics:
   1. `-h`, `--help`: immediate success exit (0), ignore others.
   2. `-V`, `--version`: immediate success exit (0), stable single-line output.
   3. `-v`, `--verbose`: accumulative verbosity (`-vv`, repeated `--verbose`).
   4. `-q`, `--quiet`: suppress non-error output; mutually exclusive with verbose (usage error exit 2).
   5. `-C`, `--chdir`: set effective working directory before file resolution.
   6. `-o`, `--output`: write normal output to file; with `--quiet`, write neither stdout nor output file.
   7. `-f`, `--format`: explicit supported formats, unknown format => usage error exit 2.
   8. `--color {auto|always|never}` and `--no-color` aliasing `never`.
3. Help/version behavior must be deterministic and concise.
4. Structured outputs go to stdout (or `--output`), diagnostics/human text to stderr.
5. Implement parsing as a small testable module returning parsed flags + remaining args.

## Definition Of Done

1. Follow TDD (failing test first or tight lockstep).
2. Every production change requires automated tests.
3. Regressions must get a reproducing and protecting test.
4. Coverage for changed code must not regress; changed lines/branches should be exercised.
5. Tests must be deterministic, isolated, and CI-repeatable.
6. Quality gates must pass: build, tests, formatting, linting/static checks, and security/secret checks.
7. Maintain backward compatibility unless a linked issue explicitly allows breaking change with migration path.
8. Update docs in same change set (README and operational/developer docs as needed).
9. If any required item is missing, work is not done.

## Go Language And Project Conventions (When Go Code Exists)

Apply this section when touching Go files.

1. Keep code idiomatic, modular, and cohesive.
2. Use clear package boundaries; minimize exported surface.
3. Add proper package comments and exported identifier doc comments.
4. Use explicit error handling with context wrapping; avoid panic for expected flow.
5. Manage resources safely (`defer` cleanup after acquisition).
6. Make concurrency ownership/lifetimes explicit; pass `context.Context` for cancelable work.
7. Refactor long functions into focused helpers with clear inputs/outputs.
8. Testing:
   1. Cover success, failures, and edge cases.
   2. Prefer table-driven tests/subtests where useful.
   3. Use fuzz tests/benchmarks for relevant risk or performance areas.
   4. Run with race detection where appropriate.
9. Layout guidance:
   1. Entrypoints: `cmd/<binary>/main.go`
   2. Internal reusable code: `internal/...`
   3. Public importable packages only in `pkg/` when intentionally external.
   4. Tests alongside code; fixtures in `testdata/`.

## Diverse Test Strategy (Risk-Based, Optional Amplification)

When test rigor needs expansion, prioritize:

1. Property-based tests for invariants and boundaries.
2. Metamorphic relations when direct oracle is hard.
3. Differential tests when a reference/alternate implementation exists.
4. Mutation-driven strengthening (or targeted reversible perturbation if no tool).
5. Go fuzzing with seeded corpus and promoted regressions.

Use these as effectiveness tools, not blind coverage gates. Keep tests readable and deterministic.

## README Refinement Standard

When updating `README.md`, ensure it serves as a high-signal project front page:

1. Clear title and concise value proposition.
2. Add only meaningful status badges when available.
3. Include TOC for longer READMEs.
4. Provide prerequisites, install, and quickstart usage with copyable commands.
5. Document key features, support path, contribution workflow, tests, credits, license, and project status.
6. Keep content current, concise, and executable; preserve valuable existing material.

For this superproject specifically, README must emphasize:

1. Purpose: pinning/orchestrating `bus` + `bus-*` submodules.
2. Common flows: `make bootstrap`, `make update`, maintainer `make upgrade`.
3. Output/install variables: `BIN_DIR`, `PREFIX`, `BINDIR`.

## Commit Workflow (When Asked To Commit)

1. Commit only staged changes.
2. If submodules have staged changes, commit them first (depth-first), then superproject.
3. Do not auto-stage files unless explicitly asked.
4. Use small, meaningful, imperative commit messages.
5. Never push, tag, or run remote synchronization as part of this workflow.

## Deletion Safety Rule

1. Never use any internal delete tool.
2. If path is tracked, use `git rm` (or `git rm --cached` to untrack but keep file).
3. If untracked, use `rm` (`-r`/`-f` only when necessary).
4. Use non-interactive deletion commands in scripts.
5. After deletion, update references/imports/scripts accordingly.
