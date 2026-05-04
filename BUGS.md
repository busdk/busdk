# BUGS.md

Track defects/blockers that affect this repo's replay/parity workflows.
Feature work belongs in `FEATURE_REQUESTS.md`.

**Last reviewed:** 2026-05-03.

## Active defects

No active defects.

## Fixed defects

- [x] Cross-module `bus dev task new` inherited the sender branch and made
  workers fail before execution.
  - Reported: 2026-05-03 while dispatching module tasks from `bus-dev`; worker
    histories showed `stderr: error: pathspec '1-bus-dev' did not match any
    file(s) known to git` for target modules that did not have the sender's
    current branch.
  - Fixed: `bus dev task new` now defaults branch metadata only for tasks whose
    recipient is the current project. Cross-module tasks omit branch metadata
    unless `--branch` or `--new-branch` is explicit.
  - Verified: `make test` and `make e2e` in `bus-dev`.

- [x] Concurrent `bus dev task new` calls can allocate duplicate task refs.
  - Reported: 2026-05-03 while dispatching parallel module tasks through the
    local Docker-backed `bus dev task` stack. Two concurrent task creations
    both printed `created bus-dev#10` / `created bus-dev#10.1`, targeting
    different modules.
  - Fixed: the shared Unix directory lock now keeps the lock file visible while
    held so every process locks the same inode, and `bus dev task new` holds
    that repository lock while it replays existing group refs and publishes the
    group/member events. Local parallel creators for the same project now
    serialize allocation without reintroducing repository-local sequence state.
  - Verified: `go test ./run -run
    'TestRunTaskNewConcurrentSubprocessesAllocateUniqueRefs|TestRunTaskNewAllocatesGroupIDFromEventReplay|TestRunTaskNewPublishesDevelopmentTaskEvents'`;
    `go test ./internal/lock ./run -run
    'TestAcquire_release|TestRunTaskNewConcurrentSubprocessesAllocateUniqueRefs'`;
    `make test` and `make e2e` in `bus-dev`.

- [x] `bus dev task watch 1.1` matches stale tasks from other modules instead
  of resolving shorthand refs relative to the current project.
  - Reported: 2026-05-03 from `bus dev -C ./bus-vat task new ...` printing
    `bus-vat#1.1`, then `bus dev -C ./bus-vat task watch 1.1 --timeout 5m`
    replaying old `bus-dev#1.1` events before the intended `bus-vat#1.1`
    events.
  - Required fix: scope unqualified task refs such as `1` and `1.1` to the
    current `-C` project for show/watch/wait/list-style matching, keep fully
    qualified refs such as `bus-dev#1.1` cross-project capable, add unit/e2e
    coverage, update docs/help if shorthand semantics are clarified, and verify
    focused module plus root gates.
  - Fixed: unqualified task refs such as `1` and `1.1` now match only task
    events that belong to the current repository selected by `-C`; fully
    qualified refs such as `bus-dev#1.1` still target the named module.
    README and task help now document the shorthand behavior.
  - Verified: `make test` and `make e2e` in `bus-dev`.

- [x] README local `docker compose up` + `bus configure` + `bus dev task` quickstart does not work end to end.
  - Reported: 2026-05-03 from the documented command sequence:
    `docker compose up --build -d`; configure `BUS_API_TOKEN` from
    `tmp/local-ai-platform/bus-config/auth/api-token`; configure
    `BUS_EVENTS_API_URL=http://127.0.0.1:8080`; run
    `bus dev -C ./bus-dev task new "Show the Codex CLI version."`; then watch
    the printed task reference.
  - Required fix: reproduce the exact README flow, identify whether the defect
    is token timing, `.env` loading, dispatcher/module behavior, compose
    routing, or task worker execution, then fix the owning module/compose/docs
    with unit/e2e coverage and verify the exact command sequence.
  - Fixed: `bus-dev` now retries transient read-only Events replay/listen
    startup failures before publishing task events, local compose mounts the
    Codex home writable for trusted live Codex sessions, local compose runs
    Codex with full access inside the already isolated task container, and
    post-commands are opt-in so a smoke task cannot stage or commit files.
    `bus-integration-dev-task` now uses `sh -c` instead of login shell mode so
    the container image `PATH` is preserved.
  - Verified: rebuilt `bus-dev` created and watched `bus-dev#17.1`, which ran
    in `/workspace/bus-dev` and reported `codex-cli 0.128.0`; `bus lint
    README.md`; `make test` in `bus-dev`; `make test` in
    `bus-integration-dev-task`; `bash
    tests/superproject/test_local_ai_platform_compose_smoke.sh`; `bash
    tests/superproject/test_dev_task_docker_compose_smoke.sh`; root `make
    test`; root `make e2e`.

- [x] Root local AI Platform compose bypasses the provider-neutral container router
  - Reported: 2026-05-03 while testing the local Docker Compose environment for Docker-backed containers and ChatGPT-powered LLM use.
  - Symptom: `compose.yaml` starts `bus-integration-docker` directly on public `bus.containers.*` events instead of routing through `bus-integration-containers` to backend-prefixed `bus.docker.*` events, so the full local stack does not exercise the intended provider-neutral container abstraction. The smoke harness also forces `.env.example`, which can hide local Codex/App Server settings from `.env`.
  - Fixed: wired the full local stack through `bus-integration-containers`, kept Docker on the `bus.docker.*` backend prefix, made the smoke harness use `.env` when present, added a real `bus containers run` assertion, and built the compose Codex worker with Codex CLI plus mounted local Codex auth for live ChatGPT-backed testing.
  - Verified: `BUS_LOCAL_AI_PLATFORM_LIVE_CODEX=1 bash tests/superproject/test_local_ai_platform_compose_smoke.sh`.

- [x] Bus replacement cutover lacks security proof for critical API/event/stream invariants
  - Reported: 2026-04-26 during Bus replacement cutover checks for the old AI Platform api-proxy.
  - Missing proof: container account isolation, event stream account authorization, work-queue single-consumer delivery, broadcast multi-listener delivery, and streamed LLM client-abort handling.
  - Fixed: added container account/usage propagation unit coverage plus Events-backed account propagation e2e; added Events API `container:admin` ACL coverage, cross-account stream isolation e2e, broadcast multi-listener e2e, and retained work-queue single-consumer proof; added LLM streamed client-abort full-stack e2e proof that `client_aborted` is persisted.
  - Verified: `make test` and `make e2e` in `bus-api-provider-containers`; `make test` and `make e2e` in `bus-api-provider-events`; `make test` and `make e2e` in `bus-api-provider-llm`.

- [x] UpCloud container runs fail immediately during transient runner VM maintenance
  - Reported: 2026-04-26 during Bus replacement cutover checks for the old AI Platform api-proxy.
  - Symptom: a Bus container run failed when UpCloud returned `SERVER_STATE_ILLEGAL` while the runner VM was in maintenance.
  - Fixed: `bus-integration-upcloud` now treats `SERVER_STATE_ILLEGAL` and `maintenance` state during start as transient, polls the configured server until it starts or the bounded context/start timeout expires, and returns a clear maintenance timeout diagnostic on expiry.
  - Verified: `make test` and `make e2e` in `bus-integration-upcloud`.

- [x] Bus container replacement lacks an internal runner lifecycle API or equivalent cleanup path
  - Reported: 2026-04-26 during Bus replacement cutover checks for the old AI Platform api-proxy.
  - Symptom: the old proxy exposed `/api/internal/containers/runner` for runner status/start/delete cleanup, but the Bus containers provider exposed only public `/api/v1/containers/*` user-owned APIs.
  - Fixed: added protected `GET`, `POST`, and `DELETE /api/internal/containers/runner` endpoints requiring audience `ai.hg.fi/internal` and scope `container:admin`; added matching Bus Events request/reply names and UpCloud worker handlers for runner status/start/delete.
  - Verified: `make test` in `bus-api-provider-containers` and `bus-integration-upcloud`; container e2e coverage includes static and Events-backed internal runner status/start/delete plus unauthorized public-token rejection.

- [x] Internal service tokens expire too quickly for long-running Bus workers
  - Reported: 2026-04-26 during Bus replacement cutover checks for the old AI Platform api-proxy.
  - Symptom: auth-issued internal service tokens appeared hard-coded to a 10 minute TTL. Long-running workers such as `bus-integration-usage`, `bus-integration-upcloud`, and `bus-integration-ssh-runner` needed configurable TTL or safe refresh/reissue behavior.
  - Fixed: added `BUS_AUTH_INTERNAL_TOKEN_TTL_SECONDS` with a secure 600 second default and documented that long-running trusted workers should use a longer internal token TTL or rotate/restart before expiry.
  - Verified: `make test` and `make e2e` in `bus-api-provider-auth`.

- [x] Bus API providers disagree on HS256 JWT secret decoding, breaking auth-issued tokens across providers
  - Reported: 2026-04-26 during Bus replacement cutover checks for the old AI Platform api-proxy.
  - Symptom: `bus-api-provider-auth` auto-decoded base64-looking `BUS_AUTH_HS256_SECRET`, while other Bus API providers treated JWT secrets as raw text. Tokens issued by auth failed against Events until a non-base64-looking secret was used.
  - Fixed: added the shared `jwtsecret` loader in `bus-api-provider-auth`, made all affected API providers use it, changed decoding to require an explicit `base64:` prefix, and documented that plain secret values remain raw text even when base64-looking.
  - Verified: `make test` and `make e2e` in `bus-api-provider-auth`, `bus-api-provider-events`, `bus-api-provider-llm`, `bus-api-provider-vm`, `bus-api-provider-containers`, `bus-api-provider-usage`, plus `bus-integration-usage` after dependency wiring.

- [x] Linux CI `make test` fails in `superproject-selftest`
  - Reported: 2026-04-25 from GitHub Actions publish run `24927523868`.
  - Symptom: `make test` exits through `Makefile:104: superproject-selftest`.
  - Fixed: changed `tests/superproject/test_changed_scope.sh` exact-match checks from doubled end anchors to portable single `$` anchors and isolated selftest scripts from inherited recursive GNU make state.
  - Verified: `bash ./tests/superproject/test_changed_scope.sh`, `make superproject-selftest`, `make test`, `make e2e`, Linux-container `bash ./tests/superproject/test_changed_scope.sh`, and Linux-container `make test`.
