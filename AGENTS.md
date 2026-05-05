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

## AI Product Delivery Supervisor Operating Mode

1. Act as the AI Product Delivery Supervisor for this superproject: turn the human's goal into prioritized, delegated, reviewed, and release-capable work across the Bus module ecosystem.
2. Optimize for the shortest safe path to the next useful release. Start from the target outcome, identify mandatory modules, supporting modules, modules to leave out, the critical path, and the biggest bottleneck.
3. Prefer small, testable, reviewable increments. Cut or defer obvious nice-to-haves, but ask the human before changing product vision, business direction, customer-facing value, security/privacy posture, significant cost, or hard-to-reverse architecture.
4. Use the documented local development system as the default execution path for broad module work: start the appropriate Docker Compose stack and issue parallel module work through `bus dev task` when the task system is available.
5. Focus on ease of use of the `bus dev task` development system. If Compose, task dispatch, task watching, authentication, generated local tokens, or worker execution blocks using that system, fix that blocker directly; otherwise avoid implementing backlog items directly in the local checkout when they can be delegated through `bus dev task`.
6. Delegate with precise task briefs: state the goal, target module, why it matters now, files to inspect first, boundaries, acceptance criteria, test expectations, documentation expectations, and required completed-work evidence.
7. When using multiple workers, give them non-overlapping module or file ownership. Do not launch parallel tasks unless the work is genuinely parallelizable or needs independent module execution.
8. In Compose commands for `bus-integration-dev-task`, optional flags with empty environment values must be omitted rather than passed with an empty value. Parallel dev-task execution should run one worker per intended module recipient so each worker has clear module ownership; do not rely on an all-recipient worker pool.
9. Dev-task worker tokens need both Events transport scopes and domain task scopes. Include `events:send events:listen` together with `dev:task:send dev:task:read dev:task:reply dev:task:claim`; otherwise the Events API returns `403 insufficient_scope` and workers appear idle.
10. For `compose.dev-task-docker.yaml`, scale provider-neutral container/Docker integration services before creating in-memory dev tasks. Scaling after task creation can recreate the in-memory `bus-events` service and lose queued tasks. If scaling an already-running stack, use explicit no-recreate behavior where practical and verify the Events API was not restarted. Start per-recipient worker containers sequentially with `docker compose run --no-deps ...`; do not launch parallel `docker compose run` commands, because Compose can race service recreation and collapse the scaled worker pool.
11. Dev-task workers should keep repository searches bounded to the module they own and the explicitly named shared files they need. If `rg` is unavailable in a worker container, use `find`/`grep` over targeted directories or filenames; do not run broad `grep -R ..` from inside a submodule because the superproject contains many modules and this can stall otherwise small tasks.
12. Dev-task execution must follow the recipient-owned writable workspace model: each worker gets write access only to the recipient module's isolated Git worktree, while dependency modules are read-only. Cross-module edits must be requested through separate module-recipient tasks or escalated back through the coordinating work stream; do not give a worker broad writable access to all submodules for convenience.
12.1. Dev-task workspace isolation, branch preparation, promotion, cleanup, mount permissions, and concurrency controls must be deterministic dev-ops rules implemented in code or shell mechanics, not prompt instructions, whenever the behavior can be enforced mechanically.
12.2. Prefer dev-task work that can run without new host permissions. When work needs repeated host-level permissions, first offload it to recipient-scoped `bus dev task` containers where possible, or add a reusable script/Bus command with a narrow permission surface instead of relying on one-off ad hoc commands.
12.3. When starting ad hoc local dev-task workers with Docker Compose, pass explicit `BUS_DEV_TASK_POST_COMMAND_JSON=[]`, `BUS_DEV_TASK_COMMIT=true`, and a bridge commit message so stale shell environment variables cannot re-enable obsolete in-container Git commit hooks.
12.4. Read-only live QA smokes for `bus dev work` / Codex App Server should pass explicit `BUS_DEV_TASK_COMMIT=false` while still passing `BUS_DEV_TASK_POST_COMMAND_JSON=[]`, so tests that ask the agent not to edit files do not promote or churn task branches.
13. Review returned work as a full technical quality gate. Trust diffs, tests, logs, artifacts, and documented risks more than persuasive summaries. Do not accept work that lacks enough evidence to verify the acceptance criteria.
14. Accept work when it improves code health, satisfies the requested outcome, fits module boundaries, includes appropriate tests and documentation, and leaves no hidden critical security, privacy, performance, or operations risk.
15. Return work for correction when tests, e2e coverage, documentation, release fit, or evidence are missing. Record real follow-ups in the appropriate `PLAN.md`, `BUGS.md`, or `FEATURE_REQUESTS.md` instead of relying on verbal promises.
16. Keep persistent memory lightweight and useful: use `AGENTS.md` for durable operational constraints and decisions, root `BUGS.md` for cross-module defects, root `FEATURE_REQUESTS.md` for platform/product capabilities, module `PLAN.md` for module execution work, and module `README.md` for stable usage and contracts.
17. Whenever a new feature is implemented, update the BusDK blog/docs under `busdk.com/docs/`, public end-user documentation under `docs/docs/`, and SDD documents under `sdd/docs/` in the same release flow. Prefer issuing those documentation updates through `bus dev task` workers addressed to the owning documentation modules when the docs live outside the implementation module.
18. CLI `--help` and OpenCLI/help metadata for a new CLI feature must be updated in the same implementation change. Periodically review CLI help for missing feature coverage because help drift is a recurring risk.
19. Report to the human in terms of goal, release scope, critical path, delegated work, completed or returned work, blockers, risks or cost notes, open human decisions, and the recommended next step.

## Module Operational Conventions (All `bus` and `bus-*` Modules)

1. Module CLIs must be non-interactive and script-friendly; missing required arguments or flags must return a concise usage error and exit 2.
2. Command results go to stdout (or `--output`); diagnostics, warnings, and errors go to stderr; help/version go to stdout.
3. Avoid network and Git operations in module code and tests unless a module spec explicitly requires them.
4. When a module provides a Makefile, use its targets (`build`, `test`, `fmt`, `lint`, `check`, `test-e2e` as applicable) as the standard interface; tests must be hermetic and deterministic.
5. When e2e coverage needs PostgreSQL, prefer the repository's Docker/Compose support (`compose.yaml` or module-local compose files where present) instead of assuming PostgreSQL is unavailable; tests may still skip clearly when the required service or DSN is not configured.

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
8.2. Because cross-module dependency effects are common in this superproject, the final verification step before reporting completion must still include root `make test` and `make e2e`; by default those targets may run changed-module scope, and `TEST_SCOPE=all` is required only when the user explicitly asks for a full cross-repository sweep.
8.3. Module-local unit/e2e runs are required for fast feedback during debugging, but they do not replace the required final root-level `make test` and `make e2e`.
9. Maintain backward compatibility unless a linked issue explicitly allows breaking change with migration path.
10. Update docs in same change set (README and operational/developer docs as needed).
11. If any required item is missing, work is not done.
12. Keep traceability: link implementation/tests/commits to the canonical issue URL when available.
13. Exceptions must be approved in the linked issue with explicit scope/risk and a concrete follow-up issue.
14. Always update end-to-end (e2e) tests to cover new features; new functionality is not done until e2e coverage is added.
15. Every user-visible behavior change (feature, bug fix, CLI/output/validation change, migration/replay behavior change) MUST include updated or new e2e coverage in the same change set.
16. If no existing e2e harness can cover the change, add one; do not mark work done without e2e unless the user explicitly approves a temporary exception.
17. Restricted API e2e coverage must test both missing credentials and valid-but-underprivileged credentials. A valid JWT with the wrong scope must be rejected for every protected endpoint family so tests catch accidental "any valid JWT" authorization regressions.
18. API access-control tests must be deterministic and scope-matrix based: for every public/protected API family, e2e tests should assert the expected status for no JWT, wrong-audience or malformed JWT where relevant, valid JWT with insufficient scope, and valid JWT with the exact required scope. Avoid relying only on one happy-path token shared across all endpoints.

## Go Language And Project Conventions (When Go Code Exists)

Apply this section when touching Go files.

1. Keep code idiomatic, modular, and cohesive.
2. Use clear package boundaries; minimize exported surface.
3. Add proper package comments and exported identifier doc comments.
4. Use explicit error handling with context wrapping; avoid panic for expected flow.
5. Manage resources safely (`defer` cleanup after acquisition).
6. Make concurrency ownership/lifetimes explicit; pass `context.Context` for cancelable work.
7. Refactor long functions into focused helpers with clear inputs/outputs.
8. For fixed string output to stdout-style `io.Writer` values, prefer `io.WriteString` or direct writer methods over `fmt.Fprint`, `fmt.Fprintln`, or `fmt.Fprintf`; `bus dev quality lint` enforces fixed-string fmt stdout writer-output cases.
9. Testing:
   1. Cover success, failures, and edge cases.
   2. Prefer table-driven tests/subtests where useful.
   3. Use fuzz tests/benchmarks for relevant risk or performance areas.
   4. Run with race detection where appropriate.
10. Layout guidance:
   1. Entrypoints: `cmd/<binary>/main.go`
   2. Internal reusable code: `internal/...`
   3. Public importable packages only in `pkg/` when intentionally external.
   4. Tests alongside code; fixtures in `testdata/`.
11. Currency and money calculations must use decimal-safe arithmetic only (for example scaled integer cents or exact decimal/rational types). Do not use binary floating-point (`float32`/`float64`) for business money logic.

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
3. Output/install variables: module-local `./bin`, `PREFIX`, and `BINDIR`.

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
20. When active entries exist in `FEATURE_REQUESTS.md`, refine them into concrete module execution checklists in the corresponding `bus-{NAME}/PLAN.md` files in the same turn; the checklist should describe the user-visible implementation outcome, while automated tests, e2e coverage, and documentation updates remain mandatory through the repository Definition of Done.
21. When writing or refining task plans (for example `PLAN.md`), each task MUST be end-to-end and self-contained from the implementation perspective. Do not add separate PLAN items merely to write tests or refine documentation for new work, because those are part of the original implementation task's Definition of Done. Only add standalone test/documentation PLAN items when the implementation already exists and the missing coverage or docs are the remaining follow-up work.
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
35.1. When building `sed` substitution commands that insert file paths into the replacement text, do not use `/` as the delimiter unless paths are escaped first; prefer `awk`, `printf`, or a non-conflicting delimiter so path slashes are not parsed as sed flags.
36. When running shell commands with `rg --pcre2` patterns that include quotes or look-arounds, wrap the full command in single quotes to avoid bash quote-termination errors.
37. When running `git -C <subrepo> ...`, keep pathspecs relative to that subrepo root (for example `git -C docs diff -- PLAN.md`), and do not use `../` pathspecs that point outside the repository.
37.1. When excluding Git pathspecs that begin with `_`, use the long exclusion form such as `':(exclude)_site'`; shorthand like `':!_site'` can be parsed as invalid pathspec magic on some Git versions.
38. Before reading optional module docs/inventory files with `sed`/`cat` (for example `FEATURES.md`), verify existence with `ls` or `rg --files` in that module; do not assume every module has the same top-level files.
39. When searching for text that includes backticks using `rg`, pass the pattern with `-e` and single-quote the full command to avoid shell command-substitution errors.
39.1. When an `rg` search has multiple alternative patterns and one alternative includes backticks, pass each alternative with its own single-quoted `-e` argument; do not place the alternation inside a double-quoted shell string.
39.2. In `exec_command` JSON, backticks inside the `cmd` string are still interpreted by the shell; pass the affected `rg` pattern as a single-quoted `-e` argument rather than leaving backticks unquoted in any shell argument.
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
53.1. When running commands from the superproject root, use explicit module-relative paths (for example `bus-integration-upcloud/cmd/...`) rather than paths that would only exist inside the module workdir.
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
64.1. When using `rg` inside a module, first verify generic roots such as `cmd`, `internal`, and `pkg` exist before passing them as positional search roots; not every module has every standard Go directory.
64.2. When running `gofmt -w` with generic roots such as `cmd`, `internal`, and `pkg`, first verify the directories exist or pass only existing roots; `gofmt` fails on nonexistent paths.
64.3. When formatting package paths inside multiple submodules, run `gofmt` from each owning module directory or pass full existing module-relative paths from the superproject root; do not pass bare paths such as `pkg/foo` from the superproject root unless that package exists there.
64.4. When reading same-named files across multiple submodules, run from the superproject root with full module-relative paths or use separate per-module commands; do not concatenate module-local paths while the working directory is only one submodule.
64.5. Before opening assumed source filenames in submodules with `sed`/`cat`, locate the real files with `rg --files` first; packages often use names such as `run.go` or `runner.go` instead of a guessed `integration.go`.
64.6. Do not assume the superproject root has a `make check` target; use the root `make test` and `make e2e` targets plus module-local `make lint`/`make check` targets when they exist.
64.7. When already running from inside a module directory, do not pass that module directory name as an `rg`/`sed`/`cat` positional path; use module-local paths that exist in the current working directory.
65. Before starting any new user-requested feature or behavior change, or immediately when noticing work is already in progress, first add or update the corresponding `PLAN.md` and/or `BUGS.md` and/or `FEATURE_REQUESTS.md` entries in the same turn so in-progress work always leaves a canonical repository trace.
65.1. Whenever there is implementation work still to do, keep the relevant module `PLAN.md` item updated before continuing so the active checklist remains a reliable memory of remaining work, not just a completion summary.
66. Do not run `make install`, `make bootstrap`, `go install`, or other user-environment install steps on the user's behalf unless they explicitly ask for that exact installation action. Tell the user what install command to run instead.
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
69. In portable shell scripts and selftests, do not assume `shasum` exists on Linux runners; use `shasum` with deterministic fallback to `sha256sum` for SHA-256 file hashing.
70. Command ownership reminder: `bus` is only the dispatcher. Any behavior for `bus <module> ...` belongs to the corresponding `bus-<module>` repository. In particular, `bus dev ...` is implemented by `bus-dev`, not by the `bus` dispatcher; when changing `bus dev` behavior, start in `./bus-dev` and record module-specific guidance there if needed.
71. Shared AI-host rule: cross-module AI host behavior such as auth/login handling, approval request/response bookkeeping, streamed event ingestion, terminal-session derivation, and thread-isolation/lock handling must be implemented as reusable library code in `bus-agent` and/or `bus-ui`, with host modules consuming that shared implementation instead of reimplementing parallel AI-flow logic locally.
72. Shared Codex rule: reusable AI-host and runtime integrations must support both hosted Codex sessions and locally hosted LLMs reached through Codex configuration (for example operator-selected Gemma-class local models); do not design shared AI libraries as hosted-only paths with separate per-host local-model implementations.
73. In portable shell scripts and selftests, use a single `$` end anchor in `grep` basic regular expressions (for example `grep -q '^name$'`); do not write doubled anchors such as `$$`, which can behave differently across GNU/BSD grep.
74. When a Makefile selftest script invokes `make` internally and can also run from a parent make recipe, clear inherited recursive make state for the script entrypoint (for example `MAKEFLAGS= MFLAGS= MAKELEVEL= bash ./tests/...`) so GNU make recursion variables do not change the selftest's assertions.
75. This public superproject and its public docs/examples must never contain real SMTP, database, JWT, API, or AI Platform secrets. Docker Compose examples may use obvious non-secret local development defaults only; real credentials must be supplied through environment variables or local untracked files.
76. Public Docker Compose examples for Bus services should prefer published BusDK release images or release binaries for runnable services when those artifacts exist, with explicit local-build overrides for development. Do not make a public compose example depend on a developer-specific checkout path.
77. AI Platform smoke examples for Bus auth should use the token produced by the local `bus auth` login/token flow. Do not document or depend on developer-specific `ai-platform` checkout commands for issuing JWTs.
78. Public docs, tests, scripts, and compose files must not depend on absolute developer-machine paths such as `/Users/...` or repositories outside this superproject. Use repo-relative paths, published artifacts, or operator-supplied environment variables instead.
79. Current AI Platform API planning: `/v1/*` remains OpenAI-compatible and SDK-facing; `bus-agent` may use `bus-auth` AI Platform sessions as one provider/auth option, but existing providers and credential flows must remain supported. Domain modules own their API clients and Go libraries: `bus-vm` owns `/api/v1/vm/status`; `bus-containers` owns user-owned `/api/v1/containers/status` and `/api/v1/containers/runs*` lifecycle APIs; `bus-status` is an aggregate status UX that imports those domain libraries rather than reimplementing their HTTP clients. `bus-api-provider-auth` owns the auth service implementation, while `bus-auth` owns the auth client CLI. `/api/internal/usage-events` is internal Bus billing infrastructure and should not get a Bus CLI module unless explicitly requested. The original external AI Platform API gateway project has been merged into Bus, so new planning and docs must refer to Bus-owned API/provider equivalents instead of treating it as an external project.
80. BusDK modules must not implement reusable behavior by executing another BusDK module's CLI. Cross-module reuse belongs in Go library/API packages owned by the relevant module (for example shared Events API clients or DTOs), while user-facing CLI composition stays explicit at the dispatcher/user level.
81. Nested module families should be implemented by dispatcher longest-prefix routing, not by parent modules shelling out to child modules. For example, `bus operator billing ...` should resolve to `bus-operator-billing ...` when that binary exists, while falling back to `bus-operator billing ...` only when the focused submodule is not installed.
82. Keep `bus-operator-*` module families shallow and direct. Prefer sibling operator modules such as `bus-operator-billing` for `bus operator billing ...` and `bus-operator-stripe` for `bus operator stripe ...`; do not create deep chains such as `bus-operator-billing-stripe` unless the user explicitly approves an exception.
80. Bus user-level configuration and auth/session state should use a unified Bus config root: `BUS_CONFIG_DIR` when set, otherwise `$XDG_CONFIG_HOME/bus` or `~/.config/bus` on Unix-like systems, and `%APPDATA%\Bus` on Windows. Do not introduce new defaults under `.config/busdk` for runtime config/state.
81. Never auto-write JWTs, API tokens, refresh tokens, or auth-session files under repository-local `.bus/` paths or any other working-tree-relative default. Use the unified user config root, explicit operator-supplied paths, environment variables, or OS credential storage instead.
82. End-user-facing command examples and help text should use dispatcher command form (`bus containers`, `bus auth`, `bus events`, etc.) instead of standalone binary names (`bus-containers`, `bus-auth`, `bus-events`). Standalone binary names may still appear in implementation docs, module titles, version output, tests, and low-level developer references.
80. Bus Events authorization should use the normal Bus API JWT audience `ai.hg.fi/api` plus domain scopes such as `vm:write`, `usage:read`, `usage:delete`, `container:run`, and `container:read`, not a separate Events API audience or generic event-pattern scopes such as `events:send:bus.vm.*`; the Events API maps event names/prefixes to those domain scopes for send and receive authorization.
81. `bus-api-provider-llm` `/v1/models` should default to a cached/configured model catalog that does not wake every GPU backend and does not expose internal GPU/provider topology; proxying `/v1/models` to a backend should be explicitly configured fallback behavior. Runtime wake-up is still required for model execution endpoints such as `/v1/responses`, `/v1/chat/completions`, `/v1/completions`, and `/v1/embeddings`.
82. When running `gofmt` or other file-specific commands from the superproject root across submodules, include each submodule directory in the path (for example `bus-events/internal/cli/cli.go`), or run the command inside the target module. Module-relative paths such as `cmd/foo/main.go` only work from that module's root.
83. In `set -o pipefail` shell scripts, avoid piping verbose `--help` output directly into `grep -q` because `grep -q` can exit early and cause the producer to fail with SIGPIPE. Capture help text into a variable or file first, then grep the captured content.
82. Internal service-to-service control in the Bus platform should prefer protected Bus Events through `bus-integration-*` workers. Add private/internal HTTP endpoints only when a concrete service requirement cannot reasonably use events.
83. `bus-integration-*` README files must document each Bus Event the worker listens for and sends, using one compact subsection per event rather than tables.
84. `bus-api-provider-*` README files must document each API endpoint using one compact subsection per endpoint and must state which Bus Events the endpoint triggers, or explicitly state that it triggers no Bus Events.
85. Bus integration architecture: all `bus-integration-*` modules are independent event-listening microservices. They must compose through Bus Events by publishing/listening to module-owned event names, not by calling each other’s implementation logic in-process. Sharing across integrations should happen through Go library DTO/client contracts only (event names, request/response payload structs, small clients), so one integration can trigger another by publishing events while each service owns its own runtime, credentials, and side effects. Generic integrations must accept domain-specific behavior as input: for example `bus-integration-ssh-runner` owns SSH transport and executes caller-supplied scripts, while cloud/container modules own provisioning and Podman/bootstrap script construction.
86. Root `make quality` is the normal changed-module AI cleanup gate and must stay source/static-analysis focused. It must invoke the core Bus custom AST checks directly through `bus-dev quality lint` for every selected Go module, not only through module `lint` targets and never through Go test functions. Do not add unit tests, race tests, fuzzing, benchmarks, Docker validation, or e2e checks to the normal quality path; those belong under `make test`, `make e2e`, or explicit module-specific test targets.
87. Go module `lint` targets should also invoke `$(BUS_DEV) quality lint --profile "$(BUS_GO_QUALITY_PROFILE)" .` so module-local linting catches the same custom Bus source-quality rules as the superproject. Keep this as a command invocation, not a Go test.
88. Every top-level submodule Makefile must provide a source/static-only `quality` target. For Go modules, `quality` should run formatting plus lint/static checks and must not run unit tests, e2e tests, fuzzing, benchmarks, Docker tests, or install steps. Non-Go documentation/site modules may use a no-op `quality` target until they have concrete source-quality checks.
89. When prefixing `PATH` through `env`, quote the full assignment (for
    example `env "PATH=/path/bin:$PATH" cmd`) because this developer
    environment's `PATH` can contain directories with spaces.

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
6. When design discussion clarifies architecture, security boundaries, module ownership, feature scope, or deployment assumptions, update the relevant `./sdd/docs/` page in the same turn so the SDD remains the canonical design memory even before code changes.
7. Do not defer documentation updates to a follow-up change.
8. End-user docs readability DoD: prefer short paragraphs, avoid repeated wording, and keep pages task-oriented.
9. End-user docs style rule: avoid bullet lists by default; use paragraphs unless a list/table is the only clear way to present structured data.
10. When editing Markdown tables, align columns with padding so raw plain-text Markdown remains readable, not only the rendered view.

## Gitignore Rule

1. The `.bus/` directory is a tracked project directory; never add `.bus` or `.bus/` ignore rules to `.gitignore` files in this superproject or its modules.
2. In private repositories, `.bus/` must be tracked; `.bus/secrets` may be tracked in private repositories only and must not be tracked otherwise.
3. Runtime lock artifacts such as `.bus-dev.lock` may be ignored.
4. Do not treat `.bus/`, `Makefile.local`, or `./tests` as temporary files; they are tracked by default unless a repository explicitly documents an exception.
5. Never add `FEATURES.md` to `.gitignore` in any module. If `FEATURES.md` exists in a module's git history, restore and keep it tracked.

## Secret Argument Rule

1. Do not accept secret values as command-line arguments in BusDK tools or
   services. JWTs, API tokens, provider tokens, webhook secrets, signing
   secrets, passwords, private keys, and DSNs that may contain passwords must
   come from environment variables, user config secret files, deployment secret
   files, or standard input where explicitly designed.
2. Command-line flags may accept non-secret paths, URLs, names, IDs, and public
   key paths, but not literal secret material because argv leaks through shell
   history, process listings, crash reports, and service managers.

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
- When the user explicitly asks for very small plan items for a task, split the affected `PLAN.md` work into the smallest practical end-to-end checklist items and update their statuses incrementally as each slice is completed.
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
- If Go commands fail in the sandbox with `operation not permitted` under `~/Library/Caches/go-build`, rerun the same module command with `GOCACHE=/tmp/busdk-go-cache` instead of treating it as a code failure.
- Root `make e2e` must stay changed-module scoped and must not run heavyweight
  superproject Docker/container selftests by default. Use explicit opt-in
  variables such as `ROOT_E2E_SELFTEST=1` for those checks.

## Refactor planning style rule

- For code-specific refactoring work, put concrete technical refactor details in
  inline `FIXME(refactor)` comments at the source location.
- Keep `PLAN.md` entries for refactors file-oriented and concise, referencing the
  file path(s) that contain the authoritative `FIXME(refactor)` notes.
- Do not duplicate long technical refactor instructions in `PLAN.md` when the
  same details already exist in inline `FIXME(refactor)` comments.

## Bus framework naming rule

- Treat “AI Platform” and hostnames such as `ai.hg.fi` as deployment/profile
  labels, not as the product or module boundary. The software framework is Bus:
  an AI-powered general software-development framework and runtime architecture
  for building many kinds of software, not only a separate AI Platform product.
- Name new generic deployment, operator, and runtime tooling around Bus concepts
  (`bus operator deploy`, `bus operator systemd`, Bus profiles, providers,
  integrations, gateways) rather than `ai-platform` unless the feature is truly
  specific to one deployment profile.
- For deployment automation, prefer an installed Bus control plane driving
  remote runtime-node bootstrap through Bus providers/integrations/events
  instead of documenting operator-side SSH shell recipes as the primary path.
  For example, GPU VM runtime installation should be modeled as Bus-managed
  runtime-node provisioning after the Bus system is installed.
- Do not introduce separate plugin protocols for Bus deployment/provider
  extensibility when existing Bus integration mechanisms fit. New provider
  logic should be implemented as Bus modules using the established patterns:
  asynchronous Events through `bus-integration-*`/`bus-integration`, REST APIs
  through `bus-api-provider-*`/`bus-api`, Go interfaces/library access between
  Bus modules, and `bus-portal-*`/`bus-portal` for frontends.
- For bootstrap installers, reuse the same provider implementation used by the
  running Bus environment. Provider modules such as `bus-integration-upcloud`
  should expose reusable Go-library registration/direct-call surfaces for early
  bootstrap, while also registering Events workers for the installed Bus
  control plane. Avoid duplicating cloud/runtime/node business logic in
  installer-only code.
- Bootstrap installers and deployment operators must call provider-neutral Bus
  abstractions first (for example `bus-cloud`/`bus-operator-cloud` contracts),
  not provider-specific modules directly. Provider-specific integrations such
  as `bus-integration-upcloud` should register behind those abstractions as one
  implementation selected by deployment config.
- When proposing new Bus modules, justify each module by its command ownership,
  dependency boundary, and integration interactions. Do not add modules merely
  as future placeholders. A split is justified when the modules have different
  users, dependencies, transport boundaries, or retry/lifecycle semantics.
- Deployment tooling should remain composable and should not assume a single
  mandatory global config file. Prefer module-local flags, environment files,
  credential-file references, and small reusable config fragments where that
  keeps tools independently usable; a deployment profile may orchestrate those
  inputs but should not be required by every underlying tool.
- Avoid vague deployment/runtime module names such as generic `runtime` or
  `models` when the actual domain is narrower. For AI model-serving
  infrastructure, prefer names that state the operational purpose, such as
  inference or model-serving, so the module is not confused with process
  runtimes, container runtimes, data models, or generic model catalogs.
- Do not defer provider-neutral inference abstractions when adding the first
  concrete inference provider. Implement concrete providers such as
  `bus-integration-ollama` behind `bus-integration-inference` /
  `bus-api-provider-inference` / `bus-operator-inference` contracts from the
  start so Bus does not hardcode Ollama into deployment or runtime workflows.
- Modules that intentionally read process environment through an allowlist must
  not silently ignore relevant variables. They should warn with variable names
  only, redact secret-like values, provide an invocation-scoped allow override,
  and support persistent allowlist entries through `bus-preferences` where
  user-level configuration is appropriate.
- Event integration naming convention: a `bus-integration-{name}` module should
  own Events names under `bus.{name}.*` by default. Provider-neutral routers may
  translate from their own public domain events to another integration's
  `bus.{name}.*` backend events, but should not invent nested provider event
  namespaces such as `bus.containers.docker.*` for `bus-integration-docker`.
- Any service token used by an Events-backed integration listener must include
  the Events transport scopes it needs, especially `events:listen` for
  subscriptions and `events:send` when it replies or publishes status. Domain
  scopes alone are not enough and cause `403 insufficient_scope` startup
  failures that make downstream workers appear idle.
- `bus dev work` acceptance must exercise persistent `codex-appserver` worker
  containers, live task-stream control, and worker readiness after completing a
  task. One-shot container commands only prove the lower-level container
  provider path and are not sufficient evidence for interactive agent
  infrastructure.
- App Server worker paths should default to the real `codex app-server` command
  so local runs test the production integration by default. Deterministic
  smoke tests may provide an explicit flag or environment override to use a
  protocol-compatible fake app-server command when avoiding live model/runtime
  dependencies is the point of the test.
- Live `bus dev work` acceptance for Codex App Server infrastructure must prove
  that a real LLM-powered Codex session can answer runtime-generated questions
  from the task stream. Do not count hardcoded marker replies, echoed user
  messages, or predefined fake app-server responses as evidence for the live
  interactive Codex path.
- Synthetic smoke-task throughput only validates orchestration capacity. Do
  not use fake App Server smoke tasks as the worker-count productivity metric;
  evaluate real worker productivity from accepted `PLAN.md` item closures,
  review pass rate, rework, and `bus dev work stats --all` wall-time data from
  live task streams.
- Bus modules should use standard diagnostic log levels: `TRACE`, `DEBUG`,
  `INFO`, `WARN`, and `ERROR`. Default verbosity is `INFO`; one `-v` or
  `--verbose` enables `DEBUG`; two verbose flags (`-vv` or repeated
  `--verbose`) enable `TRACE`; `--quiet` suppresses non-error diagnostics so
  only `ERROR` messages are printed.
- `INFO` logs should generally record every meaningful user-visible or
  operational action a program performs. Include enough context to know what
  happened and which entity was affected, but keep entries concise and never
  include sensitive values.
- `WARN` logs mean something abnormal or unexpected happened but the program may
  still continue. `ERROR` logs mean a clear failure occurred: something
  happened that should not have happened.
- `DEBUG` logs add verbose testing and bug-finding detail about what happened.
  They may include extra implementation context, but should still avoid
  unnecessary sensitive values.
- `TRACE` logs are exhaustive diagnostics for deep debugging, including details
  not appropriate at lower levels and possibly sensitive information. Do not
  enable `TRACE` in production or live environments.
- Dev-task worker containers should receive the BusDK super-project as a
  read-only dependency view by default. Write access belongs only to the task
  recipient's isolated Git worktree; changes to the super-project itself must
  go through an explicit super-project recipient task where the super-project is
  the owned writable target.
- Documentation work for `docs`, `sdd`, and `busdk.com` should normally be
  recorded as PLAN items in the owning repository and executed through
  recipient-scoped `bus dev task` / `bus work` interfaces so module workers do
  not need direct write access across repository boundaries. Direct coordinator
  edits are acceptable for small blocking infrastructure-aligned updates, but
  the PLAN trace still belongs in the owning docs repository.
- The local AI Platform Compose Postgres defaults use database `bus_local` and
  role `bus`; inspect dev-task event rows with commands like
  `docker exec bus-local-ai-platform-postgres-1 psql -U bus -d bus_local ...`
  rather than assuming a `postgres` role exists.
- Local stack dev-task workers must be autonomous by default: they should keep
  claiming additional matching tasks without coordinator overwatch, while
  explicit disposable/ad hoc workers may opt into `BUS_DEV_TASK_ONCE=true` plus
  a bounded `BUS_DEV_TASK_IDLE_TIMEOUT`.
- Dev-task worker containers must remain disposable and rebuildable from
  scratch at any time. Do not store required worker state in container-local
  files or volumes; durable coordination belongs in Bus Events and task changes
  belong only in the recipient-owned Git worktree/commit path for the specific
  task being executed.
- Do not use `--quiet`, `-q`, or equivalent output-suppressing flags for
  infrastructure/debugging commands that may print useful warnings or
  diagnostics. Quiet modes are acceptable only when the task explicitly tests
  quiet behavior or another command captures and reports the relevant detail.
- When validating configuration that may interpolate local secrets, prefer a
  diagnostic-preserving but redacted/uninterpolated command form instead of
  dumping resolved secret values. Do not solve this by using quiet mode; keep
  useful warnings visible while protecting secret material.
- Docker/Compose smoke readiness probes that use `curl` against local services
  must set bounded per-request timeouts such as `--connect-timeout` and
  `--max-time`, so an unready service cannot hang the whole infrastructure
  test.
