# BUGS.md

Track defects/blockers that affect this repo's replay/parity workflows.
Feature work belongs in `FEATURE_REQUESTS.md`.

**Last reviewed:** 2026-03-29.

## Active defects

- `bus reports day-book` and `general-ledger` expose long internal system IDs (`transaction_id`, `entry_id`) directly in human-facing columns instead of using visible/report-friendly identifiers or an abbreviated stable display form.
  - Repro:
    - `make -C exports/sanitized/data reports`
    - `pdftotext exports/sanitized/data/reports/20231231-day-book.pdf - | sed -n '15,80p'`
    - `pdftotext exports/sanitized/data/reports/20231231-general-ledger.pdf - | sed -n '15,80p'`
  - Current behavior:
    - printable day-book and general-ledger still show long technical identifiers in human-facing columns.
    - these IDs dominate the row layout and wrap across lines in dense printable reports.
    - page-local width balancing remains too rigid for mixed-width accounting rows.
  - Expected:
    - human-facing reports should prefer visible/report-friendly identifiers where available.
    - if technical IDs must remain visible for traceability, they should use a deterministic compact display form.
    - printable tables should size columns page-locally enough that identifier columns remain readable.

- `bus reports` printable table layout does not keep row height synchronized across cells, so wrapped content stretches only the overflowing cell instead of the entire logical row.
  - Repro:
    - `make -C exports/sanitized/data reports`
    - inspect `20231231-day-book.pdf` and `20231231-general-ledger.pdf`
  - Current behavior:
    - when one cell wraps, only that cell visually grows.
    - sibling cells do not expand to the same row height, so the output no longer reads as a coherent table row.
  - Expected:
    - row height should be determined by the tallest cell on that row.
    - once any cell wraps, every cell on the same logical row should occupy the same vertical row block.

- `bus reports day-book` and `general-ledger` do not preserve journal append order for same-day postings; they sort by internal IDs/string fields instead of the order postings were added.
  - Repro:
    - `make -C exports/sanitized/data reports`
    - compare journal append order to printable `day-book` / `general-ledger`
  - Current behavior:
    - same-day postings can appear in lexicographic internal-id order rather than journal append order.
    - line ordering can behave like string sorting instead of numeric append sequence order.
  - Expected:
    - printable reports must preserve the same transaction and line order as the journal was appended to Bus for rows sharing the same posting date.
