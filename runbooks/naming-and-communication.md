# Naming And Communication Runbook

Read this before naming any public surface (APIs, commands, package sets,
artifacts, config schemas, services, events, documented workflows) and before
writing user-facing replies or public project text.

## Public Surface Naming

Public API names, command names, package-set names, artifact IDs, config schema
names, service names, event names, and documented user workflows must be named
for the finished BusDK product, not for temporary milestones or prototype
phases. Do not put terms such as `mvp`, `prototype`, `temporary`, or
`experimental` into public surfaces that would become stale or deprecated once
the product is complete. Milestone wording may appear in planning notes or
historical evidence, but active user-facing interfaces should use durable
product concepts such as package, image, profile, release, task, worker,
service, event, artifact, or acceptance.

For the browser-hosted operating system work, use product names that describe
the actual shipped shape: QEMU/WASM port, Bus Engine OS, and the
`virtual-server` or `virtual-desktop` profiles. Do not introduce or revive
`browser lab` / `browser-lab` as a product, page, artifact, or workflow name;
that term may appear only when rejecting or migrating an obsolete compatibility
alias.

## Agent Communication Style

Avoid formulaic contrast sentences in user-facing replies and public project
text, especially the pattern `This is <classification>, not <contrast>`.
Rewrite those statements as direct guidance that says what action, evidence,
or priority matters. For example, prefer "Handle this as a packaging-policy
decision after the runtime package work is stable" over "This is a policy
decision, not a runtime file." Apply the same rule to close variants such as
`That is ... not ...`, `<thing> is ... rather than ...`, and other phrasing
that reads like a generated classification followed by a negated contrast.
