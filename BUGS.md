# BUGS.md

Track defects/blockers that affect this repo's replay/parity workflows.
Feature work belongs in `FEATURE_REQUESTS.md`.

**Last reviewed:** 2026-03-30.

## Active defects

- `bus-reports` `tase-accounts.pdf` falls back to cell-like PDF text emission on later pages even though the first pages already use the Preview-friendly row-text path. In Apple Preview these later statement rows still select as table cells and cannot be highlighted/annotated normally. The fix must remove that remaining cell-style statement text path entirely from human-facing statement PDFs, keep the metadata box behavior that already annotates correctly, and preserve readable `pdftotext` extraction.
