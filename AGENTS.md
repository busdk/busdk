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
6. Global flag tests should verify at least: repeated verbosity (`-vv`, repeated `--verbose`), `--` passthrough, quiet/verbose conflict (exit 2), invalid color/format (exit 2), `-C` working-directory behavior, and `--output` write/truncate semantics.

## Definition Of Done

1. Follow TDD (failing test first or tight lockstep).
2. Every production change requires automated tests.
3. Every bug fix must include both:
   1. Unit test coverage for the defect path.
   2. End-to-end (e2e) coverage that reproduces the user-visible failure and protects the fix.
4. Regressions must get a reproducing and protecting test.
5. Coverage for changed code must not regress; changed lines/branches should be exercised.
6. Tests must be deterministic, isolated, and CI-repeatable.
7. Quality gates must pass: build, tests, formatting, linting/static checks, and security/secret checks.
8. Maintain backward compatibility unless a linked issue explicitly allows breaking change with migration path.
9. Update docs in same change set (README and operational/developer docs as needed).
10. If any required item is missing, work is not done.
11. Keep traceability: link implementation/tests/commits to the canonical issue URL when available.
12. Exceptions must be approved in the linked issue with explicit scope/risk and a concrete follow-up issue.
13. Always update end-to-end (e2e) tests to cover new features; new functionality is not done until e2e coverage is added.
14. Every user-visible behavior change (feature, bug fix, CLI/output/validation change, migration/replay behavior change) MUST include updated or new e2e coverage in the same change set.
15. If no existing e2e harness can cover the change, add one; do not mark work done without e2e unless the user explicitly approves a temporary exception.

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
10. Currency and money calculations must use decimal-safe arithmetic only (for example scaled integer cents or exact decimal/rational types). Do not use binary floating-point (`float32`/`float64`) for business money logic.

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
6. If hooks/checks reject a commit, report the failure and apply the minimal correction before retrying.
7. If staged scope is too broad, prefer splitting into smaller logical commits.

## Deletion Safety Rule

1. Never use any internal delete tool.
2. If path is tracked, use `git rm` (or `git rm --cached` to untrack but keep file).
3. If untracked, use `rm` (`-r`/`-f` only when necessary).
4. Use non-interactive deletion commands in scripts.
5. After deletion, update references/imports/scripts accordingly.
6. If a target path is already absent, treat it as a warning and continue.

## Context Memory Rule

1. When discussions establish durable project context, preferences, or workflow rules, write or refine `AGENTS.md` files to preserve them.
2. Add/update `AGENTS.md` in the most specific relevant directory (repository root or a context subdirectory) so guidance applies at the right scope.
3. Revisit and refine existing `AGENTS.md` files as context evolves, including this rule itself.
4. Standing permission: add these rules in any subdirectory within this BusDK super-project and its submodules when needed to preserve context-aware information.
5. Scope constraint: each context-specific `AGENTS.md` must contain only guidance relevant to that directory subtree.
6. Treat user-stated durable workflow preferences as persistent by default and record them in the most relevant `AGENTS.md` in the same change set.
7. Automatically update `AGENTS.md` files when the user provides new durable guidance or when you learn workflow rules that should be remembered.
8. Persist newly learned durable project context immediately: when important recurring constraints, preferences, or workflow decisions are discovered during work, record them in the most relevant `AGENTS.md` in the same change set.
9. Durable user workflow guidance MUST be written to the most relevant `AGENTS.md` in the same session when learned (do not defer memory updates).
10. Prefer working inside the target module directory (`./bus` or `./bus-*`) for module implementation and tests; use superproject-root commands only for explicit superproject tasks.
11. When the user provides `BUGS.Update.md` and/or `FEATURE_REQUESTS.Update.md`, merge their contents into canonical `BUGS.md` and `FEATURE_REQUESTS.md` in the same turn, then remove the update files.
12. Whenever `BUGS.Update.md` or `FEATURE_REQUESTS.Update.md` appears in the repository, automatically merge the contents into `BUGS.md` and/or `FEATURE_REQUESTS.md` and remove the update file(s) in the same turn.
13. For import/extract/replay data handling, prefer canonical BusDK/master-data keys. If input structure is non-canonical, require explicit user-defined/configured column mapping (for example profile/`--map`) rather than implicit assumptions.
14. For any cross-module data/path/key usage, resolve through the owning module’s Go library/API (path/key accessors) instead of hardcoding foreign module file names, keys, or locations.
15. Do not hardcode source-field/header alias mappings as long-term behavior. Mapping preferences must be project-level configurable (profiles/config files/flags), with deterministic validation diagnostics for missing/unknown/ambiguous mappings.
16. Schema data is a valid preferred place for mapping configuration when supported (for example schema-declared field mappings/metadata), as long as behavior remains deterministic and override order is documented.
17. When mentioning the `bus` GitHub repository in documentation or README text, inline-link to `https://github.com/busdk/bus`.

## Documentation Paths (All Modules)

1. Documentation site workspace root is `./docs`.
2. For any BusDK module repository name `{NAME}` (including `bus` and `bus-*`, for example `bus` or `bus-books`):
   1. Module SDD location is `./docs/docs/sdd/{NAME}/`.
   2. End-user module documentation location is `./docs/docs/modules/{NAME}/`.
3. When implementation changes alter behavior, update the corresponding docs in these locations in the same change set.
4. Do not defer documentation updates to a follow-up change; include doc updates in `./docs/docs` immediately with the behavior change.

## Gitignore Rule

1. The `.bus/` directory is a tracked project directory; never add `.bus` or `.bus/` ignore rules to `.gitignore` files in this superproject or its modules.
2. Runtime lock artifacts such as `.bus-dev.lock` may be ignored.
