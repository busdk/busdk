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
Workers, Tasks, Engine, and the local Bus API gateway.

### 1. Install Prerequisites

Install PostgreSQL so `postgres` and `initdb` are on `PATH`. Also install
`git`, `curl`, `jq`, and QEMU if you plan to use `bus engine`. Install and
authenticate `codex` only when you plan to run local Codex workers.

On Debian or Ubuntu:

```bash
sudo apt-get update
sudo apt-get install -y git curl jq openssl dpkg postgresql qemu-system-x86 qemu-utils
```

On macOS with Homebrew:

```bash
brew install git curl jq openssl dpkg postgresql@18 qemu
export PATH="$(brew --prefix postgresql@18)/bin:$PATH"
```

### 2. Start Services

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
live under `.bus/` by default. The local profile provides defaults for service
ports, internal auth, Events, repository paths, worker identity state, and
Engine artifacts.

### 3. Verify The Local APIs

```bash
bus services stack validate --file services.yml
bus workers list --environment local-dev
```

```bash
bus engine status
bus engine start
bus engine status
```

Repeat `bus engine status` until the Engine reports `running`, then request the
SSH details and log in:

```bash
bus engine ssh
ssh -p 2222 bus@127.0.0.1
bus engine stop
```

The Engine service prepares its local artifact cache and downloads the Debian
12 cloud image when the Engine is started. Use module README files and public
module docs for worker creation, identity/auth setup, repository management,
Engine kernel artifacts, provider-specific options, and customization
environment variables.

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
