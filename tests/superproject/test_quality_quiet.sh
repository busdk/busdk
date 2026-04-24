#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT_DIR"

MODULE_DIR="bus-quality-selftest"
FAKE_BIN_DIR="$(mktemp -d)"
FAKE_BUS_DEV="$FAKE_BIN_DIR/bus-dev"
OUT_PASS="$(mktemp)"
OUT_FAIL="$(mktemp)"
trap 'rm -rf "$MODULE_DIR" "$FAKE_BIN_DIR"; rm -f "$OUT_PASS" "$OUT_FAIL"' EXIT

mkdir -p "$MODULE_DIR"
cat >"$MODULE_DIR/go.mod" <<'MOD'
module example.com/bus-quality-selftest

go 1.22
MOD
cat >"$MODULE_DIR/Makefile" <<'MAKE'
test:
	@printf 'UNIT_TEST_SUCCESS_OUTPUT_SHOULD_BE_HIDDEN\n'

test-race:
	@printf 'UNIT_TEST_FAILURE_OUTPUT_SHOULD_BE_HIDDEN\n'
	@exit 1
MAKE
cat >"$FAKE_BUS_DEV" <<'SH'
#!/bin/sh
exit 0
SH
chmod +x "$FAKE_BUS_DEV"

make -s quality QUALITY_SCOPE=changed CHANGED_MODULES="$MODULE_DIR" QUALITY_BUS_DEV="$FAKE_BUS_DEV" QUALITY_TARGETS="test" >"$OUT_PASS" 2>&1
if grep -q 'UNIT_TEST_SUCCESS_OUTPUT_SHOULD_BE_HIDDEN' "$OUT_PASS"; then
	echo "expected successful quality unit-test output to stay hidden" >&2
	exit 1
fi
if grep -q '^==>' "$OUT_PASS"; then
	echo "expected successful quality progress output to stay hidden by default" >&2
	exit 1
fi
grep -q '^quality: ran 1 module(s)$' "$OUT_PASS"

if make -s quality QUALITY_SCOPE=changed CHANGED_MODULES="$MODULE_DIR" QUALITY_BUS_DEV="$FAKE_BUS_DEV" QUALITY_TARGETS="test-race" >"$OUT_FAIL" 2>&1; then
	echo "expected failing quality unit-test target to fail" >&2
	exit 1
fi
if grep -q 'UNIT_TEST_FAILURE_OUTPUT_SHOULD_BE_HIDDEN' "$OUT_FAIL"; then
	echo "expected failing quality unit-test output to stay hidden behind rerun command" >&2
	exit 1
fi
grep -q "^Unit tests for $MODULE_DIR failed, run this for more information: make -C $MODULE_DIR test-race$" "$OUT_FAIL"
