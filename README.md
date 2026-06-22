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
sudo apt-get install -y git curl jq openssl postgresql qemu-system-x86 qemu-utils
```

On macOS with Homebrew:

```bash
brew install git curl jq openssl postgresql@18 qemu
export PATH="$(brew --prefix postgresql@18)/bin:$PATH"
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

For the local stack, the internal auth-token bootstrap key defaults to the same
generated local secret. Override `BUS_AUTH_INTERNAL_SHARED_KEY` only when you
need a separate local bootstrap secret.

Configure the repositories used by local workers:

```bash
bus configure BUS_WORKERS_DIRECT_REPO_ROOT="$PWD"
bus configure BUS_WORKERS_DIRECT_WORKER_IDENTITY_REPO="$PWD/agents/worker"
```

Do not configure `BUS_API_TOKEN` for the normal local stack. Services writes
the generated token file to `.bus/tokens/local-events.jwt`.

### 3. Prepare Engine Artifacts

Skip this step only when you do not plan to run `bus engine start`.

The Engine service uses these local defaults:

- artifact catalog: `.bus/artifacts/catalog.json`;
- artifact cache: `.bus/artifacts/cache`;
- QEMU runtime state: `.bus/qemu`;
- guest SSH authorized keys: `.bus/engine/authorized_keys`.

Download the Debian 12 Bookworm generic cloud image:

```bash
mkdir -p .bus/artifacts .bus/engine
curl -fL \
  -o .bus/artifacts/debian-12-genericcloud-amd64.qcow2 \
  https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-genericcloud-amd64.qcow2
```

Point `KERNEL_IMAGE` at the Bus kernel image. For private Bus kernel builds this
is normally the `vmlinuz-*` file from the built kernel package:

```bash
KERNEL_IMAGE="$HOME/git/torvalds/linux/debian/linux-image-7.1.0/boot/vmlinuz-7.1.0"
test -f "$KERNEL_IMAGE"
```

Create the default artifact catalog:

```bash
DEBIAN_SHA256="$(openssl dgst -sha256 -r .bus/artifacts/debian-12-genericcloud-amd64.qcow2 | awk '{print $1}')"
KERNEL_SHA256="$(openssl dgst -sha256 -r "$KERNEL_IMAGE" | awk '{print $1}')"

cat > .bus/artifacts/catalog.json <<EOF
{
  "records": [
    {
      "id": "debian-cloud-generic-amd64",
      "handle": "$PWD/.bus/artifacts/debian-12-genericcloud-amd64.qcow2",
      "digest": "sha256:$DEBIAN_SHA256"
    },
    {
      "id": "bus-engine-kernel-amd64",
      "handle": "$KERNEL_IMAGE",
      "digest": "sha256:$KERNEL_SHA256"
    }
  ]
}
EOF
```

Add the SSH public key that should be able to log in as `bus` inside the guest:

```bash
test -f "$HOME/.ssh/id_ed25519.pub" || ssh-keygen -t ed25519 -f "$HOME/.ssh/id_ed25519" -N ''
cp "$HOME/.ssh/id_ed25519.pub" .bus/engine/authorized_keys
```

Only use `bus configure` for Engine paths when you want to override these
defaults, for example with a shared artifact catalog:

```bash
bus configure BUS_ARTIFACTS_CATALOG_FILE=/path/to/catalog.json
bus configure BUS_QEMU_RUNTIME_DIR=/path/to/qemu-runtime
bus configure BUS_ENGINE_SSH_AUTHORIZED_KEYS_FILE=/path/to/authorized_keys
```

### 4. Start Services

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

### 5. Verify The Local APIs

```bash
bus services stack validate --file services.yml
bus workers list --environment local-dev
```

For Engine, create a short-lived local API token in your shell. Do not write
`BUS_API_TOKEN` into `.env`; this token is for the CLI process only.

```bash
export BUS_ENGINE_API_URL='http://127.0.0.1:8090/local/v1'
LOCAL_BOOTSTRAP_KEY="$(sed -n 's/^BUS_AUTH_HS256_SECRET=//p' .env | tail -n 1)"
export BUS_API_TOKEN="$(
  curl -sS -X POST "$BUS_ENGINE_API_URL/api/internal/auth/token" \
    -H "X-Bus-Internal-Key: $LOCAL_BOOTSTRAP_KEY" \
    -H 'content-type: application/json' \
    -d '{"subject":"local-engine","audience":"ai.hg.fi/api","resources":"engine:read engine:write","ttl_seconds":600}' |
    jq -r '.access_token'
)"

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
