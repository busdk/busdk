# BusDK

[![License](https://img.shields.io/github/license/busdk/busdk)](LICENSE)
[![Release](https://img.shields.io/github/v/release/busdk/busdk)](https://github.com/busdk/busdk/releases)

BusDK is a modular, CLI-first toolkit for running Bus services and workflows.
This superproject is the public entrypoint for installing the `bus` dispatcher,
starting the local Services stack, and running local Codex Spark workers.

## Simplest Local Worker Setup

This is the shortest path for the current local worker use case:

1. Install BusDK.
2. Configure local `.env` values with `bus configure`.
3. Start the Services stack with `bus services up`.
4. Create and guide a local Codex Spark worker with `bus workers ...`.

You need PostgreSQL binaries available locally and a working `codex` command
with local Codex authentication already configured.

The checked-in `services.yml` starts the services needed for local workers and
tasks:

- native PostgreSQL for durable Events storage;
- Bus Events API backed by PostgreSQL;
- Bus Repos service for Git branch and worktree materialization;
- Bus Workers service using the local direct Codex runner;
- Bus Tasks service for task threads and task-to-worker assignment;
- one Bus API gateway process with the local Workers and Tasks modules mounted.

### 1. Install

Use the release installer on Linux or macOS:

```bash
curl -fsSL https://github.com/busdk/busdk/releases/latest/download/install.sh | bash
```

The default install path is `$HOME/.local/bin`. Add it to `PATH` if needed:

```bash
export PATH="$HOME/.local/bin:$PATH"
bus --help
```

### 2. Configure

Run these commands from the project directory that contains `services.yml`.
The file stores local values in `.env`; `services.yml` remains public and
should not contain secrets or machine-specific paths.

Configure PostgreSQL. `BUS_POSTGRES_BIN` must point at the directory that
contains the `postgres` and `initdb` binaries. On macOS with Homebrew
PostgreSQL 18:

```bash
bus configure BUS_POSTGRES_BIN=/opt/homebrew/opt/postgresql@18/bin
bus configure BUS_POSTGRES_PGDATA="$PWD/.bus/services/postgres/data"
bus configure BUS_POSTGRES_PORT=5432
```

On a Linux package install, the path is often similar to:

```bash
bus configure BUS_POSTGRES_BIN=/usr/lib/postgresql/18/bin
```

Configure Events API auth and PostgreSQL storage. Generate a unique local
secret and keep using the same value when issuing the local API token:

```bash
BUS_LOCAL_SECRET="$(openssl rand -hex 32)"
bus configure BUS_EVENTS_JWT_SECRET="$BUS_LOCAL_SECRET"
bus configure BUS_EVENTS_POSTGRES_DSN='postgres://bus_service@127.0.0.1:5432/postgres?sslmode=disable'
```

Configure worker repositories. In this superproject checkout, the product
repository is the current directory and the worker identity repository is
`agents/worker`:

```bash
bus configure BUS_WORKERS_DIRECT_REPO_ROOT="$PWD"
bus configure BUS_WORKERS_DIRECT_WORKER_IDENTITY_REPO="$PWD/agents/worker"
```

Create a local API token for the services. Run this in the same shell where
`BUS_LOCAL_SECRET` is set, or replace it with the same unique value configured
as `BUS_EVENTS_JWT_SECRET`. The default local auth audience is `ai.hg.fi/api`;
keep it unless you have changed the local API/Event auth configuration.

```bash
BUS_AUTH_HS256_SECRET="$BUS_LOCAL_SECRET" \
  bus configure BUS_API_TOKEN="$(bus operator token --format token issue --local \
    --subject local-workers \
    --audience ai.hg.fi/api \
    --scope 'events:send events:listen workers:read workers:write workers:control task:send task:read task:reply' \
    --ttl 12h)"
```

### 3. Start Services

Start the local stack:

```bash
bus services up
```

Stop it when finished:

```bash
bus services down
```

Service runtime state, logs, generated repository configuration, and PostgreSQL
data live under `.bus/` by default. The PostgreSQL profile initializes `PGDATA`
on first start and skips initialization when `PG_VERSION` already exists.

### 4. Create And Guide A Worker

The Workers and Tasks APIs are served through the local Bus API gateway. The
default local URL is:

```text
http://127.0.0.1:8090/local/v1
```

List workers:

```bash
bus workers --api-url http://127.0.0.1:8090/local/v1 list --environment local-dev
```

Create a local Codex Spark worker. Omit `--id`; the Workers API provider
generates a UUID and the worker identity branch defaults to
`worker/{worker_uuid}`:

```bash
bus workers --api-url http://127.0.0.1:8090/local/v1 create \
  --label "Spark 1" \
  --type agent \
  --profile codex-spark \
  --model gpt-5.3-codex-spark \
  --runner-kind direct \
  --runner-provider codex-direct \
  --environment local-dev \
  --sandbox workspace-write
```

Use the returned worker id for guidance:

```bash
bus workers --api-url http://127.0.0.1:8090/local/v1 message <worker-id> \
  --environment local-dev \
  --text "Inspect the task details and wait for guidance before editing."
```

Read worker responses and status:

```bash
bus workers --api-url http://127.0.0.1:8090/local/v1 messages <worker-id> --environment local-dev
bus workers --api-url http://127.0.0.1:8090/local/v1 status <worker-id> --environment local-dev
bus workers --api-url http://127.0.0.1:8090/local/v1 logs <worker-id> --environment local-dev
bus workers --api-url http://127.0.0.1:8090/local/v1 attach <worker-id> --environment local-dev
```

Stop the worker:

```bash
bus workers --api-url http://127.0.0.1:8090/local/v1 stop <worker-id> \
  --environment local-dev \
  --reason "done"
```

## Services Configuration

The root `services.yml` is intentionally small and uses operator-facing service
ids:

```text
postgres -> events -> repos -> workers
                  \-> tasks
events, workers, tasks -> api
```

The `api` service is one `bus-api` process. Its profile enables multiple API
modules with repeated `--provider` and `--enable-module` flags. More API
modules can be added to the same process as their providers are wired into
`bus-api`.

The `repos`, `workers`, and `tasks` services currently run as separate native
processes. That makes it easy to restart one domain service without restarting
the others. The shared `bus-integration` runtime is the path toward a combined
integration host, but the default stack does not pretend that aggregate host is
already wired for every domain.

The stack points at runtime profiles stored under `profiles/`:

```text
profiles/
- postgres/native.json
- bus/api/events/postgres.yml
- bus/api/local.yml
- bus/integration/repos/local.yml
- bus/integration/tasks/local.yml
- bus/integration/workers/direct.yml
```

Profiles define commands, arguments, environment references, healthchecks, and
deterministic initialization steps. The stack file chooses which services run
and how they depend on each other.

If you change `BUS_WORKERS_DIRECT_REPO_ROOT` or
`BUS_WORKERS_DIRECT_WORKER_IDENTITY_REPO`, remove
`.bus/services/repos/repositories.json` before starting again so the repos
integration regenerates its local repository configuration.

## Install From Source

Clone the superproject and initialize submodules:

```bash
git clone https://github.com/busdk/busdk.git
cd busdk
git submodule update --init --recursive
```

Build and install all module tools:

```bash
make install
```

The default install prefix is `$HOME/.local`. Override it with `PREFIX`:

```bash
make install PREFIX=/opt/busdk
```

Build without installing:

```bash
make build
```

Run repository checks:

```bash
make check
```

## Repository Layout

BusDK is a superproject of smaller `bus-*` modules. The root repository pins
module versions and provides shared installation, service-stack, and release
workflows. Feature implementation belongs in the owning module repository.

Useful top-level paths:

- `bus/`: the `bus <command> ...` dispatcher;
- `bus-services/`: Services CLI;
- `bus-integration-services/`: local Services runtime supervisor;
- `bus-worker/`: Workers CLI, installed as `bus-workers`;
- `bus-api/`: local API gateway;
- `bus-api-provider-events/`: Events API provider;
- `bus-api-provider-worker/`: Workers API provider;
- `bus-integration-worker/`: Workers integration runtime;
- `bus-integration-repos/`: repository/worktree integration;
- `docs/`: public documentation;
- `services.yml`: default local Services stack;
- `profiles/`: runtime profiles used by `services.yml`.

## Advanced Development

Docker-backed development-task stacks, container runners, remote environments,
and broader module development workflows are available for maintainers, but
they are not required for the local Codex Spark worker setup above.

For module development, work in the owning `bus-*` repository and use that
module's `README.md`, `AGENTS.md`, `Makefile`, and tests. The root `make`
targets are for building, installing, and checking the pinned superproject as a
whole.

## Documentation And Support

- Public docs: `docs/`
- System design docs: `sdd/`
- Website: `busdk.com/`
- License: see [LICENSE](LICENSE)
