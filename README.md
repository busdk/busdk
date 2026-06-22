# BusDK

[![License](https://img.shields.io/github/license/busdk/busdk)](LICENSE)
[![Release](https://img.shields.io/github/v/release/busdk/busdk)](https://github.com/busdk/busdk/releases)

BusDK is a modular, CLI-first toolkit for running Bus services and workflows.
This superproject is the public entrypoint for installing the `bus` dispatcher,
starting the local Services stack, and running local Codex Spark workers.

## Install BusDK

Use the release installer on Linux or macOS:

```bash
curl -fsSL https://github.com/busdk/busdk/releases/latest/download/install.sh | bash
```

The default install path is `$HOME/.local/bin`. Add it to `PATH` if needed:

```bash
export PATH="$HOME/.local/bin:$PATH"
bus --help
```

## Get The Source Checkout

The local Services stack and private module development use the BusDK source
checkout. Clone the superproject before running source-tree commands:

```bash
git clone https://github.com/busdk/busdk.git
cd busdk
```

Public users can use the released binaries with the checked-out service
configuration. Building the full superproject from source is for private Bus
developers with access to all pinned module repositories.

Private developers can initialize all module submodules:

```bash
git submodule update --init --recursive
```

## Build From Source

Build and install all module tools only after the source checkout and private
submodules are available:

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

## Local Development Services

These are the required steps for a local `bus services` development stack.
Run them from the BusDK checkout root, where `services.yml` is located.

The root stack starts PostgreSQL, Events, Identities, Auth, Repos, Repos SSH,
Workers, Tasks, and the local Bus API gateway.

### 1. Install Prerequisites

Install PostgreSQL so `postgres` and `initdb` are on `PATH`. Also install
`git`. Install and authenticate `codex` only when you plan to run local Codex
workers.

On macOS with Homebrew, add the PostgreSQL bin directory to `PATH` first when
Homebrew does not link the commands globally:

```bash
export PATH="/opt/homebrew/opt/postgresql@18/bin:$PATH"
```

### 2. Configure `.env`

Use `bus configure` so values are written to the local `.env` file. Do not put
secrets or machine-specific paths in `services.yml`.

Configure PostgreSQL, Events, and Auth:

```bash
bus configure BUS_POSTGRES_PGDATA="$PWD/.bus/services/postgres/data"
bus configure BUS_POSTGRES_PORT=5432
BUS_LOCAL_SECRET="$(openssl rand -hex 32)"
bus configure BUS_API_JWT_SECRET="$BUS_LOCAL_SECRET"
bus configure BUS_AUTH_HS256_SECRET="$BUS_LOCAL_SECRET"
bus configure BUS_EVENTS_POSTGRES_DSN='postgres://bus_service@127.0.0.1:5432/postgres?sslmode=disable'
bus configure BUS_EVENTS_URL='http://127.0.0.1:8081/local/v1'
```

Configure the repositories used by local workers:

```bash
bus configure BUS_WORKERS_DIRECT_REPO_ROOT="$PWD"
bus configure BUS_WORKERS_DIRECT_WORKER_IDENTITY_REPO="$PWD/agents/worker"
```

Do not configure `BUS_API_TOKEN` for the normal local stack. Services writes
the generated token file to `.bus/tokens/local-events.jwt`.

### 3. Start Services

Start the local stack:

```bash
bus services up
```

Show the running services:

```bash
bus services ps
```

Stop it when finished:

```bash
bus services down
```

Runtime state, generated tokens, repository storage, logs, and PostgreSQL data
live under `.bus/` by default.

### 4. Verify The Local APIs

```bash
bus services stack validate --file services.yml
bus workers list --environment local-dev
```

Use module README files for worker creation, identity/auth setup, repository
management, and provider-specific options.

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
