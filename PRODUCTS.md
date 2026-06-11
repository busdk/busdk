# BusDK Product Lines

This file lists the public product pages BusDK should present to end users,
buyers, operators, developers, and technical evaluators. It is intentionally
not a module inventory. A product page may be backed by many `bus-*` modules,
and most provider, integration, operator, and support modules should appear
inside the product line they serve instead of becoming separate marketed
products.

## End-User Product Lines

| Product page | Positioning | Primary module ownership |
| --- | --- | --- |
| BusDK | Full BusDK bundle, installer, and product-family overview. | `bus`, `bus-update`, release/install docs |
| Bus Top | Human-readable process and system monitoring with optional AI explanations. | `bus-top`, `bus-status` |
| Bus Services | Project service stacks from `services.yml`: plan, start, stop, status, and verification. | `bus-services`, `bus-integration-services`, `bus-api-provider-services` |
| Bus Agentic Development | Automated agentic software development with task threads, durable workers, a lightweight agent runtime, prompts, chat, review, repository workspaces, MCP capability exposure, and developer workflow UI. | `bus-task`, `bus-worker`, `bus-agent-runtime`, `bus-run`, `bus-agent`, `bus-chat`, `bus-dev`, `bus-factory`, `bus-lint`, `bus-remote`, `bus-remote-control`, `bus-mcp`, `bus-repos`, `bus-api-provider-mcp`, `bus-api-provider-repos`, `bus-api-provider-task`, `bus-api-provider-worker`, `bus-integration-repos`, `bus-integration-task`, `bus-integration-worker`, `bus-portal-ai` |
| Bus AI API | Self-hostable OpenAI-compatible model API, inference runtime control, lifecycle events, and usage hooks. | `bus-api-provider-llm`, `bus-api-provider-inference`, `bus-integration-inference`, `bus-integration-codex`, `bus-integration-ollama` |
| Bus Runtime | User-owned VMs, containers, terminal sessions, and runtime backends. | `bus-vm`, `bus-containers`, `bus-api-provider-vm`, `bus-api-provider-containers`, `bus-api-provider-terminal`, `bus-integration-containers`, `bus-integration-docker`, `bus-integration-podman`, `bus-integration-upcloud` |
| Bus Auth and Billing | Login, sessions, account approval, service tokens, entitlements, usage, and Stripe-backed billing. | `bus-auth`, `bus-billing`, `bus-api-provider-auth`, `bus-api-provider-session`, `bus-api-provider-billing`, `bus-api-provider-usage`, `bus-integration-billing`, `bus-integration-usage`, `bus-integration-stripe`, `bus-operator-auth`, `bus-operator-billing`, `bus-operator-stripe` |
| Bus Deploy | Deployment orchestration, node setup, cloud/database/inference readiness, and SSH-runner-backed operations. | `bus-operator-deploy`, `bus-operator-cloud`, `bus-operator-database`, `bus-operator-inference`, `bus-operator-node`, `bus-api-provider-cloud`, `bus-api-provider-database`, `bus-api-provider-node`, `bus-integration-cloud`, `bus-integration-database`, `bus-integration-node`, `bus-integration-postgres`, `bus-integration-ssh-runner` |
| Bus Auth Portal | Frontend product for registration, login, approval/waitlist, logout, and session UX. | `bus-portal-auth` |
| Bus Notes Portal | Frontend product for browsing, searching, reviewing, editing, publishing, and archiving notes. | `bus-portal-notes` |
| Bus Books | Auditable bookkeeping software built on open workspace data, including local bookkeeping UI and customer-facing accounting portal workflows. | `bus-books`, `bus-ledger`, `bus-portal-accounting`, accounting domain modules |
| Bus Data Workbench | Schema-backed CSV/workspace data, sheets, files, attachments, and replayable state. | `bus-data`, `bus-sheets`, `bus-files`, `bus-attachments`, `bus-replay` |
| Bus Formula Language | Deterministic formulas for workspace data and workbook extraction. | `bus-bfl` |
| Bus PDF Renderer | Deterministic PDFs for invoices, reports, evidence packs, and other render-model-driven documents. | `bus-pdf` |
| Bus Notes | Durable project notes, review, search, publish, archive, and FAQ-style answer storage. | `bus-notes`, `bus-api-provider-notes`, `bus-integration-notes`, `bus-faq` |
| Bus Inspection | Inspection, customer, site, observation, export, photo, and AI-assisted inspection workflows. | `bus-inspection` |

## Supporting Platform Products

These pages explain infrastructure that BusDK users, operators, and developers
may need to understand, but they are usually supporting software for the
end-user product lines above rather than products sold on their own.

| Platform page | Role | Primary module ownership |
| --- | --- | --- |
| Bus CLI and Busfiles | Deterministic command dispatcher and `.bus` automation files used across product lines. | `bus`, `bus-shell` |
| Bus Workspace | Workspace initialization, configuration, preferences, and secret references. | `bus-init`, `bus-config`, `bus-configure`, `bus-preferences`, `bus-secrets` |
| Bus API Host | Provider-hosting API shell, OpenAPI/gateway contract, and token-gated local/service APIs. | `bus-api` |
| Bus Integration Runtime | Event-worker host/runtime for integration modules. | `bus-integration` |
| Bus Events | Publish, listen, replay, sync, and request/reply event substrate for BusDK components. | `bus-events`, `bus-api-provider-events`, `bus-integration-events` |
| Bus Operator | Operator command shell for trusted deployment, admin, and service automation. | `bus-operator`, `bus-operator-token` |
| Bus Portal Host | Frontend module shell and dispatcher for Bus application modules. | `bus-portal`, `bus-gateway` |
| Bus GX / Bus UI | TSX/React-style UI development for Go and Go/WASM with deterministic rendering and reusable components. | `bus-gx`, `bus-ui` |
