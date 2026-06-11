#!/bin/bash
cd "$(dirname "$0")/.."
status=0
pids=()
dirs=()

if ! git push >/dev/null 2>&1; then
  echo "warning: push failed for superproject" >&2
  status=1
fi

while read -r DIR; do
  (cd "$DIR" && git push >/dev/null 2>&1) &
  pids+=("$!")
  dirs+=("$DIR")
done < <(git config --file .gitmodules --get-regexp '^submodule\..*\.path$' | awk '{print $2}')

for i in "${!pids[@]}"; do
  if ! wait "${pids[$i]}"; then
    echo "warning: push failed for sub-module: ${dirs[$i]}" >&2
    status=1
  fi
done

exit "$status"
