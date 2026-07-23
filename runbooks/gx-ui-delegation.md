# GX/UI Delegation Runbook

Read this before any GX/UI cleanup, adopter migration, facade-parity,
assistantui, terminalui, or `pkg/uikit`-removal work, together with
`skills/bus-ui-gx-roadmap/SKILL.md`. These rules continue the root `AGENTS.md`
section `Supervisor Worker Delegation` as items 7a-15. General delegation
items 4-7 and 17-46 are in `runbooks/worker-delegation.md`; its items 6 and 7
carry additional GX/UI-specific clauses that also bind GX/UI lanes.

7a. For GX/UI module-owned worker prompts, do not assume the App Server
    product worktree opens at the BusDK superproject root. The first preflight
    must prove whether the effective cwd/root is the BusDK root or the target
    module root with `pwd`, `git rev-parse --show-toplevel`, and a small
    path-existence check for the scoped files and goal doc. Include an explicit
    path map in the live worker message: `product_worktree_root`, `busdk_root`
    if different or available, `target_module_root`, `goal_doc_absolute_path`,
    and `scoped_file_paths_relative_to_target_module_root`. Do not tell a
    worker to blindly `cd <module>` unless the proved product-worktree root is
    the BusDK superproject; if the worker is already in the module root, use
    paths such as `internal/run/run.go`, not
    `bus-chat/internal/run/run.go`. For goal-doc lookup from a module-root
    worker, provide the absolute `projects/busdk/docs/docs/goals/gx-ui.md`
    path or a preverified relative path such as
    `../docs/docs/goals/gx-ui.md`, instead of making each worker rediscover it.
    Before creating a GX/UI worker prompt, run a tiny supervisor-side path
    preflight against the actual worker base and nested module cwd for every
    referenced target, source, and test file. Use `test -f` or `rg --files`
    evidence from the target module root. Prompt tables must include only
    verified existing source files plus files explicitly labeled as desired-new
    targets. Remove stale paths instead of leaving them as hints; one
    nonexistent path can turn a mechanical Mini implementation slice into an
    avoidable source-map investigation turn.
7b. For GX/UI worker lanes, do not count the lane as active implementation and
    do not allow product edits until the worker proves the exact owning module
    source tree is populated. The first hard gate must include `pwd`,
    `git rev-parse --show-toplevel`, `git status --short`, and
    `test -f <scoped target file>` from the target module root, such as
    `test -f pkg/ui/ai_upload_facade.go` for the AI-upload facade blocker. If
    the checkout is only an empty submodule/gitlink, if `--module bus-ui` does
    not expose the expected `pkg/ui` tree, or if hydration requires GitHub SSH
    access the worker does not have, stop the implementation lane and
    repair/route worker materialization or local-reference hydration first.
    Do not spend repeated nudges on code patches inside wrong nested checkouts
    or unproven module roots.
8. For GX/UI API refactors, split mixed adopter cleanup by semantic surface and
   prefer one-surface or one-file verification rhythms over broad mechanical
   loops. Action/resource cleanup, WASM browser cleanup, terminal generic
   imports, and terminal stream/container request conversion should normally be
   separate worker slices with narrow commands and tests, so failures identify
   the component, facade, or adopter surface that broke.
9. In GX/UI architecture, `Action`, `Resource`, and `Effect` are shared public
   boundaries. For unpublished/internal-only GX/UI APIs, backward
   compatibility is not a goal by itself: do not keep `pkg/uikit`, `*Checked`
   compatibility wrappers, old string-first aliases, or local wrapper layers
   merely to preserve old call sites. Move or rewrite behavior into the
   correct public package or a new non-compatibility internal package owned by
   the node-first architecture.
9a. GX/UI facade parity must preserve behavior while matching the target public
    architecture, not blindly copying legacy `pkg/uikit` API shapes. Render
    and composition APIs should be node-first on the primary public facade;
    data and control-plane APIs should expose typed DTO/helper boundaries; raw
    HTML, string, or unsafe boundaries should exist only where intentionally
    part of the new design, not for unpublished backward compatibility. For a
    legacy renderer that only has HTML/string output, move or rewrite the
    implementation into the correct public or internal package first; then add
    a node-first public facade such as `RenderX` returning the new public node
    type, and an explicit boundary such as `RenderXHTML` only when callers
    intentionally need string output. Tests should prove the architecture
    shape and output behavior where it matters. Core facade review gates must
    reject green-test patches that merely wrap or alias `pkg/uikit` as the new
    implementation layer.
9b. For GX/UI core migrations that remove `pkg/uikit` as a backing
    implementation, do not dispatch a broad "move the whole facade" worker
    without a source-map table. The planning artifact must name the old
    `pkg/uikit` file/symbol group, the target owning package/file, the exported
    API that must remain, the behavior or test invariant, and the first focused
    test. Implement in this order: add or move real implementation into the new
    owner package first; add or preserve focused owner tests; then replace
    facade aliases or wrappers group-by-group. Do not delete or shrink the
    public facade file until the new owner implementation compiles and the
    public API compatibility is proven. For `assistantui`, split the
    uikit-removal blocker into micro-slices if a worker stalls or drifts:
    DTO/model types, event/status/history helpers, AI panel render and
    client-script behavior, and the js render-props adapter. Each micro-slice
    must end with `go test ./pkg/assistantui` or the exact first compile error,
    plus a scoped no-production-`pkg/uikit` audit for the touched assistantui
    files. A `PLAN.md`-only diff, deleted facade file, or package-comment-only
    facade is negative evidence; park that worker path quickly and relaunch
    with a smaller source-map slice. After each accepted micro-slice or full
    assistantui slice, rerun the hydrated deletion/build-exclusion probe to
    prove the matrix advances beyond `assistantui_ai_facade.go`.
10. In GX/UI adopter audits, production direct `pkg/uikit` imports and
    production `uikit.` references are blockers until classified or removed.
    Test harness `uikit`/`uikittest` usage and accepted asset URL strings such
    as `assets/uikit.css` must be classified separately, not blindly removed.
    Do not accept a local wrapper layer whose only purpose is hiding `uikit`.
10a. For GX/UI adopter implementation, do not mechanically replace
    `uikit.X(...)` with `ui.XChecked(...)` without reading the public helper
    signature and tests. Public `Checked` helpers are explicit
    string-boundary APIs with validation contracts, not drop-in replacements
    for old convenience helpers. Before broad patching, worker prompts should
    include a checked-boundary contract review step: list each old string
    helper, the chosen public node-first or checked boundary, required
    props/IDs/actions, and exact test invariant. For checked navigation,
    panel, and form helpers, preserve behavior by supplying stable IDs,
    action tokens, `ControlID`, `ControlName`, and matching rendered child
    `id`/`name` fields where required. If the product module already has an
    internal package named `ui`, deliberately alias the imported
    `bus-ui/pkg/ui` package, such as `busui`, to avoid import-name churn. If
    tests fail only on byte-fragile markup after the public checked contract
    is correct, update assertions narrowly around stable visible behavior,
    routes, and semantics rather than weakening the behavior check.
11. If a GX/UI adopter lane discovers a missing public facade needed to preserve
    accepted behavior, stop or return a no-change diagnosis and create a
    narrow core facade parity lane. Do not invent local wrappers, direct
    internal imports, or adopter-specific aliases to bypass the missing public
    boundary.
12. When a remaining GX/UI item is broad enough to hide facade parity or
    semantic-contract unknowns, pause before implementation workers and create
    a short planning or probe artifact in the task thread or goal document.
    The artifact should name exact files in scope, map old symbols or APIs to
    public facades, list behavior invariants, identify missing public facade
    gaps, split implementation slices, classify critical-path app-readiness
    work versus post-core cleanup/docs/tests, and state acceptance checks for
    each slice.
13. Before resuming a GX/UI adopter lane after a core facade parity patch, run
    or require a bounded facade and behavior parity probe for the exact files
    in that adopter slice. The probe prompt and task DoD must require an
    explicit table schema. Each old symbol or call-site must be classified as
    one of: public `ui`, public `terminalui`, explicit adopter adapter,
    test-only accepted, accepted asset/string, or missing public core facade.
    For every scoped test or behavior-sensitive call site, the table must also
    name the old behavior under `pkg/uikit` or existing adopter tests, the
    public facade symbol/type expected to preserve it, whether parity is
    already proven by a core test, whether the adopter may update only package
    types/imports or whether changed expectations mean a missing core parity
    lane, and the exact invariant to preserve. Risky invariants include
    request path, method, resource kind, result kind, callback invocation,
    `Done()` channel behavior, reconnect attempt behavior, provider/client
    error semantics, and no double-prefix paths. An inventory-only response,
    file dump, or generic "no missing facades" statement is not accepted probe
    evidence. Do not resume implementation until the supervisor has reviewed
    the classification table and it has no missing public core facade or
    missing behavior parity entries, or until those entries are split into
    narrow core facade tasks. If an adopter test expectation fails because the
    public facade regressed old behavior, pause the adopter and split a narrow
    core parity lane rather than weakening the test. If the worker probe is
    incomplete, reopen or nudge the probe for the table, or produce and review
    the table as a supervisor planning artifact before launching
    implementation.
13a. At the start of any broad GX/UI cleanup goal, and before reporting a
    "final" remaining lane or ETA, run a repository-wide production-surface
    audit for the target smell, not only the modules already active on the
    board. For GX/UI, audit production direct `pkg/uikit` imports, production
    `uikit.` references, `Checked`/`NodeChecked` helpers, raw HTML slot
    patterns, and docs/examples that teach deprecated APIs across all BusDK
    modules that apps may use. Turn the audit into an explicit inventory table
    grouped by module family with files/symbol patterns, production versus
    test/docs classification, app-readiness criticality, expected public
    facade, behavior invariants, immediate milestone versus deferred status,
    and whether a facade-parity probe is required. Tie ETA and backlog language
    to that inventory. If a surface is out of the immediate milestone, name it
    as deferred instead of leaving it undiscovered. After each accepted lane,
    refresh the repo-wide audit before saying cleanup is closed; the DoD should
    either show no remaining production hits in scope or name the deferred
    inventory with task refs.
13b. Keep broad GX/UI module-family probes output-bounded and table-first.
    The first worker turn must receive exact file scope and the supervisor's
    known hit list, then produce a compact classification table plus concise
    missing-facade list. Do not ask these workers to dump large file contents,
    paste broad `rg` output, or rerun repository-wide discovery when the
    supervisor already has the scoped inventory. If the surface is too large
    for one compact answer, require partial tables by category, such as
    CLI/server, browser/WASM, AI/render, and docs/tests; the accepted artifact
    is the table, not the search log. If a broad probe completes with
    `last_agent_message=null`, malformed output, or an oversized transcript,
    and one corrective nudge still produces no usable table, park that
    worker/runtime shape immediately and relaunch with a smaller prompt or a
    different configured template/runtime shape. When a probe table creates
    core follow-up tasks, rebaseline the inventory at once with those task refs
    and mark which module-family rows are blocked on each core task, so backlog
    and velocity reporting count newly split architecture work explicitly.
13c. Keep GX/UI backlog and dispatch reporting scope-gated against the active
    milestone. Every unfinished item counted in velocity or backlog should
    cite a goal-document inventory row, accepted/pending core slice, or task
    ref that is inside the active app-readiness milestone. When a worker or
    probe finds a new surface, first classify it against the goal document as
    active milestone, deferred cleanup, test/docs-only, or out of scope before
    adding it to the count. Before dispatching a new implementation worker,
    state which goal-doc row or core slice the work unblocks; if no row or
    slice exists, update the inventory or explicitly mark the work deferred or
    out of scope. After each accepted core slice, refresh the goal inventory
    and recalculate the active backlog so accepted work, deferred cleanup, and
    still-blocked adopter work are not double-counted.
13d. Once an active GX/UI adopter row has been probed enough to name
    implementation-sized surfaces, maintain a small explicit slice queue for
    that row before dispatching more workers. Each slice should name scoped
    files, accepted facade dependencies, behavior invariants, DoD checks, and
    whether the slice is active, deferred, or probe-needed. Velocity and ETA
    reporting should count those implementation slices, not only broad module
    family rows, while still summarizing related slices as one supervision lane
    when useful. After accepting a partial slice, update the goal row by
    removing completed files and confirming the remaining pre-listed slices
    instead of treating the remainder as newly discovered work at the next
    monitor sample. If a sub-slice depends on unclear facade ownership, mark
    it `probe-needed` with a concrete probe DoD rather than hiding it inside a
    broad row count.
13e. GX/UI ETA and "remaining work" reports must distinguish visible active
    workers, known active implementation slices, and total discovered or
    enumerated slices since the baseline. Do not use worker count or broad
    module-family row count as the ETA denominator once probes reveal multiple
    implementation-sized surfaces inside a row. For GX/UI or any broad cleanup
    goal, the initial planning artifact must show the exact canonical module
    set from the goal document, the exact audit commands, and a row for every
    matching production surface before dispatching implementation workers or
    reporting ETA. A repo-wide audit is not satisfied by checking only active
    workers, dirty modules, or the first-wave worker queue; it must cover the
    full goal-doc module set. If the supervisor deliberately starts a smaller
    tactical wave, status must label it as "first-wave execution queue only,"
    not "unfinished work" or "final backlog." When the operator explicitly
    requests the broad audit first, include a proof line in the next report:
    "Full goal-scope audit completed over modules X; excluded Y as
    test/docs/deferred; current implementation-slice count Z." If that proof
    is missing, do not claim an ETA. Require facade-parity probes before
    adopter implementation estimates when scoped files still depend on
    `pkg/uikit` for behavior-rich helpers. Treat newly revealed sub-slices
    inside a known row as estimation debt and an instruction-following failure
    when a broad audit was requested, not random surprise; update the row's
    sub-slice queue immediately so the next monitor sample does not rediscover
    it.
13f. For GX/UI, derive the end-user module set mechanically from Go module
    dependencies before relying on remembered goal rows. The first/current
    inventory step must scan `go.mod` files for dependencies on
    `github.com/busdk/bus-ui` and `github.com/busdk/bus-gx`, compare that
    dependency-derived set with `docs/docs/goals/gx-ui.md`, and classify every
    module in either set as active, accepted, deferred/test-docs-only, or out
    of scope. For each dependency user, run or delegate two independent gates:
    `go test ./...` for public facade/API compatibility, and a production
    static audit for forbidden old-surface imports/usages such as direct
    `github.com/busdk/bus-ui/pkg/uikit` in non-test app code. Tests alone are
    not enough while compatibility shims still compile. Use the
    dependency-derived module set as the denominator for "all end users
    counted," then use the implementation-slice queue as the denominator for
    ETA. When core `bus-ui` or `bus-gx` work is believed complete, prove it by
    testing every dependency user and separately proving the old-surface
    production audit is clean or has named active/deferred slices.
13g. Use a throwaway `pkg/uikit` deletion or build-exclusion compile-break
    probe as the authoritative sequencing gate for GX/UI compiler blockers,
    not as the whole scope or ETA denominator. The full repo/module static
    inventory defines remaining scope: dependency-derived module set,
    production direct `pkg/uikit` imports, production `uikit.` calls, owner
    `pkg/ui`/`pkg/assistantui`/`pkg/terminalui` facades still backed by
    `uikit`, and separate tests/docs/examples rows.
    The probe must run in a worker-owned branch/worktree and must not be
    promoted until all replacement tasks are accepted. Remove or build-exclude
    `bus-ui/pkg/uikit` and `bus-ui/pkg/uikit/uikittest`, then run
    `go test ./...` in `bus-ui` first and across every dependency user
    discovered by the `bus-ui`/`bus-gx` go.mod scan. Convert compiler failures
    into an inventory split by owner: core `bus-ui` public facade
    implementation still backed by uikit, adopter direct imports, test harness
    replacement, docs/examples/catalog residue, and truly deferred or
    out-of-scope items. Do not count "adopters stop importing uikit" as the
    whole remaining scope; removing `uikit` as a backing implementation layer
    from `bus-ui` itself is part of the end state unless a specific behavior is
    moved into a new non-compatibility internal package.
    Before reporting ETA, update the goal document with concrete source-map
    rows for every currently visible core and adopter surface, mark parent or
    planning rows non-counting once split, and classify tests/docs/examples
    separately from production. For unpublished internal code, do not preserve
    compatibility layers as a finish strategy; move behavior into the intended
    public facade or a deliberate non-compatibility internal owner.
    During the same inventory pass, classify repeated work for automation:
    deterministic audit/probe runners and alias/import codemods, generated
    patch skeletons that still require review, or reasoning-heavy/manual rows.
    Prefer the smallest temporary local tool only when it replaces repeated
    worker turns or repeated supervisor scans; do not build broad tooling
    before the inventory proves it will save quota.
    Before interpreting `go test ./...` output from a deletion/build-exclusion
    probe, hydrate the owner module's full local `replace ../...` graph in the
    worker-owned product worktree. For `bus-ui`, prove replacement siblings
    such as `bus-gx`, `bus-help`, and `bus-update` are present at the
    BusDK-pinned SHAs before treating compile output as product evidence. For
    downstream dependency-user modules, first scan that module's `go.mod`
    `replace ../...` entries and either hydrate those siblings or classify the
    row explicitly as environment/hydration-only, not GX/UI product work. The
    accepted deletion-probe inventory must include a short setup-proof header:
    owner module, local replace modules hydrated, pinned SHAs or explicit
    environment gaps, then the real post-deletion compiler failures.
    After each accepted core blocker exposed by this probe, immediately rerun
    the hydrated deletion/build-exclusion probe far enough to prove the matrix
    advanced past that blocker. Normal `go test ./...` in `bus-ui` is not the
    whole DoD for a deletion-probe-derived core slice; update the inventory row
    with the next compiler failure, or with a "clean through this owner/module"
    proof if the probe no longer stops there. Apply the same cadence after
    assistant/core facade fixes before dispatching more adopter work, so the
    active backlog follows the authoritative compiler matrix rather than stale
    rows.
    After every hydrated deletion-probe advance, also run a static production
    audit in the owner module for remaining `pkg/uikit` imports and `uikit.`
    calls. For `bus-ui` core work, audit `pkg/ui` non-test Go files and add
    or refresh table-first goal rows for each visible future facade/file with
    a concrete source-map or DoD. Report the next compiler blocker separately
    from the remaining known core backlog; the deletion probe still chooses
    sequencing, but backlog and ETA must not compress known future core facade
    work into a single row. Keep adopter lanes parked until the core
    production owner-module audit is clean or every remaining hit is
    explicitly scoped, deferred, and counted with a row and definition of done.
14. After a core facade or behavior parity blocker is accepted, any GX/UI
    adopter worker carrying an old dirty diff must prove a fresh product
    root/module base and produce the bounded symbol-plus-behavior table before
    implementation continues. Timebox that fresh-base gate in the next short
    supervision window: count only fresh-base proof plus table, output, or
    reviewable diff as active progress. If the worker cannot move from the old
    base to the new pinned base promptly, preserve its diff as reference
    evidence, stop or park it, and launch a clean worker on the accepted BusDK
    pin unless the attempt exposes a concrete infrastructure or rebase failure
    that needs its own task.
15. For GX/UI WASM adopter slices, separate product failures from verifier-host
    or toolchain proof gaps. Before treating a `GOOS=js GOARCH=wasm` failure as
    product work, record the exact `go` binary, `go version`,
    `GOOS=js GOARCH=wasm go env GOROOT GOOS GOARCH GOEXPERIMENT`, and a tiny
    control such as `GOOS=js GOARCH=wasm go list std` or a minimal package that
    imports `syscall/js`. If the control fails broadly across standard library
    packages, route WASM proof to a known-good worker, host, or toolchain, or
    record a named environment proof exception while keeping product acceptance
    grounded in native tests, scoped no-legacy-surface audits, worker diff
    review, and any available WASM-side worker result. If the control succeeds
    but the module fails, keep it as product work and name the first compile
    error, file, and symbol. Record the environment used for final WASM proof
    in the goal or memo.
