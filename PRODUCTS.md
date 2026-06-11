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
| Bus Agentic Development | Automated agentic software development with task threads, durable workers, a lightweight agent runtime, prompts, chat, project notes, review, repository workspaces, MCP capability exposure, and developer workflow UI. | `bus-task`, `bus-worker`, `bus-agent-runtime`, `bus-run`, `bus-agent`, `bus-chat`, `bus-dev`, `bus-factory`, `bus-lint`, `bus-remote`, `bus-remote-control`, `bus-mcp`, `bus-repos`, `bus-notes`, `bus-portal-notes`, `bus-faq`, `bus-api-provider-mcp`, `bus-api-provider-notes`, `bus-api-provider-repos`, `bus-api-provider-task`, `bus-api-provider-worker`, `bus-integration-notes`, `bus-integration-repos`, `bus-integration-task`, `bus-integration-worker`, `bus-portal-ai` |
| Bus AI Platform | Self-hostable AI hosting platform with OpenAI-compatible model access, inference runtime control, deployment automation, user-owned VMs, containers, terminal sessions, login, billing, entitlement, usage, lifecycle events, and service hooks. | `bus-api-provider-llm`, `bus-api-provider-inference`, `bus-integration-inference`, `bus-integration-codex`, `bus-integration-ollama`, `bus-vm`, `bus-containers`, `bus-auth`, `bus-portal-auth`, `bus-billing`, `bus-api-provider-auth`, `bus-api-provider-session`, `bus-api-provider-billing`, `bus-api-provider-usage`, `bus-api-provider-vm`, `bus-api-provider-containers`, `bus-api-provider-terminal`, `bus-operator-auth`, `bus-operator-billing`, `bus-operator-stripe`, `bus-operator-deploy`, `bus-operator-cloud`, `bus-operator-database`, `bus-operator-inference`, `bus-operator-node`, `bus-api-provider-cloud`, `bus-api-provider-database`, `bus-api-provider-node`, `bus-integration-billing`, `bus-integration-usage`, `bus-integration-stripe`, `bus-integration-cloud`, `bus-integration-containers`, `bus-integration-database`, `bus-integration-docker`, `bus-integration-node`, `bus-integration-podman`, `bus-integration-postgres`, `bus-integration-ssh-runner`, `bus-integration-upcloud` |
| Bus Books | Auditable bookkeeping software built on open workspace data, including local bookkeeping UI, customer-facing accounting portal workflows, data workbench surfaces, deterministic formulas, and accounting documents. | `bus-books`, `bus-ledger`, `bus-portal-accounting`, `bus-data`, `bus-sheets`, `bus-files`, `bus-attachments`, `bus-replay`, `bus-bfl`, `bus-pdf`, accounting domain modules |
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
