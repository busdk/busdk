# BUGS.md

Track defects/blockers that affect this repo's replay/parity workflows.
Feature work belongs in `FEATURE_REQUESTS.md`.

**Last reviewed:** 2026-04-06.

## Active defects

- `bus-secrets`: repo-scope `set` + `list` succeeds after fresh `init`, but `get` for the same secret fails with `secret not found`, and no `.bus/secrets/<name>.sops.json` file is created in the target repo. Repro from this checkout:
  `HOME=$(pwd)/busdk.com/tmp/secrets-local-home ./bus-secrets/bin/bus-secrets -C busdk.com/tmp/secrets-local-demo init`
  `HOME=$(pwd)/busdk.com/tmp/secrets-local-home ./bus-secrets/bin/bus-secrets -C busdk.com/tmp/secrets-local-demo set smoke.test value --scope repo`
  `HOME=$(pwd)/busdk.com/tmp/secrets-local-home ./bus-secrets/bin/bus-secrets -C busdk.com/tmp/secrets-local-demo list --scope repo`
  `HOME=$(pwd)/busdk.com/tmp/secrets-local-home ./bus-secrets/bin/bus-secrets -C busdk.com/tmp/secrets-local-demo get smoke.test --scope repo`
  Observed: `list` prints `smoke.test`, but `get` fails and the repo contains only `.bus/secrets/config.json` and `recipients.txt`.
