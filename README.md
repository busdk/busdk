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
