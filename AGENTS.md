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
   1. Module-local build outputs use literal `./bin` paths (no `BIN_DIR` variable).
   2. `PREFIX ?= $(HOME)/.local`
   3. `BINDIR ?= $(PREFIX)/bin`
   4. Support `DESTDIR ?=` for staged installs; install/uninstall paths use `$(DESTDIR)$(BINDIR)`.
   5. Module Makefiles must provide `test-docker` using a standard per-module `Dockerfile` and `docker run` with the parent directory mounted at `/workspace`.
   6. Pass through `GO ?= go`, `GOFLAGS`, `CGO_ENABLED`.
10. Do not add alternative build systems, package-manager integrations, network features, or CLI binaries in this superproject.
11. Repository visibility boundary:
   1. Public/open-source repos: `./` (superproject), `./bus`, `./docs`, `./busdk.com`.
   2. Private/commercial-customer repos: every `./bus-*` module.
   3. In public repos, do not introduce in-process coupling to private module internals; use stable CLI/library boundaries only.

## Module Operational Conventions (All `bus` and `bus-*` Modules)

1. Module CLIs must be non-interactive and script-friendly; missing required arguments or flags must return a concise usage error and exit 2.
2. Command results go to stdout (or `--output`); diagnostics, warnings, and errors go to stderr; help/version go to stdout.
3. Avoid network and Git operations in module code and tests unless a module spec explicitly requires them.
4. When a module provides a Makefile, use its targets (`build`, `test`, `fmt`, `lint`, `check`, `test-e2e` as applicable) as the standard interface; tests must be hermetic and deterministic.

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
8. After any code change, always run automated tests before reporting completion; if a module `make` target is a no-op or stale, run the underlying test/build commands directly for that module.
8.1. During development, first run the affected module's unit/e2e tests for fast iteration and debugging.
8.2. Because cross-module dependency effects are common in this superproject, the final verification step before reporting completion must still be the full superproject `make test` and `make e2e`.
8.3. Module-local unit/e2e runs are required for fast feedback during debugging, but they do not replace the required final root-level `make test` and `make e2e`.
9. Maintain backward compatibility unless a linked issue explicitly allows breaking change with migration path.
10. Update docs in same change set (README and operational/developer docs as needed).
11. If any required item is missing, work is not done.
12. Keep traceability: link implementation/tests/commits to the canonical issue URL when available.
13. Exceptions must be approved in the linked issue with explicit scope/risk and a concrete follow-up issue.
14. Always update end-to-end (e2e) tests to cover new features; new functionality is not done until e2e coverage is added.
15. Every user-visible behavior change (feature, bug fix, CLI/output/validation change, migration/replay behavior change) MUST include updated or new e2e coverage in the same change set.
16. If no existing e2e harness can cover the change, add one; do not mark work done without e2e unless the user explicitly approves a temporary exception.

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

Core principle for AGENTS memory updates: avoid repeating mistakes. Learn from this session’s errors and from prior observed errors, and codify preventive guidance immediately in the most relevant `AGENTS.md` so the same failure mode does not recur.

1. When discussions establish durable project context, preferences, or workflow rules, write or refine `AGENTS.md` files to preserve them.
2. Add/update `AGENTS.md` in the most specific relevant directory (repository root or a context subdirectory) so guidance applies at the right scope.
3. Revisit and refine existing `AGENTS.md` files as context evolves, including this rule itself.
4. Standing permission: add these rules in any subdirectory within this BusDK super-project and its submodules when needed to preserve context-aware information.
5. Scope constraint: each context-specific `AGENTS.md` must contain only guidance relevant to that directory subtree.
6. Treat user-stated durable workflow preferences as persistent by default and record them in the most relevant `AGENTS.md` in the same change set.
7. Automatically update `AGENTS.md` files when the user provides new durable guidance or when you learn workflow rules that should be remembered.
8. Persist newly learned durable project context immediately: when important recurring constraints, preferences, or workflow decisions are discovered during work, record them in the most relevant `AGENTS.md` in the same change set.
9. Durable user workflow guidance MUST be written to the most relevant `AGENTS.md` in the same session when learned (do not defer memory updates).
10. When a **system-level** CLI command fails due to incorrect parameters (for example `rg`, `sed`, `cat`, `find`, `git`, `make`), record the correct invocation or constraint in the most relevant `AGENTS.md` so the mistake is not repeated. Do not add rules for project-specific commands under active development.
11. On macOS/BSD `cat`, `-A` is unsupported; use `cat -vet` or `sed -n 'l'` to visualize tabs and line endings instead.
12. On macOS/BSD `awk`, avoid using `in` as a variable name (`in` is reserved in `for (x in y)`); use names like `inside` instead.
13. On macOS/BSD `awk`, avoid slash-delimited regex fragments that try to carry `/` inside a character class in embedded scripts (for example `[^/]` in `... /.../ ...` within shell/Make recipes); prefer `index(...)`/`split(...)` or another BSD-safe formulation.
14. When `printf` needs to print a format string that starts with `-`, use `printf -- '...'` so the format is not parsed as an option.
15. When running shell commands that contain backticks in regex/pattern arguments (for example with `rg`), wrap the full command in single quotes or escape backticks to avoid command-substitution parse errors.
16. `rg` does not support look-around by default; use `rg --pcre2` when patterns require look-ahead/look-behind.
17. Use `python3` (not `python`) for Python scripting in this environment.
12. Feature request implementation order is user-defined and must be followed unless explicitly revised: FR65, FR66, FR59, FR58, FR46, FR63.
10. Prefer working inside the target module directory (`./bus` or `./bus-*`) for module implementation and tests; use superproject-root commands only for explicit superproject tasks.
11. When the user provides `*.Update.md` tracker files (including `BUGS.Update.md` and `FEATURE_REQUESTS.Update.md`), merge their contents into the corresponding canonical tracker files in the same turn, then remove the update files.
12. Whenever `*.Update.md` tracker files appear in the repository, automatically process them into their canonical tracker files and remove the update file(s) in the same turn.
13. For import/extract/replay data handling, prefer canonical BusDK/master-data keys. If input structure is non-canonical, require explicit user-defined/configured column mapping (for example profile/`--map`) rather than implicit assumptions.
14. For any cross-module data/path/key usage, resolve through the owning module’s Go library/API (path/key accessors) instead of hardcoding foreign module file names, keys, or locations.
15. Do not hardcode source-field/header alias mappings as long-term behavior. Mapping preferences must be project-level configurable (profiles/config files/flags), with deterministic validation diagnostics for missing/unknown/ambiguous mappings.
16. Schema data is a valid preferred place for mapping configuration when supported (for example schema-declared field mappings/metadata), as long as behavior remains deterministic and override order is documented.
17. When mentioning the `bus` GitHub repository in documentation or README text, inline-link to `https://github.com/busdk/bus`.
18. For bug-fix work, prefer adding multiple related regression tests (unit/e2e) beyond the minimal reproducer whenever nearby behavior coverage is thin, to reduce recurrence risk.
19. Do not add persistent workspace configuration for previous-year or cross-workspace inputs. If a tool needs external prior-year data, require it explicitly on the command line for that invocation; prefer dedicated commands that derive and print reusable Bus commands or carry-forward artifacts instead of hidden cross-workspace config.
20. When active entries exist in `FEATURE_REQUESTS.md`, refine them into concrete module execution checklists in the corresponding `bus-{NAME}/PLAN.md` files in the same turn, including explicit unit-test, e2e-test, and docs update work items.
21. When writing or refining task plans (for example `PLAN.md`), each task MUST be end-to-end and self-contained: include implementation, documentation updates, unit tests, and e2e tests in the same task; do not split these across separate tasks.
22. When `go.mod` dependencies or local `replace` directives change in a module, update that module's `Makefile.local` `MODULE_BIN_DEPS` in the same change set so it stays aligned with `go.mod`.
23. Always process `BUGS.Update.md` first when it exists: merge its content into canonical `BUGS.md`, remove `BUGS.Update.md`, and only then start fixing or verifying active bugs from `BUGS.md`.
24. Treat every new bug report as a new triage item even if it appears to match a previously fixed issue; deterministically re-verify both the original bug path and the new reported path before concluding fixed.
25. When a bug report includes explicit repro instructions or a shell repro script, do not close or downgrade the bug based only on code inspection or nearby tests; rerun the provided repro steps as written (or the closest deterministic equivalent if paths need sanitization) before deciding whether the bug is still active.
26. If multiple active bug reports exist in `BUGS.md` or `BUGS.Update.md` and the user refers in singular form to “the bug report” or says to fix “it” without uniquely identifying which bug, stop and ask a concise clarification question before implementing. Do not guess which active bug they meant. Include a short summary of the active bug options in the clarification so the user can choose explicitly.
27. When processing `BUGS.Update.md` or `FEATURE_REQUESTS.Update.md`, do not assume every listed item is new. Re-verify whether each item is already handled, stale, duplicated, or superseded before copying it into canonical trackers, and keep only still-relevant active items.
28. For user-facing CLI naming, keep command-to-module mapping direct and simple (for example `bus plan` -> `bus-plan`); avoid alias-heavy indirection.
29. For private backend architectures, keep CLI modules as thin clients that call backend APIs/services; avoid embedding monolithic backend business logic into CLI binaries.
30. Any module-specific guidance must live in the module’s own `AGENTS.md` (for example `bus-foo/AGENTS.md`); do not add or keep module-specific rules in this superproject `AGENTS.md`.
31. For any work in a module or subdirectory, always check and follow the most specific local `AGENTS.md` in that subtree in addition to this root file.
32. Apply mistake-learning rigor to memory updates: if a command, workflow, or reasoning pattern fails, add a concise preventive rule so future runs use a corrected approach by default.
33. Prefer learning from existing guidance and prior failures in this repository before trial-and-error; do not repeat an already documented failed approach.
34. When searching `rg` patterns that begin with `-` (for example `--dim`), always use `-e` for each pattern (`rg -e "--dim" ...`) so patterns are not parsed as flags.
35. When using `perl -pi -e 's#...#...#g'`, do not use `#` as the delimiter if either pattern contains `#`; choose another delimiter (for example `|`) or escape literal `#` characters.
36. When running shell commands with `rg --pcre2` patterns that include quotes or look-arounds, wrap the full command in single quotes to avoid bash quote-termination errors.
37. When running `git -C <subrepo> ...`, keep pathspecs relative to that subrepo root (for example `git -C docs diff -- PLAN.md`), and do not use `../` pathspecs that point outside the repository.
38. Before reading optional module docs/inventory files with `sed`/`cat` (for example `FEATURES.md`), verify existence with `ls` or `rg --files` in that module; do not assume every module has the same top-level files.
39. When searching for text that includes backticks using `rg`, pass the pattern with `-e` and single-quote the full command to avoid shell command-substitution errors.
40. When searching literal placeholder text with `rg` that contains `{` or `}` (for example `V-{inc}`), use `rg -F` or escape the braces; otherwise default regex parsing treats them as quantifiers and fails.
41. `rg` does not accept a literal `\n` escape in normal regex mode; when a search needs newline-aware matching, use `-U`/`--multiline` (and `--multiline-dotall` if needed) or split the search into separate patterns instead of passing `\n` literally.
42. When a refactor changes canonical data modeling or report semantics, and it is unclear whether a concept should be represented as user-configured data versus synthesized in code, stop and ask the user to define that boundary before implementing. Do not guess domain structure for accounting/reporting hierarchies.
43. Module e2e wrappers must stay quiet on success except for summary lines, but they must print any `SKIP ...` lines from the captured log before the success line and include summary counts in the form `e2e OK (module: passed X, skipped Y)` or `e2e FAILED (module: passed X, skipped Y, failed Z)`; multi-script e2e harnesses must print explicit `RUN`, `PASS`, and `FAIL` lines per internal script so the failing inner test is visible immediately.
44. Do not hand-edit Frictionless Data table files or schema files through raw CSV/JSON string assembly in production code when shared storage/schema APIs exist. For owned datasets, use the owning module library or the shared `bus-data` storage-aware read/init/mutate/write APIs so logical fields, `_pad`, `PCSV-1`, and schema metadata stay consistent.
45. If a command or test process is terminated unexpectedly with signals such as `Killed: 9` / exit 137 and the cause is not obvious from stdout/stderr, stop and ask the user to check whether F-Secure event logs show the process being blocked before continuing root-cause analysis; do not assume a product-code bug first.
46. Performance timing output for Bus CLI commands must use plain tokenized lines, not key-value envelopes: `<LEVEL> perf <module> <op> <duration_s>` (for example `INFO perf bus-reports trial-balance 0.123`).
47. Prefer reusable, approval-friendly commands over ad hoc shell scripts: use the repository or module standard interfaces first (for example `make test`, `make e2e`, `make check`, `go test ./...` in a module) instead of long `bash -lc`, pipelines, temporary trace files, or chained command recipes.
48. When a standard Makefile target exists for the needed action, use that target as the default command surface before falling back to lower-level or custom shell commands.
49. Keep commands simple and repeatable so they can be safely re-run by humans and approval rules can match them; avoid one-off compound shell invocations unless no reusable interface exists.
50. When an e2e suite depends on an external environment capability (for example loopback TCP bind), probe that capability once in the suite runner and emit explicit `SKIP <test>: <reason>` lines for affected cases instead of failing them generically when the environment forbids the capability.
51. When using `rg --files` with path globs, pass each glob via `-g` (for example `rg --files -g 'bus*/AGENTS.md'`); do not pass the glob as a positional path argument.
52. Each module-specific `AGENTS.md` must stand on its own for agents working in an independently checked out module; copy any generally needed operational guidance into the module file instead of assuming this root `AGENTS.md` is available.
53. When running commands from inside a module directory, use module-relative paths by default (for example `gofmt -w internal/app/run.go`), not superproject-prefixed paths.
54. Module e2e scripts should be quiet by default: successful runs print only a short stable success line, and detailed shell tracing is enabled only with `BUS_E2E_VERBOSE=1`.
55. Module `test-e2e` Makefile targets should capture script output and print it only on failure; do not stream verbose e2e logs during successful runs by default.
56. For date-bounded Git history inspection, use `git log --since=... --until=...` (optionally with `--stat` or `--name-only`). Do not try to pass date strings as a revision range to `git show`; `git show` expects commit-ish arguments, not calendar boundaries.
57. ACP-related `bus-agent` extraction/integration tasks are low priority by default; do not pick them up unless the user explicitly asks for low-priority work or they are required to unblock higher-priority work.
58. For bug-fix work, prefer converting manual repro steps into module unit tests and/or e2e tests, then verify through the module's standard test interface (for example `make test`, `make e2e`, `make check`) instead of relying on ad hoc shell repro commands as the primary proof.
59. For performance optimization work, first add investigation-oriented `PLAN.md` items that use Go profiling/benchmark tools to measure allocations, I/O, and other root causes in the current code path; do not jump straight to new batching/tooling designs before the measured root cause is documented. New helper tools or architectural changes may be proposed only after benchmark/profile evidence shows simpler fixes are insufficient.
60. Treat locale as part of the test matrix for all user-facing text/HTML/report/browser paths. Tests must either pin locale explicitly or be written locale-tolerant by default; do not rely on the developer shell locale implicitly.
61. When a user reports a test failure that does not reproduce locally, first compare locale/environment-sensitive inputs (for example `LANG`, `LC_*`, browser runtime) before assuming the failure is flaky or non-reproducible.
62. For affected user-facing modules, debug runs should include at least one alternate locale execution (for example `LANG=fi_FI.UTF-8` with mixed `LC_*`) before declaring a test green across environments.
63. Root `make test` and `make e2e` should default to changed-module scope, not a whole-repository sweep; use `TEST_SCOPE=all` only when a full cross-module run is explicitly desired.
64. When using `rg` from the superproject root, do not include nonexistent generic paths like `internal` as positional search roots; target the actual module directories explicitly.
65. Before starting any new user-requested feature or behavior change, or immediately when noticing work is already in progress, first add or update the corresponding `PLAN.md` and/or `BUGS.md` and/or `FEATURE_REQUESTS.md` entries in the same turn so in-progress work always leaves a canonical repository trace.
66. Do not run `make install`, `go install`, or other user-environment install steps on the user's behalf unless they explicitly ask for that exact installation action. Tell the user what install command to run instead.
67. Before making any historical claim about what changed on a given date, verify
    the actual Git diff first. Do not infer behavior from commit subjects,
    repository creation dates, or assumptions about what "must have" happened.
67. Historical verification process:
    1. locate the exact date window with `git log --since=... --until=...`
    2. inspect the concrete file changes with `git log --stat`, `git show`, or both
    3. if the claim concerns code behavior, open the introduced/changed source,
       tests, docs, or help text and confirm the behavior really existed then
    4. only after that make the historical statement in plans, docs, blog copy,
       or user-facing summaries
68. Treat repo initialization, docs-only changes, pin bumps, and scaffolding as
    separate from feature delivery unless the diff shows a real user-visible
    capability, command surface, workflow, or documentation milestone.

## Documentation Paths (All Modules)

1. Documentation surfaces are split by audience:
   1. `./busdk.com/docs/` is for commercial/product landing and product-audience messaging.
   2. `./docs/docs/` is for end-user documentation about how to use BusDK software.
   3. `./sdd/docs/` is for implementation/developer software design documentation (private by default).
2. When editing files under any of these trees, follow the most specific local `AGENTS.md` (`./busdk.com/AGENTS.md`, `./docs/AGENTS.md`, `./sdd/AGENTS.md`) in addition to this root file.
3. For any BusDK module `{NAME}` (for example `bus` or `bus-books`):
   1. End-user module documentation location is `./docs/docs/modules/{NAME}.md`.
   2. Module implementation SDD location is `./sdd/docs/modules/{NAME}.md`.
4. The same topic may exist in both `./docs/docs` and `./sdd/docs`, but each version must be refined for its audience (end-user vs implementer/developer) without losing core information.
5. When implementation changes alter behavior, update the corresponding end-user and SDD documents in the same change set.
6. Do not defer documentation updates to a follow-up change.
7. End-user docs readability DoD: prefer short paragraphs, avoid repeated wording, and keep pages task-oriented.
8. End-user docs style rule: avoid bullet lists by default; use paragraphs unless a list/table is the only clear way to present structured data.

## Gitignore Rule

1. The `.bus/` directory is a tracked project directory; never add `.bus` or `.bus/` ignore rules to `.gitignore` files in this superproject or its modules.
2. In private repositories, `.bus/` must be tracked; `.bus/secrets` may be tracked in private repositories only and must not be tracked otherwise.
3. Runtime lock artifacts such as `.bus-dev.lock` may be ignored.
4. Do not treat `.bus/`, `Makefile.local`, or `./tests` as temporary files; they are tracked by default unless a repository explicitly documents an exception.
5. Never add `FEATURES.md` to `.gitignore` in any module. If `FEATURES.md` exists in a module's git history, restore and keep it tracked.

## Global unit documentation traceability rule

- Every top-level production-code unit (`func`, `type`, `var`, and `const` blocks when they define global API/behavior) must include an inline comment that states its purpose.
- For each top-level global unit, also include concise `Used by:` traceability in the inline comment (or immediately adjacent comment) that names the primary caller(s), owning flow, or integration point.
- Keep `Used by:` comments accurate when refactoring: update or remove stale references in the same change set.
- Do not add new undocumented top-level global units.

## PLAN granularity and memory rule

- `PLAN.md` checkboxes must be executable in one end-to-end implementation pass: implementation + tests + docs in the same item.
- When the user gives new instructions or changes scope, immediately add or update a local internal `PLAN.md` checklist for the affected repository/subtree before continuing substantial work.
- Keep unfinished earlier work visible in that `PLAN.md` instead of dropping it implicitly; finish the current highest-priority item first and queue only the necessary additional items behind it.
- If work naturally must be done together in one pass, model it as one checklist item (do not split coupled work into multiple checkboxes).
- When users provide durable workflow preferences (for example planning granularity/process constraints), record them in the most relevant `AGENTS.md` in the same session.
- When adding or refining a module `PLAN.md` for a new user-requested feature, also add or update the corresponding canonical entry in `FEATURE_REQUESTS.md` in the same turn unless the user explicitly says not to.
- Any unchecked feature-oriented item in a module plan (including `bus/PLAN.md` and `bus-*/PLAN.md`) must have a corresponding mention in `FEATURE_REQUESTS.md`; when auditing or adding plan items, fix missing canonical mentions in the same turn.
- In this repository, do not estimate calendar time, engineer-days, or duration as the default planning output. When users ask how big a job is, answer with scope, dependencies, risks, sequencing, and optional phase breakdowns instead of time forecasts unless the user explicitly requires a time estimate.
- Always treat active `BUGS.md` work as higher priority than `PLAN.md` or feature work: verify and fix unresolved bugs before continuing open plan items unless the user explicitly reprioritizes.
- When the user sets the DoD for plan execution to leaving no plan work undone, continue consuming relevant open `PLAN.md` items sequentially and do not report the plan effort complete while those open items remain.
- Whenever a `FIXME(refactor)` comment is added in code, add/update a corresponding `PLAN.md` item that references the owning file path in the same change set.
- If an owning file already has a completed (`[x]`) refactor item in `PLAN.md`, adding a new `FIXME(refactor)` must reopen planning by adding a new open (`[ ]`) item for that same file path in the same change set.
- Before completion, ensure active `FIXME(refactor)` comments and open `PLAN.md` items are in sync for the touched module.
- Changes to canonical planning/tracking files must leave a durable git trace, but tracker commits are the only autonomous commits allowed by default: whenever you add, reopen, complete, remove, or otherwise change entries in `PLAN.md`, `BUGS.md`, or `FEATURE_REQUESTS.md`, commit only those tracker-file changes and do not include implementation/docs/test changes in the same autonomous commit.
- Do not make autonomous commits for non-tracker work unless the user explicitly asks for commits.
- When tracker files change in the same turn as implementation/docs/test files, leave the non-tracker changes uncommitted for the user's own commit workflow; only the tracker-only commit may be created automatically.
- When removing tracked inbox/update files that may already have staged changes, prefer `git rm -f <file>`; plain `git rm` can fail with "file has changes staged in the index".
- For tracker-only commits, prefer `scripts/commit-tracker-only.sh <repo-path> <message> <tracker-file>...` so the commit uses `git commit --only -- ...` and cannot accidentally include other staged files from that repository; `scripts/commit-plan-only.sh` remains only as a compatibility wrapper for `PLAN.md`.
- For user-facing CLI tokens and flag values, accept both hyphenated and underscore-separated spellings when they represent the same canonical concept and no ambiguity is introduced. Keep one canonical internal/stored form, but do not force operators to guess whether Bus expects `-` or `_`. The same rule applies to other shorthand or alternate invocation forms: accept them only when normalization is deterministic and exact; if input could mean multiple things, fail with a usage error instead of guessing.
- Before changing user-facing CLI `--help` text, define or follow the shared help-style contract under `sdd/docs/cli/`. Do not expand help ad hoc into dense prose; prefer syntax-first, structured help modeled on common system tools such as `git -h`, `git add -h`, `tar --help`, and similar command surfaces.
- When improving BusDK help output, do not use older Bus help text as the style reference. Compare against common operating-system and Git help surfaces first, then apply the shared `sdd/docs/cli/help-output-contract.md` rules.
- Do not install software or module binaries into the user's personal paths on their behalf. When PATH or dispatcher verification depends on a fresh installed binary, ask the user to run the relevant `make install` themselves and then continue verification against that installed binary.
- For temporary historical verification work such as `git worktree` checkouts, prefer the repository-root `./tmp/` directory over system `/tmp` so scratch state stays inside the workspace and can usually be used without extra permission prompts.

## Refactor planning style rule

- For code-specific refactoring work, put concrete technical refactor details in
  inline `FIXME(refactor)` comments at the source location.
- Keep `PLAN.md` entries for refactors file-oriented and concise, referencing the
  file path(s) that contain the authoritative `FIXME(refactor)` notes.
- Do not duplicate long technical refactor instructions in `PLAN.md` when the
  same details already exist in inline `FIXME(refactor)` comments.
