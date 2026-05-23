# AGENTS.md

Merged guidance from `.cursor/rules/*.mdc`.

## Scope And Precedence

1. Apply this file to the whole BusDK superproject.
2. If instructions conflict, use this order:
   1. Repository identity, security, privacy, and safety constraints.
   2. Definition of done and quality gates.
   3. Module boundaries and architecture contracts.
   4. Repo-local skill runbooks and task-specific instructions.
3. Prefer minimal, deterministic, script-friendly behavior.
4. For module work, read this file plus the most specific local `AGENTS.md`
   under the target subtree before changing files.

## Guidance Layout

- Keep this root file limited to superproject orchestration, cross-module
  architecture, family-wide policy, safety, release-quality rules, and skill
  triggers.
- Put module-specific implementation, command behavior, and local workflow
  rules in the owning module's `AGENTS.md`; those files must stand alone for
  independently checked out modules.
- Use repo-local skills in `./skills` for detailed operational runbooks. Mount
  those skills into worker containers when practical.
- Keep public docs free of agent-only process rules. For SDD/public-doc
  architecture candidates, leave compact triggers and follow-up notes unless a
  task explicitly asks for public documentation edits.

## Repo-Local Skills Index

Read the relevant skill before doing detailed operational work:

1. `skills/bus-product-delivery-supervisor/SKILL.md`: broad multi-module
   supervision, worker dispatch, monitoring, review, process improvement,
   throughput analysis, heartbeat/progress/closeout reporting, and GX/UI
   roadmap coordination. Use it before running supervisor mode.
2. `skills/bus-dev-task-worker-ops/SKILL.md`: concrete `bus dev work` /
   `bus dev task` dispatch, Compose/App Server workers, monitoring, reopen,
   closeout, promotion, auth/token handling, write scopes, worker infrastructure
   troubleshooting, and generated-artifact promotion hazards. Use it before
   touching worker ops.
3. `skills/bus-plan-memory-maintainer/SKILL.md`: `PLAN.md`, `AGENTS.md`,
   Bus Notes/hourly memo practice, tracker-file processing, durable lessons,
   historical verification, commit/tracker closeout, and planning granularity.
4. `skills/bus-ui-gx-roadmap/SKILL.md`: GX and Bus UI feature-candidate
   planning, docs, implementation, semver promotion, and portal migration
   prerequisites.
5. `skills/bus-docs-quality/SKILL.md`: public docs and SDD structure, Markdown
   linting, UI docs page shape, examples, links, and duplicate-content cleanup.
6. `skills/bus-go-quality-review/SKILL.md`: Go implementation/review gates,
   unit/e2e expectations, module Makefile checks, and final `bus lint
   path/to/file.go` peer review. Use it before touching Go files.
7. `skills/bus-generated-artifact-hygiene/SKILL.md`: generated WASM/static
   artifact tracking, ignore/clean/regenerate rules, and dirty-checkout
   prevention.

## Repository Identity

1. This repository is the public superproject for `busdk/busdk`.
2. Do not implement accounting logic or BusDK module source code here.
3. Keep BusDK modules as Git submodules at repository root (`bus`, `bus-*`).
4. Treat checked-in submodule commit SHAs as authoritative pins. Do not add
   lockfiles.
5. Keep orchestration in exactly one root `Makefile` using POSIX shell, `git`,
   and POSIX `make`.
6. Do not add alternative build systems, package-manager integrations, network
   features, or CLI binaries in this superproject.
7. The `.bus/` directory is a tracked project directory. Never add `.bus` or
   `.bus/` ignore rules. Runtime lock artifacts such as `.bus-dev.lock` may be
   ignored.
8. Do not treat `.bus/`, `Makefile.local`, `./tests`, or `FEATURES.md` as
   temporary files unless a repository explicitly documents an exception.

## Root Makefile Contract

When editing the root `Makefile`, preserve superproject-only orchestration:
deterministic discovery of `bus` and `bus-*` module Makefiles, delegation via
`make -C`, POSIX shell/make, required lifecycle targets, module-local `./bin`
outputs, `PREFIX`/`BINDIR`/`DESTDIR`, Go variable pass-through, and
changed-module-scoped root test/e2e defaults. Do not add lockfiles or reimplement
module internals.

## Repository Visibility And Secrets

1. Public/open-source repos: `./` (superproject), `./bus`, `./docs`,
   `./busdk.com`.
2. Private/commercial-customer repos: every `./bus-*` module unless explicitly
   documented otherwise.
3. In public repos, do not introduce in-process coupling to private module
   internals; use stable CLI/library/API boundaries only.
4. This public superproject and its public docs/examples must never contain real
   SMTP, database, JWT, API, AI provider, webhook, signing, password, private
   key, DSN-with-password, or customer secrets.
5. Do not accept secret values as command-line arguments in BusDK tools or
   services. Secrets must come from environment variables, user config secret
   files, deployment secret files, OS credential storage, or standard input
   where explicitly designed.
6. Treat committed `AGENTS.md`, docs, and examples as public unless they are
   explicitly inside a private repository. Logs, memos, and notes are internal
   operator records, but still avoid writing secrets unless the owning
   repository explicitly documents a private secret-handling surface.
7. Never print broad `.env` contents. Query only exact non-secret keys or report
   key presence with values redacted.
8. Never auto-write JWTs, API tokens, refresh tokens, or auth-session files
   under repository-local `.bus/` paths or any other working-tree-relative
   default. Use the unified user config root, explicit operator-supplied paths,
   environment variables, or OS credential storage.
9. For multi-remote worker credential design, keep root metadata non-secret and
   read `skills/bus-dev-task-worker-ops/SKILL.md`.

## Definition Of Done

Production, bug-fix, and user-visible behavior changes require deterministic
automated tests, appropriate e2e coverage, formatting/lint/static/security
checks, docs/help/SDD updates when behavior changes, backward compatibility
unless explicitly approved, and tracker follow-up for any approved exception.
Before module command, test, runtime, CLI, docs, restricted API, or Go changes,
read the owning module guidance and the relevant skill or SDD source.

## Cross-Module Architecture

Before changing module boundaries, command ownership, Events/auth/config,
AI-host behavior, provider/runtime architecture, notes modules, naming, or
private/public coupling, read the relevant module SDD under `/workspace/SDD/docs`
or `./sdd/docs` plus the owning module `AGENTS.md`. If stable architecture still
exists only in agent guidance, record an SDD-recipient follow-up instead of
rewriting public docs in this root file.

## Commit And Deletion Safety

Read `skills/bus-plan-memory-maintainer/SKILL.md` before tracker-only commits
or memory closeout. Root safety context: commit only when asked or explicitly
allowed, commit staged scope only, never push/tag/sync without request, use
tracked/untracked deletion commands deliberately, and keep tracker-only commits
separate from implementation/docs/test changes.

## Shell And Tool Hygiene

For shell scripts, Docker inspection, readiness probes, search/format commands,
or other repeatable debugging practice, read the owning module guidance or
relevant skill first. Root safety context: keep commands simple, portable,
path-correct, and redacted.

For historical delivery or behavior claims, verify the relevant Git diff before
writing the claim. For progress, heartbeat, review, and closeout reports, follow
`skills/bus-product-delivery-supervisor/SKILL.md`.
