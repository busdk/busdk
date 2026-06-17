#!/usr/bin/env bash
set -euo pipefail

root_dir=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
cd "$root_dir"

tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

module_dir="$tmp_dir/freshness-module"
bindir="$tmp_dir/bin"
build_log="$tmp_dir/build.log"
install_log="$tmp_dir/install.log"
module_name="freshness-module"
module_bin="$module_dir/bin/$module_name"
installed_bin="$bindir/$module_name"

mkdir -p "$module_dir/bin" "$bindir"

cat >"$module_dir/Makefile" <<'MAKE'
MODULE_NAME := freshness-module
BUILD_LOG ?=
INSTALL_LOG ?=

.PHONY: build install

build: bin/$(MODULE_NAME)

bin/$(MODULE_NAME): main.go
	@mkdir -p bin
	@if [ -n "$(BUILD_LOG)" ]; then printf 'build\n' >>"$(BUILD_LOG)"; fi
	@printf 'fresh build\n' >"$@"

install: build
	@mkdir -p "$(DESTDIR)$(BINDIR)"
	@if [ -n "$(INSTALL_LOG)" ]; then printf 'install\n' >>"$(INSTALL_LOG)"; fi
	@cp bin/$(MODULE_NAME) "$(DESTDIR)$(BINDIR)/$(MODULE_NAME)"
MAKE

cat >"$module_dir/main.go" <<'GO'
package main

func main() {}
GO

printf 'stale bin\n' >"$module_bin"
printf 'installed bin\n' >"$installed_bin"
touch -t 202606180001 "$module_bin"
touch -t 202606180002 "$installed_bin"
touch -t 202606180003 "$module_dir/main.go"

: >"$build_log"
: >"$install_log"
BUILD_LOG="$build_log" INSTALL_LOG="$install_log" \
	make -s install MODULE_DIRS="$module_dir" BINDIR="$bindir" >"$tmp_dir/install.out" 2>&1

grep -qx 'build' "$build_log"
grep -qx 'install' "$install_log"
grep -qx 'fresh build' "$installed_bin"

touch -t 202606180004 "$module_bin"
touch -t 202606180005 "$installed_bin"

: >"$build_log"
: >"$install_log"
BUILD_LOG="$build_log" INSTALL_LOG="$install_log" \
	make -s install MODULE_DIRS="$module_dir" BINDIR="$bindir" >"$tmp_dir/install-again.out" 2>&1

test ! -s "$build_log"
test ! -s "$install_log"
grep -qx 'fresh build' "$installed_bin"

: >"$build_log"
: >"$install_log"
BUILD_LOG="$build_log" INSTALL_LOG="$install_log" CHANGED_MODULES="$module_dir" \
	make -s build install MODULE_DIRS="$module_dir" BINDIR="$bindir" >"$tmp_dir/build-install.out" 2>&1

test ! -s "$build_log"
test ! -s "$install_log"
grep -qx 'fresh build' "$installed_bin"

printf 'freshness install regression OK\n'
