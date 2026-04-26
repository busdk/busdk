# BusDK (Business Development Kit)

[![License](https://img.shields.io/github/license/busdk/busdk)](LICENSE)
[![Release](https://img.shields.io/github/v/release/busdk/busdk)](https://github.com/busdk/busdk/releases)

BusDK is a modular, CLI-first toolkit for running a business with Git-native, auditable data. It stores business datasets as UTF-8 CSV backed by Frictionless Table Schema (JSON), favoring simple primitives, deterministic behavior, and workflows that work well for both humans and automation. This repository is the one-command entrypoint to install the full BusDK toolchain.

## Quick install

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

Each module also installs a standalone binary, for example:

```bash
bus-journal --help
```

## Install from source

Prerequisites:

- `git` with submodule support
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
PREFIX=/opt/busdk BINDIR=/opt/busdk/bin \
  curl -fsSL https://github.com/busdk/busdk/releases/latest/download/install.sh | bash
```

Packaging with `DESTDIR`:

```bash
DESTDIR=/tmp/pkg PREFIX=/usr \
  curl -fsSL https://github.com/busdk/busdk/releases/latest/download/install.sh | bash
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
- `BIN_DIR`: local build output directory (default: `bin`)
- `GO`: Go tool to use (default: `go`)
- `SKIP_MODULES`: space-separated module names or shell globs to skip in root targets (default skips `bus-filing`, `bus-filing-prh`, `bus-filing-vero`)
- `TEST_SCOPE`: `changed` (default) or `all` for root `make test` / `make e2e`
- `CHANGED_MODULES`: explicit whitespace-separated module list overriding auto-detected changed modules for root `make test`, `make e2e`, or focused `make quality` runs
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
