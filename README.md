# BusDK (Business Development Kit)

[![License](https://img.shields.io/github/license/busdk/busdk)](LICENSE)
[![Release](https://img.shields.io/github/v/release/busdk/busdk)](https://github.com/busdk/busdk/releases)

BusDK is a modular, CLI-first toolkit for running a business with Git-native, auditable data. It stores business datasets as UTF-8 CSV backed by Frictionless Table Schema (JSON), favoring simple primitives, deterministic behavior, and workflows that work well for both humans and automation. This repository is the one-command entrypoint to install the full BusDK toolchain.

## Status

Pre-release and actively maintained. Interfaces, schemas, and file conventions may still evolve.

## Features

- One command to install a consistent set of BusDK CLI tools
- Modular subcommands for accounts, journal, invoices, VAT, reports, and more
- Git-friendly, schema-validated CSV datasets with deterministic outputs
- Reproducible builds with consistent output and install paths

## Prerequisites

- `git` with submodule support
- POSIX `make`
- Go toolchain available as `go`

## Install

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
- Installs into `$(HOME)/.local/bin` (from `BINDIR`)

To install into a different prefix:

```bash
make bootstrap PREFIX=/opt/busdk
```

To build without installing:

```bash
make build
```

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

```bash
curl -fsS https://github.com/busdk/busdk/releases/download/v0.0.4/install.sh | bash
```

Install a specific tag:

```bash
curl -fsS https://github.com/busdk/busdk/releases/download/v0.1.0/install.sh | bash
```

Uninstall:

```bash
curl -fsS https://github.com/busdk/busdk/releases/download/v0.0.4/install.sh | bash -s -- --uninstall
```

Install location overrides (also respected for uninstall):

```bash
PREFIX=/opt/busdk BINDIR=/opt/busdk/bin \
  curl -fsS https://github.com/busdk/busdk/releases/download/v0.0.4/install.sh | bash
```

Packaging with `DESTDIR`:

```bash
DESTDIR=/tmp/pkg PREFIX=/usr \
  curl -fsS https://github.com/busdk/busdk/releases/download/v0.0.4/install.sh | bash
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

- `PREFIX`: install prefix (default: `$(HOME)/.local`)
- `BINDIR`: install directory (default: `$(PREFIX)/bin`)
- `BIN_DIR`: local build output directory (default: `bin`)
- `GO`: Go tool to use (default: `go`)
- `SKIP_MODULES`: space-separated module names or shell globs to skip in root targets (default skips `bus-filing`, `bus-filing-prh`, `bus-filing-vero`)

## Tests

The root repository has no test suite. Run tests in individual modules as needed, for example:

```bash
make -C bus-journal test
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

See [LICENSE](LICENSE).

## Commercial licensing

Pre-built BusDK CLI tools are freeware and free to use. Full source code access and use is available for commercial users under the MIT license with a paid contract and subscription model. For source licensing, contact `info@hg.fi`.
