# FEATURE_REQUESTS.md

Enhancement requests for BusDK in this repo context.

Privacy rule for request write-ups:
- Keep examples/repro snippets sanitized (no real customer names/emails/IBANs/account numbers/invoice numbers/local paths).
- Prefer placeholders and aggregated outputs over raw customer-linked row dumps.

Last reviewed: 2026-03-21.

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

3. Add first-class editor tooling and distribution for `.bus` source files.
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

4. Add optional PostgreSQL-backed workspace storage to `bus-data`.
   - Current limitation:
     - `bus-data` currently persists workspace rows only as filesystem-backed CSV or `PCSV-1` tables.
     - schema evolution commands such as `schema init`, `schema field add`, and row mutation operate only on file-backed table storage.
     - there is no first-class way to keep the same logical BusDK table/schema contract while storing row data in SQL tables.
   - Requested behavior:
     - allow a workspace to opt into PostgreSQL storage through `datapackage.json` metadata without changing the default CSV behavior for existing workspaces.
     - keep `datapackage.json` and beside-the-table `*.schema.json` files on disk, but store row data in PostgreSQL tables so the existing bus-data schema and row commands keep working against the selected backend.
     - make schema evolution easy and deterministic, including adding columns and rewriting logical tables without manual SQL migrations for ordinary bus-data operations.
     - preserve the same logical table-path contract (`items.csv`, `items.schema.json`) for CLI behavior, package discovery, and validation even when no physical CSV file exists.
     - keep connection secrets out of `datapackage.json` by resolving the PostgreSQL DSN from an environment variable named in metadata.
   - Constraints and verification:
   - PostgreSQL support must be an optional storage backend, not a mandatory dependency for all workspaces.
   - deterministic row ordering, export/read behavior, and resource rename/remove semantics must match the existing logical bus-data contract.
   - unsupported combinations such as filesystem-only `PCSV-1` plus PostgreSQL should be rejected explicitly until a combined design is specified.
   - verification must include automated tests against a real PostgreSQL instance running in Docker, not only mocks or pure unit tests.

5. Add `bus-gateway` as the local authentication and module-entry layer for BusDK browser modules.
   - Status update 2026-03-25:
     - `bus-gateway` now ships a runnable runtime container image, a separate `Dockerfile.test` path for the standard `make test-docker` surface, and a checked-in Docker Compose example that brings up `bus-gateway` with PostgreSQL-backed workspace storage.
     - the compose example uses the same shared `bus-data` PostgreSQL contract as the local module e2e flow, so gateway-owned schemas remain on the workspace volume while gateway rows live in PostgreSQL tables.
   - Current limitation:
     - BusDK has browser-facing modules such as `bus-ledger`, `bus-portal`, and `bus-inspection`, but there is no dedicated shared module that owns login, session handling, module access policy, startup orchestration, and authenticated reverse-proxy routing across those modules.
     - `bus-inspection` already contains local-first login/session/bootstrap account code, but that logic is inspection-specific today and cannot act as the shared gateway boundary for other modules.
     - there is no canonical workspace-local model yet for which user may access which downstream `bus-*` module.
   - Requested behavior:
     - add a new module `bus-gateway` that becomes the authentication and entry layer in front of authenticated browser-facing BusDK modules.
     - keep the initial design local-first and deterministic: workspace-local users, grants, sessions, and module registry state under `.bus/bus-gateway/`, with no mandatory external identity provider or database dependency.
     - persist the canonical gateway configuration model through the shared `bus-data` storage system so the same gateway-owned schemas and logical tables work on ordinary CSV-backed workspaces and on optional PostgreSQL-backed workspaces.
     - move generic auth/session/bootstrap-account logic out of `bus-inspection` into `bus-gateway` once the shared contract is stable enough to reuse across modules.
     - let the gateway own which users may access which modules through workspace-local service catalog rows plus per-user available-service settings, and start allowed modules and proxy browser/API requests to them.
   - Constraints and verification:
     - the gateway must remain optional module-specific infrastructure, not an excuse to pull downstream business logic into the gateway itself.
     - the post-login gateway UI must let the user choose among the currently available tools, and admin users must be able to configure the service catalog plus per-user visible services from gateway-owned settings.
     - the same user and service configuration model must also be manageable from non-interactive CLI commands with full CRUD-style control so gateway administration can be scripted completely.
     - gateway-owned state must not fork into a private storage format that bypasses workspace storage selection; if the workspace selects PostgreSQL through `bus-data`, gateway configuration must use that backend too.
     - new gateway behavior must land with unit tests, module e2e coverage, and updated README plus matching public docs and SDD pages in the same change set.
     - extraction from `bus-inspection` must preserve the printed bootstrap-credential contract and the real login flow through automated regression coverage.
