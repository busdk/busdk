#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT_DIR"

OUT_CHANGED_TEST="$(mktemp)"
OUT_CHANGED_E2E="$(mktemp)"
OUT_ALL_TEST="$(mktemp)"
OUT_NONE_TEST="$(mktemp)"
OUT_AUTO_CHANGED_TEST="$(mktemp)"
TEMP_CHANGED_FILE="bus-reports/.changed-scope-selftest.touch"
trap 'rm -f "$OUT_CHANGED_TEST" "$OUT_CHANGED_E2E" "$OUT_ALL_TEST" "$OUT_NONE_TEST" "$OUT_AUTO_CHANGED_TEST" "$TEMP_CHANGED_FILE"' EXIT

make -s print-test-modules TEST_SCOPE=changed CHANGED_MODULES="bus-reports" >"$OUT_CHANGED_TEST"
grep -q '^bus-reports$' "$OUT_CHANGED_TEST"
if grep -q '^aiz$$' "$OUT_CHANGED_TEST"; then
	echo "expected changed-scope test run to skip aiz" >&2
	exit 1
fi

make -s print-e2e-modules TEST_SCOPE=changed CHANGED_MODULES="bus-reports" >"$OUT_CHANGED_E2E"
grep -q '^bus-reports$' "$OUT_CHANGED_E2E"
if grep -q '^aiz$$' "$OUT_CHANGED_E2E"; then
	echo "expected changed-scope e2e run to skip aiz" >&2
	exit 1
fi

make -s print-test-modules TEST_SCOPE=all CHANGED_MODULES="bus-reports" >"$OUT_ALL_TEST"
grep -q '^aiz$' "$OUT_ALL_TEST"
grep -q '^bus-reports$' "$OUT_ALL_TEST"

make -s print-test-modules TEST_SCOPE=changed CHANGED_MODULES="docs" >"$OUT_NONE_TEST"
test ! -s "$OUT_NONE_TEST"

touch "$TEMP_CHANGED_FILE"
make -s print-test-modules TEST_SCOPE=changed CHANGED_MODULES="" >"$OUT_AUTO_CHANGED_TEST"
grep -q '^bus-reports$' "$OUT_AUTO_CHANGED_TEST"
