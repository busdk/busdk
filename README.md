# BusDK Superproject

[![License](https://img.shields.io/github/license/busdk/busdk)](LICENSE)

BusDK is the **superproject** that pins the `bus` dispatcher and all `bus-*` modules as Git submodules, then provides one reproducible entrypoint (`Makefile`) to fetch, build, and install the entire CLI toolchain. Use it when you want **one command** to install a consistent set of BusDK tools without juggling module versions yourself.

This repository does **not** contain module source code beyond the pinned submodule checkouts; module development happens in the individual `bus-*` repositories.

## Table of contents

- [Status](#status)
- [Features](#features)
- [Prerequisites](#prerequisites)
- [Install](#install)
- [Usage](#usage)
- [Repository layout](#repository-layout)
- [Workflows](#workflows)
- [Tests](#tests)
- [Roadmap](#roadmap)
- [Support](#support)
- [Contributing](#contributing)
- [Authors and credits](#authors-and-credits)
- [License](#license)

## Status

Active and maintained. The superproject focuses on stability and reproducible builds.

## Features

- One `Makefile` to initialize, build, and install all BusDK tools
- Automatic module discovery (`bus` and any `bus-*` directories with a `Makefile`)
- Stable pins via submodule SHAs (no separate lockfile)
- Consistent build output and install locations across modules

## Prerequisites

- `git` with submodule support
- POSIX `make`
- Go toolchain available as `go`

## Install

From a fresh clone:

```bash
make bootstrap
```

Defaults:

- Builds into `./bin`
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

Expected output includes the global help header for the dispatcher and a list of available subcommands.

Each module also installs a standalone binary, for example:

```bash
bus-journal --help
```

## Repository layout

Each submodule lives at the repository root (`bus` and `bus-*`). New modules are picked up automatically by the root `Makefile` if the directory contains its own `Makefile`. The pinned submodule SHAs in this superproject are the authoritative version pins.

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

- `PREFIX`: install prefix (default: `$(HOME)/.local`)
- `BINDIR`: install directory (default: `$(PREFIX)/bin`)
- `BIN_DIR`: local build output directory (default: `bin`)
- `GO`: Go tool to use (default: `go`)

## Tests

The superproject itself has no test suite. Run tests in the individual modules as needed, for example:

```bash
make -C bus-journal test
```

## Roadmap

- Improve contributor guidance for submodule pin updates
- Add a release checklist for coordinated multi-module updates

## Support

Use the GitHub issue tracker for questions and bug reports: `https://github.com/busdk/busdk/issues`.

## Contributing

Contributions to this superproject are welcome (submodule pin updates, build orchestration, documentation). For module behavior changes, please contribute to the relevant `bus-*` repository instead.

## Authors and credits

Maintained by the BusDK maintainers. Module authors and contributors are credited in their respective repositories.

## License

See [LICENSE](LICENSE).
