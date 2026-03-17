# FEATURE_REQUESTS.md

Enhancement requests for BusDK in this repo context.

Privacy rule for request write-ups:
- Keep examples/repro snippets sanitized (no real customer names/emails/IBANs/account numbers/invoice numbers/local paths).
- Prefer placeholders and aggregated outputs over raw customer-linked row dumps.

Last reviewed: 2026-03-17.

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

2. Add a Windows-native BusDK bootstrap installer and HTTPS executable package management.
   - Status update 2026-03-16:
     - Windows release assets currently ship as a ZIP of binaries rather than a native installer.
     - `bus` is intentionally only a dispatcher and should remain the user-facing entry point, but package-management logic should live in `bus-update`, not in `bus` core.
     - `bus-update` currently focuses on release checking and Git-workspace module updates; it does not yet manage installed machine-local executable packages.
   - Current limitation:
     - Windows users do not have an MSI-style bootstrap installer for a first-class BusDK install/uninstall/upgrade flow.
     - the current distribution model assumes downloading many binaries at once, even when a user needs only `bus` plus a small initial tool set.
     - there is no stable BusDK package URL contract for downloading a single module executable by module name, operating system, architecture, and version.
     - there is no machine-local package database or managed installation directory for optional `bus-*` executables outside the Git-workspace update flow.
   - Requested behavior:
     - ship an MSI-style Windows bootstrap installer that installs only `bus` and `bus-update` into a managed BusDK binary directory and adds that directory to `PATH`.
     - keep `bus` as a thin dispatcher; installer/package-manager UX exposed through `bus ...` must continue to delegate to `bus-update` rather than embedding package-management logic into the dispatcher.
     - extend `bus-update` into a package manager that can install, upgrade, remove, list, and verify additional `bus-*` executable packages in the managed binary directory.
     - preserve a clear distinction between machine-local package-management flows and the existing Git-workspace module-update flows so users can understand which surface they are using.
     - make module packages downloadable as single executables over HTTPS from a stable URL or manifest contract that identifies at least module name, operating system, architecture, version, and checksum/signature material; for example a shape like `https://pkg.busdk.com/busdk/{os}/{arch}/{module}/{version}` or an equivalent deterministic layout.
     - support Windows-native `.exe` package installation while keeping the package contract compatible with other operating systems and architectures.
   - Security and operability constraints:
     - package fetch/install must verify integrity before replacing an installed executable and should use atomic replacement/rollback semantics on failure.
     - package-management tests must be hermetic by default, using local stub HTTPS fixtures or deterministic test servers instead of real network dependencies.
     - the bootstrap installer and package-manager docs must explain install root, PATH behavior, uninstall/upgrade semantics, and how checksum/signature verification works.
   - Why this matters:
     - a small bootstrap installer reduces Windows installation friction and avoids bundling the full toolchain when only a few modules are needed initially.
     - turning `bus-update` into the package manager preserves the BusDK module boundary: `bus` stays minimal while package-management behavior has a clear owning module.
     - a stable per-module HTTPS package contract enables future automation, selective installs, and predictable upgrade tooling across Windows and other platforms.

3. Add a working Docker image for `bus-portal`.
   - Status update 2026-03-16:
     - `bus-portal` currently documents local execution and has no documented or checked-in runtime Docker image contract.
     - the module already depends at runtime on `bus-attachments` for upload handling and `bus-reports` for evidence-pack generation, so a useful image must account for those helper binaries rather than packaging `bus-portal` alone.
   - Current limitation:
     - there is no supported container image that starts the customer portal against a mounted workspace and prints a usable URL for opening the app.
     - the current local default behavior is oriented around app-style local shell startup, which is not appropriate inside a normal Docker container.
     - there is no documented container contract covering workspace mount path, exposed port, writable output paths under `.bus/`, or helper-binary availability.
   - Requested behavior:
     - ship a working Docker image for `bus-portal` that starts the server on a container-safe listen address, prints the token-gated URL to stdout, and does not attempt GUI/webview startup inside the container.
     - support a mounted workspace so the running portal can read workspace metadata, store uploaded files through `bus-attachments`, and persist evidence-pack state and artifacts under `.bus/bus-portal/...`.
     - bundle or otherwise provide the runtime helper binaries required for the current portal behavior, at minimum `bus-attachments` and `bus-reports`, so upload and `Aloita` evidence-pack flows work inside the image.
     - document a stable `docker run` operator contract covering volume mount, port mapping, startup output, and any required environment variables.
   - Verification and quality constraints:
     - add deterministic container-oriented verification that the image starts successfully, prints the URL, serves the landing page, accepts uploads, runs evidence-pack generation, and exposes generated artifacts from the mounted workspace.
     - keep the image behavior script-friendly and suitable for local/container deployment without relying on host GUI integration.
   - Why this matters:
     - a documented working image makes the customer portal easier to run in repeatable local and server environments than the current source-first local setup.
     - the portal is only truly useful in a container when the mounted-workspace upload and evidence-pack flows work end-to-end, not just when the HTTP server starts.

4. Add first-class editor tooling and distribution for `.bus` source files.
   - Status update 2026-03-16:
     - the repository already ships a VS Code-compatible `.bus` language package, but the remaining active work is broader distribution and deeper editor tooling rather than basic syntax-highlighting existence.
     - the currently unchecked follow-up work is concentrated in the `bus` module plan and covers distribution, parser-backed highlighting, and semantic editor support.
   - Current limitation:
     - the current `.vsix` distribution story is not yet fully automated/documented across the intended editor/package surfaces.
     - there is no Tree-sitter grammar/query layer yet for parser-backed highlighting in editors such as Neovim/Emacs.
     - there is no semantic-token/LSP support for `.bus`, so editor integrations remain limited to lexical highlighting.
   - Requested behavior:
     - complete maintainer-ready distribution coverage for the shipped VS Code-compatible `.bus` extension, with clear release surfaces and install guidance for VS Code/Cursor/VSCodium-style editors.
     - add a parser-backed `.bus` highlighting layer with Tree-sitter grammar and highlight queries derived from the BusDK busfile syntax contract.
     - add semantic-token/LSP support for `.bus` after the parser-backed layer stabilizes so commands, flags, assignments, strings, dates, and numbers can be surfaced through standard editor token classes.
   - Verification and documentation constraints:
     - each editor-tooling increment must land with deterministic tests, packaged/distribution verification as appropriate, and updated README/docs/SDD wording in the same change.
     - editor-support work should preserve the existing module boundary: `bus` owns `.bus` source-format tooling and distribution for that format.
   - Why this matters:
     - `.bus` files are a first-class BusDK source format, so users need editor support that scales beyond a basic local extension artifact.
     - consistent parser-backed and semantic tooling improves authoring quality, discoverability, and long-term maintainability for BusDK command files.

5. Expand `bus-inspection` from a lightweight local inspection portal into the versioned reporting and action-list demo described in the 2026-03-17 inspection SDD.
   - Status update 2026-03-17:
     - `bus-inspection` already provides the local `bus-portal`-style chassis: token-gated local server, embedded WASM UI, seeded admin/manager/customer roles, site-scoped visibility, inspection round entry, observations with photos, customer acknowledgement, and basic admin CRUD.
     - the remaining gap is the new SDD delta: versioned report packages/configs, richer site dossier and section data, previous-inspection comparison, category `0` through `6` action-list handling, snapshot exports, at least one DOCX export, AI-assisted config publication flow, and broader audit/security coverage.
   - Current limitation:
     - the current demo still uses a simpler state model and does not yet model report packages, config versions, site-profile sections, observation event history, export snapshots, or AI config requests/suggestions.
     - inspection data entry is lighter than the SDD target and does not yet cover at least three configurable report sections with previous-inspection comparison.
     - export and audit behavior is not yet at SDD parity, especially for action-list PDF output with inline images and a deliverable DOCX path.
   - Requested behavior:
     - keep `bus-inspection` on its deterministic local demo chassis, but extend it so the module can demonstrate the updated käytönjohtaja reporting flow end-to-end.
     - support admin-managed customers, sites, contacts, access, and report packages; manager inspection rounds with dossier plus section data; a rolling observation register in classes `0` through `6`; customer acknowledgements; snapshot-based PDF exports for both report types; DOCX export for at least one document; and an AI-assisted config request/diff/approve/publish flow for authorized users.
     - ensure new config versions apply only to new inspections while historical inspection/export data stays pinned to the earlier version.
     - keep heavy reuse of `bus-ui` and demo-safe local storage/file handling rather than introducing remote services into this module.
   - Verification and documentation constraints:
     - land the work with module README updates plus matching end-user and SDD documentation in the same change set.
     - add unit coverage, module e2e coverage, and negative access-control/export tests for all user-visible behavior changes.
   - Why this matters:
     - the current demo proves the chassis, but the updated SDD is for a materially richer customer demo centered on report-shaped field work, versioned configuration, and deliverable documents.
     - planning and implementation need to target that expanded demo scope without abandoning the module's deterministic local-runtime contract.
