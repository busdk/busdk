# BUGS.md

Track defects/blockers that affect this repo's replay/parity workflows.
Feature work belongs in `FEATURE_REQUESTS.md`.

**Last reviewed:** 2026-04-26.

## Active defects

No active defects.

## Fixed defects

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
