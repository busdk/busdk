# Workspace Handoff Notes

## 2026-02-26 - Period reopen attempt for 2024-12

- Scope: `/Users/jhh/git/busdk/busdk/examples/synthetic-full-fictional-2024/data`
- Request: reopen period `2024-12` with approval metadata for adding a new purchase invoice.
- Commands run:
  - `bus period reopen --period 2024-12 --reason "New purchase invoice must be added." --approved-by "Jaakko Heusala, CEO"` -> failed: `period "2024-12" is locked; cannot reopen`
  - `bus period open --period 2024-12` -> failed: `period "2024-12" is locked; cannot re-open`
  - `bus period list` -> `2024-12` state remains `locked`
  - `bus period list --history | tail -n 6` -> latest rows confirm `2024-12` is `closed` then `locked` at `2026-02-26T13:04:08Z`
- Result: reopen not possible through current Bus period commands once locked.
- Blocker: locked period prevents invoice insertion into `2024-12` without an alternate workflow (replay-before-lock or supported unlock capability).

## CLI invocation notes learned

- `bus period` subcommand help is not accepted as `bus period <subcommand> --help` in this environment.
- Use `bus period --help` for command-level guidance.

## 2026-02-26 - Balance sheet / profit-and-loss regeneration attempt

- Scope: `/Users/jhh/git/busdk/busdk/examples/synthetic-full-fictional-2024/data`
- Request: produce `Tase` and `Tuloslaskelma`.
- Commands run:
  - `bus -o balance-sheet-2024-12-31.csv -f csv reports balance-sheet --as-of 2024-12-31` -> failed: `bus-reports: row 140 duplicate primary key`
  - `bus -o profit-loss-2024.csv -f csv reports profit-and-loss --period 2024` -> failed: `bus-reports: row 140 duplicate primary key`
  - `bus -o tase-2024-12-31.pdf -f pdf reports balance-sheet --as-of 2024-12-31` -> failed: `bus-reports: row 140 duplicate primary key`
  - `bus -o tuloslaskelma-2024.pdf -f pdf reports profit-and-loss --period 2024` -> failed: `bus-reports: row 140 duplicate primary key`
  - `bus validate` -> pass (exit 0, no output)
  - `bus status` -> `READY_TECHNICAL`, latest period `2024-12` in `locked` state
- Recovery action:
  - Failed `bus -o` runs truncated report files to zero bytes.
  - Restored from tracked `HEAD` content:
    - `git show HEAD:examples/synthetic-full-fictional-2024/data/balance-sheet-2024-12-31.csv > balance-sheet-2024-12-31.csv`
    - `git show HEAD:examples/synthetic-full-fictional-2024/data/profit-loss-2024.csv > profit-loss-2024.csv`
    - `git show HEAD:examples/synthetic-full-fictional-2024/data/tase-2024-12-31.pdf > tase-2024-12-31.pdf`
    - `git show HEAD:examples/synthetic-full-fictional-2024/data/tuloslaskelma-2024.pdf > tuloslaskelma-2024.pdf`
- Current available outputs:
  - `balance-sheet-2024-12-31.csv`, `profit-loss-2024.csv`, `tase-2024-12-31.pdf`, `tuloslaskelma-2024.pdf` restored and non-empty.
- Blocker:
  - `bus reports balance-sheet` and `bus reports profit-and-loss` currently fail with duplicate primary key error (`row 140`) and cannot be regenerated until underlying data/parser issue is resolved.

## 2026-02-26 - Extended statement outputs (laaja) workaround

- Scope: `/Users/jhh/git/busdk/busdk/examples/synthetic-full-fictional-2024/data`
- Request: produce extended versions of balance sheet and profit-and-loss.
- Root-cause finding:
  - `journal-2024.csv` and `journal-2024-12.csv` overlap on `entry_id` values (18 duplicates), while both are listed in `journals.csv`.
  - This triggers `bus-reports: row 140 duplicate primary key` in direct report generation.
- Workaround execution:
  - Created isolated temp workspace copy under `/tmp/bus-laaja-2024`.
  - In temp copy, restricted `journals.csv` to `period=2024` -> `journal-2024.csv` only.
  - Generated extended reports with `--layout-id kpa-full`:
    - `tase-2024-12-31-laaja.pdf`
    - `tuloslaskelma-2024-laaja.pdf`
    - `tase-2024-12-31-laaja.csv`
    - `tuloslaskelma-2024-laaja.csv`
  - Copied generated outputs back to this workspace.
- Result:
  - Extended files are now present and non-empty in this workspace.
  - Core workspace accounting source files were not modified for the workaround.

## 2026-02-26 - Duplicate CSV verification from replay/export artifacts

- Scope: `/Users/jhh/git/busdk/busdk/examples/synthetic-full-fictional-2024/data`
- Prompt: verify whether duplicate CSV content may exist from `../*.bus` exports.
- Findings:
  - No in-file duplicate full rows detected in top-level `*.csv`.
  - Cross-file overlap detected in `journal` exports:
    - `journal-2024.csv` (year scope) and `journal-2024-12.csv` (month scope) share 18 identical `entry_id` values.
    - `journals.csv` includes both files (`2024,journal-2024.csv` and `2024-12,journal-2024-12.csv`), which can trigger duplicate-key ingestion paths in reports.
- Representative command evidence:
  - `python3` duplicate scan over `journal*.csv` -> `total overlapping entry_id: 18`.
  - `rg -n "reports -o|journal"` on `../2025-01-closing.bus` confirms annual report export flow in replay scripts.

## 2026-02-27 - Day book / general ledger PDF regeneration

- Scope: `/Users/jhh/git/busdk/busdk/examples/synthetic-full-fictional-2024/data`
- Request: produce `päiväkirja` and `pääkirja` as PDF.
- Direct command attempt:
  - `bus -o day-book-2024.pdf -f pdf reports day-book --period 2024` -> failed: `bus-reports: row 140 duplicate primary key`
  - `bus -o general-ledger-2024.pdf -f pdf reports general-ledger --period 2024` -> failed: `bus-reports: row 140 duplicate primary key`
- Workaround execution:
  - Created isolated temp workspace copy at `/tmp/bus-daybook-ledger-2024`.
  - In temp copy, restricted `journals.csv` to `period=2024` row (`journal-2024.csv`) to avoid overlapping `entry_id` ingestion.
  - Generated PDFs in temp workspace:
    - `day-book-2024.pdf`
    - `general-ledger-2024.pdf`
  - Copied generated PDFs back into this workspace.
  - Added Finnish alias filenames:
    - `paivakirja-2024.pdf` (copy of `day-book-2024.pdf`)
    - `paakirja-2024.pdf` (copy of `general-ledger-2024.pdf`)
- Verification:
  - `wc -c day-book-2024.pdf general-ledger-2024.pdf paivakirja-2024.pdf paakirja-2024.pdf` -> all files non-zero (`19934` / `20033` bytes).
- Result:
  - Requested day book and general ledger PDFs are present and non-empty in the workspace.
  - Core accounting source CSV files in workspace were not modified.

## 2026-03-01 - Tase / Tuloslaskelma regeneration (updated outputs)

- Scope: `/Users/jhh/git/busdk/busdk/examples/synthetic-full-fictional-2024/data`
- Request: create updated `Tase` and `Tuloslaskelma` outputs.
- Preflight commands run:
  - `pwd`, `ls`
  - `bus --help`, `bus journal --help`
  - `rg --files -g 'journal*.csv'`, `rg --files -g '*.csv'`
- Direct command attempt (workspace):
  - `bus validate && bus status && bus -o tase-2024-12-31.pdf -f pdf reports balance-sheet --as-of 2024-12-31 ...` -> failed at first report with `bus-reports: row 140 duplicate primary key`.
- Workaround attempts:
  - Temp workspace with restricted journals (`period,filename` -> only `2024,journal-2024.csv`) and default layout -> failed: unmapped account `2931` for `statement_target=tase` (`FR-REP-007`).
  - Temp workspace with same restricted journals and explicit `--layout-id kpa-full` -> success for all requested outputs.
- Generated and copied back to workspace:
  - `tase-2024-12-31.pdf`
  - `tuloslaskelma-2024.pdf`
  - `tase-2024-12-31.csv`
  - `tuloslaskelma-2024.csv`
- Verification:
  - `wc -c tase-2024-12-31.pdf tuloslaskelma-2024.pdf tase-2024-12-31.csv tuloslaskelma-2024.csv` -> non-zero sizes (`2481`, `2639`, `439`, `508` bytes).
  - `head` checks show valid CSV headers and section rows.
  - `bus validate && bus status` -> validation pass; status remains `READY_TECHNICAL`, latest period `2024-12` locked.
- Remaining blockers:
  - Direct workspace report generation without workaround still blocked by duplicate key ingestion.
  - Default-layout balance-sheet generation also blocked by missing report mapping for account `2931`.
