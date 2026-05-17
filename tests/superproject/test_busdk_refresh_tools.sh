#!/usr/bin/env bash
set -euo pipefail

root_dir=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

workspace="$tmp_dir/workspace"
wrapper_dir="$tmp_dir/wrappers"
bin_dir="$tmp_dir/runtime-bin"
fake_bin="$tmp_dir/fake-bin"
caller_dir="$tmp_dir/caller"
mkdir -p "$workspace" "$wrapper_dir" "$bin_dir" "$fake_bin" "$caller_dir"

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

printf 'busdk refresh tools OK\n'
