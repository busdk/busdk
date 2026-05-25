#!/bin/sh
set -eu

codex_bin=${BUS_DEV_TASK_CODEX_REAL_COMMAND:-codex}

if [ -n "${CODEX_HOME:-}" ]; then
  standalone_dir="$CODEX_HOME/packages/standalone/current"
  standalone_bin="$standalone_dir/codex"
  if [ ! -x "$standalone_bin" ]; then
    mkdir -p "$standalone_dir"
    for candidate in /usr/local/lib/node_modules/@openai/codex/node_modules/@openai/codex-linux-*/vendor/*/bin/codex; do
      if [ -x "$candidate" ]; then
        ln -sf "$candidate" "$standalone_bin"
        break
      fi
    done
  fi
fi

"$codex_bin" app-server daemon start >/dev/null
exec "$codex_bin" "$@"
