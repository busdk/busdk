#!/usr/bin/env bash
set -euo pipefail

root_dir=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

workspace="$tmp_dir/workspace"
wrapper_dir="$tmp_dir/wrappers"
bin_dir="$tmp_dir/runtime-bin"
missing_bin_dir="$tmp_dir/runtime-bin-created-by-wrapper"
fake_bin="$tmp_dir/fake-bin"
fallback_bin="$tmp_dir/fallback-bin"
caller_dir="$tmp_dir/caller"
build_log="$tmp_dir/build-outputs.log"
mkdir -p "$workspace" "$wrapper_dir" "$bin_dir" "$fake_bin" "$fallback_bin" "$caller_dir"

for module in bus bus-dev bus-gx bus-lint bus-notes; do
  mkdir -p "$workspace/$module/cmd/$module" "$workspace/$module/bin"
  printf 'package main\nfunc main() {}\n' >"$workspace/$module/cmd/$module/main.go"
  printf '#!/bin/sh\nexit 99\n' >"$workspace/$module/bin/$module"
  chmod +x "$workspace/$module/bin/$module"
done

cat >"$fake_bin/go" <<'EOF'
#!/bin/sh
set -eu

if [ "$1" != "build" ]; then
  printf 'unexpected go command: %s\n' "$*" >&2
  exit 2
fi

shift
out=
while [ "$#" -gt 0 ]; do
  case "$1" in
    -o)
      out=$2
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done

if [ -z "$out" ]; then
  printf 'missing go build -o output\n' >&2
  exit 2
fi

if [ -n "${BUSDK_FAKE_GO_BUILD_LOG:-}" ]; then
  printf '%s\n' "$out" >>"$BUSDK_FAKE_GO_BUILD_LOG"
fi

tool=${PWD##*/}
cat >"$out" <<EOF_INNER
#!/bin/sh
set -eu
tool=$tool
case "\$tool:\${1:-}" in
  bus:dev)
    shift
    exec bus-dev "\$@"
    ;;
  bus:gx)
    shift
    exec bus-gx "\$@"
    ;;
  bus:lint)
    shift
    exec bus-lint "\$@"
    ;;
  bus:notes)
    shift
    exec bus-notes "\$@"
    ;;
esac
printf '%s|%s|%s\n' "\$tool" "\$PWD" "\$*"
EOF_INNER
chmod +x "$out"
EOF
chmod +x "$fake_bin/go"

cat >"$fallback_bin/mktemp" <<'EOF'
#!/bin/sh
exit 1
EOF
chmod +x "$fallback_bin/mktemp"

BUSDK_WORKSPACE_ROOT="$workspace" \
BUSDK_TOOL_WRAPPER_DIR="$wrapper_dir" \
BUSDK_TOOL_BIN_DIR="$bin_dir" \
PATH="$fake_bin:$PATH" \
  "$root_dir/scripts/busdk-refresh-tools.sh" --refresh-only

for tool in bus bus-dev bus-gx bus-lint bus-notes; do
  test -x "$wrapper_dir/$tool"
done

assert_output() {
  expected=$1
  shift
  output=$(cd "$caller_dir" && PATH="$wrapper_dir:$fake_bin:$PATH" BUSDK_TOOL_BIN_DIR="$bin_dir" "$@")
  if [ "$output" != "$expected" ]; then
    printf 'FAIL busdk refresh tools: expected %s, got %s\n' "$expected" "$output" >&2
    exit 1
  fi
}

assert_output "bus|$caller_dir|--help" bus --help
assert_output "bus-dev|$caller_dir|work monitor --help" bus dev work monitor --help
assert_output "bus-gx|$caller_dir|help" bus gx help
assert_output "bus-lint|$caller_dir|--help" bus lint --help
assert_output "bus-notes|$caller_dir|--help" bus notes --help

if grep -Fq 'tmp_bin="$bin.tmp.$$"' "$wrapper_dir/bus"; then
  printf 'FAIL busdk refresh tools: generated wrapper still uses pid-only temp path\n' >&2
  exit 1
fi
grep -Fq 'mktemp "$bin.tmp.XXXXXX"' "$wrapper_dir/bus"

output=$(cd "$caller_dir" && PATH="$fallback_bin:$wrapper_dir:$fake_bin:$PATH" BUSDK_TOOL_BIN_DIR="$bin_dir" bus --help)
if [ "$output" != "bus|$caller_dir|--help" ]; then
  printf 'FAIL busdk refresh tools: mktemp fallback produced %s\n' "$output" >&2
  exit 1
fi

output=$(cd "$caller_dir" && PATH="$wrapper_dir:$fake_bin:$PATH" BUSDK_TOOL_BIN_DIR="$missing_bin_dir" bus --help)
if [ "$output" != "bus|$caller_dir|--help" ]; then
  printf 'FAIL busdk refresh tools: missing runtime bin dir produced %s\n' "$output" >&2
  exit 1
fi
test -d "$missing_bin_dir"

: >"$build_log"
concurrent_pids=
for _ in 1 2 3 4 5 6 7 8 9 10 11 12; do
  (
    cd "$caller_dir"
    PATH="$wrapper_dir:$fake_bin:$PATH" \
    BUSDK_TOOL_BIN_DIR="$bin_dir" \
    BUSDK_FAKE_GO_BUILD_LOG="$build_log" \
      bus lint --help >/dev/null
  ) &
  concurrent_pids="$concurrent_pids $!"
done

for pid in $concurrent_pids; do
  wait "$pid"
done

expected_builds=24
actual_builds=$(wc -l <"$build_log" | tr -d ' ')
if [ "$actual_builds" != "$expected_builds" ]; then
  printf 'FAIL busdk refresh tools: expected %s concurrent build outputs, got %s\n' "$expected_builds" "$actual_builds" >&2
  exit 1
fi

unique_builds=$(sort -u "$build_log" | wc -l | tr -d ' ')
if [ "$unique_builds" != "$expected_builds" ]; then
  printf 'FAIL busdk refresh tools: concurrent wrapper builds reused a temp output\n' >&2
  sort "$build_log" | uniq -d >&2
  exit 1
fi

if find "$bin_dir" -name '*.tmp.*' -print | grep .; then
  printf 'FAIL busdk refresh tools: temporary build outputs were left behind\n' >&2
  exit 1
fi

printf 'busdk refresh tools OK\n'
