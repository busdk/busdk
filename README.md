# BusDK (Business Development Kit)

[![License](https://img.shields.io/github/license/busdk/busdk)](LICENSE)
[![Release](https://img.shields.io/github/v/release/busdk/busdk)](https://github.com/busdk/busdk/releases)

BusDK is a modular, CLI-first toolkit for running a business with Git-native, auditable data. It stores business datasets as UTF-8 CSV backed by Frictionless Table Schema (JSON), favoring simple primitives, deterministic behavior, and workflows that work well for both humans and automation. This repository is the one-command entrypoint to install the full BusDK toolchain.

## Quick install

Use this on Linux or macOS with `bash`, `curl`, and permission to write the
install directory. The default install path is `$(HOME)/.local/bin`; add that
directory to `PATH` before running `bus`.

```bash
curl -fsSL https://github.com/busdk/busdk/releases/latest/download/install.sh | bash
```

## Status

Pre-release and actively maintained. Interfaces, schemas, and file conventions may still evolve.

## Features

- One command to install a consistent set of BusDK CLI tools
- Modular subcommands for accounts, journal, invoices, VAT, reports, and more
- Git-friendly, schema-validated CSV datasets with deterministic outputs
- Reproducible builds with consistent output and install paths

## Usage

After installation, ensure `$(PREFIX)/bin` is on your `PATH`, then run:

```bash
bus --help
```

Expected output includes the dispatcher help header and a list of available subcommands.

Use modules through the dispatcher, for example:

```bash
bus journal --help
```

Each module also installs a standalone binary for direct/debug use, but the
intended user-facing command form remains `bus <module> ...`:

```bash
bus-journal --help
```

## Local Bus cloud platform stack

For local validation of the Bus cloud platform flow described by the
UpCloud/Stripe deployment tutorial, start the root Compose stack.

Prerequisites:

- Docker Desktop or Docker Engine with Compose support.
- This superproject as the current working directory.
- Submodules initialized so the `bus` and `bus-*` module directories exist.
- `bus` installed and on `PATH` for `bus configure`, or use the equivalent
  source-tree command `go run ./bus-configure/cmd/bus-configure`.
- A trusted local development machine. The stack mounts `/var/run/docker.sock`
  into `bus-integration-docker`, which grants host-level Docker control.
- Optional live Codex auth in `${BUS_CODEX_HOME:-$HOME/.codex}` when running
  the live chat smoke with `BUS_LOCAL_AI_PLATFORM_LIVE_CODEX=1`; the default
  smoke does not require Codex credentials.

```bash
bus configure LOCAL_AI_PLATFORM_PORT=8080
bus configure LOCAL_AI_PLATFORM_POSTGRES_PORT=15432
bus configure LOCAL_AI_PLATFORM_MAILHOG_PORT=8025
bus configure BUS_CODEX_MODEL=auto
bus configure BUS_PORTAL_TOKEN=local-dev
docker compose up --build -d
docker compose exec testing-agent sh
```

The stack reads configuration from `.env` automatically and uses non-secret
development defaults for values that are not present. Use `bus configure KEY=VALUE`
for local overrides instead of hand-editing `.env`; it creates the file when it
does not exist and preserves existing comments and unknown values. Use
`.env.example` only as a checked-in reference for the local defaults.

The stack starts PostgreSQL, MailHog, nginx, Events, Auth, LLM, Usage, Billing,
Stripe webhook ingress, VM, Containers, the Bus portal, a local Docker container
execution worker, a development-task-to-container bridge, and a Codex-backed LLM
execution worker. It does not provision UpCloud resources, public DNS, TLS
certificates, or systemd units.

Useful configuration commands:

```bash
bus configure list
bus configure --module portal list
bus configure --module portal doctor
bus configure --module integration-docker list
bus configure --module integration-docker doctor
bus configure --module integration-codex list
bus configure --module integration-codex doctor
```

To move the local HTTP port or MailHog UI port, update the dotenv file through
`bus configure` and restart Compose:

```bash
bus configure LOCAL_AI_PLATFORM_PORT=8081
bus configure LOCAL_AI_PLATFORM_MAILHOG_PORT=18025
docker compose up --build -d
```

To point the Codex worker at a non-default local Codex config directory:

```bash
bus configure BUS_CODEX_HOME=/path/to/codex-home
docker compose up --build -d bus-codex bus-llm
```

The public local base URL is:

```bash
http://127.0.0.1:8080
```

If `LOCAL_AI_PLATFORM_PORT` is changed, replace `8080` with the configured
port.

nginx exposes the same local route families used by the production tutorial:

```text
/v1/*
/api/v1/auth/*
/api/v1/events*
/api/v1/billing/*
/api/v1/vm/*
/api/v1/containers/*
/api/internal/auth/*
/api/internal/billing/*
/api/internal/usage-events*
/api/internal/containers/*
/api/internal/stripe/webhook
/portal/local-dev/*
```

The local portal is available at:

```bash
http://127.0.0.1:8080/portal/local-dev/
```

If `LOCAL_AI_PLATFORM_PORT` is changed, replace `8080` with the configured
port.

It runs `bus-portal` with `bus-portal-auth`, `bus-portal-ai`, and experimental
`bus-portal-accounting` mounted. Portal modules remain frontend-only; auth,
billing, LLM, container, and accounting business operations stay behind the
same API-provider routes listed above.

Inside `testing-agent`, generated local JWTs are available at:

```text
~/.config/bus/auth/api-token
~/.config/bus/auth/auth-token
```

Smoke-check the local OpenAI-compatible route:

```bash
TOKEN="$(cat ~/.config/bus/auth/api-token)"
wget -qO- --header="Authorization: Bearer $TOKEN" http://nginx:8080/v1/models
```

Start the full local stack and create a Docker-backed Codex task from the host:

```bash
bus configure BUS_DOCKER_CODEX_HOME_WRITABLE=true
docker compose up --build -d
bus configure BUS_API_TOKEN="$(cat tmp/local-ai-platform/bus-config/auth/api-token)"
bus configure BUS_EVENTS_API_URL=http://127.0.0.1:8080
bus dev -C ./bus-dev work start "Show the Codex CLI version."
bus dev -C ./bus-dev work watch <task-ref-from-work-start-output> --timeout 5m
```

`docker compose up --build -d` writes a non-secret local development token under
`tmp/local-ai-platform/bus-config/auth/api-token`. Store that token and the
local Events API URL with `bus configure` so they are managed in `.env` instead
of shell exports. `BUS_DOCKER_CODEX_HOME_WRITABLE` is enabled for this trusted
local Docker stack because live `codex exec` needs to create session state
under the mounted Codex home. When no explicit `BUS_API_TOKEN`, `--token-file`,
or `BUS_CONFIG_DIR` token is configured, `bus dev work <controller-command>` and `bus dev task` can still use that
source-checkout token automatically before falling back to
`~/.config/bus/auth/api-token`. The Events API default is `http://127.0.0.1:8080`,
matching the local nginx route.

By default the task bridge runs Codex in the addressed module repository. A
task created from `bus-dev`, or explicitly addressed as `@bus-dev`, runs in
`/workspace/bus-dev` inside the Docker-created Codex container. A task addressed
as `@bus-integration-docker` runs in `/workspace/bus-integration-docker`.

### Parallel development tasks

Use one `bus-integration-dev-task` worker per module recipient. Do not run
generic recipient-less workers: independent module work should be claimed by a
worker addressed to exactly that module.

Task containers use isolated Git worktrees by default in the local Docker
stack. The mounted workspace is the read-only dependency view, and only the
recipient's task worktree is mounted writable. For this BusDK superproject,
Compose sets `BUS_DEV_TASK_WORKSPACE_RECIPIENT=busdk`; use recipient `busdk`
only for work that intentionally edits the superproject root. Other projects
can choose their own workspace-recipient name without changing worker code.

The local task stack can be scaled while it is running. Start with four provider
routers and four active module workers, then increase in steps of two only when
Docker has CPU, memory, and Codex quota headroom:

```bash
docker compose -f compose.dev-task-docker.yaml up -d \
  --scale bus-integration-docker=6 \
  --scale bus-integration-containers=6 \
  bus-integration-docker bus-integration-containers
```

Stack-managed module workers are autonomous by default: after completing one
task they keep listening for the next matching task for the same recipient.
They are still disposable containers. You can remove and recreate them at any
time because durable coordination is in Bus Events and task changes are in the
recipient-owned Git worktree and promoted commit path, not in container-local
state.

Add a one-shot module worker dynamically with a unique container name and
explicit recipient only when you want a disposable batch worker that exits after
one matching task or after a bounded idle period:

```bash
docker compose -f compose.dev-task-docker.yaml run -d --no-deps \
  --name busdk-dev-task-bus-journal-1 \
  -e BUS_DEV_TASK_RECIPIENT=bus-journal \
  -e BUS_DEV_TASK_ONCE=true \
  -e BUS_DEV_TASK_IDLE_TIMEOUT=10m \
  bus-integration-dev-task
```

Then create a targeted task:

```bash
bus dev -C ./bus-dev task new @bus-journal "Implement the next PLAN.md item."
```

Measured local plumbing settings from
`tests/superproject/bench_dev_task_docker_compose_workers.sh` on the
provider-neutral fake App Server path. These are synthetic smoke tasks that
prove claim/start/steer/done throughput; they do not measure completed
`PLAN.md` backlog work and should not be used as the productivity metric.

| Workers | Smoke tasks/min |
|---------|-----------------|
| 1       | 12.81           |
| 2       | 18.73           |
| 3       | 24.28           |
| 4       | 27.90           |
| 6       | 29.64           |
| 8       | 31.31           |

Use 4 parallel module workers as the default routine setting until real work
data says otherwise. For real Codex-backed work, increase only when
`bus dev work stats --all` shows workers spend most wall time waiting on
external LLM turns and human review can keep up. Real productivity is accepted
PLAN item closures per hour, review pass rate, and rework. Treat 6 or 8 as
monitored experiments, not defaults, because more workers also create more
review, token, memory, and Git-worktree pressure.

The local Codex App Server worker image currently lacks Codex's Linux
workspace-sandbox helper, so `compose.dev-task-docker.yaml` defaults
`BUS_DEV_TASK_CODEX_SANDBOX=danger-full-access` for that Docker-contained
worker path. The bridge still verifies the addressed isolated worktree before
promotion and reports blocked instead of done when a worker produces no diff or
self-reports incomplete evidence.

Watch task state and container pressure while scaling:

```bash
bus dev -C ./bus-dev task list --all
docker ps
docker stats --no-stream
```

One-shot per-recipient workers should exit by themselves. Persistent stack
workers should be removed and recreated freely when changing worker layout:

```bash
docker stop busdk-dev-task-bus-journal-1
docker compose -f compose.dev-task-docker.yaml down --remove-orphans
```

The default local task command is:

```json
["codex","exec","--skip-git-repo-check","--sandbox","danger-full-access","{prompt}"]
```

The Codex process already runs inside a Docker-created task container, so the
local stack uses Codex's full-access sandbox mode inside that container. The
default production-like post-command deterministically stages, commits, and
pushes the task branch so work survives disposable task containers:

```bash
bus configure BUS_DEV_TASK_POST_COMMAND_JSON='["sh","-c","cd {repo_path} && git add . && (git diff --cached --quiet || git -c user.name=BusDevTask -c user.email=bus-dev-task@localhost commit -m chore:dev-task-{work_ref}) && git push -u origin {branch}"]'
```

The push is a trusted worker post-command, not normal `bus-dev` behavior.
Smoke tests override this post-command to `[]` so they never contact a real
upstream.

The LLM route uses `bus-api-provider-llm --execution-backend events` and
`bus-integration-codex`; it no longer uses a local echo/stub model service.
The `bus-codex` service builds a local image with the Codex CLI and mounts
`${BUS_CODEX_HOME:-$HOME/.codex}` at `/root/.codex`. Docker-created task
containers also use `${BUS_DOCKER_CODEX_HOME_HOST:-$BUS_CODEX_HOME or
$HOME/.codex}` and mount the current superproject as `/workspace` by default.
For branch pushes, configure trusted local SSH access with
`BUS_DOCKER_CODEX_SSH_HOST=$HOME/.ssh`, optional
`BUS_DOCKER_CODEX_SSH_AGENT_HOST=$SSH_AUTH_SOCK`, and
`BUS_DOCKER_CODEX_GIT_SSH_COMMAND`.
The default smoke script overrides the task command to `codex --version` so it
can prove the container path without consuming quota. Live chat execution is
opt-in because it consumes real ChatGPT-backed Codex quota:

```bash
BUS_LOCAL_AI_PLATFORM_LIVE_CODEX=1 \
bash tests/superproject/test_local_ai_platform_compose_smoke.sh
```

Run the full local smoke script from the superproject root:

```bash
bash tests/superproject/test_local_ai_platform_compose_smoke.sh
```

Set `BUS_LOCAL_AI_PLATFORM_KEEP=1` to leave the stack running after that smoke
script exits.

MailHog is exposed on `http://127.0.0.1:8025`; if
`LOCAL_AI_PLATFORM_MAILHOG_PORT` is changed, replace `8025` with the configured
port.

## Local dev-task Docker stack

For live testing of `bus dev work` / `bus dev task` with local Docker-backed container runs,
start the root Compose stack. The stack builds a local Codex CLI image for the
`codex` container profile. The API emits public `bus.containers.*` events,
`bus-integration-containers` routes them to `bus.docker.*`, and
`bus-integration-docker` performs the local Docker work.

Prerequisites:

- Docker Desktop or Docker Engine with Compose support.
- This superproject as the current working directory.
- Submodules initialized so the `bus` and `bus-*` module directories exist.
- `bus` on `PATH` for `bus configure`; from an uninstalled source checkout,
  use `go run ./bus-configure/cmd/bus-configure` for the same configuration
  updates.
- A trusted local development machine. The stack mounts `/var/run/docker.sock`
  into `bus-integration-docker`, which grants host-level Docker control.

```bash
docker compose -f compose.dev-task-docker.yaml up --build -d
docker compose -f compose.dev-task-docker.yaml exec testing-agent sh
```

Inside the testing shell, the stack has generated a local development JWT at
`~/.config/bus/auth/api-token` and exposes:

```bash
export BUS_EVENTS_API_URL=http://bus-events:8081
export BUS_AI_API_URL=http://bus-api-provider-containers:8080
```

Create a task and watch the Docker-backed bridge process it:

```bash
cd /workspace/bus-dev
go run ./cmd/bus-dev work start --new-branch work/docker-smoke @bus-dev "Reply hello from Docker."
go run ./cmd/bus-dev work watch <task-ref-from-work-start-output> --timeout 5m
```

Use the task reference printed by `work start`, for example `task_01example`
when that exact value appears in the command output.

The default task command for real local use runs `codex exec` in the addressed
module repository, prepares the requested branch, then runs the configured
post-command. A task without branch flags defaults to the current branch of the
repository where `bus dev work start` or `bus dev task new` is run. Use `--branch NAME` to use an
existing branch, or `--new-branch NAME --base-branch main` to create a
disposable work branch from `main`. The smoke scripts override the command to
`codex --version` and the post-command to `[]` so they do not consume
ChatGPT-backed Codex quota or push to upstream. To customize hooks:

```bash
bus configure BUS_DEV_TASK_PRE_COMMAND_JSON='["git","status","--short"]'
bus configure BUS_DEV_TASK_POST_COMMAND_JSON='["sh","-c","cd {repo_path} && git add . && (git diff --cached --quiet || git -c user.name=BusDevTask -c user.email=bus-dev-task@localhost commit -m chore:dev-task-{work_ref}) && git push -u origin {branch}"]'
docker compose -f compose.dev-task-docker.yaml up --build -d
```

The same stack can test the container API directly:

```bash
cd /workspace/bus-containers
go run ./cmd/bus-containers run --profile codex -- codex --version
```

The stack mounts `/var/run/docker.sock` into `bus-integration-docker`; use it
only on trusted local development machines.

## Install from source

Prerequisites:

- `git` with submodule support
- read access to the private `bus-*` submodule repositories, or credentials
  configured for the pinned submodule remotes
- POSIX `make`
- Go toolchain available as `go`

Windows notes:
- Use Git for Windows with **Git Bash** (or MSYS2 with GNU `make` + `bash`).
- Run all `make` commands from that POSIX shell.
- On Windows, prefer POSIX-style paths for overrides (for example `/c/busdk/bin`).

Clone the repository and run the bootstrap target. This initializes modules, builds all tools, and installs them.

```bash
git clone https://github.com/busdk/busdk
cd busdk
make bootstrap
```

Step-by-step (equivalent to bootstrap):

```bash
make init
make build
make install
```

Defaults:

- Builds into `./bin`
- Installs into `$(HOME)/.local/bin` (or `$(USERPROFILE)/.local/bin` when `HOME` is unset)

To install into a different prefix:

```bash
make bootstrap PREFIX=/opt/busdk
```

Windows example:

```bash
make bootstrap PREFIX=/c/busdk BINDIR=/c/busdk/bin
```

To build without installing:

```bash
make build
```

## Documentation and resources

- Specifications and documentation: `https://docs.busdk.com`
- Project website: `https://busdk.com`
- GitHub organization and modules: `https://github.com/busdk`

## Repository layout

This repository focuses on building and installing the BusDK toolchain. Module development happens in the individual `bus-*` repositories; they are included here as pinned Git submodules at the repository root. The root `Makefile` discovers modules automatically and delegates build and install to each module.

## Workflows

- **Release pipeline (GitHub Actions)**:

Create a secret named `BUSDK_SUBMODULES_TOKEN` in the BusDK GitHub repository settings at `Settings → Secrets and variables → Actions`. Use a **personal access token** (PAT), either classic or fine-grained, with read access to this repository and all private `bus-*` submodule repositories so the release workflow can fetch submodules.

Required token permissions:

- **Classic PAT**: `repo` scope (read access to private repositories).
- **Fine-grained PAT**: Repository access to this repo **and** every private `bus-*` repo, with **Contents: Read** permission.

Tags like `v0.1.0` trigger a release build and publish.

- **Install script (curl | bash)**:

The release assets include an `install.sh` that supports install, upgrade (rerun), and uninstall. GitHub also provides auto-generated source archives (`.tar.gz`/`.zip`) for each release. Release assets are public for this repository, so a token is not required. If assets are ever marked private, provide `GITHUB_TOKEN` (a PAT with read access) when using the script.

Install a specific tag:

```bash
curl -fsSL https://github.com/busdk/busdk/releases/download/v0.1.0/install.sh | bash
```

Uninstall:

```bash
curl -fsSL https://github.com/busdk/busdk/releases/latest/download/install.sh | bash -s -- --uninstall
```

Install location overrides (also respected for uninstall):

```bash
curl -fsSL https://github.com/busdk/busdk/releases/latest/download/install.sh |
  PREFIX=/opt/busdk BINDIR=/opt/busdk/bin bash
```

Packaging with `DESTDIR`:

```bash
curl -fsSL https://github.com/busdk/busdk/releases/latest/download/install.sh |
  DESTDIR=/tmp/pkg PREFIX=/usr bash
```

- **Initialize modules** (fresh clone):

```bash
make init
```

- **Sync modules to the pinned commits** (does not advance pins):

```bash
make update
```

- **Show pinned module SHAs**:

```bash
make status
```

- **Build all tools into `./bin`**:

```bash
make build
```

- **Run tests for changed modules only** (default for root `test` and `e2e`):

```bash
make test
make e2e
```

Root `make e2e` does not run the superproject agent-container Docker selftest
by default. Use `ROOT_E2E_SELFTEST=1 make e2e` when explicitly validating that
developer container path.

- **Run Go source quality checks for changed modules only** (default for root `quality`):

```bash
make quality
```

- **Force full test/e2e/source-quality sweeps across all modules**:

```bash
make test TEST_SCOPE=all
make e2e TEST_SCOPE=all
make quality QUALITY_SCOPE=all
```

- **Run the complete slow quality sweep**:

```bash
make quality-complete
```

This runs the all-module source/static quality sweep, then uses `bus lint` to
check each module's published end-user documentation page and each available
module binary's `--help` output.

- **Manually choose the module subset**:

```bash
make test CHANGED_MODULES="bus-reports bus-bank"
make e2e CHANGED_MODULES="bus-reports bus-bank"
make quality CHANGED_MODULES="bus-reports bus-bank"
```

- **Skip selected modules** (space-separated shell globs):

```bash
make build SKIP_MODULES="bus-filing*"
```

- **Install tools into `$(BINDIR)`**:

```bash
make install
```

- **Maintainership: intentionally move pins to latest remotes**:

```bash
make upgrade
git status
git commit
```

- **Clean local build artifacts**:

```bash
make clean
```

- **Return to a “fresh clone” state** (cleans + deinitializes modules):

```bash
make distclean
```

### Variables

- `PREFIX`: install prefix (default: `$(HOME)/.local`, or `$(USERPROFILE)/.local` when `HOME` is unset)
- `BINDIR`: install directory (default: `$(PREFIX)/bin`)
- Module-local build outputs are written to each module's literal `./bin`
  directory.
- `GO`: Go tool to use (default: `go`)
- `SKIP_MODULES`: space-separated module names or shell globs to skip in root targets (default skips `bus-filing`, `bus-filing-prh`, `bus-filing-vero`)
- `TEST_SCOPE`: `changed` (default) or `all` for root `make test` / `make e2e`
- `CHANGED_MODULES`: explicit whitespace-separated module list overriding auto-detected changed modules for root `make test`, `make e2e`, or focused `make quality` runs
- `ROOT_E2E_SELFTEST`: set to `1` to include the superproject agent-container Docker selftest in root `make e2e`
- `QUALITY_SCOPE`: `changed` (default) or `all` for root `make quality`; setting `CHANGED_MODULES` narrows quality to those modules unless `QUALITY_SCOPE=all` is also set
- `QUALITY_TARGETS`: whitespace-separated source/static-analysis module Makefile targets for `make quality` to run after the required direct `bus-dev quality lint` custom AST pass (default: `lint security`; missing module targets are skipped)
- `QUALITY_DEEP`: set to `1` to append `QUALITY_DEEP_TARGETS` to the normal quality run; by default no deep targets are configured because root quality is not a test runner
- `QUALITY_DEEP_TARGETS`: extra source/static-analysis targets appended when `QUALITY_DEEP=1` (default: empty)
- `QUALITY_ALLOW_TEST_TARGETS`: set to `1` only for temporary compatibility if an operator deliberately puts test-style targets in `QUALITY_TARGETS`; normal root quality rejects `test*`, `e2e`, `bench`, and Docker targets
- `QUALITY_PROFILE`: default `bus-dev quality lint` profile for root `make quality` (default: `cli`)
- `QUALITY_HTTP_MODULES`: module names or shell globs that should use the `http-service` quality profile
- `QUALITY_LIBRARY_MODULES`: module names or shell globs that should use the `library` quality profile
- `QUALITY_KEEP_GOING`: set to `1` to continue across modules and report all failed steps instead of stopping at the first failure
- `QUALITY_PROGRESS`: set to `1` to print module/target progress during `make quality`; by default successful steps stay quiet
- `QUALITY_COMPLETE_SCOPE`: module scope for `make quality-complete`; defaults to `all`
- `QUALITY_COMPLETE_BUILD`: set to `0` only for harnesses that provide prebuilt module binaries; default `1`
- `QUALITY_COMPLETE_SOURCE`: set to `0` to skip the source/static quality phase; default `1`
- `QUALITY_COMPLETE_PROGRESS`: set to `1` to print module-level progress during `make quality-complete`
- `QUALITY_DOCS_MODULE_DIR`: module documentation directory for `make quality-complete`; default `docs/docs/modules`

## Tests

The root repository provides orchestration checks plus changed-module runners.
By default, `make test` and `make e2e` only run modules that Git currently
shows as changed. Use `TEST_SCOPE=all` when you explicitly want a full
cross-module test/e2e sweep. You can still run an individual module directly,
for example:

```bash
make -C bus-journal test
```

For AI-assisted cleanup loops, use the root quality sweep before running tests
so source-code findings are reported module by module in deterministic order.
By default, `make quality` uses the same changed-module scope as root
`make test` and `make e2e`; use `QUALITY_SCOPE=all` when you explicitly want
the slower full-fleet static sweep. Root quality always runs the core Bus custom
AST checks directly through `bus-dev quality lint` for every selected Go module;
these checks are not hidden inside Go tests or module test targets. The default
additional source-quality target set is `lint security`. Root quality is
intentionally not a test runner: unit tests, race tests, fuzzing, benchmarks,
Docker validation, and e2e checks belong under `make test`, `make e2e`, or
module-specific test targets.

Use `make quality-complete` when the slower reader-facing lint surface matters.
It defaults to `QUALITY_COMPLETE_SCOPE=all`, builds the local dispatcher and
`bus-lint`, builds selected module binaries, and checks
`docs/docs/modules/<module>.md` plus captured `--help` output through `bus lint`.
A clean run prints only the summary unless progress is enabled.

Module-local `make lint` targets also run `bus-dev quality lint`, so the same
custom AST bad-pattern checks are available when working inside an individual
module. In the superproject, root `make quality` passes the freshly built local
`bus-dev` binary into those module targets; standalone module checkouts should
have `bus-dev` available on `PATH` or pass `BUS_DEV=/path/to/bus-dev`.

Successful module target output and progress lines are hidden; failed
lint/security steps print their diagnostics. A full collection run can continue
after failures:

```bash
make quality QUALITY_KEEP_GOING=1
make quality QUALITY_SCOPE=all QUALITY_KEEP_GOING=1
```

During tighter repair loops, narrow the target set:

```bash
make quality CHANGED_MODULES="bus-ledger" QUALITY_TARGETS="lint"
make quality QUALITY_SCOPE=changed QUALITY_TARGETS="lint"
make quality QUALITY_PROGRESS=1
```

## Roadmap

- Improve contributor guidance for coordinated module pin updates
- Add a release checklist for multi-module releases

## Support

Use the GitHub issue tracker for questions and bug reports: `https://github.com/busdk/busdk/issues`.

## Contributing

Contributions to this repository are welcome (build orchestration, documentation, pin updates). For module behavior changes, please contribute to the relevant `bus-*` repository instead.

## Authors and credits

Maintained by the BusDK maintainers. Module authors and contributors are credited in their respective repositories.

## License

See [LICENSE.md](LICENSE.md).

## Commercial licensing

Pre-built BusDK CLI tools are freeware and free to use. Full source code access and use is available under FSL-1.1-MIT (Functional Source License 1.1, MIT Future License). For source licensing, contact `info@hg.fi`.
