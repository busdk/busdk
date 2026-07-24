# Root Makefile Contract


When editing the root `Makefile` or adding root orchestration, preserve
superproject-only orchestration: exactly one root `Makefile`, POSIX shell,
`git`, POSIX `make`, deterministic discovery of `bus` and `bus-*` module
Makefiles, delegation via `make -C`, required lifecycle targets, module-local
`./bin` outputs, `PREFIX`/`BINDIR`/`DESTDIR`, Go variable pass-through, and
changed-module-scoped root test/e2e defaults. Do not add lockfiles, alternative
build systems, package-manager integrations, or reimplemented module internals.

