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

## Live Working Memo

This section is core operating memory for Codex agents in this repository. Do
not compact it out of root `AGENTS.md`, move it only to a less visible skill, or
replace it with a pointer. Other guidance may summarize it, but this root file
must preserve the live memo contract itself.

1. Maintain a live working memo during every substantial work session. The memo
   is hourly based.
2. At the start of work, create or update
   `./logs/{YYYYMMDD}-{HH}-agent-memo.md`, where `YYYYMMDD` is the current
   local/project date and `HH` is the zero-padded 24-hour hour when that memo
   period starts. Create `./logs` if it does not exist.
3. Use the current local/project time when naming memo files. Continue writing
   to the same memo only while the current hour remains the same.
4. When the hour changes, finish the current memo with a short handoff note
   explaining the current state of the work, what is complete, what is still in
   progress, what was verified, what remains uncertain, and what should happen
   next. Then create or continue the next hourly memo for the new hour.
5. Write each memo as an editorial engineering diary in story form. It should
   read like a clear narrative of the work session, not like a checklist,
   changelog, or raw activity dump.
6. The memo should let a future maintainer, human reviewer, or AI agent
   understand the flow of work: what the agent was trying to accomplish, what
   it found, why it made certain choices, where it hesitated, what changed,
   what went wrong, what worked well, and what could be improved next time.
7. Use Markdown. Prefer narrative paragraphs over lists. Headings may be used
   when helpful, such as `## Session Context`, `## Work Narrative`,
   `## Observations`, `## Decisions`, `## Tests and Checks`,
   `## Problems and Friction`, `## Improvement Ideas`, `## Hourly Handoff`,
   and `## Final State`.
8. Lists are allowed only when they genuinely improve readability, for example
   for compact test results or final next steps.
9. Update the current hourly memo throughout the hour after meaningful phases
   of work. Add a short narrative note explaining what just happened and what
   it means.
10. Do not merely write "ran tests" or "updated parser." Explain why tests were
    run, what the result suggested, why a change was needed, whether the change
    felt clean, and whether any concern remains.
11. If work changes direction, describe the reason. If an assumption turns out
    to be wrong, record how that changed the approach. If a command fails,
    explain the failure, likely cause, and next action.
12. Before making a risky, broad, or hard-to-reverse change, write a short note
    explaining the intended change, why it seems necessary, and what risk it
    carries. After making the change, update the memo with what actually
    happened.
13. If no code changes were made during an hour, still write the story of that
    hour: what was examined, what was learned, what remains uncertain, and what
    the next useful action would be.
14. Keep the memo truthful, concise, and useful for later learning. Do not
    claim planned work as completed. Do not invent successful results. Clearly
    separate facts from interpretation. Mark uncertainty, failed attempts,
    skipped checks, and assumptions honestly.
15. Avoid blame-oriented language. Focus on what the project, tooling,
    architecture, process, tests, or prompts can learn from the session.
16. Summarize long command outputs instead of pasting them in full, and mention
    how the result can be reproduced when useful.
17. Treat committed logs and memos as public repository content. Never write
    secrets, API keys, passwords, tokens, private customer data, proprietary
    customer details, raw `.env` contents, or other sensitive values into memos
    or committed logs. Summarize or redact sensitive evidence instead.
18. When investigating environment variables or config files, query only the
    exact non-secret key needed, or report whether a key exists without
    displaying unrelated values.
19. Do not edit historical hourly memos after the hour/session has passed
    except to remove sensitive information or undo an accidental inappropriate
    edit. Later lessons from old memos should be captured in the current memo
    or in durable project guidance.
20. Before finishing a session, review the current hourly memo. Make sure it
    explains not only what changed, but how the work unfolded and what can be
    learned from it.
21. End the final memo for the session with a concise final state: what is
    complete, what remains incomplete, what was verified, what was not
    verified, and what the next agent or maintainer should probably do next.
22. Every hourly memo should contain enough handoff detail that another agent
    can resume without re-reading the whole conversation. For broad work,
    include compact coverage of the current goal, key decisions, modified
    files, commands and tests run with outcomes, blockers, active follow-ups,
    and important context.
23. When Bus Notes is available and configured, delegated workers or
    long-running agents may also publish concise notes through `bus notes` so
    the work becomes searchable and attributable. Local
    `./logs/*-agent-memo.md` files remain the canonical session diary unless
    this repository explicitly chooses Bus Notes as the primary store.
24. If Bus Notes is unavailable, unconfigured, or inappropriate for the current
    repository, continue with local memo files only and mention that limitation
    in the memo or final handoff when relevant.

## Supervisor Worker Delegation

This section is core operating memory for Codex supervisor agents in this
repository. Do not compact it out of root `AGENTS.md`, move it only to a less
visible skill, or replace it with a pointer. Other guidance may expand it, but
this root file must preserve the supervisor/worker boundary itself.

1. In supervisor mode, all implementation work that can be delegated must be
   done through Bus task/work workers, not by the supervisor directly editing
   product or module code in the primary checkout.
2. The supervisor's default job is to define work, update PLAN/memo guidance,
   dispatch workers with clear scopes and acceptance criteria, monitor
   progress, provide guidance, review results, reopen incomplete work, promote
   accepted commits, and keep the board moving.
3. The supervisor may edit repo guidance, `PLAN.md`, live memos, and narrow
   coordination artifacts when those edits are themselves supervision work.
4. Codex background threads for BusDK superproject work must make the owning
   repository or module path operationally real before edits. Prefer opening
   the thread on the exact saved module project when available. If only the
   supervisor project is a saved Codex project, the thread may start there
   only when its first product step is to create and use an isolated worktree
   for the single target module. Split broad cleanup or salvage reviews by
   module owner when any follow-up edit may be needed.
5. For local App Server workers on BusDK submodules, send the worker the exact
   absolute product-worktree path as soon as `bus workers status` reports it,
   then tell it to `cd <module>` inside that tree before any file edit. Also
   name the primary checkout path as out of scope. If a worker log or command
   output references the primary checkout path after that, stop the worker,
   preserve any leaked patch, restore only the leaked primary files, and
   relaunch with stricter path guardrails. Do not trust a worker diff until the
   primary checkout for that module has been checked clean.
6. Worker creation is not proof of execution. After creating a worker, send an
   explicit start message unless the worker stream already shows assistant
   output from the intended prompt. Count a lane as active only after three
   signals exist: the assistant/event stream has started, the worker-owned
   worktree has either a diff or a clear no-change diagnosis, and the task
   thread records the current prompt. A `running`/`ready` worker with no
   assistant output, command trace, or diff is queued capacity, not progress;
   inspect session logs and nudge or replace it instead of waiting on elapsed
   time alone. Treat prompt files as supervisor reference artifacts, not as
   the worker's primary task context. For every replacement or implementation
   worker, send a live worker message that includes the complete scoped task,
   exact paths, accepted base pins, DoD checks, and first concrete action; do
   not ask the worker to discover a runtime-local prompt file. The first live
   checkpoint must verify assistant stream, fresh-base/root SHA evidence, and
   either a first diff or a concrete no-change/facade-gap diagnosis within one
   short supervision window. For small implementation-only GX/UI lanes, if a
   worker says it is patching but the owned tree remains clean after the gate,
   stop counting it as active implementation and either send a minimal inline
   patch plan or park/replace the worker. If that minimal inline patch plan
   still leaves the tree clean after the next checkpoint, park or replace the
   worker instead of sending another broad nudge. After two clean-tree
   implementation workers on the same GX/UI slice have received complete live
   context plus a minimal patch plan and still produce no diff or concrete
   missing-facade diagnosis, stop retrying the same runtime/model/prompt shape;
   more identical replacements are not active product progress. Before any
   further implementation retry on that same child slice, simplify first:
   create a supervisor-owned source-map and patch-target table with direct file
   paths, exact symbol lists, and no glob-heavy or regex-heavy discovery
   commands. If a GX/UI micro-slice remains no-diff because it discovers
   package-owned helper or API-shape questions, convert immediately to this
   planning gate before the next implementation attempt. The planning artifact
   must name the exact owner for node types, helper symbols, facade alias
   removals, file targets, and focused tests. If ownership or API shape is
   still conceptually ambiguous, use a
   `gpt-5.5` planning/source-map pass to produce the mechanical patch plan,
   then delegate that simplified implementation to the normal supported worker
   first. Escalate the implementation worker to `gpt-5.4` or `gpt-5.5` only
   after the simplified task still fails because of reasoning or API-shape
   complexity, not because of checkout materialization, prompt shape, or
   tool-router errors. Otherwise escalate the execution path: choose a
   different runtime known to apply patches, route a narrow worker-infrastructure
   diagnosis for App Server or tool-router clean-tree behavior, or ask the
   operator for a narrow supervisor exception to implement the already-scoped
   patch in a worker-owned worktree with normal review and promotion. Keep the
   product backlog count stable unless a concrete missing facade or
   infrastructure repair task is created with its own definition of done, and
   preserve the accepted table and mechanical patch plan as the next attempt's
   starting material. When using that reviewed worker-owned exception path for
   GX/UI, preflight the exact edit context first: read the current alias/import
   blocks and target helper files, patch new implementation files separately
   from alias removals, verify `git status --short` after each chunk, and only
   then run gofmt, tests, and scoped audits. Do not start a large multi-file
   exception patch before the exact context is known, because one stale hunk
   must not erase otherwise-ready progress.
   For the GX/UI form-controls split, treat `pkg/ui/control_uikit_bridge.go`
   as a temporary split aid, not a durable compatibility layer. Every remaining
   form-controls child review must say whether that child shrinks, deletes, or
   leaves each bridge conversion unchanged; if a conversion remains, name the
   exact not-yet-moved boundary that still requires it. By the final
   form-controls alias-removal/deletion-probe child, the bridge must either be
   gone or explicitly reduced to only still-compiler-derived non-form-control
   work from the latest deletion matrix.
   GX/UI planning/source-map workers must satisfy the same owning-module
   hydration gate before their output counts as evidence: prove `pwd`,
   `git rev-parse --show-toplevel`, `git status --short`, and the target files
   from the planning prompt in the exact module root. If a planning worker has
   an empty module checkout or cannot see the target files, stop it as a
   materialization failure; do not treat its no-file diagnosis as a product
   source-map result.
   Before launching another GX/UI product worker after a worker/service
   execution repair, run a local worker health gate across the full
   storage/control-plane chain: prove there is enough disk for service writes;
   prove Postgres is running or recovered; prove a direct Events publish
   succeeds; prove Repos is running and materializes a product workspace; prove
   Workers and API respond from a live PID rather than only a stale status
   file; prove the launched command resolves to the checked-out BusDK
   dispatcher or module binary and supports the profile flags, especially
   `--token-file`; prove the deployed worker integration code includes any
   required evidence-window repair such as the three-minute direct message
   timeout, or state explicitly that it has not reloaded; and run one tiny
   non-product worker/message smoke that produces assistant output inside the
   evidence window. Until Workers API message projections include assistant
   response text, do not count `message.response` with `status=delivered` as
   assistant progress. For product workers, require assistant text in the
   worker Codex session JSONL, a real worker-owned git diff or commit plus
   required check output, or explicit runtime error evidence; `ready`, a clean
   worktree row, and delivered-only messages are transport evidence only. For
   tonight's GX/UI local App Server work, use `--environment local-dev` only
   unless the worker system is repaired and a smoke proves another environment.
   `--environment local` has accepted create requests that did not materialize
   in the live local pool or produced unusable module roots. Treat an
   accidental `local` create as an environment-routing mistake, stop or ignore
   it immediately, and do not wait on it as product capacity. For
   tonight's GX/UI data/evidence lanes, prefer `gpt-5.4-mini` on the local App
   Server substrate unless Spark first passes a fresh assistant-output smoke;
   Spark materialization without assistant text is false-active capacity.
   For GX/UI render tests, verify the target package's GX intrinsic elements
   or constructors before writing expected markup, or reuse elements already
   proven in neighboring tests. Do not assume generic HTML tags such as
   `strong` or `em` are available in the GX intrinsic table.
7. Before adopter workers edit against newly accepted shared facades, require a
   fresh-base preflight in the worker message that names the repository root
   for every SHA check. In nested BusDK/product worktrees, BusDK commits,
   module commits, and supervisor commits live in different repositories; a
   correct preflight prints `pwd`, `git rev-parse --show-toplevel`, the BusDK
   superproject HEAD from the worker's product-worktree root, the target module
   root and module HEAD from the module directory, and relevant submodule pins
   from the BusDK root when the task depends on a core facade commit. Do not
   write generic "must include commit X" prompts without stating which repo is
   expected to contain that commit. If a core facade lands while an adopter
   worker is already running, treat stale-base promotion as a review risk and
   rebase, recreate, or explicitly justify acceptance before promoting its
   patch.
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
    different model. When a probe table creates core follow-up tasks, rebaseline
    the inventory at once with those task refs and mark which module-family
    rows are blocked on each core task, so backlog and velocity reporting count
    newly split architecture work explicitly.
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
    probe as the authoritative truth gate when counting remaining GX/UI work.
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
16. The only normal exception for direct implementation edits is when there is a
   real blocker and the infrastructure needed to run Bus task workers is not
   available, and the direct edit is the narrowest safe change to restore that
   worker infrastructure.
17. If the worker substrate is partially usable, prefer dispatching an
   infrastructure worker or reviewer worker over local implementation. Use the
   supervisor checkout for investigation and evidence gathering, not for
   absorbing product implementation.
18. When the supervisor must make an exception, record the reason in the current
   hourly memo, including why worker delegation was unavailable, what exact
   infrastructure path was restored, what verification was run, and which tasks
   should be reopened or dispatched afterward.
18. Periodically compare recent hourly memos, task statistics, and active-worker
   evidence against the active goal. If independent parallel capacity is
   underused, explicitly dispatch/refill unblocked work or record the concrete
   blocker; report utilization truthfully instead of implying full capacity
   when the board is idle or thinly staffed.
19. Treat each periodic memo/task-stat review as an operating-control loop, not
   as a retrospective note. The review must end with one of these concrete
   outcomes: updated PLAN/tasks, new or reopened worker dispatch, promoted or
   rejected worker output, a documented automation improvement, or a specific
   reason why no safe parallel work can be started. If the review finds
   underutilization, stale workers, repeated manual steps, or evidence gaps,
   convert that finding into the next supervisor action before returning to
   ordinary status reporting.
20. For every substantial supervisor session and every progress report on an
   active multi-worker goal, do a compact goal-health review before answering:
   recent memo evidence, active workers per environment, independent unblocked
   work topics, accepted/promoted output since the previous review, current
   bottleneck, and the next dispatch/reopen/promote action. If the review shows
   idle capacity on H100, dev-hg, local, or other configured environments, fill
   it with scoped work unless a concrete blocker prevents it.
21. Measure the supervisor process by accepted work and learning rate, not by
    activity. Record when actual parallelism is materially below available
    capacity, when the supervisor absorbed work that should have been delegated,
    when a worker lane failed because of platform friction, and what guidance,
    PLAN item, automation task, or worker dispatch was created to prevent the
    same stall from recurring.
21. For broad goals, use delegated supervisor agents as the normal scaling
    unit. The lead supervisor should own global priority, acceptance, pinning,
    and operator communication, while sub-supervisors own work lines such as
    remote freshness/proof, parallel lane refill, review/promote triage, or a
    specific module family. A sub-supervisor should not merely write a one-shot
    report: it should start safe workers, monitor them, refill the lane when a
    worker exits, and leave accept/reopen guidance with evidence.
22. Lead supervisors and delegated sub-supervisors must read and apply
    `skills/bus-product-delivery-supervisor/SKILL.md` and
    `skills/bus-dev-task-worker-ops/SKILL.md` before running broad supervisor
    loops, dispatching workers, or reporting progress on multi-worker goals.
    Sub-supervisor prompts must include these skill paths so the scaling loop
    is not lost when work is delegated to another agent.
23. After accepting and pinning changes that affect worker launch, Events sync,
    remote credentials, worker images, model/runtime configuration, or Bus
    developer tooling, update configured remote environments before using them
    as proof. Verify the remote checkout commit, affected submodule SHAs, and
    rebuilt/installed binaries or images. If a remote still runs stale software,
    treat that as an operating issue to fix or delegate, not as product
    evidence.
24. Permission prompts are exceptional. Supervisors must first use already
    approved commands, remote workers, and configured Bus services. Do not ask
    the operator for permission for routine Markdown edits, worker monitoring,
    SSH status checks, remote dispatch, or deterministic verification. If the
    local sandbox blocks Git metadata writes or another required operation,
    continue independent remote/worktree work where possible and request
    permission only when that exact operation is required to finish an accepted
    change.
25. Do not keep broad, vague checklist items as the active operating plan.
    Before reporting a goal checklist or dispatching workers, split fuzzy items
    into module-owned `PLAN.md` entries with concrete DoD: the command or user
    workflow that must work, the service/runtime owner, the required evidence,
    the verification command, and the condition that lets the checkbox be
    closed. Remove or explicitly defer items that are not required for the
    current minimum goal.
    - Do not label general remote-worker features as H100-only unless H100 has
      a genuinely different implementation path. Use H100/dev-hg as test
      environments for the same product feature.
    - Treat configuration/proof work as verification for a feature, not as a
      vague implementation item. If the implementation is really systemd
      service install, remote freshness, credential resolution, or App Server
      model switching, name that feature directly.
    - Split statistics and operator-path work by the exact facts collected or
      command made usable, such as attempt identity, requested/observed model,
      failure reason, recovery/intervention attribution, install command,
      refresh command, status command, or evidence command.
26. When the operator corrects the architecture or priority, update durable
    guidance or the owning `PLAN.md` in the same work session. Do not rely on
    chat memory for repeated lessons such as single-binary/systemd deployment
    shape, per-remote credential sources instead of process-global tokens,
    App Server as the normal worker backend, or H100/dev-hg capacity usage.
    For local Bus worker services, the supported Codex path is the Codex App
    Server protocol, normally launched as a host process so macOS supervisor
    hosts do not require Docker or nested virtualization. Do not reintroduce
    `codex exec`, `direct-exec`, `direct` runner kind, or `codex-direct`
    provider as the operator-facing worker path; add new providers such as
    `bus-agent-runtime` behind the worker provider/App Server-style contract.
    When a normal implementation worker stalls, simplify the task before
    switching it to a smarter model: split planning from implementation,
    narrow the files, and make the implementation DoD mechanical. For hard or
    unclear architecture/source-map work, use `gpt-5.5` for the planning or
    table artifact when needed, then delegate the simplified implementation to
    the normal supported implementation worker first, such as Spark on the
    current App Server substrate or Mini only where that model is actually
    supported. Escalate implementation to `gpt-5.4` or `gpt-5.5` only after
    the simplified implementation still fails because of reasoning or behavior
    complexity, not because of checkout materialization, unsupported model
    mapping, bad prompt shape, missing hard gates, or quota state.
27. Treat important operator corrections, focus reminders, naming lessons, and
    repeated “don’t do that” guidance as durable memory work, not just chat.
    When the lesson is expected to matter again, write it into the most
    specific relevant `AGENTS.md` in the same session, and update the current
    hourly memo to record why it mattered. Use `PLAN.md` alongside `AGENTS.md`
    when the lesson also changes execution order or acceptance criteria.
    Stage and commit `PLAN.md` changes directly on `develop` in the owning
    repository before moving on; do not leave planning edits as uncommitted
    supervisor checkout drift.
28. For the H100/remote-worker goal, prioritize the minimum real-work loop over
    adjacent product polish: one configured model can be enough, private image
    delivery can be deferred when source-checkout/App Server works, and stats
    can be improved while testing instead of blocking the first accepted loop.
    Keep the checklist focused on work that directly makes remote workers
    productive and repeatable.
29. For unfinished BusDK goals, do not report "not proven" or "not done" as a
    blocker. Before stopping or asking the operator, decompose the remaining
    work into concrete module-owned items with DoD: the command or workflow
    that must succeed, the owner module, required evidence, expected files or
    services touched, and the verification command. For each item, ask whether
    it is truly in the current goal scope or should be deferred. Use the live
    memos to estimate how long the current approach has failed; if the answer
    is hours of unsuccessful work, ask the operator for scope refinement or
    supervisor help with the precise decision needed. When rereading memos,
    check whether the work repeated mistakes the operator had already
    corrected, and immediately improve `AGENTS.md`, `PLAN.md`, or the relevant
    runbook when the instruction was too easy to miss.
30. At BusDK session closeout, review the current hourly memo against these
    operating rules and the operator corrections recorded during the session.
    If the work drifted from the rules, say so in the memo and improve the
    smallest relevant `AGENTS.md`, `PLAN.md`, or skill runbook before
    finishing the session.
31. Use precise acceptance vocabulary. A worker that is `created`, `claimed`,
    `running`, `done`, or even promoted inside an isolated/remote checkout is
    not accepted project progress until supervisor-side review verifies the
    diff, required checks pass, the owning branch is promoted or repaired, and
    the superproject pin is updated when applicable. Reports and memos must
    distinguish: task created, worker claimed, worker produced a diff, worker
    branch promoted, supervisor accepted, root pinned, pushed, and released.
32. When a worker result is partly useful but fails review, prefer the normal
    iterative production loop: reopen with exact findings, hand the repair to a
    stronger model or reviewer lane when useful, or make the smallest
    supervisor acceptance repair only when delegation is blocked. Do not
    describe a first-attempt failure as H100/model failure when the overall
    attempt-review-repair-promote loop is still producing accepted work.
33. Treat pause/release mode as a hard drain-and-collect workflow. When the
    operator pauses new development or asks for a release, stop scheduling new
    work; inspect local, dev-hg, H100, and other configured environments for
    queued/claimed/running tasks; cancel stale queued or false-active streams
    with evidence; collect useful remote patches/logs before stopping
    services; verify no environment has commits ahead of its upstream that need
    retrieval; verify the root checkout is clean; then run the requested
    release command.
34. Treat worktree cleanup as review-first. Prefer first-class Bus prune
    commands and dry-run reports over manual deletion. Do not run destructive
    cleanup while task refs are active or while Git locks may still represent
    live work; use `--apply`-style cleanup only after reviewing the dry-run
    candidates, active-task refusal evidence, and submodule worktree registry
    behavior.
35. After solving a BusDK infrastructure issue, record the reusable diagnostic
    path in the current memo and the most specific `AGENTS.md`. The note must
    include the original symptom, the wrong or stale assumption, the decisive
    command/log/observation, the invariant that fixed it, the verification
    command or proof, and the first check to run next time. This is required
    for worker launch, App Server, Events relay, service startup, install or
    version skew, route pairing, credential, and local safety-filter failures.
36. When a worker or App Server path fails with a vague execution error such as
    "no such file or directory", do not guess at task/worker architecture
    first. Check the exact service process argv, selected binary path, worker
    workdir, App Server allowed directories, sandbox/network policy,
    environment id, and the installed-vs-source commit. Add narrow diagnostics
    that expose paths, ids, booleans, and command names without secrets; then
    reproduce with a fresh worker message before accepting the fix.
37. When a locally built fix does not affect a service or remote proof, assume
    release skew until disproved. Verify the executable that `bus services up`
    launches, the superproject commit, affected submodule SHA, install target,
    and remote checkout before changing product logic. If `make clean build
    install` or submodule refresh is the intended release step, run it before
    judging runtime behavior.
38. When Events relay behavior surprises task or worker flows, inspect Event
    metadata first: origin environment, destination environment,
    sync-target ids, recipient ids, task ref, worker id, correlation id, route
    owner, and durable cursor namespace. Product relay eligibility must not
    depend on event names. Add hermetic fake-transport tests for the Event
    metadata and cursor behavior that caused the surprise, and use live SSH
    proof only as an end-to-end acceptance layer.
39. After the service-owned Events relay MVP is accepted, BusDK product work
    must use Bus tasks and persistent Bus worker identities as the normal and
    exclusive execution infrastructure. Supervisors define task refs, pick or
    create worker identities, send guidance with `bus workers message`, monitor
    Events/status/log evidence, review diffs, reopen incomplete work, and
    promote accepted branches. Supervisors do not directly implement product
    changes or run direct compile/test/install loops as a substitute for worker
    work.
40. Prefer `gpt-5.3-codex-spark` for BusDK worker identities and dispatches
    unless the operator explicitly requests another model or a task has a
    concrete model-specific requirement. When a worker must use a different
    model, record the reason in the task stream or memo.
41. Keep the local dispatch surfaces separate. Bus task
    creation/status/events use the Events API surface, currently
    `bus task --api-url http://127.0.0.1:8081/local/v1 --token-file
    .bus/tokens/local-events.jwt ...` and matching `bus events ...` commands.
    Persistent worker list/create/control/message uses the Workers API
    surface, currently `bus workers --api-url http://127.0.0.1:8090/local/v1
    --token-file .bus/tokens/local-events.jwt ...`. Live worker prompts must
    use the supported `bus workers message ... --text <prompt>` shape, not
    guessed positional prompt text. A bare `bus workers list` may hit the
    legacy/default surface and print no workers; do not treat that as evidence
    that the persistent worker store is empty without checking the configured
    Workers API.
42. The default local Services stack must not require SSH access to
    `dev.hg.fi` or any other remote worker host. `bus services up` must start
    the local control-plane services needed for task submission, review, and
    local worker orchestration without Events relay credentials. Keep
    `events-relay` and remote sync/proof services optional, for example behind
    `--all` or explicit profile selection, so missing remote host keys or SSH
    credentials cannot block local development.
43. Temporary supervisor, worker, proof, and scratch worktrees must live under
    an ignored scratch path, normally `tmp/worktrees/` in this superproject or
    the Services-owned `.bus/services/workers/...` runtime paths. Do not create
    new temporary worktrees, symlink farms, or proof checkouts under
    `projects/busdk/worktrees`; that path is visible to Git status and should
    stay empty unless a future tracked product feature explicitly owns it.

## Recipient-Scoped Worker Focus

1. Recipient-scoped implementation workers are not supervisors. They should
   follow the recipient-local `AGENTS.md` and the explicit task brief first,
   and should not inherit broad supervisor habits such as repo-wide memo,
   PLAN, README, or throughput review unless the task explicitly asks for
   those.
2. For minimal implementation or proof lanes, start with the exact failing
   command, named files, stale text, or acceptance surface given in the task.
   Do not spend quota reading root hourly memos, unrelated `README.md` files,
   unrelated `PLAN.md` files, or broad repo guidance unless the named surface
   is insufficient to complete the task honestly.
3. Root supervisor guidance about dispatch boards, throughput reviews, memo
   operating loops, broad plan grooming, and cross-module coordination applies
   to supervisors and sub-supervisors. It is not default required work for a
   recipient-local implementation worker turn.

## Parallel Supervisor Operating Standard

This section is core operating memory for broad BusDK goals. Do not compact it
out of root `AGENTS.md` or move it only to a skill. It exists because repeated
memo evidence showed the supervisor could reach high throughput for one hour
and then fall back to one-worker-at-a-time execution.

1. Broad goals must run from a ready queue, not from a single next task. At any
   time the supervisor should maintain a short list of scoped, unblocked,
   module-owned tasks that can be started as soon as capacity exists.
2. Review is asynchronous work, not a reason to stop dispatch. While accepted
   or terminal worker output is being reviewed, the supervisor must keep
   independent lanes filled unless the checkout is dirty in a way that would
   make dispatch unsafe.
3. Each hour of a broad active goal must record numeric utilization in the
   memo: tasks accepted/promoted, task refs actively worked, peak active worker
   count, environments used, and the reason any available safe environment had
   no workers.
4. Use recent best throughput as a floor to challenge the next hour. If an
   earlier hour achieved multiple accepted items or several useful parallel
   lanes, later hours should either keep comparable independent work moving or
   record the concrete bottleneck that prevents it.
5. Do not let one platform hiccup idle the whole board. A failed token, stale
   checkout, sandbox, Docker, SSH, Events, or model issue should become a
   scoped infrastructure task while unrelated local, dev-hg, H100, or other
   configured lanes continue when safe.
6. Do not confuse "active worker" with throughput. Claimed/running workers are
   only useful capacity when they emit meaningful task-stream progress, produce
   reviewable diffs, or create actionable failure evidence. False-active lanes
   must be routed quickly while other lanes keep moving.
   A queued task, SSH-runner request, container-status event, or stale remote
   process alone is not an active lane. Count it separately as queued,
   request-only, launched-only, stale, or false-active until task Events show
   claim, App Server/model progress, terminal evidence, a commit, or an exact
   failure.
7. When H100 is paused for cost, immediately compensate with local and dev-hg
   worker lanes for work that does not require the GPU. When H100 is approved
   for use, keep it fed with real scoped work and scheduler/backlog tasks
   rather than sequential proof-only attempts.
8. Use delegated supervisor agents as soon as the lead supervisor has more than
   one independent work line to track. At minimum, split review/promote triage,
   remote freshness/readiness, and implementation-lane refill when all are
   active.
9. If an hour ends with zero or one worker despite multiple unblocked topics,
   the memo must call that out as underutilization and must include the next
   dispatch, plan split, or infrastructure fix that will prevent repeating it.
10. Do not report broad-goal status without the numbers. Progress reports must
    include completed task count, active task count, queued/refill candidates,
    environments in use, and blockers with owner tasks. If the numbers are weak,
    say so plainly and change the operating plan before the next report.
11. Compare each hour to the best recent proven throughput, not to a low-effort
    baseline. Memo evidence showed this project can sustain many parallel
    workers when scopes are independent and review is asynchronous; later
    one-lane operation must be justified by concrete constraints such as paused
    H100 cost, dirty checkout, blocked worker substrate, or lack of scoped work.
12. Keep remote proof and product work separate in reports. Testing on H100,
    dev-hg, or another environment is verification of the same product flow
    unless the environment truly needs different implementation. Avoid vague
    "prove H100" checklist items; name the product feature being verified, such
    as scheduler claiming, service readiness, credential resolution, relay
    sync, App Server model switching, or terminal evidence collection.

## Repo-Local Skills Index

Read the relevant skill before doing detailed operational work:

Keep this index current. Whenever adding a new repo-local skill, deleting a
skill, renaming a skill, moving a skill file, or materially changing a skill's
purpose, trigger conditions, or operating scope, update this root index in the
same change set with the skill path, basic purpose, and when agents should read
it. Do not leave skill discovery dependent on memory, chat history, or scanning
the `skills/` directory.

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
   Use it before `PLAN.md` or `AGENTS.md` edits, memo closeout, tracker-only
   commits, or durable lesson capture.
4. `skills/bus-ui-gx-roadmap/SKILL.md`: GX and Bus UI feature-candidate
   planning, docs, implementation, semver promotion, and portal migration
   prerequisites. Use it before planning, dispatching, reviewing, or reporting
   GX/UI roadmap work, feature-candidate implementation, portal migration, or
   semver promotion.
5. `skills/bus-docs-quality/SKILL.md`: public docs and SDD structure, Markdown
   linting, UI docs page shape, examples, links, and duplicate-content cleanup.
   Use it before editing public docs, SDD docs, README-style documentation,
   Markdown examples, docs navigation, or docs lint fixes.
6. `skills/bus-go-quality-review/SKILL.md`: Go implementation/review gates,
   unit/e2e expectations, module Makefile checks, and final `bus lint
   path/to/file.go` peer review. Use it before touching Go files.
7. `skills/bus-generated-artifact-hygiene/SKILL.md`: generated WASM/static
   artifact tracking, ignore/clean/regenerate rules, and dirty-checkout
   prevention. Use it before touching generated browser, WASM, static, build
   output, or other artifact files, and before deciding whether generated
   changes should be committed, regenerated, ignored, or cleaned.
8. `skills/bus-development-retrospective/SKILL.md`: evidence-based
   development retrospectives for releases, incidents, agent-worker sessions,
   difficult implementation periods, and public docs reports under
   `docs/docs/reports/` when the retrospective should be shareable. Use it when
   source changes, worker performance, `bus dev task` conversations/events,
   human orchestration, stale next-step claims, and durable guidance/test/doc
   updates all need review.

## Repository Identity

1. This repository is the public superproject for `busdk/busdk`.
2. Do not implement accounting logic or BusDK module source code here.
3. Keep BusDK modules as Git submodules at repository root (`bus`, `bus-*`).
4. Treat checked-in submodule commit SHAs as authoritative pins. Do not add
   lockfiles.
5. Use `develop` as the only normal integration and promotion branch for the
   BusDK superproject and Bus modules. Do not merge, fast-forward, push, or
   promote work to `main` unless the operator explicitly asks for `main` in
   that specific request.
6. Before editing the root `Makefile` or adding root orchestration, read the
   `Root Makefile Contract` below.
7. Do not add root CLI binaries or network features to this superproject.
8. The `.bus/` directory is a tracked project directory. Never add `.bus` or
   `.bus/` ignore rules. Runtime lock artifacts such as `.bus-dev.lock` may be
   ignored.
9. Do not treat `.bus/`, `Makefile.local`, `./tests`, or `FEATURES.md` as
   temporary files unless a repository explicitly documents an exception.

## Root Makefile Contract

When editing the root `Makefile` or adding root orchestration, preserve
superproject-only orchestration: exactly one root `Makefile`, POSIX shell,
`git`, POSIX `make`, deterministic discovery of `bus` and `bus-*` module
Makefiles, delegation via `make -C`, required lifecycle targets, module-local
`./bin` outputs, `PREFIX`/`BINDIR`/`DESTDIR`, Go variable pass-through, and
changed-module-scoped root test/e2e defaults. Do not add lockfiles, alternative
build systems, package-manager integrations, or reimplemented module internals.

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

Prefer building on existing lower-level architecture over duplicating platform
features in product modules. Before adding any new feature or mechanism to a
module, first check whether Bus Events, Bus Data, Auth, Bus API, worker/task
infrastructure, or another platform layer already owns the needed primitive.
This applies broadly: synchronization, replication, idempotency, cursoring,
storage, credentials, task routing, audit history, metadata, validation,
capability discovery, transport, retries, status reporting, and similar
cross-cutting behavior should be reused from the owning layer or extended there.
Feature modules should stay focused on their domain semantics and projections.
For example, Bus Notes should consume and project `bus.notes.*` operations while
Events owns append-only history, origin metadata, replay, relay, and remote
synchronization.

Keep Bus product families consistent. `bus-{name}` owns the user-facing product
and CLI, `bus-api-provider-{name}` owns API/controller integration with
`bus-api`, and `bus-integration-{name}` owns event/integration-provider runtime
behavior for the `bus-integration` runner. For the workers refactor, the target
family is plural: `bus-workers` provides `bus workers`, local control flows
through `bus-api-provider-workers`, and remote worker/container management
flows through `bus-integration-workers`.

## Product Taxonomy Guidance

Keep `PRODUCTS.md` as a product taxonomy, not a module inventory or agent
process note. It should describe product lines, supporting platform products,
and excluded/not-yet-marketable surfaces in user-facing terms.

Use these rules when editing product taxonomy or public product pages:

- Keep BusDK as the bundle, installer, and shared product-family identity.
- Give primary product pages to user-facing products that buyers, operators,
  developers, or finance users can understand as a complete product.
- Order end-user product lines by strategic public importance, not by command
  or module order. Bus Agentic Development, Bus AI Platform, and Bus Books
  should appear before smaller command-oriented products such as Bus Top and
  Bus Services.
- Present Bus Services as generally useful process-level service stack
  software, not only as BusDK project support. Its public message may compare
  it to Docker Compose for packaging multiple services, especially during
  development, while emphasizing that it does not require containers or
  virtualization and can run inside containers or systemd-managed environments.
  Do not describe Bus Services as a security, sandboxing, or service isolation
  layer; it does not limit access between services.
- Present Bus GX/UI Library as a main product line even though it also supports
  other BusDK products. Teams may want Go-native UI components with TSX-like
  authoring directly, so `bus-gx` and `bus-ui` should be public product
  surfaces for compiled Go render roots, reusable component families, runtime
  bridges, deterministic tests, and policy-free frontend surfaces. Do not
  position it as "React cloned in Go"; React and TSX are useful reference
  points, but the product contract is Go-first and keeps routes,
  authorization, provider semantics, secrets, and business policy in owning
  product modules.
- Group supporting infrastructure under a separate supporting-platform category
  when it exists mainly to build, host, connect, or operate BusDK components.
- Treat dispatcher and host modules such as `bus`, `bus-api`,
  `bus-integration`, `bus-portal`, and `bus-operator` as host products. Their
  child modules belong under the concrete product line they serve.
- Do not duplicate a module across multiple marketed product pages. Cross-link
  when a module participates in more than one workflow.
- Do not market unfinished, research-only, or unclear surfaces as public
  products yet. Document them as research, technical preview, or internal
  modules until their user-facing value is ready.
- Keep the explicit exclusion list in this guidance, not in `PRODUCTS.md`.
  Current exclusions:
  - Bus Filing Finland is a real direction, but not ready for marketing yet.
    This covers `bus-filing`, `bus-filing-prh`, and `bus-filing-vero`.
  - `aiz` is a research project for now.
  - `bus-work` should not be marketed until its status is fully reconciled with
    Bus Agentic Development.
  - Individual `bus-api-provider-*`, `bus-integration-*`, and
    `bus-operator-*` modules should be assigned to the product line they serve
    instead of published as separate product pages.
- Keep Bus Books as the single public accounting and financial-workflow
  product for humans and agentic AI. The deterministic accounting engine, data
  workbench surfaces, Bus Formula Language, and `bus-portal-accounting` are
  proof and feature depth inside Bus Books unless they later become
  independently sellable. The Bus Books product page may explain that human
  apps, agent-facing tools, the UI, CLI, and API operate over the same
  deterministic workspace data for accounting, invoices, and financial
  workflows. Modules
  under Bus Books include `bus-accounts`, `bus-assets`, `bus-attachments`,
  `bus-balances`, `bus-bank`, `bus-bfl`, `bus-budget`, `bus-customers`, `bus-data`,
  `bus-debts`, `bus-entities`, `bus-files`, `bus-inventory`, `bus-invoices`,
  `bus-journal`, `bus-ledger`, `bus-loans`, `bus-memo`, `bus-payroll`,
  `bus-pdf`, `bus-period`, `bus-reconcile`, `bus-replay`, `bus-reports`,
  `bus-sheets`, `bus-validate`, `bus-vat`, and `bus-vendors`.
  `bus-portal-accounting` is the customer-facing portal experience for
  workspace summaries, attachment uploads, evidence packages, and artifact
  preview/download workflows.
  `bus-pdf` is document-rendering infrastructure for Bus Books workflows such
  as invoices, reports, and evidence packs, not a standalone end-user product.
- Keep Bus Auth, Bus Auth Portal, and Bus Billing under Bus AI Platform.
  `bus-auth`, `bus-portal-auth`, `bus-billing`, auth/session providers, usage
  hooks, Stripe integration, and auth/billing operators are platform services
  for login, approval, entitlements, metering, and paid AI hosting. They should
  not be a separate public product page unless the auth/billing experience
  later becomes independently understandable and sellable.
- Keep Bus Notes under Bus Agentic Development. `bus-notes`,
  `bus-portal-notes`, `bus-api-provider-notes`, `bus-integration-notes`, and
  `bus-faq` provide durable project memory, review notes, publishing, search,
  and FAQ-style answer storage for agentic development workflows; they should
  not be a separate public product page unless the notes experience later
  becomes independently understandable and sellable.
- Use Bus AI Platform, not Bus AI API, as the public product line for AI
  hosting services. This product may include OpenAI-compatible model access,
  inference/runtime control, deployment automation, user-owned VMs,
  containers, terminal sessions, node/cloud/database readiness, lifecycle
  events, usage hooks, auth, billing, and future UIs. Bus Deploy, Bus Runtime,
  Bus Auth, and Bus Billing modules belong under Bus AI Platform unless a
  separate deployment, runtime, or auth/billing product becomes independently
  understandable and sellable.
- Keep Bus Agentic Development as the product line for semi-autonomous
  software development. The selling point is integrating autonomous AI worker
  and supervisor agents into a software project so they can operate as
  autonomously as normal human workers, not merely human-supervised AI
  assistance. The market focus should be BusDK's own AI-native development
  workflow: BusDK software, BusDK tools, Go-heavy systems, and adjacent
  projects where the same semi-automatic development loop works seamlessly.
  This is not a strict language boundary, but generic "any kind of software
  development" should not be the first public promise. Human review and
  approval should be presented as an available governance/control layer, while
  the product should also support AI supervisor agents, such as Codex or Claude
  App sessions, that can define work, launch workers, monitor evidence, review
  output, and keep the board moving. Multi-environment execution is a core
  product point: Bus agents can work across local and remote development
  environments, and teams should be able to add multiple SSH-accessible
  environments as work capacity for autonomous agents. Do not split tasks,
  workers, agent runtime, prompts, chat, AI portal, notes, MCP, repository
  workspace contracts, or developer factory UI into separate public product
  pages unless those surfaces later become independently understandable and
  sellable. MCP and repository modules are not one shared product; they are
  supporting capabilities under Bus Agentic Development. That product page
  should explain the full loop: task threads, worker creation and control, the
  lightweight Bus-owned agent runtime, local and remote execution,
  SSH-configured development environments, prompt/script/pipeline workflows,
  chat, durable project notes, approvals, terminal state, repository
  workspaces, MCP capability exposure, quality review, supervisor-agent
  automation, and developer workflow UI.

Canonical task lifecycle Events use `bus.task.*`. Canonical worker
lifecycle/control Events use `bus.workers.*`. Treat `bus.dev.task.*`,
`bus.work.*`, and singular `bus.worker.*` names as legacy, compatibility, or
bootstrap surfaces unless the owning module explicitly documents otherwise.
Do not present singular `bus-worker`, `bus-api-provider-worker`, or
`bus-integration-worker` scaffolding as the final workers product path without
migrating or wrapping it behind the plural API/provider/integration family.

## LLM Tool Prompt Construction

When building or changing any BusDK tool that sends prompts to an LLM, keep the
largest stable prefix first and put changing request data last. Stable prefix
material includes role/task instructions, repository policy, output schema,
rubrics, safety rules, examples, and deterministic completion contracts.
Dynamic material includes timestamps, random or attempt IDs, task refs, file
paths, line-numbered source, diffs, `PLAN.md` contents, current `AGENTS.md`
contents, worktree paths, dependency checkout paths, command output, tool
results, model/runtime observations, and other per-run metadata.

For prompt-template code, prefer this shape:

1. Stable tool identity and task.
2. Stable policy, rubric, and output schema.
3. Stable examples that use placeholders instead of real per-run values.
4. A clearly labeled final dynamic context section containing all changing
   input.
5. The immediate instruction that applies the stable rules to that final
   dynamic context.

Do not prepend dynamic context merely because the model should read it first.
Instead, keep it near the end and explicitly instruct the model, in the stable
prefix, to consult the final dynamic context before acting. Avoid placing
timestamps, task IDs, file-specific paths, command output, or generated tool
results before reusable instructions because that can defeat prompt prefix/KV
cache reuse for local model runners and other providers. Do not claim
OpenAI/Anthropic-style cached-token metrics for providers such as Ollama unless
the provider actually exposes them; use provider-supported keep-alive and cache
configuration instead.

## Worker Backend Policy

Before choosing or changing Bus development worker backend/runtime behavior,
read `skills/bus-dev-task-worker-ops/SKILL.md` and the owning module
`AGENTS.md`/`PLAN.md`. Root policy: Codex App Server is the normal development
worker backend because it supports live steering, approvals, progress events,
structured closeout, and task attempt metadata. One-shot Codex execution is
legacy compatibility, not the default for configured local or remote worker
lanes.
Development worker systems must store Bus Events task history durably, using
PostgreSQL or an explicit repository-file-backed store. The Events `memory`
backend is acceptable only for automated tests, self-tests, or intentionally
disposable smokes, never for local or remote worker lanes whose conversations
should be retained.

## Supervisor Host And Remote Environment

The BusDK superproject is checked out under the supervisor root at
`projects/busdk`. Keep BusDK-specific architecture, command, release, worker,
and module policy in this file or the most specific nested module
`AGENTS.md`; keep supervisor identity and role memory in the parent
`/Users/jhh/git/busdk/agent-supervisor/AGENTS.md`.

The local supervisor host is a macOS virtual server without supported nested
virtualization. Do not plan or diagnose BusDK Docker/container work as if
Docker should run locally here. Container and Docker-specific build,
inspection, smoke, and worker proof should run on a configured remote
environment unless the operator provides a newer remote target for that task.
Environment names, remote ids, and host aliases are user-defined deployment
data, not BusDK product constants. Remote config may contain operator-provided
aliases as data, but software should treat them as arbitrary identifiers. Do
not hardcode SSH usernames, ports, gateway details, or environment-specific
names into product code, ENV variable names, profile semantics, tests, or
product documentation. For SSH targets, prefer the configured host alias and
leave usernames, ports, gateway users, keys, host-key policy, and proxy details
to the operator's SSH config.

For the current task/worker refactor, the intended operating topology is a
local Bus control plane on the supervisor host for Events/task submission and
review, with Docker/App Server worker execution on a configured persistent
remote.
Starting work locally should route task Events to the remote worker-side Events
service and import remote claim/progress/terminal evidence back locally; do not
replace this with a local Docker worker attempt on the macOS supervisor host.

When Docker-related proof moves to `dev.hg.fi`, record the remote environment,
checkout commit, relevant submodule SHAs, rebuilt binaries or images, and the
exact verification command or worker evidence. A local Docker failure on this
host is an environment-boundary fact, not by itself a BusDK product failure.

For local ChatGPT/Codex subscription Spark workers, use the exact raw model id
`gpt-5.3-codex-spark`. Do not substitute display-style names such as
`GPT-5.3-Codex-Spark`, and do not add automatic model-name normalization as
part of the current refactor. Prefer exact pass-through of configured model ids
until an explicit later feature adds optional aliasing.

## Commit And Deletion Safety

Read `skills/bus-plan-memory-maintainer/SKILL.md` before tracker-only commits
or memory closeout. Root safety context: commit only when asked or explicitly
allowed, commit staged scope only, never push/tag/sync without request, use
tracked/untracked deletion commands deliberately, and keep tracker-only commits
separate from implementation/docs/test changes.

## Shell And Tool Hygiene

For shell scripts, Docker inspection, readiness probes, search/format commands,
or other repeatable debugging practice, read the owning module `AGENTS.md`
first, then the relevant runbook: `skills/bus-dev-task-worker-ops/SKILL.md`
for worker/remote/container readiness, `skills/bus-docs-quality/SKILL.md` for
docs commands, and `skills/bus-go-quality-review/SKILL.md` for Go test/lint
commands. Keep commands simple, portable, path-correct, bounded, and redacted.

Use `./tmp/worktrees` for disposable supervisor, worker, review, and remote
checkout worktrees. `tmp/` is already ignored, so do not introduce separate
local-only worktree directories such as `./worktrees`.

For historical delivery or behavior claims, verify the relevant Git diff before
writing the claim. For progress, heartbeat, review, and closeout reports, follow
`skills/bus-product-delivery-supervisor/SKILL.md`.

## Simplify Before Building

1. Before implementing a feature, abstraction, workflow, or infrastructure
   change, pause and ask whether the current complexity is actually required.
   Review the real goal first, then choose the smallest shape that would still
   solve it. Prefer removing constraints, assumptions, or moving parts over
   building new machinery around them.
2. When a goal is blocked, find the smallest path that can already do real
   work and use that first. Prefer a narrow working slice over a broader design
   that is still theoretical.
3. Treat temporary/manual supports as acceptable when they unlock immediate
   productive work. A temporary path is good if it is explicit, reversible,
   and keeps the architecture honest; do not wait for full automation when a
   simpler support can get useful work moving now.
4. Only automate what the team has already proven necessary. If a manual step,
   reduced feature set, or simplified runtime is enough to unblock real work,
   defer the generalized version until the simpler path is producing value.
5. When choosing between fixing the whole platform and fixing the next missing
   dependency on the active path, prefer the active path. Record what was
   intentionally deferred so later automation can replace the temporary
   support without pretending it was never temporary.
6. Apply this rule broadly, not only to worker infrastructure. The fastest way
   to finish often is to simplify away unneeded flexibility or complexity so
   there is less to build, less to debug, and less to maintain.
7. During design and implementation, actively look for complexity that can be
   deleted, deferred, narrowed, or moved out of the critical path. Engineers
   often overbuild by default; this rule exists to make simplification a
   deliberate first move instead of an afterthought.
8. Before building a new mechanism, explicitly ask whether the goal can be met
   by removing a requirement, narrowing the problem, reusing a smaller
   existing primitive, or accepting a temporary manual step. Prefer less
   system over more system when both would honestly solve the current need.
9. When an open product, architecture, credential, runner, or proof-shape
   question could materially change the fastest path, stop and ask the
   operator before investing significant implementation time. Treat this as
   part of the supervisor/team-lead role: surfacing consequential ambiguity is
   progress, and guessing through it for hours is not.
10. Prefer a minimal core with optional overlays. Project-specific rituals such
   as Bus Notes usage, PLAN-driven closeout rules, reporting formats, or other
   workflow conventions should be opt-in project policy unless the active proof
   shows they are truly required by the substrate itself. Do not hard-wire
   project process into the core worker/task/event machinery unless that
   dependency is intentional, explicit, and source-backed.
11. For worker infrastructure specifically, prioritize getting one smallest
   useful worker lane running end to end before expanding registry UX, remote
   parity, generalized orchestration, or product polish. Once that lane works,
   use it to help build the fuller system.

## Troubleshooting And Evidence Discipline

1. When troubleshooting infrastructure, worker, runtime, API, sync, or
   cross-module integration issues, turn the lights on first. Enable existing
   verbose logging before guessing, and if current logs do not explain the
   failure, add the smallest useful DEBUG/TRACE instrumentation in the owning
   module before attempting broad behavioral changes.
2. Keep useful observability hooks durable. If a service, CLI, worker, or
   provider needs deeper logs to be supportable, add a real way to enable those
   logs through flags, environment variables, or config instead of relying on
   ad hoc local patches that disappear after the session.
3. DEBUG/TRACE logs should make decisions legible: input identity, event name,
   work ref, recipient, worker lane, backend, remote/environment, chosen code
   path, retry/conflict result, and important external call outcomes. Prefer
   structured logs or stable key/value text that can be searched and compared.
4. Trace the whole failing path, not only one process. For multi-service
   failures, collect or improve logs at each boundary that matters: caller,
   client SDK, API/provider, worker/supervisor, container/runtime, and remote
   transport when present.
5. Verify with proof instead of assuming from symptoms. Reproduce the failure,
   gather direct evidence, and prefer source-level or protocol-level facts over
   impressions from partial output. Do not report a cause as established until
   logs, tests, replay evidence, or code-path inspection support it.
6. Aim for root cause, not just the first visible error. When a problem is
   only understandable after adding logs or collecting better proof, record the
   underlying cause, the evidence that proved it, and the change that prevents
   the same stall from recurring.
7. Never log secrets, raw tokens, passwords, private keys, full `.env`
   contents, or customer-sensitive payloads. When richer logging is needed,
   log source kinds, file paths, presence/absence, IDs, sizes, counts, and
   redacted summaries instead of secret values.
8. For `bus services up` proof, verify the binary the service stack actually
   launches. The normal stack prefixes `dist-bin` on `PATH`, so a module
   `make install` into `~/.local/bin` or `bin/` is not enough evidence. After
   promotion or remote refresh, compare the superproject commit, affected
   submodule SHAs, and an observable marker from `dist-bin/bus`,
   `dist-bin/bus-integration`, or the affected `dist-bin/bus-*` binary before
   declaring the stack updated.
9. For local-plus-remote proof, treat version freshness as a first diagnostic,
   not a late cleanup step. Check local and remote `develop` commits,
   submodule pins, rebuilt installed binaries, and restarted native services
   before spending time debugging behavior that may come from stale software.
10. For Events relay failures, inspect event routing metadata, cursor state,
    import/origin markers, and relay state before changing product modules.
    Relay decisions should be metadata-addressed, not event-name filtered. If
    a fresh addressed event is not moving, look for cursor/window starvation,
    route-pair ownership, import suppression, or stale service binaries before
    adding special-case sync logic to task or worker modules.
    When the relay cursor appears to advance but a specific addressed Event is
    absent on the destination, search both local and remote Events by
    `correlationId` and `bus.destination.environment.id`, then inspect the
    relay status cursor and recent-event set. If the missing Event is older
    than the cursor or surrounded by imported remote Events, treat it as a
    pending-destination scan/window bug until disproved. Fix and test the
    generic Events relay; do not add task, worker, or event-name-specific
    forwarding rules.
11. For worker message delivery failures, compare the user-visible delivery
    result with the lifecycle code path. `delivery=recorded` means the message
    was stored but no live lifecycle messenger accepted it; inspect whether the
    active worker lifecycle implements message delivery. App Server workers
    must use the Codex App Server turn path, not a legacy one-shot exec path.
12. For App Server worker runtime errors, debug the concrete boundary in this
    order: host worktree path and existence, container or App Server process
    status, App Server URL, capability-token file presence, WebSocket
    handshake status, then turn/session response. Log paths, booleans, ids,
    HTTP status codes, and file presence only. A `401 Unauthorized` handshake
    means the messenger/auth path is wrong until the capability token source is
    wired correctly; do not treat it as an unproven worker failure.
13. For local worker/App Server `No such file or directory` failures, search
    recent memos and prior commits for the exact error before designing a new
    worker architecture. Then compare the process argv, configured cwd,
    declared writable roots or `--add-dir` args, materialized submodules, and
    installed binary path. Preserve the successful diagnostic sequence in the
    current memo once the root cause is found.
14. Worker communication and task guidance are allowed to contain token-shaped
    text, model ids, and secret discussion in local or isolated environments.
    Do not use broad substring filters such as matching `sk-` anywhere in a
    message. Secret protection belongs at logging, persistence, export, and
    transport boundaries where values would be exposed unintentionally; if a
    detector produces false positives on normal worker content, narrow or
    remove that detector instead of blocking the worker flow.
15. After fixing a repeated BusDK infrastructure problem, immediately record a
    future-practice note in the current memo and, when reusable, in this file
    or the owning module `AGENTS.md`. Name the original symptom, the mistaken
    assumption that slowed progress, the decisive check, the invariant fixed,
    and the first command or inspection to run next time.
16. For App Server WebSocket `401 Unauthorized` failures, start with the
    capability-token path instead of treating the worker as generally broken.
    Check that the lifecycle created a host-side token file next to the worker
    worktree, the container or App Server process requires WebSocket auth, the
    messenger reads the host token file without logging the value, and the
    client sends `Authorization: Bearer ...` during the WebSocket upgrade. Add
    a protocol-level handshake regression when this path changes.
17. For App Server message deliveries that report `turn/started` but never
    return assistant evidence, compare the configured Services timeout with
    the messenger instance used by the active lifecycle. If `services.yml` or
    a profile already sets a longer evidence timeout, verify the App Server
    lifecycle passes that same value into its messenger instead of silently
    using a constructor default. Prove the fix with both a unit test that
    observes the carried timeout and a fresh worker message through the normal
    `bus workers message` surface.
18. For App Server worker delivery failures after a worker has been created or
    resumed, verify runtime metadata freshness before changing worker routing
    or relay semantics. Compare the user/request intent Event, the persisted
    worker state, lifecycle-owned `meta.env`, the actual container or App
    Server port, and the messenger session cache. If the container is up on a
    fresh port but delivery uses an older `app_server_url`, the lifecycle must
    refresh non-secret runtime facts from `meta.env` before message delivery
    and status reporting, and the messenger must drop cached sessions when the
    App Server URL changes. Preserve this with unit tests for metadata refresh
    and cache invalidation, then verify with a fresh `bus workers message`
    through the normal Services stack.
19. For nested Git write failures in Codex or App Server-backed workers, treat
    the worker launch configuration as an owned repair surface. First compare
    the worktree path, root `.git`, `.git/modules`, and nested submodule
    gitdir paths against the actual `--add-dir` arguments or writable roots
    passed to the Codex process. Fix the worker/App Server launch path before
    relying on escalated Git as a routine promotion mechanism.
20. When a BusDK issue is solved after a long loop, capture the reusable
    method, not only the commit. The memo and durable guidance should preserve
    the symptom, slow assumption, decisive diagnostic, code/config invariant,
    verification command, and the first check to run next time so future
    workers can begin from the proven route.
21. When resuming a BusDK issue that resembles a recent worker, relay,
    service-launch, install, credential, or remote-runtime failure, run a
    recent-fix intake before dispatching or coding: read the current and
    previous hourly memos for future-practice notes, search for the exact
    symptom text, and begin with the last successful diagnostic sequence. If
    the new case differs, record that difference in the memo before choosing a
    new design path.
21. When a solved issue depended on comparing live behavior against the
    intended service path, make that comparison the next default diagnostic.
    For BusDK this often means checking that `bus services up` is launching the
    freshly rebuilt `dist-bin` binaries, that local and remote checkouts share
    the same `develop` commit and submodule pins, that Events are addressed by
    metadata rather than event name, and that App Server workers are using the
    accepted live turn path. Do these checks before adding new synchronization,
    credential, worker, or CLI logic.
22. When a worker or relay fix succeeds, record the exact proof shape that
    closed it: the Bus command or service path used, task ref, worker id, route
    or environment ids, relevant event names and metadata fields, local/remote
    commits, rebuilt binaries, and the verification command. Future workers
    should be able to replay the same first check without reconstructing it
    from chat history.
