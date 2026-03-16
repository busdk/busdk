# BUGS.md

Track defects/blockers that affect this repo's replay/parity workflows.
Feature work belongs in `FEATURE_REQUESTS.md`.

**Last reviewed:** 2026-03-15.

## Active defects

- `bus reports filing-package` and `annual-template` stay company/public-filing shaped even when Bus already treats the workspace as a non-corporate sole-entrepreneur profile.
  - Repro:
    - `bus -C exports/jhh/2025/data reports compliance-checklist --period 2025`
    - `bus -C exports/jhh/2025/data reports filing-package --period 2025`
    - `bus -C exports/jhh/2025/data reports annual-template --period 2025`
  - Current behavior:
    - the checklist marks corporate-only controls as not applicable, for example AGM and PRH annual filing are `not_applicable`.
    - but `filing-package` still marks `balance_sheet`, `income_statement`, `notes`, and `signatures_and_approval_date` as required `public_filing` outputs.
    - `annual-template` still emits a PMA/KPA public-filing assembly (`cover`, `income_statement`, `balance_sheet`, `notes`, `signatures`).
  - Expected:
    - once Bus has recognized the workspace as non-corporate / sole-proprietor for compliance purposes, package/template outputs should follow the same profile and stop requiring company-style public-filing structure.
  - Repo impact:
    - JHH still cannot use Bus-native annual/package outputs as its final personal-finance reporting surface even though some personal / sole-proprietor support has landed.
