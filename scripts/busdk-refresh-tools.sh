#!/bin/sh
set -eu

usage() {
  printf 'usage: %s [--refresh-only] [-- command...]\n' "$0" >&2
  printf 'Refreshes BusDK command wrappers from mounted source modules, then optionally executes command.\n' >&2
}

refresh_only=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    --refresh-only)
      refresh_only=1
      shift
      ;;
    --help)
      usage
      exit 0
      ;;
    --)
      shift
      break
      ;;
    -*)
      usage
      exit 2
      ;;
    *)
      break
      ;;
  esac
done

quote_sh() {
  printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"
}

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
default_workspace_root=$(CDPATH= cd -- "$script_dir/.." && pwd)

workspace_root=${BUSDK_WORKSPACE_ROOT:-$default_workspace_root}
if [ ! -d "$workspace_root" ]; then
  printf 'BusDK workspace root not found: %s\n' "$workspace_root" >&2
  exit 2
fi

if [ "${BUSDK_TOOL_WRAPPER_DIR+x}" ]; then
  wrapper_dir=$BUSDK_TOOL_WRAPPER_DIR
elif [ -d /usr/local/bin ] && [ -w /usr/local/bin ]; then
  wrapper_dir=/usr/local/bin
else
  wrapper_dir=$workspace_root/.busdk-tools/bin
fi

tool_bin_dir=${BUSDK_TOOL_BIN_DIR:-/tmp/busdk-tools}
mkdir -p "$wrapper_dir" "$tool_bin_dir"

created=0
for module in "$workspace_root"/bus "$workspace_root"/bus-*; do
  [ -d "$module" ] || continue
  tool=${module##*/}
  [ -f "$module/cmd/$tool/main.go" ] || continue

  wrapper=$wrapper_dir/$tool
  tmp_wrapper=$wrapper.tmp.$$
  module_q=$(quote_sh "$module")
  tool_q=$(quote_sh "$tool")
  bin_dir_q=$(quote_sh "$tool_bin_dir")

  cat >"$tmp_wrapper" <<EOF
#!/bin/sh
set -eu

tool=$tool_q
module=$module_q
cmd="./cmd/\$tool"
go_cmd=\${GO:-go}
bin_dir=\${BUSDK_TOOL_BIN_DIR:-$bin_dir_q}
bin="\$bin_dir/\$tool"

new_tmp_bin() {
  if tmp_path=\$(mktemp "\$bin.tmp.XXXXXX" 2>/dev/null); then
    printf '%s\n' "\$tmp_path"
    return 0
  fi

  i=0
  while [ "\$i" -lt 100 ]; do
    tmp_path="\$bin.tmp.\$\$.\$i"
    if (set -C; : >"\$tmp_path") 2>/dev/null; then
      printf '%s\n' "\$tmp_path"
      return 0
    fi
    i=\$((i + 1))
  done

  printf '%s\n' "unable to allocate temporary build path for \$bin" >&2
  return 1
}

tmp_bin=\$(new_tmp_bin)
cleanup_tmp_bin() {
  [ -z "\${tmp_bin:-}" ] || rm -f "\$tmp_bin"
}
trap cleanup_tmp_bin EXIT HUP INT TERM

if [ ! -f "\$module/cmd/\$tool/main.go" ]; then
  printf '%s\n' "\$tool wrapper requires \$module/cmd/\$tool/main.go" >&2
  exit 127
fi

mkdir -p "\$bin_dir"
(
  cd "\$module"
  "\$go_cmd" build -o "\$tmp_bin" "\$cmd"
)
chmod +x "\$tmp_bin"
mv "\$tmp_bin" "\$bin"
tmp_bin=
exec "\$bin" "\$@"
EOF
  chmod +x "$tmp_wrapper"
  mv "$tmp_wrapper" "$wrapper"
  created=$((created + 1))
done

if [ "$created" -eq 0 ]; then
  printf 'BusDK tool refresh found no mounted command modules under %s\n' "$workspace_root" >&2
fi

if [ "$refresh_only" -eq 1 ]; then
  exit 0
fi

if [ "$#" -eq 0 ]; then
  exec /bin/sh
fi

exec "$@"
