# FEATURE_REQUESTS.md

Enhancement requests for BusDK in this repo context.

Privacy rule for request write-ups:
- Keep examples/repro snippets sanitized (no real customer names/emails/IBANs/account numbers/invoice numbers/local paths).
- Prefer placeholders and aggregated outputs over raw customer-linked row dumps.

Last reviewed: 2026-03-15.

Goal note:
- Target workflow is Bus-only for bookkeeping/audit operations.
- Operators should not need shell text pipelines (`grep/sed/awk/column`) to answer accounting control questions.

Active requests:

1. Add a dedicated non-company / personal-finance reporting profile for Bus.
   - Status update 2026-03-15:
     - `bus-config` now ships workspace-level `busdk.accounting_entity.entity_kind` metadata with `business`/`personal` values and a deterministic `business` fallback for older workspaces.
     - `bus accounts sole-proprietor investment|withdrawal` now produces balanced owner-flow entry suggestions.
     - `bus reports compliance-checklist` already recognizes non-corporate applicability such as AGM/PRH filing not being required for a sole entrepreneur.
     - the active remaining gap is downstream consumer behavior, especially `bus-reports` defaults, household-native layouts, and person-appropriate evidence/report metadata.
   - Context and legal boundary:
     - ordinary household money management is not the same thing as Finnish statutory business bookkeeping, and Bus should not force personal users through company-only terminology or filing-shaped outputs.
     - the strongest compliance pressure in this use case is tax evidence, receipts, and muistiinpanovelvollisuus for activities such as rental, investment, forestry, and other non-business income-producing activity, not KPA/PMA annual statements.
   - Current limitation:
     - personal-finance books can be rendered today only by forcing them through company-style profit-and-loss and balance-sheet layouts.
     - that produces technically renderable outputs, but the terminology, grouping, PDF metadata, and default report set remain business/statutory shaped instead of fitting a household or natural person workspace.
     - transfers between a user's own accounts, savings moves, and private owner-style flows are not first-class presentation concepts in the reporting contract.
     - `annual-template` still outputs a PMA/KPA public-filing assembly template rather than a natural-person / household reporting package.
     - `filing-package` still marks company-style public-filing documents such as balance sheet, income statement, notes, and signatures as required public outputs even when the legal-form-aware checklist says PRH filing is not applicable.
     - there is still no visible report layout/profile selection that yields native personal-finance outputs.
   - Requested behavior:
     - support a first-class personal-finance reporting profile with person-appropriate layout ids, defaults, and PDF metadata that do not assume business-id/Y-tunnus, company signers, or statutory annual-report wording.
     - consume the shipped workspace-level entity classification metadata so Bus can distinguish a personal workspace from a business workspace and select the right default report family, evidence-pack behavior, and related reporting defaults without local scripts.
     - provide at least monthly budget-vs-actual, cashflow, net-worth, account-movement, and transfer-aware report surfaces.
     - treat own-account transfers and savings moves separately from income and expense so household cashflow is understandable without local post-processing.
     - support attachment and tax-evidence friendly outputs so receipts, deduction evidence, and long-lived asset/improvement records can be linked back to reports.
     - ensure annual/package outputs follow the same non-corporate profile instead of falling back to PMA/KPA public-filing structure.
   - Data-model and standards direction:
     - keep the core model account-based and ledger-compatible, but make the household defaults category-first rather than company-statement-first.
     - use COICOP 2018 as the default expense-category baseline, while allowing user-defined subcategories and rules.
     - keep ISO 20022 camt.053/camt.054 file import as the preferred early data-ingest path for household banking data.
     - treat ISO 22222 as planning-process background for goals, review cadence, and financial-wellbeing workflows rather than as a bookkeeping schema.
   - Household-specific UX and privacy direction:
     - support multi-member households, shared accounts, split attribution of transactions, and visibility levels ranging from summary-only to line-level detail.
     - keep privacy-by-design explicit because personal finance data can reveal sensitive life details even when the service is not a regulated financial institution.
     - keep export/delete/data-portability paths explicit in the user-facing design.
   - Compliance and integration constraints:
     - keep file import as the safe default path; any future live bank-feed design must respect PSD2/AIS, strong customer authentication, and secure communication requirements instead of screen-scraping assumptions.
     - if Bus ever moves into regulated AIS territory, the design must also account for the higher ICT-governance bar that follows from that operating model.
   - Why this matters:
     - personal books need native Bus outputs instead of company statements adapted afterward in local replay scripts.
     - the end state should be a household-appropriate Bus workflow that still preserves deterministic accounting data, tax evidence traceability, and long-term portability.
