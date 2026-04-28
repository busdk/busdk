#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT_DIR"

MODULE_DIR="bus-quality-selftest"
DEEP_MODULE_DIR="bus-quality-deep-selftest"
NO_GO_MODULE_DIR="bus-quality-nogo-selftest"
FAKE_BIN_DIR="$(mktemp -d)"
FAKE_BUS_DEV="$FAKE_BIN_DIR/bus-dev"
OUT_PASS="$(mktemp)"
OUT_FAIL="$(mktemp)"
OUT_DEEP_DEFAULT="$(mktemp)"
OUT_DEEP_FULL="$(mktemp)"
OUT_INVALID="$(mktemp)"
OUT_NO_GO="$(mktemp)"
BUS_DEV_CALLS="$FAKE_BIN_DIR/bus-dev.calls"
trap 'rm -rf "$MODULE_DIR" "$DEEP_MODULE_DIR" "$NO_GO_MODULE_DIR" "$FAKE_BIN_DIR"; rm -f "$OUT_PASS" "$OUT_FAIL" "$OUT_DEEP_DEFAULT" "$OUT_DEEP_FULL" "$OUT_INVALID" "$OUT_NO_GO"' EXIT

mkdir -p "$MODULE_DIR"
cat >"$MODULE_DIR/go.mod" <<'MOD'
module example.com/bus-quality-selftest

go 1.22
MOD
cat >"$MODULE_DIR/Makefile" <<'MAKE'
lint:
	@printf 'LINT_SUCCESS_OUTPUT_SHOULD_BE_HIDDEN\n'

security:
	@printf 'SECURITY_FAILURE_OUTPUT_SHOULD_PRINT\n'
	@exit 1

test:
	@printf 'TEST_TARGET_SHOULD_NOT_RUN_FROM_QUALITY\n'
MAKE
cat >"$FAKE_BUS_DEV" <<'SH'
#!/bin/sh
if [ -n "${BUS_DEV_CALLS:-}" ]; then
	printf '%s\n' "$*" >>"$BUS_DEV_CALLS"
fi
exit 0
SH
chmod +x "$FAKE_BUS_DEV"

make -s quality QUALITY_SCOPE=changed CHANGED_MODULES="$MODULE_DIR" QUALITY_BUS_DEV="$FAKE_BUS_DEV" QUALITY_TARGETS="lint" >"$OUT_PASS" 2>&1
if grep -q 'LINT_SUCCESS_OUTPUT_SHOULD_BE_HIDDEN' "$OUT_PASS"; then
	echo "expected successful quality lint output to stay hidden" >&2
	exit 1
fi
if grep -q '^==>' "$OUT_PASS"; then
	echo "expected successful quality progress output to stay hidden by default" >&2
	exit 1
fi
grep -q '^quality: ran 1 module(s)$' "$OUT_PASS"

mkdir -p "$NO_GO_MODULE_DIR"
cat >"$NO_GO_MODULE_DIR/Makefile" <<'MAKE'
quality:
	@touch quality-ran
MAKE
BUS_DEV_CALLS="$BUS_DEV_CALLS" make -s quality QUALITY_SCOPE=changed CHANGED_MODULES="$NO_GO_MODULE_DIR" QUALITY_BUS_DEV="$FAKE_BUS_DEV" QUALITY_TARGETS="quality" >"$OUT_NO_GO" 2>&1
grep -q '^quality: ran 1 module(s)$' "$OUT_NO_GO"
test -f "$NO_GO_MODULE_DIR/quality-ran"
if [ -f "$BUS_DEV_CALLS" ] && grep -q "quality lint --profile cli $NO_GO_MODULE_DIR" "$BUS_DEV_CALLS"; then
	echo "expected non-Go quality module not to run Go source lint" >&2
	exit 1
fi

if make -s quality QUALITY_SCOPE=changed CHANGED_MODULES="$MODULE_DIR" QUALITY_BUS_DEV="$FAKE_BUS_DEV" QUALITY_TARGETS="security" >"$OUT_FAIL" 2>&1; then
	echo "expected failing quality security target to fail" >&2
	exit 1
fi
grep -q 'SECURITY_FAILURE_OUTPUT_SHOULD_PRINT' "$OUT_FAIL"
grep -q "^Security checks for $MODULE_DIR failed, run this for more information: make -C $MODULE_DIR security$" "$OUT_FAIL"

if make -s quality QUALITY_SCOPE=changed CHANGED_MODULES="$MODULE_DIR" QUALITY_BUS_DEV="$FAKE_BUS_DEV" QUALITY_TARGETS="test" >"$OUT_INVALID" 2>&1; then
	echo "expected quality to reject test targets" >&2
	exit 1
fi
grep -q 'invalid quality target test: root make quality is source/static analysis only' "$OUT_INVALID"
if grep -q 'TEST_TARGET_SHOULD_NOT_RUN_FROM_QUALITY' "$OUT_INVALID"; then
	echo "expected rejected test target not to run" >&2
	exit 1
fi

mkdir -p "$DEEP_MODULE_DIR"
cat >"$DEEP_MODULE_DIR/go.mod" <<'MOD'
module example.com/bus-quality-deep-selftest

go 1.22
MOD
cat >"$DEEP_MODULE_DIR/Makefile" <<'MAKE'
lint:
	@touch lint-ran

help-check:
	@touch help-ran

security:
	@touch security-ran

test-race:
	@touch race-ran

test-fuzz:
	@touch fuzz-ran

test-bench:
	@touch bench-ran

test-docker:
	@touch docker-ran
MAKE

BUS_DEV_CALLS="$BUS_DEV_CALLS" make -s quality QUALITY_SCOPE=changed CHANGED_MODULES="$DEEP_MODULE_DIR" QUALITY_BUS_DEV="$FAKE_BUS_DEV" >"$OUT_DEEP_DEFAULT" 2>&1
grep -q '^quality: ran 1 module(s)$' "$OUT_DEEP_DEFAULT"
test -f "$DEEP_MODULE_DIR/lint-ran"
test -f "$DEEP_MODULE_DIR/security-ran"
! test -f "$DEEP_MODULE_DIR/help-ran"
! test -f "$DEEP_MODULE_DIR/race-ran"
! test -f "$DEEP_MODULE_DIR/fuzz-ran"
! test -f "$DEEP_MODULE_DIR/bench-ran"
! test -f "$DEEP_MODULE_DIR/docker-ran"
grep -q "quality lint --profile cli $DEEP_MODULE_DIR" "$BUS_DEV_CALLS"

BUS_DEV_CALLS="$BUS_DEV_CALLS" make -s quality QUALITY_SCOPE=changed CHANGED_MODULES="$DEEP_MODULE_DIR" QUALITY_BUS_DEV="$FAKE_BUS_DEV" QUALITY_DEEP=1 >"$OUT_DEEP_FULL" 2>&1
grep -q '^quality: ran 1 module(s)$' "$OUT_DEEP_FULL"
! test -f "$DEEP_MODULE_DIR/fuzz-ran"
! test -f "$DEEP_MODULE_DIR/bench-ran"
! test -f "$DEEP_MODULE_DIR/docker-ran"
