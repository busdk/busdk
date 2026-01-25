# BusDK

[![License](https://img.shields.io/github/license/busdk/busdk)](LICENSE)

BusDK is the **superproject** repository for the BusDK CLI toolchain. It pins the `bus` dispatcher and all `bus-*` modules as **Git submodules** and provides a single, reproducible entrypoint (`Makefile`) to **fetch, build, and install** the full toolchain in one command.

Module development happens in the individual `bus-*` repositories; this repository does **not** contain module source code beyond the pinned submodule checkouts.

## Table of contents

- [Prerequisites](#prerequisites)
- [Install](#install)
- [Usage](#usage)
- [Repository layout](#repository-layout)
- [Workflows](#workflows)
- [Support](#support)
- [Contributing](#contributing)
- [License](#license)

## Prerequisites

- `git` (with submodule support)
- `make` (POSIX make)
- Go toolchain (available as `go` on PATH)

## Install

From a fresh clone:

```bash
make bootstrap
```

Defaults:

- Builds go into `./bin`
- Installs into `$(HOME)/.local/bin`

To install into a different prefix:

```bash
make bootstrap PREFIX=/opt/busdk
```

## Usage

After installation, ensure `$(PREFIX)/bin` is on your `PATH`, then run:

```bash
bus --help
```

Each module also installs a standalone binary, for example:

```bash
bus-journal --help
```

## Repository layout

Each submodule lives at the repository root:

- `bus`
- `bus-accounts`
- `bus-assets`
- `bus-attachments`
- `bus-bank`
- `bus-budget`
- `bus-entities`
- `bus-inventory`
- `bus-invoices`
- `bus-journal`
- `bus-payroll`
- `bus-period`
- `bus-reconcile`
- `bus-reports`
- `bus-validate`
- `bus-vat`
- `bus-filing`
- `bus-filing-prh`
- `bus-filing-vero`

The superproject commit SHAs are the version pins (no separate lockfile).

## Workflows

- **Initialize submodules** (fresh clone):

```bash
make init
```

- **Sync submodules to the pinned commits** (does not advance pins):

```bash
make update
```

- **Show pinned submodule SHAs**:

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

- **Return to a “fresh clone” state** (cleans + deinitializes submodules):

```bash
make distclean
```

### Variables

- **`PREFIX`**: install prefix (default: `$(HOME)/.local`)
- **`BINDIR`**: install directory (default: `$(PREFIX)/bin`)
- **`BIN_DIR`**: local build output directory (default: `bin`)
- **`GO`**: Go tool to use (default: `go`)

## Support

Use the GitHub issue tracker for questions and bug reports: `https://github.com/busdk/busdk/issues`.

## Contributing

Contributions to this superproject are welcome (submodule pin updates, build orchestration, documentation).

For module behavior changes, please contribute to the relevant `bus-*` repository instead.

## License

See [LICENSE](LICENSE).
