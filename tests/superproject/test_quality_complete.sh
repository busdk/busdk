#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT_DIR"

MODULE_DIR="bus-quality-complete-selftest"
DOCS_DIR="$(mktemp -d)"
FAKE_BIN_DIR="$(mktemp -d)"
FAKE_BUS="$FAKE_BIN_DIR/bus"
FAKE_BUS_LINT="$FAKE_BIN_DIR/bus-lint"
CALLS="$FAKE_BIN_DIR/calls"
OUT_PASS="$(mktemp)"
OUT_MISSING_DOC="$(mktemp)"
trap 'rm -rf "$MODULE_DIR" "$DOCS_DIR" "$FAKE_BIN_DIR"; rm -f "$OUT_PASS" "$OUT_MISSING_DOC"' EXIT

mkdir -p "$MODULE_DIR/bin" "$DOCS_DIR"
cat >"$MODULE_DIR/Makefile" <<'MAKE'
build:
	@:
MAKE
cat >"$MODULE_DIR/bin/$MODULE_DIR" <<'SH'
#!/bin/sh
if [ "${1:-}" = "--help" ]; then
	printf 'Usage: bus-quality-complete-selftest [flags]\n\n'
	printf 'Flags:\n'
	printf '  -h, --help  Show help and exit.\n'
	exit 0
fi
exit 2
SH
chmod +x "$MODULE_DIR/bin/$MODULE_DIR"
cat >"$DOCS_DIR/$MODULE_DIR.md" <<'MD'
---
title: Quality complete selftest
description: Selftest module documentation.
---

## Overview

This page exists only while the superproject quality-complete selftest runs.
MD

cat >"$FAKE_BUS" <<'SH'
#!/bin/sh
printf 'bus %s\n' "$*" >>"$QUALITY_COMPLETE_CALLS"
if [ "${1:-}" = "lint" ]; then
	shift
	exec bus-lint "$@"
fi
exit 127
SH
chmod +x "$FAKE_BUS"

cat >"$FAKE_BUS_LINT" <<'SH'
#!/bin/sh
printf 'bus-lint %s\n' "$*" >>"$QUALITY_COMPLETE_CALLS"
last=
for arg do
	last="$arg"
done
if [ -n "$last" ] && [ "$last" != "-" ] && [ ! -s "$last" ]; then
	printf 'empty lint input: %s\n' "$last" >&2
	exit 1
fi
exit 0
SH
chmod +x "$FAKE_BUS_LINT"

QUALITY_COMPLETE_CALLS="$CALLS" PATH="$FAKE_BIN_DIR:$PATH" make -s quality-complete \
	QUALITY_COMPLETE_SCOPE=changed \
	CHANGED_MODULES="$MODULE_DIR" \
	QUALITY_COMPLETE_SOURCE=0 \
	QUALITY_COMPLETE_BUILD=0 \
	QUALITY_BUS="$FAKE_BUS" \
	QUALITY_BUS_LINT="$FAKE_BUS_LINT" \
	QUALITY_DOCS_MODULE_DIR="$DOCS_DIR" >"$OUT_PASS" 2>&1

grep -q '^quality-complete: ran 1 module(s) (doc lint 1, help lint 1)$' "$OUT_PASS"
grep -q "bus lint --type documentation $DOCS_DIR/$MODULE_DIR.md" "$CALLS"
grep -q 'bus lint --type cli-help ' "$CALLS"
grep -q "bus-lint --type documentation $DOCS_DIR/$MODULE_DIR.md" "$CALLS"
grep -q 'bus-lint --type cli-help ' "$CALLS"

if QUALITY_COMPLETE_CALLS="$CALLS" PATH="$FAKE_BIN_DIR:$PATH" make -s quality-complete \
	QUALITY_COMPLETE_SCOPE=changed \
	CHANGED_MODULES="$MODULE_DIR" \
	QUALITY_COMPLETE_SOURCE=0 \
	QUALITY_COMPLETE_BUILD=0 \
	QUALITY_BUS="$FAKE_BUS" \
	QUALITY_BUS_LINT="$FAKE_BUS_LINT" \
	QUALITY_DOCS_MODULE_DIR="$DOCS_DIR/missing" >"$OUT_MISSING_DOC" 2>&1; then
	echo "expected quality-complete to fail when module documentation is missing" >&2
	exit 1
fi
grep -q "Complete quality documentation lint for $MODULE_DIR failed: missing $DOCS_DIR/missing/$MODULE_DIR.md" "$OUT_MISSING_DOC"
