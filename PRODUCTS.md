# BusDK Product Lines

This file lists the public product pages BusDK should present to end users,
buyers, operators, developers, and technical evaluators. It is intentionally
not a module inventory. A product page may be backed by many `bus-*` modules,
and most provider, integration, operator, and support modules should appear
inside the product line they serve instead of becoming separate marketed
products.

## Product Page Rules

- Keep BusDK as the bundle, installer, and shared product-family identity.
- Give a page to user-facing products and major platform hosts that users can
  understand as a product surface.
- Treat dispatcher and host modules such as `bus`, `bus-api`,
  `bus-integration`, `bus-portal`, and `bus-operator` as host products. Their
  child modules belong under the concrete product line they serve.
- Do not duplicate a module across multiple marketed product pages. Cross-link
  when a module participates in more than one workflow.
- Do not market unfinished, research-only, or unclear surfaces as public
  products yet. Document them as research, technical preview, or internal
  modules until their user-facing value is ready.

## Product Pages To Publish

| Product page | Positioning | Primary module ownership |
| --- | --- | --- |
| BusDK | Full BusDK bundle, installer, and product-family overview. | `bus`, `bus-update`, release/install docs |
| Bus CLI and Busfiles | Deterministic command dispatcher and `.bus` automation files. | `bus`, `bus-shell` |
| Bus Workspace | Workspace initialization, configuration, preferences, and secret references. | `bus-init`, `bus-config`, `bus-configure`, `bus-preferences`, `bus-secrets` |
| Bus API Host | Provider-hosting API shell, OpenAPI/gateway contract, and token-gated local/service APIs. | `bus-api` |
| Bus Integration Runtime | Event-worker host/runtime for integration modules. | `bus-integration` |
| Bus Operator | Operator command shell for trusted deployment, admin, and service automation. | `bus-operator`, `bus-operator-token` |
| Bus Portal Host | Frontend module shell and dispatcher for Bus application modules. | `bus-portal`, `bus-gateway` |
| Bus Top | Human-readable process and system monitoring with optional AI explanations. | `bus-top`, `bus-status` |
| Bus Services | Project service stacks from `services.yml`: plan, start, stop, status, and verification. | `bus-services`, `bus-integration-services`, `bus-api-provider-services` |
| Bus Events | Publish, listen, replay, sync, and request/reply event workflows. | `bus-events`, `bus-api-provider-events`, `bus-integration-events` |
| Bus Tasks | Task threads for humans, scripts, services, and agents. | `bus-task`, `bus-api-provider-task`, `bus-integration-task` |
| Bus Workers | Durable local and remote worker creation, control, status, logs, and attach. | `bus-worker`, `bus-api-provider-worker`, `bus-integration-worker`, `bus-remote` |
| Bus Agent Runtime | Lightweight Bus-owned agent runtime for worker-owned checkouts, provider adapters, tools, extensions, and audit events. | `bus-agent-runtime` |
| Bus Agent Workflows | Local prompts, scripts, pipelines, and provider-agnostic agent execution. | `bus-run`, `bus-agent`, `bus-chat`, `bus-remote-control` |
| Bus AI API | Self-hostable OpenAI-compatible model API, inference runtime control, lifecycle events, and usage hooks. | `bus-api-provider-llm`, `bus-api-provider-inference`, `bus-integration-inference`, `bus-integration-codex`, `bus-integration-ollama` |
| Bus Runtime | User-owned VMs, containers, terminal sessions, and runtime backends. | `bus-vm`, `bus-containers`, `bus-api-provider-vm`, `bus-api-provider-containers`, `bus-api-provider-terminal`, `bus-integration-containers`, `bus-integration-docker`, `bus-integration-podman`, `bus-integration-upcloud` |
| Bus Auth and Billing | Login, sessions, account approval, service tokens, entitlements, usage, and Stripe-backed billing. | `bus-auth`, `bus-billing`, `bus-api-provider-auth`, `bus-api-provider-session`, `bus-api-provider-billing`, `bus-api-provider-usage`, `bus-integration-billing`, `bus-integration-usage`, `bus-integration-stripe`, `bus-operator-auth`, `bus-operator-billing`, `bus-operator-stripe` |
| Bus Deploy | Deployment orchestration, node setup, cloud/database/inference readiness, and SSH-runner-backed operations. | `bus-operator-deploy`, `bus-operator-cloud`, `bus-operator-database`, `bus-operator-inference`, `bus-operator-node`, `bus-api-provider-cloud`, `bus-api-provider-database`, `bus-api-provider-node`, `bus-integration-cloud`, `bus-integration-database`, `bus-integration-node`, `bus-integration-postgres`, `bus-integration-ssh-runner` |
| Bus GX / Bus UI | TSX/React-style UI development for Go and Go/WASM with deterministic rendering and reusable components. | `bus-gx`, `bus-ui` |
| Bus AI Portal | Frontend product for AI chat, agent work, terminal, and container experiences. | `bus-portal-ai` |
| Bus Accounting Portal | Frontend product for accounting customer navigation, uploads, evidence packages, previews, and downloads. | `bus-portal-accounting` |
| Bus Auth Portal | Frontend product for registration, login, approval/waitlist, logout, and session UX. | `bus-portal-auth` |
| Bus Notes Portal | Frontend product for browsing, searching, reviewing, editing, publishing, and archiving notes. | `bus-portal-notes` |
| Bus Books | Auditable bookkeeping software built on open workspace data. | `bus-books`, `bus-ledger`, accounting domain modules |
| Bus Data Workbench | Schema-backed CSV/workspace data, sheets, files, attachments, and replayable state. | `bus-data`, `bus-sheets`, `bus-files`, `bus-attachments`, `bus-replay` |
| Bus Formula Language | Deterministic formulas for workspace data and workbook extraction. | `bus-bfl` |
| Bus PDF Renderer | Deterministic PDFs for invoices, reports, evidence packs, and other render-model-driven documents. | `bus-pdf` |
| Bus Notes | Durable project notes, review, search, publish, archive, and FAQ-style answer storage. | `bus-notes`, `bus-api-provider-notes`, `bus-integration-notes`, `bus-faq` |
| Bus Dev / Factory | Developer workflow automation, module-building UI, and quality review workflows. | `bus-dev`, `bus-factory`, `bus-lint` |
| Bus MCP and Repos | MCP capability exposure and repository workspace contracts. | `bus-mcp`, `bus-api-provider-mcp`, `bus-repos`, `bus-api-provider-repos`, `bus-integration-repos` |
| Bus Inspection | Inspection, customer, site, observation, export, photo, and AI-assisted inspection workflows. | `bus-inspection` |

## Bus Books Boundary

Bus Books is the marketed end-user accounting product. The accounting engine is
not a separate product page right now. It is proof inside the Bus Books page:
the UI, CLI, and API operate over the same deterministic workspace data.

Accounting modules that belong under Bus Books include `bus-accounts`,
`bus-assets`, `bus-balances`, `bus-bank`, `bus-budget`, `bus-customers`,
`bus-debts`, `bus-entities`, `bus-inventory`, `bus-invoices`, `bus-journal`,
`bus-ledger`, `bus-loans`, `bus-memo`, `bus-payroll`, `bus-period`,
`bus-reconcile`, `bus-reports`, `bus-validate`, `bus-vat`, and `bus-vendors`.

## Not Public Product Pages Yet

- Bus Filing Finland: real direction, but not ready for marketing yet.
  Modules: `bus-filing`, `bus-filing-prh`, `bus-filing-vero`.
- `aiz`: research project for now.
- `bus-work`: do not market until its status is fully reconciled with
  `bus-task` and `bus-worker`.
- Individual `bus-api-provider-*`, `bus-integration-*`, and `bus-operator-*`
  modules: assign them to the product line they serve instead of publishing
  separate product pages.
