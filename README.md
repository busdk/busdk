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
with local Codex authentication already configured. For self-hosted GPU worker
hosts, you can use the Bus-owned agent runtime instead of Codex by configuring
the local model provider values below.

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

Configure PostgreSQL. The native profile runs `postgres` and `initdb` from
`PATH`, so install PostgreSQL and make those commands visible to the shell that
starts `bus services`. Then choose the local data directory and port:

```bash
bus configure BUS_POSTGRES_PGDATA="$PWD/.bus/services/postgres/data"
bus configure BUS_POSTGRES_PORT=5432
```

On macOS with Homebrew, add the PostgreSQL bin directory to `PATH` first when
Homebrew does not link the commands globally:

```bash
export PATH="/opt/homebrew/opt/postgresql@18/bin:$PATH"
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

Configure the Bus-owned runtime on self-hosted GPU hosts. These values assume
an Ollama-compatible endpoint is listening locally and serving `gemma4:31b`.
Keep using the Codex runner commands below on machines where Codex should
remain the direct worker provider.

```bash
bus configure BUS_WORKERS_DIRECT_DEFAULT_PROVIDER=bus-agent-runtime
bus configure BUS_AGENT_CODEX_LOCAL_MODEL=gemma4:31b
bus configure BUS_AGENT_RUNTIME_MESSAGE_PROVIDER=ollama
bus configure BUS_AGENT_RUNTIME_MESSAGE_MODEL=gemma4:31b
bus configure BUS_AGENT_RUNTIME_MESSAGE_TIMEOUT=5m
bus configure OLLAMA_HOST=http://127.0.0.1:11434
```

The current setup spells out the required values so the checked-in
`services.yml` remains reproducible across hosts. Defaults such as generated
JWT secrets, local runtime provider choices, and provider-specific model
settings should come from the owning Bus modules and service/profile metadata,
not from hard-coded literals inside `bus configure`.

`bus services up` uses `BUS_EVENTS_JWT_SECRET` to create the local API token
file. Do not configure `BUS_API_TOKEN` for the normal local stack; Services
writes the token to `.bus/tokens/local-events.jwt`. Standard local Events and
Workers client settings are dispatcher-provided runtime defaults, so they do
not need to be written to `.env`.

### 3. Start Services

Start the local stack:

```bash
bus services up
```

The root `services.yml` declares `default_services`, so `bus services up`
starts the default service set plus dependencies. Use `--all` to start every
service declared in the file, including optional services that are not part of
the default set:

```bash
bus services up --all
```

Stop it when finished:

```bash
bus services down
```

Service runtime state, logs, generated repository configuration, and PostgreSQL
data live under `.bus/` by default. The PostgreSQL profile initializes `PGDATA`
on first start and skips initialization when `PG_VERSION` already exists.

The dispatcher supplies these non-secret local client defaults to child
commands when they are otherwise unset:

```bash
BUS_EVENTS_API_URL=http://127.0.0.1:8081/local/v1
BUS_EVENTS_TOKEN_FILE=.bus/tokens/local-events.jwt
BUS_WORKERS_API_URL=http://127.0.0.1:8090/local/v1
BUS_WORKERS_API_TOKEN_FILE=.bus/tokens/local-events.jwt
```

Precedence is process environment, then `.env`, then dispatcher defaults. Use
`.env` only for explicit local overrides, private configuration, and values
such as `BUS_EVENTS_JWT_SECRET`.

### 4. Create And Guide A Worker

The Workers and Tasks APIs are served through the local Bus API gateway. After
`bus services up`, the dispatcher supplies the standard local API URL and token
file defaults, so the normal worker commands do not need `--api-url` or
`--token-file`.

List workers:

```bash
bus workers list --environment local-dev
```

Create a local Codex Spark worker. Omit `--id`; the Workers API provider
generates a UUID and the worker identity branch defaults to
`worker/{worker_uuid}`:

```bash
bus workers create \
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
bus workers message <worker-id> \
  --environment local-dev \
  --text "Inspect the task details and wait for guidance before editing."
```

Read worker responses and status:

```bash
bus workers messages <worker-id> --environment local-dev
bus workers status <worker-id> --environment local-dev
bus workers logs <worker-id> --environment local-dev
bus workers attach <worker-id> --environment local-dev
```

Stop the worker:

```bash
bus workers stop <worker-id> \
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

The file also groups services with short display names: `Infrastructure`
contains PostgreSQL and Events, `Integrations` contains Repos, Workers, and
Tasks, and `API gateways` contains the local Bus API gateway. Group `name` is
the display label; `description` is optional and only needed for longer
explanation.

The `events` service is launched as `bus api ... --provider events`, so the
Events API is hosted through the Bus API surface rather than by executing a
provider binary directly. The `api` service is another `bus api` process with
the local Workers and Tasks providers enabled. More API providers can be added
to the same process as they are wired into `bus-api`.

The `repos`, `workers`, and `tasks` services launch the shared integration host
as `bus integration ... --provider <name>`. Each profile still runs as its
own service process so one domain can be restarted without restarting the
others, but the launched binary is the integration host and the selected
`bus-integration-*` module is enabled inside that host.

The stack points at runtime profiles stored under `profiles/`:

```text
profiles/
- postgres/native.json
- bus/events/postgres.yml
- bus/events/memory.yml
- bus/api/local.yml
- bus/repos/local.yml
- bus/tasks/local.yml
- bus/workers/direct.yml
```

Profile references follow their file paths without the extension, such as
`bus/events/postgres` for `profiles/bus/events/postgres.yml`. Profiles define
commands, arguments, environment references, healthchecks, and deterministic
initialization steps. The stack file chooses which services run and how they
depend on each other.

Service `params` configure typed profile-local values, such as capability path
tokens or Events API URLs used only to build command arguments. They are not
exported to the child process environment unless the profile explicitly
references them in `runtime.env`. Runtime environment entries in profiles
include descriptions so operators can see why each value is passed through.

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
