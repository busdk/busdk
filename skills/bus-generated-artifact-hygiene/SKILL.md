---
name: bus-generated-artifact-hygiene
description: Use when builds, tests, workers, or portal modules dirty generated browser/WASM artifacts or other derived files, and when deciding whether to track, ignore, clean, regenerate, or restore them.
---

# Bus Generated Artifact Hygiene

Use this skill when generated outputs interfere with development, worker
promotion, or clean checkouts.

## Decide Ownership

Determine whether the file is source or derived:

- inspect Makefile/build rules
- check whether a clean command can regenerate it
- use `git ls-files` to see whether it is tracked
- identify the source inputs and command that produce it

Do not delete source assets such as `index.html`, loader scripts, CSS, or source
Go files when the generated output is only `app.wasm`, `wasm_exec.js`, or a
similar build product.

## Current WASM Rule

Portal-style modules should not track generated
`internal/ui/static/assets/app.wasm` or `internal/ui/static/assets/wasm_exec.js`
when Makefile targets can regenerate them. Add exact `.gitignore` rules, make
server builds depend on the WASM generation step when needed, and make `clean`
remove generated assets.

Use `git rm --cached` for tracked generated files that should remain present in
the working tree, or `git rm` when the checkout can regenerate them before
build/test. Follow the module's deletion safety rules.

## Worker Promotion

Dirty tracked generated artifacts in a primary checkout block worker starts,
reopens, and promotions. Do not repeatedly restore and retry without fixing the
root cause. Either untrack/ignore the generated outputs, adjust build rules to
write into recipient-owned temporary paths, or record a concrete infrastructure
PLAN item.

When a worker e2e needs helper binaries from dependency modules, build helpers
into recipient-owned temporary paths with explicit names. Do not write generated
binaries into read-only dependency checkouts.

## Verification

After artifact hygiene changes, verify:

- clean checkout build regenerates the artifact before it is needed
- module `clean` removes generated outputs
- `git status --short` stays clean after tests
- relevant unit/e2e/module checks pass
