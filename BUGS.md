# BUGS.md

Track defects/blockers that affect this repo's replay/parity workflows.
Feature work belongs in `FEATURE_REQUESTS.md`.

**Last reviewed:** 2026-04-25.

## Active defects

None currently.

## Fixed defects

- [x] Linux CI `make test` fails in `superproject-selftest`
  - Reported: 2026-04-25 from GitHub Actions publish run `24927523868`.
  - Symptom: `make test` exits through `Makefile:104: superproject-selftest`.
  - Fixed: changed `tests/superproject/test_changed_scope.sh` exact-match checks from doubled end anchors to portable single `$` anchors.
  - Verified: `bash ./tests/superproject/test_changed_scope.sh`, `make superproject-selftest`, `make test`, and `make e2e`.
