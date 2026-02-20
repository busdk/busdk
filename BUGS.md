# BUGS.md

Track **defects and blockers** that affect this repo's replay or parity work: actual bugs in our software or in BusDK/tooling when they block us. **Nice-to-have features and enhancement requests** are in **[FEATURE_REQUESTS.md](FEATURE_REQUESTS.md)**.

**Last reviewed:** 2026-02-20 (revalidated after update merge).

---

## Active issues

- None currently open in this tracker file.

## Resolved (2026-02-20)

- `bus status readiness` now applies post-subcommand `--year`, `--format`, `--compliance` flags and rejects unknown extras.
- `bus-vat validate --strict-fi-eu-rc` now works in subcommand-flag position.
- `bus-vat report --from/--to` now skips strict period-coverage failure when coverage metadata is unavailable (same workspace preconditions as period mode).
- `bus bank backlog -f json` now returns usage error when global flags are placed after subcommand (`global flag ... must appear before subcommand`); pre-subcommand form still works.
- `bus-reconcile match/propose` now compare bank amount to invoice evidence gross (lines + VAT model) instead of header `total_net`, aligning with `bus-invoices` net validation semantics.
- `bus-reconcile post --kind invoice_payment` now supports deterministic partial payments with money-safe prorated VAT split and explicit `posted_amount`/`open_amount` status fields.
- `bus reconcile propose` now falls back to yearly journal schema (`journal-YYYY.schema.json`) when monthly journal schema sidecars are missing for indexed monthly journal CSV files.
