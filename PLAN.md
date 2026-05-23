# PLAN.md

- [ ] Current first-priority product lane: make multi-remote worker execution
  useful enough for real operator testing and daily development. Business/user
  value: Bus operators should be able to send work to `localhost`, `ai.hg.fi`,
  UpCloud, and future worker systems through one natural workflow, compare
  which systems produce accepted work, and avoid wasting hosted quota or cloud
  spend on blind experiments.
  - [ ] Prove parallel multi-remote execution with at least two remote
    identities active in the same run, preserving isolated worktrees,
    recipient/write-scope ownership, terminal evidence, and serialized
    promotion.
  - [ ] Add per-remote capacity and throughput reporting so supervisors can see
    accepted/failed/blocked work, tasks/hour, latency, and stale workers by
    remote id/kind and by remote+recipient.
  - [ ] Mature remote default/selection UX so commands that need worker
    systems make `--remote`, configured defaults, and built-in remotes feel as
    predictable as `git remote` rather than special-case local/cloud flags.
  - [ ] Add integrated multi-system worker scheduling: users should be able to
    request work and let Bus choose or fan out across eligible remotes according
    to explicit capacity/cost/policy limits, instead of manually starting a
    separate flow per system.
  - [ ] Prepare the UpCloud manually installed runner path for operator-owned
    live testing. Do not run paid live tests here; instead provide the software
    readiness checklist, expected commands, non-secret evidence to collect, and
    clear pass/fail criteria so the external UpCloud system can test it.
  - [ ] Add GPU/server format switching support from Bus for the single-image
    UpCloud model: support changing the existing VPS format/model on demand
    without reinstalling the image, keeping create/delete/provisioning outside
    the near-term scope unless explicitly approved.
  - [ ] Measure worker throughput and cost by remote, including enough event
    metadata for local Docker, UpCloud, and future remotes to compare accepted
    work per hour and operator-visible cost signals.
  - [ ] Smooth Go agent tooling: make `gopls` MCP and Go debugger support
    usable by Codex/dev-task workers without brittle method errors, surprise
    installs, host attach, or unclear prompt context.
  - [ ] Finish release-quality blockers that directly affect this lane: the
    full all-module `quality-complete` rerun and remaining module help/docs
    cleanup found by the sweep. `busdk#99.1` reclassified the old
    `busdk#86.1` blocker: the exact prior failure command,
    `timeout 10s env -u BINARY bus-configure/bin/bus-configure --help`, now
    exits 0 with deterministic help, and the focused root changed-module
    `quality-complete` run for `bus-configure` passes doc/help lint.
  - [ ] When reporting "release hardening", name the concrete risk, affected
    user/operator workflow, and why the fix matters now; do not use broad
    hardening language without enough detail for the operator to choose.

- [x] Publish a real image-backed dev-task worker image for SSH-Docker hosts.
  - Goal: make `BUS_DEV_SSH_DOCKER_LAUNCH_MODE=image` usable without a
    pre-cloned BusDK checkout or private GitHub submodule access on every
    remote Docker host.
  - End-user/operator value: a normal user should be able to run a remote worker
    after `bus remote add lab-host ssh://lab-host` when the host has SSH,
    Docker, and access to the published worker image.
  - Triggering evidence: `coding-agent@dev.hg.fi` can SSH and run Docker, but
    `docker pull ghcr.io/busdk/bus-integration-dev-task:latest` returned
    `denied`, and the existing local `bus-local-codex:dev` image relies on the
    superproject being mounted at `/workspace`.
  - Scope:
    - Add or refine a release/build workflow that publishes the default
      `ghcr.io/busdk/bus-integration-dev-task:latest` image, or define the
      correct public/private package name and tags if `latest` is not the right
      contract.
    - Ensure the image contains the runtime/tooling needed by
      `bus-integration-dev-task` in image-backed mode, rather than depending on
      a mounted checkout.
    - Keep private source/access boundaries explicit; do not make private
      module source public accidentally through a public image.
    - Add operator diagnostics for pull/access failures so `bus dev work
      --remote <id> check` can tell whether the host lacks image access versus
      Docker itself.
  - Verification:
    - CI release workflow now builds the worker image from the Linux release
      artifact binaries, smoke-runs `bus-integration-dev-task --help`, `bus dev
      work --help`, `bus notes --help`, `codex --version`, `gopls version`, and
      `dlv version`, verifies the bare image invocation dry-runs to a
      worker-shaped `bus-integration-dev-task` command with token redaction
      rather than defaulting to help, then publishes
      `ghcr.io/busdk/bus-integration-dev-task` with tag, sha, and release
      `latest` tags.
    - Local static validation for this slice: Dockerfile/workflow/README
      checks plus `docker compose -f compose.dev-task-docker.yaml config`.
    - Runtime image publication still requires the GitHub Actions release
      workflow to run; the external host pull and worker terminal-state smoke
      are tracked as the follow-up item below.

- [x] Run a real external Docker-backed worker integration smoke on
  `coding-agent@dev.hg.fi`.
  - Done: created remote Events task `busdk#1.1`, built the remote worker
    support image on the SSH host, initialized the source checkout through
    `ssh -A`, mounted the remote rootless Docker socket into the worker stack,
    and ran a Docker child task through the remote container backend.
  - Evidence: final task evidence reported
    `REMOTE_SMOKE_PWD=/workspace/bus-integration-dev-task`,
    `REMOTE_SMOKE_HOST=ddfcc6a156a1`, `REMOTE_SMOKE_HEAD=e1d6022`, followed
    by `bus.dev.task.done` for run
    `ddfcc6a156a1f9e6ac871e346f58aaa088e62274003e4ced7815fd05739a266f`.
  - Value: proves that an external SSH-accessible Docker host can run the
    BusDK worker stack, claim a task from Events, launch a child Docker task,
    and publish terminal evidence back through Events.
  - Important limitation: this was a manual/source-checkout integration smoke,
    not the final normal-user image-backed path. It required remote submodule
    hydration and a temporary rootless Docker socket override.

- [x] Run the external image-backed SSH-Docker worker smoke on
  `coding-agent@dev.hg.fi`.
  - Done: pushed the current root and touched submodules, updated the remote
    checkout without requiring GHCR visibility, built
    `bus-integration-dev-task:local-image-smoke` directly on the SSH host, and
    ran `scripts/test-ssh-docker-image-smoke.sh` from the local controller.
  - Evidence: remote image id
    `sha256:6a63b42945d7fe14ba40b5ef0ee37e64a86b6c8db50c87caeb7c1d164a950302`;
    smoke task `bus-ssh-docker-smoke#7.1`; remote container
    `143cc4e3f82488bbf20fef273600e0bfda20d7de883dc40f18ebb44a9439e946`;
    normal Bus Events showed container launch, `bus.dev.task.claimed`,
    isolated worktree preparation, self-test execution, and terminal
    `bus.dev.task.done`.
  - Value: proves the image-backed SSH-Docker worker path can run on an
    external host with SSH, Docker, a reachable Events control plane, and a
    locally built/installed worker image. This avoids requiring GitHub package
    visibility just to test a private software installation path.
  - Boundary: this diagnostic proof used the `self-test` backend. Real Codex
    auth, open-source model inference quality, and UpCloud GPU offload are
    tracked by the next local/UpCloud worker infrastructure lane.

- [x] Fix GitHub Actions release workflow Node 20 deprecation warnings and
  moving runner labels.
  - Goal: keep the release workflow compatible with GitHub's June/September
    2026 hosted-runner changes before they become release blockers.
  - Scope: update `.github/workflows/release.yml` to use current Node 24 action
    majors where available for checkout, setup-go, upload/download artifacts,
    and GitHub release publication; replace moving runner labels where the
    workflow should intentionally test a specific OS image, especially the
    Windows VS 2026 migration path.
  - Verification: validate the workflow YAML, run a lightweight grep check
    that no release workflow step still uses the deprecated action majors or
    `windows-latest`, and document any intentionally retained `*-latest`
    labels with rationale.

- [ ] Coordinate oversized module `AGENTS.md` linting and compaction from the
  superproject. Use `bus lint AGENTS.md` in each affected module, review every
  AI-backed agent-guidance finding, and refactor oversized guidance without
  losing useful rules.
  - Goal: keep module guidance useful for workers while reducing repeated,
    stale, or misplaced instructions that waste agent context and make
    supervision less reliable.
  - Supervisor discovery: run `find bus bus-* docs busdk.com sdd logs
    -maxdepth 2 -name AGENTS.md -type f -size +8k -print` from the
    superproject, ignoring `./tmp`, disposable worker homes, generated
    artifacts, and archived logs that are not active instruction surfaces.
    Save the affected path list in the supervisor note/worker brief, not in a
    generated file, unless a later worker owns a real tracker/document update.
  - Initial affected modules/projects for sharding: `bus`, `bus-accounts`,
    `bus-agent`, `bus-api`, `bus-api-provider-books`,
    `bus-api-provider-session`, `bus-assets`, `bus-attachments`,
    `bus-balances`, `bus-bank`, `bus-bfl`, `bus-books`, `bus-budget`,
    `bus-config`, `bus-configure`, `bus-data`, `bus-dev`, `bus-faq`,
    `bus-filing`, `bus-filing-prh`, `bus-filing-vero`, `bus-gateway`,
    `bus-gx`, `bus-help`, `bus-init`, `bus-integration-dev-task`,
    `bus-inventory`, `bus-invoices`, `bus-journal`, `bus-ledger`, `bus-loans`,
    `bus-payroll`, `bus-pdf`, `bus-period`, `bus-preferences`,
    `bus-reconcile`, `bus-replay`, `bus-reports`, `bus-run`, `bus-sheets`,
    `bus-ui`, `bus-validate`, `bus-vat`, `docs`, and `busdk.com`. Re-run
    discovery before dispatch because the affected set may change as shards
    land.
  - Worker shard shape: dispatch one recipient-scoped task per affected module
    or per tightly related small batch only when the recipients share one
    public docs surface and have non-overlapping write scopes. Each worker owns
    exactly that recipient's `AGENTS.md` plus any closer child `AGENTS.md`,
    repo-local `skills/**`, or public docs paths explicitly listed in the
    brief. Do not let a module worker edit the superproject `PLAN.md`, another
    module's `AGENTS.md`, or public docs unless the write scopes name those
    paths.
  - Batching priority: start with the highest worker-context and dispatch-risk
    surfaces: `bus-dev`, `bus-integration-dev-task`, `bus-agent`, `bus-api`,
    `bus-gx`, `bus-ui`, `docs`, `busdk.com`, and root-facing command modules
    such as `bus-configure`, `bus-help`, `bus-run`, and `bus-validate`. Next
    batch private/commercial business-domain modules by shared accounting
    vocabulary (`bus-accounts`, `bus-books`, `bus-journal`, `bus-ledger`,
    `bus-reports`, `bus-vat`, payroll/filing/reconcile/bank flows), then
    compact remaining leaf provider/helper modules. Serialize promotion for
    same-recipient follow-ups.
  - Compaction method: preserve guidance by deduplicating repeated root policy,
    moving long operational runbooks into repo-local skills, moving durable
    public architecture or user-facing behavior into docs/SDD when appropriate,
    and replacing moved detail with compact trigger/index bullets that say
    when to read the new location. Use closer child `AGENTS.md` files only for
    path-specific implementation rules that workers need before editing those
    paths.
  - Public/private boundary: never move private/customer/commercial-module
    rules, customer examples, local deployment details, or secret-handling
    specifics into public docs, `docs`, `busdk.com`, or the public root. Public
    repos may keep generic safety, CLI/API boundary, and release-quality rules;
    private modules keep commercial implementation constraints inside their own
    repository guidance or private repo-local skills.
  - Preservation rules: do not delete guidance merely to reduce byte count.
    Keep module-specific safety, auth/token handling, data/privacy, release,
    generated-artifact, e2e, and lint/test requirements unless they are exact
    duplicates of stronger root guidance. When removing or moving text, record
    the destination or reason in the worker closeout.
  - Required worker loop for each shard: read root `AGENTS.md`, the target
    module `AGENTS.md`, and any existing local skills first; run `bus lint
    AGENTS.md` before editing to capture agent-guidance findings; compact or
    move/reference-index the guidance; then rerun `bus lint AGENTS.md` and the
    module-appropriate Markdown/text gates. Use worker-safe lint mode only for
    deterministic closeout if the AI-backed lint runtime is unavailable, and
    report that limitation explicitly.
  - Acceptance criteria per shard: `AGENTS.md` is smaller or clearly better
    indexed; every moved rule has a reachable destination or trigger; no
    private guidance moved to public surfaces; no module-specific safety/test
    rule silently disappears; `bus lint AGENTS.md` findings are resolved or
    individually deferred with rationale; changed files match declared write
    scopes; closeout lists moved/kept/deferred guidance and exact verification
    commands.
  - Superproject review gates: review each worker diff before promotion with
    `git diff --check`, `bus lint AGENTS.md` in the changed recipient, and any
    module `make`/docs quality target the worker reports as appropriate. Reject
    shards that only delete content for size, blur public/private boundaries,
    add broad public process rules, omit lint evidence, or leave moved guidance
    undiscoverable.

- [x] Make AI Product Delivery Supervisor heartbeat/service operation
  deterministic end to end: add a root Compose `bus-dev-supervisor` service
  that refreshes BusDK wrappers, issues a scoped local token, runs
  `bus dev work monitor --format json` as a short non-streaming heartbeat,
  writes health/status evidence under `tmp/dev-task-supervisor`, documents the
  local start/check workflow, and verifies the wiring with focused root smoke
  coverage.

- [x] Add the first bounded AI Product Delivery Supervisor policy cycle end to
  end: teach the root Compose `bus-dev-supervisor` service heartbeat to call
  `bus dev work monitor --format json`, classify active and terminal task
  snapshots, and record explicit no-op status/event/evidence under
  `tmp/dev-task-supervisor` when no safe work is available. Keep the
  classification provider-neutral, document the local check workflow, and
  verify it with focused shell smoke coverage.

- [x] Complete AI Product Delivery Supervisor action-loop automation end to
  end:
  owner/entrypoint is the root Compose `bus-dev-supervisor` service plus the
  `bus-dev` workflow command surface. Closed after the dry-run action queue was
  followed by the accepted mutating `bus-dev` executor surface: `bus-dev` commit
  `c5164b8` added approved supervisor execution, review/refill dispatch, root
  pin planning, and reopen/refill gates; later `bus-dev` commit `3c9437f`,
  pinned by superproject commit `d26ce86`, documented and e2e-tested the
  approved mutation gates. Verification recorded in the 2026-05-19/20 memos:
  focused supervisor executor tests, `go test ./cmd/bus-dev`, `go test ./run`,
  `make build`, `make check`, `bus lint`/worker-safe `bus-lint`, and `git diff
  --check` passed for the changed slices.
  - [x] Add a provider-neutral, non-mutating heartbeat action-plan artifact
    that turns terminal monitor classification into explicit review/pin,
    reopen, blocker-record, and refill-eligibility decisions without running
    Git, reopening tasks, dispatching workers, or approving work.
  - [x] Add provider-neutral per-terminal heartbeat action-queue evidence that
    lists the terminal work refs behind review/pin, reopen, and blocker-record
    routes without running Git, reopening tasks, dispatching workers, or
    approving work.
  - [x] Add a root-only dry-run executor-plan slice that consumes the existing
    heartbeat action-plan/action-queue evidence and reports the exact planned
    review-worker dispatch, accepted-review root pin, reopen, blocker-record,
    and refill-worker operations without mutating Git, task streams, worker
    queues, product direction, security/privacy posture, cost, destructive
    state, or hard-to-reverse architecture.
  - [x] Implement the follow-on mutating consumer slices in `bus-dev` for root
    pin handling, review/progress-audit Bus worker dispatch, and safe
    reopen/refill execution after the dry-run executor plan is reviewed. Closed
    by accepted `bus-dev` commits `c5164b8` and `3c9437f`, with root pin
    evidence through superproject commits `27965d3` and `d26ce86`.

- [x] Make BusDK dev-task container and host toolchain freshness automatic end
  to end: reproduce the recurring stale-tool problem where worker containers or
  the host dispatcher lack the latest BusDK commands such as `bus lint` or `bus
  dev work monitor`, then update the superproject bootstrap/container workflow
  so local workers start with the current checked-out Bus tools on `PATH`.
  Include a fast smoke that proves a task container can run `bus lint`, `bus dev
  work monitor --help`, and the dispatcher form `bus gx`/other installed module
  commands after recent submodule promotions. Document the refresh path and
  verify focused root gates.

- [x] Operationalize AI Product Delivery Supervisor task dispatch end to end:
  persist the supervisor/delegation rules in `AGENTS.md`, inspect root
  `BUGS.md`, `FEATURE_REQUESTS.md`, and module `PLAN.md` backlogs, start the
  documented Docker Compose development-task stack with
  `docker compose -f compose.dev-task-docker.yaml up -d`, issue non-overlapping
  `bus dev task` work for active module issues, fix any blockers in the task
  system itself, and review returned task artifacts before accepting or closing
  items. Closed by the 2026-05-19/20 localhost worker batches and blocker-first
  supervisor passes: remote, dev-task, UpCloud, gopls, debugger, bus-events,
  bus-lint, and bus-dev follow-up workers were dispatched through the local
  dev-task substrate, reviewed, corrected or reopened when needed, accepted, and
  pinned through superproject commits up to `d26ce86`.
  - [x] Add a root-stack supervisor `inspect` check that validates heartbeat
    freshness, prints the current policy/action queue summary, and reports
    root/module `PLAN.md` backlog counts without dispatching, reopening,
    approving, pinning, or editing submodules.
  - [x] Cross-module request for `bus-dev`: add the executable supervisor
    command surface that consumes the non-mutating heartbeat action queue and
    performs review-worker dispatch, precise reopen/refill decisions, and root
    pin handling with dry-run evidence and operator approval gates where
    required. Closed by accepted `bus-dev` commits `c5164b8` and `3c9437f`.
  - [x] Cross-module request for `bus-integration-dev-task`: expose
    controller-owned worker startup/refill mechanics so the supervisor service
    can request recipient-scoped workers deterministically instead of relying
    on manual Compose worker starts.

- [ ] Shift development execution toward Bus-owned local and UpCloud AI worker
  infrastructure under hosted Codex budget constraints end to end: review the
  current local Docker Compose, container-provider, LLM-provider,
  UpCloud-runner, SSH-runner, and dev-task worker paths; identify the shortest
  safe path for `bus dev task` workers to run in operator-owned containers and
  GPU/local-model runtimes instead of hosted Codex; dispatch recipient-scoped
  implementation tasks for the owning modules; keep paid UpCloud provisioning
  behind explicit operator approval; document the cost-control operating mode;
  and verify with local/provider-neutral smokes before any live-cloud spend.
  Current UpCloud direction: optimize first for one manually installed
  UpCloud VPS image that can run Bus-owned worker containers and later be
  resized or changed to a different UpCloud GPU/server format on demand without
  reinstalling the virtual server. Bus should eventually be able to request
  that format/model switch, but broad GPU virtual-server creation/provisioning
  is not part of the immediate lane unless existing installation support already
  covers it safely.
  Add Go-aware Codex worker context through `gopls` MCP in this lane: review
  official `gopls` MCP support, use detached `gopls mcp` for saved-file worker
  containers by default, generate the model instructions with
  `gopls mcp -instructions` into task context, expose opt-in policy/config for
  Go workers, and account for security/network/cache behavior before enabling
  it on local or UpCloud worker images.
  Current accepted base: `bus-remote` owns named remotes including
  `localhost`, `localhost:{port}`, URL remotes, and `ai.hg.fi`; `localhost` is a
  Docker Compose remote, not a special local-only shortcut. `bus-dev` resolves
  dev-task/work commands through `bus-remote`, launches Compose remotes through
  `compose.dev-task-docker.yaml`, uses conditional append for multi-remote
  claiming/group allocation, and has no open local PLAN work. The
  `bus-integration-dev-task` module records remote metadata in worker/App
  Server closeout evidence, consumes worker-start requests, supports
  task-scoped `gopls` MCP context, and supports safe no-install `dlv dap`
  debugger context. `bus-integration-upcloud` supports no-spend
  `existing-only`/`adopt-existing` manually installed runner modes and preserves
  task env/workdir/source metadata. No paid UpCloud provisioning has been
  performed.
  Current shortest path after the external SSH-Docker proof: treat the first
  UpCloud H100 server as an operator-provisioned SSH-Docker remote, install or
  build the worker image on that host from pushed source, run the same
  image-backed self-test smoke there, then add one model-backed worker backend
  that talks to an operator-managed local inference endpoint. Use existing
  inference/UpCloud/Ollama modules and command-line tools; do not build new MCP
  servers for this slice.
  - [ ] Next concrete slice: run an operator-ready multi-remote dry-run and
    local proof package from the current pinned root, covering `bus dev work
    --remote eligible start --dry-run`, `bus dev work stats`, and the no-spend
    UpCloud existing-runner checklist. Owner modules: `bus-dev`, `bus-remote`,
    `bus-integration-upcloud`, `docs`, and `sdd`. Acceptance: commands and docs
    show how an operator can test localhost plus an external manually installed
    runner without provisioning paid resources here.
    - [x] Initial no-spend UpCloud GPU worker proof package:
      `scripts/test-upcloud-worker-offload-dry-run.sh` configures an
      `upcloud-h100` SSH-Docker candidate remote, checks the static UpCloud
      existing-runner surface, runs Ollama/Gemma `model.ensure` and install
      dry-runs, and emits a `bus dev work --remote upcloud-h100 start
      --dry-run` image-backed worker plan. This proves the minimum product path
      without paid provisioning, GHCR visibility, or remote model download.
      Verification: `sh -n scripts/test-upcloud-worker-offload-dry-run.sh`
      passed, and the script completed with `OK no-spend Upcloud worker offload
      dry-run`; the worker plan reported `launch_mode=image`,
      `worker_events_api_url_status=ok`, `worker_image=bus-integration-dev-task:local-image-smoke`,
      and `no task streams created; no workers launched; no provisioning requested`.
    - [x] Local-model command profile slice: image-mode SSH-Docker workers now
      pass `BUS_DEV_TASK_CONTAINER_IMAGE` and `BUS_DEV_TASK_CONTAINER_PROFILE`
      through to the image worker, the dev-task worker image includes `curl`
      for first inference endpoint smokes, and
      `scripts/test-upcloud-worker-offload-dry-run.sh` writes
      `local-model-worker-profile.env` plus `local-model-command.json` for an
      Ollama-style `/api/generate` smoke. The profile runs the existing
      `container` backend with the selected worker image as the child task
      image, keeping the first model lane on existing Bus container contracts
      instead of adding a new MCP/backend. Verification:
      `go test ./run -run TestDevTaskSSHDockerRunnerRequestSupportsImageLaunchMode`
      in `bus-dev`, `sh -n` for the changed scripts, `git diff --check`,
      `bus lint bus-dev/run/worker.go`, `bus lint bus-dev/run/worker_test.go`,
      and `scripts/test-upcloud-worker-offload-dry-run.sh` passed.
    - [ ] Live operator-host model smoke: on an approved H100/GPU-capable
      SSH-Docker host with the worker image and local inference runtime
      installed, run the generated local-model command profile through
      `bus dev work --remote <id> start`, verify the child container reaches
      the inference endpoint, records model output in the task stream, and
      reaches a terminal Bus Events state without hosted Codex credentials.
      - [x] Removed the immediate container mount blocker found during the
        `coding-agent@dev.hg.fi` mock-model smoke: `bus-dev` now passes
        remote workspace host roots and worktree-disable knobs into
        image-backed workers, the smoke scripts can select a local-model child
        container command, and `bus-integration-docker` honors explicit
        provider-neutral mounts plus fallback workspace mounts for non-Codex
        profiles. This keeps the first local-model path on existing container
        contracts instead of adding a new backend. Verification:
        `make -C bus-integration-docker test`, escalated
        `GOCACHE=/private/tmp/bus-go-cache make -C bus-dev test`, focused
        `go test` runs, `sh -n` for the SSH-Docker smoke scripts,
        `git diff --check`, and AI-backed `bus lint` on the changed Go files
        passed.
      - [ ] Reinstall/rebuild the updated worker/provider stack on the target
        SSH-Docker host, rerun `scripts/test-ssh-docker-local-model-smoke.sh`
        against the mock endpoint on `coding-agent@dev.hg.fi`, then repeat on
        the operator-provided H100 host with the real local inference endpoint.
    - [x] `busdk#115.1` docs slice: public docs now include a no-spend
      multi-remote worker test checklist, integration navigation links,
      bus-dev module reference links, explicit live-run token scopes, a
      read-only live smoke prompt, and cleanup guidance for temporary external
      remotes. Evidence: focused `bus lint` on the changed docs passed 5/5,
      `make -C docs quality` passed, and `git -C docs diff --check` passed.
  - [x] Local Codex worker image slice: provision pinned `gopls` v0.20.0 in
    `deploy/local-ai-platform/codex/Dockerfile`, verify MCP instructions at
    image build time, and extend dev-task Docker compose config/smoke coverage
    so the Codex profile image and `bus-integration-dev-task` worker service
    assert `gopls` availability.
  - [x] Remaining Go-aware worker context slice: closed by
    `bus-integration-dev-task` commit `958dbeb`, now pinned at `78277ac`,
    which wires detached `gopls mcp` and `gopls mcp -instructions` into
    task-scoped Codex context, exposes `--gopls-mcp` and lifecycle-policy
    auto/off/require configuration for Go workers, records App Server gopls
    metadata, documents security/network/cache behavior, and adds focused
    config/instruction tests with an optional `gopls` smoke. Local image
    provisioning is covered by root commit `e8e42b8` with pinned `gopls`
    v0.20.0; no UpCloud resources were provisioned.
  - [x] Remote registry and localhost Compose selection slice: closed by
    accepted `bus-remote` commits `600e6f7`, `be1b037`, `cb274c4`, and
    `823b7d5`, plus accepted `bus-dev` commits `c4d7d65`, `93b4424`,
    `9c61068`, and `ebf1347`. Evidence: focused remote/launcher tests,
    localhost read-only smoke `busdk#53.1`, documentation/SDD follow-ups, and
    `git diff --check` passed; root pins are recorded through commits including
    `abc8fcc`, `2fbee6e`, `de8af8f`, `d242dc9`, `bbaad41`, `604d5a8`,
    `17621ce`, and `4985a50`.
  - [x] Provider-neutral worker-start and remote metadata slice: closed by
    `bus-integration-dev-task` commits `b5ab8f7` and `61d2135`, which propagate
    resolved remote metadata, reject credential-bearing endpoints, and consume
    `bus.dev.work.worker.start.request` events into
    `bus.containers.run.request` without host-local mounts. Evidence: focused
    worker-start/metadata/help tests and `git diff --check` passed; broader
    reopened metadata failures were tracked separately and later fixed.
  - [x] Multi-remote claim correctness slice: closed by `bus-events` commit
    `3974901` and `bus-dev` commit `5402b1b`, with bus-events PLAN hygiene in
    `c81fa37`. Evidence: conditional append unit/race/module checks, focused
    `bus-dev` task claim/group allocation tests, `make build`, `bus lint`, and
    `git diff --check` passed for the changed slices.
  - [x] No-spend UpCloud existing-runner slice: closed by
    `bus-integration-upcloud` commits `b4f39ad` and `6d1a757`, now pinned by
    superproject commit `6a2ba13`. Evidence: focused command/provider tests,
    `go test ./...`, changed-file `bus lint --type go-source`, and
    `make BINARY=bus-integration-upcloud check` passed; real UpCloud e2e
    remained opt-in and no live UpCloud provisioning or deletion was attempted.
  - [x] Safe Go debugger context slice: closed by
    `bus-integration-dev-task` commit `217226d`, pinned by superproject commit
    `55bf63f`, which mirrors the `gopls` policy/config pattern for optional
    no-install `dlv dap` detection, App Server metadata, prompt guidance, and
    no host attach/default debug server. Evidence: focused debugger/lifecycle
    tests, help schema tests, `git diff --check`, and
    `make BINARY=bus-integration-dev-task check` passed.
  - [x] Root local worker image debugger provisioning slice: owner `busdk`.
    Add a pinned Delve install to the local Codex worker image and root
    compose/smoke coverage that proves `dlv dap` is available when the
    `bus-integration-dev-task` debugger policy is enabled, while preserving the
    no-host-attach/no-server-start default. Acceptance evidence: Dockerfile or
    image-build check for the pinned `dlv`, focused compose smoke, `git diff
    --check`, `bus lint PLAN.md README.md` if docs change, and relevant root
    selftests. Closed by adding pinned Delve v1.25.2 to
    `deploy/local-ai-platform/codex/Dockerfile`, wiring explicit
    `BUS_DEV_TASK_GO_DEBUGGER=auto` / `BUS_DEV_TASK_GO_DEBUGGER_COMMAND=dlv`
    defaults through `compose.dev-task-docker.yaml`, and extending root
    compose config/full-stack smoke coverage for `dlv dap` plus no default
    listener or host attach. Evidence: Docker image build passed the pinned
    `dlv` and `dlv dap --help` checks, focused compose config selftest passed,
    narrow compose image smoke passed, and the full dev-task Docker compose
    smoke skipped only because the local Docker daemon could not share the
    workspace path.
  - [x] Root Go 1.26.3 local compose alignment slice: owner `busdk`. Update
    root local AI platform and dev-task Docker Compose defaults so Go service
    containers and local Codex image builds use the current Go 1.26.3 line,
    document the `BUS_LOCAL_GO_IMAGE` / `BUS_LOCAL_GO_VERSION` overrides, and
    extend focused compose config coverage so stale `golang:1.24` defaults are
    caught before local worker runs.
  - [x] Localhost end-to-end worker execution release smoke: owner `busdk` with
    follow-up fixes in `bus-dev` or `bus-integration-dev-task` only if the smoke
    fails. From a clean root checkout, run the documented
    `compose.dev-task-docker.yaml` stack, resolve `localhost` through
    `bus-remote`, dispatch a recipient-scoped no-op or tiny PLAN-only worker
    through `bus dev work --remote localhost`, prove the controller-owned worker
    starts without manual Compose container commands, and verify claim,
    closeout, remote metadata, monitor/status output, tool freshness, and root
    pin behavior. Acceptance evidence: non-secret command transcript summary,
    `git diff --check`, focused root smoke, and affected module gates for any
    follow-up fixes. Closed by `busdk#85.1`: `bus remote --format json resolve
    localhost` returned the built-in Compose remote with
    `compose.dev-task-docker.yaml`; `bus dev work bootstrap --check` passed with
    dispatcher-visible `/tmp/busdk-tools` binaries; `bus dev work --remote
    localhost start --write-scope PLAN.md @busdk ...` launched a
    controller-owned `bus-integration-dev-task` worker without a manual
    `docker compose run`; `watch` showed `worker launched`,
    `bus.dev.task.claimed`, isolated root worktree branch
    `bus-dev-task/busdk-3-1`, fake App Server process/thread/turn start,
    `removed isolated worktree without promotion`, and `bus.dev.task.done`; and
    `monitor --format json` showed the active supervisor task plus the smoke
    terminal transition. The worker container environment required two
    non-product accommodations: a temporary localhost TCP forward to the
    Compose `bus-events` service because this worker container's
    `127.0.0.1:8081` is not the host, and a temporary resolved Compose config
    using the already-running `busdk` stack's Docker host checkout path because
    Docker Desktop rejected `/workspace` as an unshared host bind path. No
    cloud resources or manual worker containers were provisioned for the
    accepted smoke.
  - [x] UpCloud existing-runner worker execution smoke: owner
    `bus-integration-upcloud` for provider behavior, with `bus-dev` /
    `bus-integration-dev-task` follow-ups only if routing or worker-start
    contracts fail. Use static-provider coverage by default and a real
    manually installed UpCloud VPS only with explicit operator approval and
    `existing-only` or `adopt-existing`; do not create, resize, delete, or
    otherwise provision paid UpCloud resources in this smoke. Acceptance
    evidence: proof that env/workdir/source metadata reaches the remote Podman
    worker request, no unsupported mounts are projected, no create/delete API
    calls occur in no-spend modes, relevant module `make check`/e2e static
    provider checks pass, and any live-cloud run records the operator approval
    reference. Closed by `bus-integration-upcloud` commit
    `759cb6b39e7941ff56045985c09834c918f65578`: static no-spend coverage now
    proves env/workdir/source metadata reaches the remote Podman request,
    unsupported mounts are rejected before projection, and no create/delete API
    calls occur in existing-runner mode. Evidence: `git diff --check HEAD^
    HEAD`, `go test ./pkg/upcloudintegration`, and `make -C
    bus-integration-upcloud check` passed; real UpCloud e2e remained opt-in and
    was not run.

- [x] Refactor root `AGENTS.md` guidance structure end to end: move non-memo operational rules out from the `Live Working Memo` section into topical sections or scoped module `AGENTS.md` files, clarify the difference between cross-module family policy and module-specific guidance, remove ambiguous repeated ordered-list numbers, rerun `bus lint AGENTS.md`, and keep the supervisor/development-speed rules easy to find.

- [x] Fix local Codex task-image Bus toolchain availability end to end: reproduce the worker-container failure where module `make lint` cannot find `bus-dev`, provide a deterministic `bus-dev` command on `PATH` inside the local Codex task image without host installs, document the behavior in the dev-task workflow, add a focused smoke check, and verify that module lint can run from a Codex task container.

- [x] Complete the full local compose stack `bus dev task` path end to end: wire `bus-integration-dev-task` into the main `compose.yaml` stack that already exposes nginx and `bus-portal`, make the Docker codex profile use the locally built Codex CLI image, support optional Codex home/workspace mounts for live task execution, extend the full local compose smoke to create/watch a `bus dev task` while still verifying portal modules, update README guidance if command behavior changes, and verify with Docker-backed compose e2e.

- [x] Verify and fix local Docker Compose `bus dev task` Codex-container execution end to end: run the actual local Compose stack with Docker-backed container execution and the `bus dev task` interface, prove a task can be created, executed in the configured Codex/container profile, and observed through `watch`, fix any integration/config/test issues found, update docs if operator-facing behavior changes, and verify focused module plus root changed-module gates.
- [x] Refine `bus configure` top-level get/set syntax end to end: document `bus configure KEY=VALUE [KEY2=VALUE2]` as the primary write form and `bus configure KEY [KEY2]` as the read-only lookup form, keep previous `edit` and `--set` compatibility, update root/module README examples, and verify module/root checks.
- [x] Clarify README module invocation guidance end to end: document dispatcher-first usage such as `bus journal ...`, explain that standalone `bus-*` binaries are installed for direct/debug use, and verify README lint.
- [x] Refine `bus configure` assignment syntax end to end: make README examples use `bus configure edit KEY=VALUE` instead of the redundant `edit --set KEY=VALUE` form, rely on default `.env` discovery in examples, preserve compatibility for older `--set` invocations, and verify README lint.
- [x] Refine README configure examples end to end: rely on default `.env` discovery instead of documenting redundant `--env-file .env` flags, keep the local stack setup commands script-friendly, and verify README lint.
- [x] Refine local Docker stack README setup end to end: replace raw `.env` copy/edit guidance with `bus configure` based initialization, validation, and non-interactive value setting, keep the local compose startup and portal/Codex/container smoke guidance complete, avoid documenting real secrets, and verify README lint plus root changed-module tests where practical.
- [x] Enable Bus portal modules in the local compose stack end to end: add `bus-portal` as a local source-run service with `auth`, `ai`, and experimental `accounting` modules enabled, proxy it through nginx under the local stack, document the portal URL and module set, extend the compose smoke test to verify health and `/v1/modules` exposes all portal modules, and verify root test/e2e plus focused docs lint.
- [x] Fix the root local AI Platform compose smoke path end to end: make `compose.yaml` route public container events through `bus-integration-containers` before the Docker backend, default the smoke harness to `.env` when it exists with `.env.example` as the non-secret fallback, add a deterministic container-run smoke assertion, and verify both Docker-backed container execution and Codex-backed LLM access through the local compose stack.
- [x] Add a local-only Bus cloud platform compose stack end to end: translate the UpCloud/Stripe tutorial into `docker compose up` from the BusDK superproject root using `.env`/`.env.example` style configuration, run PostgreSQL, MailHog, nginx, Events, Auth, LLM, Usage, Billing, VM, Containers, Stripe webhook, and local Docker-backed container execution with non-secret defaults, avoid UpCloud/systemd/real TLS dependencies, document local smoke flows and safety boundaries, add deterministic compose/config validation and shell smoke tests where practical, and verify changed-module/root quality gates.
- [x] Add a root Docker Compose environment for live-style `bus dev task` to local Docker-backed Codex container testing end to end: provide a superproject-root compose file that starts the local Events API and container API surfaces with non-secret development defaults, wires local macOS Docker execution through a new `bus-integration-docker` worker behind the existing `bus.containers.*` event contract, exposes a testing-agent shell with the relevant Bus CLIs available through module `go run`, documents token generation and smoke-test commands, avoids checked-in secrets or developer-machine paths, and verify the compose configuration plus direct container and `bus dev task watch` smoke paths deterministically.
- [ ] Run and finish the complete superproject quality sweep end to end: use the existing slow `quality-complete` root target to run source/static quality across every buildable `bus` and `bus-*` module, lint each available module `--help` output with `bus lint --type cli-help`, lint each published end-user module page under `docs/docs/modules/{name}.md` with `bus lint --type documentation`, fix source/help/documentation findings in the owning module/docs repo, rerun focused checks while iterating, and close only after the full all-module complete-quality sweep passes with no findings.
  - [x] `busdk#100.1` root orchestration fix: root module delegation now passes
    `BINARY=<module>` to module `make -C` calls, so worker or shell
    environments with `BINARY=busdk` no longer make `bus-dev`, `bus`, or other
    modules build the wrong `cmd/busdk` binary. Regression evidence:
    `bash tests/superproject/test_quality_complete.sh` passes with
    `BINARY=wrong-from-env`.
  - [x] `busdk#100.1` all-module source/static quality rerun reached every
    selected module after the root `BINARY` fix: in a disposable root copy with
    matching pinned module checkouts, `make quality-complete
    QUALITY_COMPLETE_KEEP_GOING=1 QUALITY_COMPLETE_PROGRESS=1` reported
    `quality: ran 114 module(s)` before entering doc/help lint. The direct
    isolated-worktree `make init` path is environment-limited in this worker
    because Git cannot create submodule gitdirs under read-only
    `/workspace/.git/worktrees/-busdk-busdk-100-1/modules/...`.
  - [ ] `busdk#100.1` remaining module-owned doc/help cleanup from the
    doc/help-only evidence capture: `make quality-complete
    QUALITY_COMPLETE_SOURCE=0 QUALITY_COMPLETE_BUILD=0
    QUALITY_COMPLETE_KEEP_GOING=1 QUALITY_COMPLETE_PROGRESS=1` reported
    `quality-complete: 117 step(s) failed across 114 module(s)` after
    attempting documentation lint for 114 modules and help lint for 107 modules;
    the failing total breaks down to 45 documentation-lint failures and 72
    help-lint failures. Exact focused rerun form for each module:
    `make quality-complete QUALITY_COMPLETE_SCOPE=changed
    CHANGED_MODULES='<module>' QUALITY_COMPLETE_SOURCE=0
    QUALITY_COMPLETE_PROGRESS=1`. Current failing modules and failure classes:
    `bus-accounts` documentation; `bus-api` help;
    `bus-api-provider-billing` help; `bus-api-provider-books`
    documentation/help; `bus-api-provider-cloud` help;
    `bus-api-provider-containers` help; `bus-api-provider-data`
    documentation; `bus-api-provider-database` help;
    `bus-api-provider-events` documentation/help;
    `bus-api-provider-inference` help; `bus-api-provider-llm`
    documentation/help; `bus-api-provider-node` help;
    `bus-api-provider-notes` documentation; `bus-api-provider-session`
    documentation/help; `bus-api-provider-terminal` help;
    `bus-api-provider-usage` help; `bus-api-provider-vm`
    documentation/help; `bus-assets` documentation/help;
    `bus-attachments` documentation/help; `bus-balances` documentation;
    `bus-bank` documentation; `bus-bfl` help; `bus-billing` help;
    `bus-books` help; `bus-budget` help; `bus-chat` help; `bus-config` help;
    `bus-configure` help; `bus-data` documentation/help; `bus-debts`
    documentation; `bus-entities` help; `bus-events` documentation;
    `bus-factory` documentation; `bus-faq` help; `bus-files` documentation;
    `bus-filing-prh` documentation/help; `bus-filing-vero`
    documentation/help; `bus-gateway` documentation/help; `bus-gx` help;
    `bus-help` help; `bus-init` help; `bus-inspection` help;
    `bus-integration-billing` help; `bus-integration-cloud`
    documentation/help; `bus-integration-codex` help;
    `bus-integration-containers` documentation/help;
    `bus-integration-database` help; `bus-integration-dev-task` help;
    `bus-integration-docker` documentation/help;
    `bus-integration-inference` documentation/help;
    `bus-integration-node` documentation/help; `bus-integration-notes`
    documentation; `bus-integration-ollama` help; `bus-integration-podman`
    documentation/help; `bus-integration-postgres` help;
    `bus-integration-ssh-runner` documentation/help;
    `bus-integration-stripe` documentation/help; `bus-integration-upcloud`
    help; `bus-integration-usage` help; `bus-inventory` documentation/help;
    `bus-invoices` help; `bus-journal` documentation; `bus-ledger` help;
    `bus-loans` documentation/help; `bus-memo` help; `bus-notes`
    documentation/help; `bus-operator-auth` help; `bus-operator-billing`
    documentation; `bus-operator-cloud` documentation/help;
    `bus-operator-database` documentation/help; `bus-operator-deploy` help;
    `bus-operator-node` help; `bus-operator-stripe` help;
    `bus-operator-token` help; `bus-payroll` documentation; `bus-pdf`
    documentation/help; `bus-period` help; `bus-portal` help;
    `bus-portal-ai` documentation; `bus-portal-notes` documentation;
    `bus-reconcile` help; `bus-remote-control` documentation; `bus-replay`
    documentation; `bus-secrets` documentation/help; `bus-sheets` help;
    `bus-status` help; `bus-update` help; `bus-validate` documentation/help.
  - [ ] `busdk#109.1` focused root quality reconnaissance follow-up: the worker
    stopped the broad AI-backed quality run early when it was heating the
    operator laptop, but captured enough evidence to route high-value owner
    fixes. Direct isolated worktree discovery found zero buildable modules
    because empty submodules plus the read-only `/workspace/.git/worktrees/...`
    gitdir block `make init`; the disposable `/tmp` copy excluding `.git`,
    `tmp`, and copied `bin` outputs found 114 buildable modules. Source/static
    quality reached all 114 modules and failed on `bus-books`,
    `bus-inspection`, `bus-ledger`, `bus-portal`, and `bus-portal-ai`. Route
    those as first follow-up workers, then continue with AI-platform and
    multi-remote docs/help cleanup, then accounting/filesystem/destructive CLI
    docs/help cleanup. Later `/tmp/.../bus/bin/bus: not found` lines in the
    task evidence were stop artifacts from terminating the expensive run, not a
    separate product finding.
    - [x] `busdk#110.1` checked the first owner shard, `bus-books`, and the
      focused module `make quality` gate passed without changes. Treat the
      earlier `bus-books` source/static failure as stale or
      context-dependent unless the next full sweep reproduces it.
    - [x] `busdk#111.1` checked the next owner shard, `bus-inspection`, and the
      focused module `make lint` plus `make quality` gates passed without
      changes. Treat the earlier `bus-inspection` source/static failure as
      stale or context-dependent unless the next full sweep reproduces it.
    - [x] `busdk#112.1` checked `bus-ledger`, and the focused module
      `make lint` plus `make quality` gates passed without changes. Treat the
      earlier `bus-ledger` source/static failure as stale or context-dependent
      unless the next full sweep reproduces it.
    - [x] `busdk#113.1` checked `bus-portal`, and the focused module
      `make quality` gate passed without changes. Treat the earlier
      `bus-portal` source/static failure as stale or context-dependent unless
      the next full sweep reproduces it.
    - [x] `busdk#114.1` checked `bus-portal-ai`, and the focused module
      `make lint` plus `make quality` gates passed without changes. Treat the
      earlier `bus-portal-ai` source/static failure as stale or
      context-dependent unless the next full sweep reproduces it.
    - [x] Bounded root source/static verification passed for the five checked
      modules with `make quality QUALITY_SCOPE=changed
      CHANGED_MODULES='bus-books bus-inspection bus-ledger bus-portal
      bus-portal-ai'`; it ran 5 modules successfully, so this source/static
      shard is closed unless a future full sweep reproduces a different
      failure.
    - [ ] Route AI-platform and multi-remote docs/help cleanup into explicit
      owner tasks for the provider/integration modules that affect operator
      setup confidence for localhost, external Events remotes, and UpCloud
      existing-runner testing.
    - [ ] Route accounting/filesystem/destructive CLI docs/help cleanup into
      explicit owner tasks for the modules whose help/docs affect safe scripted
      release and customer smoke usage.
- [x] Fix BusDK source-package pricing end to end: make the generated pricing model account for time-based human labour and deterministic operating-cost assumptions while still using commits for relative module sizing; remove stale hard-coded EUR totals from `busdk.com/docs`; update public docs/FAQ caveats; add regression coverage for the pricing generator; refresh generated pricing data; and verify root/docs/site checks.
- [x] Document Bus API JWT audiences and scopes end to end: review the current auth, events, LLM, VM, containers, and usage providers; write the public operator/end-user contract in `docs/docs`; write the implementation/security contract in `sdd/docs`; document which scopes are end-user API scopes versus internal service/admin scopes; flag any suspicious current mismatches; update navigation; verify docs quality; and close only after the documentation reflects the reviewed code.
- [x] Replicate module-local `quality` targets to every buildable submodule end to end: audit all top-level `bus`, `bus-*`, docs, sdd, aiz, and site Makefiles; add a source/static-only `quality` target that delegates to each module's existing formatting/lint/static checks without running unit/e2e tests; preserve module-local quality semantics and custom Bus lint wiring; run root `make quality QUALITY_SCOPE=all`; fix all reported source-quality issues; and close only when every selected module has a `quality` rule and passes.
- [x] Replicate module-local `quality` targets to currently edited Bus modules end to end: add a source/static-only `quality` Makefile rule to `bus-integration`, `bus-integration-upcloud`, `bus-integration-usage`, `bus-api-provider-llm`, `bus-api-provider-vm`, and `bus-api-provider-containers`; make it run formatting plus lint/custom Bus source lint without unit/e2e tests; keep root `make quality` compatible with module delegation; update no unrelated modules; and verify focused module quality targets plus root changed-module quality.
- [x] Clear Bus-side api-proxy cutover blockers end to end: coordinate fixes for shared JWT secret loading, configurable or refreshable internal service-token TTLs, internal container-runner lifecycle cleanup, UpCloud runner maintenance retries, and security proof for container isolation, event authorization, work-queue single-consumer delivery, broadcast multi-listener delivery, and streamed LLM client-abort handling; keep implementation in the owning provider/integration modules, update `BUGS.md`, README/public docs/SDD where command or deployment behavior changes, add unit/e2e regression coverage in each affected module, and verify through affected module gates plus root `make test`, `make e2e`, and `make quality`.
- [x] Make core Bus source-quality checks direct, not test-target-dependent, end to end: ensure root `make quality` always invokes `bus-dev quality lint` custom AST checks directly for each selected Go module even when module `lint` targets exist, keep module targets limited to additional source/static checks, update README/selftests/AGENTS guidance, and verify with root `make quality`, `make test`, and `make e2e`.
- [x] Ensure every Go module Makefile runs custom Bus source lint end to end: audit all buildable `bus`/`bus-*` module `lint` targets, add `BUS_DEV`/`BUS_GO_QUALITY_PROFILE` wiring and `bus-dev quality lint` calls where missing, update any module-local tests/docs if behavior changes, and verify with module/root `make quality`, `make test`, and `make e2e`.
- [x] Refine root `make quality` into a source-only static quality loop end to end: remove test-style module targets from default quality and deep-quality documentation, keep it focused on fast lint/static/security bad-pattern detection before tests, update help/README/selftests/AGENTS guidance, and verify with root `make quality`, `make test`, and `make e2e`.
- [x] Complete AI Platform api-proxy replacement parity across Bus end to end: coordinate the module plans for LLM runtime wake-up, streaming billing capture, usage-event taxonomy, model listing/cache behavior, auth check equivalence, scoped VM/container lifecycle access, secured event ACLs, and full-stack Docker e2e coverage; keep provider-specific work inside the owning `bus-api-provider-*` and `bus-integration-*` modules; update `docs/docs` and `sdd/docs`; and close only after root `make test`, `make e2e`, and `make quality` pass.
- [x] Make root `make quality` fast enough for normal AI cleanup loops end to end: remove duplicate custom lint execution when module `lint` already covers it, keep the default changed-module quality gate focused on lint/help/security/race checks, move fuzz/benchmark/Docker validation behind an explicit deep-quality mode, update README/help/selftests, and verify through root `make test`, `make e2e`, and both normal/deep quality runs.
- [x] Restore changed-module default for root quality end-to-end: make plain `make quality` use the same changed-module scope as root `make test`/`make e2e`, keep `QUALITY_SCOPE=all` as the explicit full-fleet sweep after the successful 55-module verification, update help/README/selftests, and verify the superproject scope behavior.
- [x] Fix current full root quality sweep findings end-to-end: run `make quality QUALITY_KEEP_GOING=1`, repair every reported module issue with tests/docs where behavior changes are involved, rerun focused module quality targets while iterating, then close only after root `make quality`, `make test`, and `make e2e` pass.
- [x] Make root `make quality` a true all-module sweep by default end-to-end: separate quality scope from test/e2e changed scope, keep an explicit changed-scope override for focused quality runs, update help/README/selftest coverage, and verify through the superproject selftest plus the relevant quality module-selection checks.
- [x] Fix root quality sweep findings end-to-end: run `make quality`, address reported reusable Bus Go quality findings in the affected modules with behavior-preserving code changes where possible and tests/docs where behavior changes are required, rerun the affected module quality/test gates, then close only after the relevant root quality/test/e2e verification is green.
- [x] Add a root quality sweep end-to-end: implement `make quality` in the superproject Makefile using deterministic module discovery/changed-scope selection, build and use the local `bus-dev` binary for reusable `quality lint`, delegate standard module validation targets one by one when present, add variables for profiles/target selection/keep-going behavior, update README/help, add superproject selftest coverage, and verify through root test/e2e gates.
- [x] Refresh the superproject agent container workflow so `scripts/start-shell.sh` and `scripts/start-agent.sh` provide a reproducible Go + Codex development environment with current toolchain packages, wrapper coverage, a real container e2e check, and any needed usage/doc updates in the same change set.
- [x] Refine the default agent-container interactive shell prompt so `scripts/start-shell.sh` opens with a stable BusDK-specific prompt instead of the container fallback identity prompt, with self-test coverage in the same change set.
- [x] Fix the superproject agent-container non-interactive TTY regression end-to-end: make `scripts/start-shell.sh <topic> <command...>` omit `docker run -it` for command-style non-interactive runs while still preserving interactive shell behavior when opening an actual shell, add or update superproject selftest coverage for both paths, and update any relevant usage/docs in the same change.
- [x] Remove remaining literal secret command-line arguments end to end: migrate user/operator JWT flags such as `bus vm --token`, `bus status --token`, `bus containers --token`, `bus auth --token`, `bus operator ... --token`, `bus operator token --internal-key`, and `bus operator stripe --api-key` to environment/config/token-file flows only; update help/README/public docs/SDD, add rejection tests for inline secret flags, update e2e coverage, and verify affected module tests/quality.
- [x] Complete end-user CLI argument documentation for AI Platform Bus modules end to end: audit help output against `docs/docs/modules/*` for the edited auth, billing, operator, VM/container/status/events, and integration modules; document every public flag and supported environment input without exposing secret values in examples; start by covering `bus-integration-upcloud --container-runner-name` and related runner flags; update README/SDD only where command behavior or operator contract changes; verify docs/module quality after edits.
