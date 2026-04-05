# BUGS.md

Track defects/blockers that affect this repo's replay/parity workflows.
Feature work belongs in `FEATURE_REQUESTS.md`.

**Last reviewed:** 2026-04-05.

## Active defects

- `bus reports statement-explain --report profit-and-loss` can still include explicit `closing-result` / legacy period-close rows in its explain/validate account scope even though the actual `profit-and-loss` report already excludes those rows from current-period activity.
  - Current behavior:
    - report calculation paths such as `profit-and-loss` and `*-accounts` already skip `closing-result` / legacy close rows through the shared period-close filter.
    - `statement-explain` / `statement-validate` still build their profit-and-loss account scope from raw journal rows in-period, so the explain surface can disagree with the rendered statement about whether close rows belong to current-period activity.
  - Expected:
    - the explain/validate profit-and-loss scope should honor the same close-row exclusion contract as the actual profit-and-loss statement and account-breakdown renderers.
  - Repo impact:
    - makes it look like classification support exists but is only partially honored, which is misleading during audit/debug work because explain output can contradict the real statement surface.
