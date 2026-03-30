# BUGS.md

Track defects/blockers that affect this repo's replay/parity workflows.
Feature work belongs in `FEATURE_REQUESTS.md`.

**Last reviewed:** 2026-03-30.

## Active defects

- `bus-reports` human-facing PDF reports still emit cell-like visible text objects outside the already-fixed statement row path. `general-ledger` is still reproducibly Preview-hostile, and the remaining wrapped-table/review layouts need the same non-cell row-text emission model that fixed `tase`/`tuloslaskelma`, while preserving readable `pdftotext` extraction.
