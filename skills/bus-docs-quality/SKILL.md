---
name: bus-docs-quality
description: Use when editing BusDK public docs, SDD docs, docs navigation, Markdown examples, or documentation PLAN items, especially under docs/docs and sdd/docs.
---

# Bus Docs Quality

Use this skill for public documentation and SDD work. Keep public docs useful to
end users and reviewers; keep process guidance in `AGENTS.md`, skills, logs, or
module plans.

## Public Docs Rules

Do not add `AGENTS.md` under `docs/docs`; that tree is public output. Put
agent-facing rules in `docs/AGENTS.md` or a more specific non-public guide.

Avoid meta text such as "review this first" or worker DoD commentary inside
public pages. Organize pages so the review order is obvious from navigation,
page names, internal links, and compact content.

Remove duplicated explanations. Keep the canonical topic on one page and link
to it from dependent pages.

## UI Docs Shape

Under `docs/docs/ui`, use only:

- minimal `index.md`
- implemented semver patch directories such as `v0.1.16/`
- unfinished feature-candidate directories such as
  `fc-025-product-module-integration/`

Each version or candidate directory should have a compact `index.md` that only
links to inner files. Put real content in small, topic-specific pages. Do not
combine unrelated concepts such as navigation plus events, forms plus storage,
or state plus effects on one page.

Implemented versions may link to same-version or earlier implemented concepts.
They must not link forward to future candidates.

## Examples

Examples should match the current design:

- GX templates use `.gx`/Go syntax
- data may be JSON/YAML when the page is about data or configuration
- public CLI examples use the dispatcher form such as `bus gx ...`
- avoid inline JSON-like YAML; expand YAML when YAML is the right format

## Checks

Run documentation lint on individual Markdown files when practical:

```bash
bus lint path/to/file.md
```

For broader docs changes, run `make -C docs quality` from the superproject root
when that target is available. If it is absent or not relevant to the touched
files, run `bus lint` on the changed Markdown files and `git diff --check`
before closeout.

When dispatching docs workers, scope paths relative to the docs recipient, for
example `docs/ui/fc-025-product-module-integration`, not `docs/docs/ui/...`.
