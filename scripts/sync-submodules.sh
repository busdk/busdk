#!/bin/bash
set -u

cd "$(dirname "$0")/.."

do_pull=1
do_push=1
status=0
ok_count=0
skip_count=0
fail_count=0
jobs=8
verbose=0
targets=()

usage() {
  cat <<'EOF'
Usage: scripts/sync-submodules.sh [--pull-only|--push-only] [--no-pull] [--no-push] [--jobs N] [--verbose] [path ...]

Synchronize the BusDK superproject and submodules in one pass.

By default this quietly fetches, fast-forwards when possible, rebases cleanly
diverged branches onto their upstreams when possible, and then pushes the
superproject plus every submodule listed in .gitmodules, running targets in
parallel batches. If path arguments are given, only those paths are
synchronized. Use "." to include the superproject in a focused run. Pass
--verbose to print each target and the final success summary.
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    --pull-only)
      do_pull=1
      do_push=0
      ;;
    --push-only)
      do_pull=0
      do_push=1
      ;;
    --no-pull)
      do_pull=0
      ;;
    --no-push)
      do_push=0
      ;;
    --jobs)
      shift
      if [ "$#" -eq 0 ] || ! [[ "$1" =~ ^[0-9]+$ ]] || [ "$1" -lt 1 ]; then
        echo "error: --jobs requires a positive integer" >&2
        exit 2
      fi
      jobs="$1"
      ;;
    --verbose)
      verbose=1
      ;;
    --)
      shift
      while [ "$#" -gt 0 ]; do
        targets+=("$1")
        shift
      done
      break
      ;;
    -*)
      echo "error: unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
    *)
      targets+=("$1")
      ;;
  esac
  shift
done

if [ "$do_pull" -eq 0 ] && [ "$do_push" -eq 0 ]; then
  echo "error: nothing to do; both pull and push are disabled" >&2
  exit 2
fi

if [ "${#targets[@]}" -eq 0 ]; then
  targets+=(".")
  while IFS= read -r dir; do
    targets+=("$dir")
  done < <(git config --file .gitmodules --get-regexp '^submodule\..*\.path$' | awk '{print $2}')
fi

git_dir_for() {
  git -C "$1" rev-parse --git-dir 2>/dev/null
}

has_rebase_or_merge() {
  local dir="$1"
  local git_dir
  git_dir="$(git_dir_for "$dir")" || return 1
  [ -d "$git_dir/rebase-merge" ] || [ -d "$git_dir/rebase-apply" ] || [ -f "$git_dir/MERGE_HEAD" ] || [ -f "$git_dir/CHERRY_PICK_HEAD" ]
}

current_branch() {
  git -C "$1" symbolic-ref --quiet --short HEAD 2>/dev/null
}

current_upstream() {
  git -C "$1" rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null
}

is_dirty() {
  [ -n "$(git -C "$1" status --porcelain 2>/dev/null)" ]
}

print_log() {
  local file="$1"
  if [ -s "$file" ]; then
    sed 's/^/    /' "$file" >&2
  fi
}

run_git_step() {
  local dir="$1"
  local label="$2"
  shift 2
  local log
  log="$(mktemp "${TMPDIR:-/tmp}/sync-submodules.XXXXXX")" || return 1
  if git -C "$dir" "$@" >"$log" 2>&1; then
    rm -f "$log"
    return 0
  fi
  echo "warning: $label failed for $dir: git $*" >&2
  print_log "$log"
  rm -f "$log"
  return 1
}

submodule_conflict_paths() {
  local dir="$1"
  git -C "$dir" ls-files -u | awk '$1 == "160000" { print $4 }' | sort -u
}

has_non_submodule_conflicts() {
  local dir="$1"
  [ -n "$(git -C "$dir" ls-files -u | awk '$1 != "160000" { print; exit }')" ]
}

resolve_rebase_submodule_conflicts() {
  local dir="$1"
  local original_head="$2"
  local path
  local desired_rev
  local ours_rev
  local theirs_rev
  local paths

  paths="$(submodule_conflict_paths "$dir")"
  if [ -z "$paths" ] || has_non_submodule_conflicts "$dir"; then
    return 1
  fi

  while IFS= read -r path; do
    [ -n "$path" ] || continue
    desired_rev="$(git -C "$dir" rev-parse "$original_head:$path" 2>/dev/null)" || return 1
    ours_rev="$(git -C "$dir" ls-files -u -- "$path" | awk '$3 == 2 { print $2; exit }')"
    theirs_rev="$(git -C "$dir" ls-files -u -- "$path" | awk '$3 == 3 { print $2; exit }')"
    if [ -z "$desired_rev" ] || [ -z "$ours_rev" ] || [ -z "$theirs_rev" ]; then
      return 1
    fi
    if ! git -C "$dir/$path" cat-file -e "$desired_rev^{commit}" 2>/dev/null; then
      return 1
    fi
    if ! git -C "$dir/$path" merge-base --is-ancestor "$ours_rev" "$desired_rev" 2>/dev/null; then
      return 1
    fi
    if ! git -C "$dir/$path" checkout -q "$desired_rev"; then
      return 1
    fi
    if ! git -C "$dir" update-index --cacheinfo 160000 "$desired_rev" "$path"; then
      return 1
    fi
  done <<<"$paths"

  [ -z "$(git -C "$dir" ls-files -u)" ]
}

rebase_with_submodule_resolution() {
  local dir="$1"
  local upstream="$2"
  local original_head
  local log

  original_head="$(git -C "$dir" rev-parse HEAD 2>/dev/null)" || return 1
  log="$(mktemp "${TMPDIR:-/tmp}/sync-submodules.XXXXXX")" || return 1
  if git -C "$dir" rebase "$upstream" >"$log" 2>&1; then
    rm -f "$log"
    return 0
  fi

  while has_rebase_or_merge "$dir"; do
    if ! resolve_rebase_submodule_conflicts "$dir" "$original_head"; then
      echo "warning: rebase failed for $dir: git rebase $upstream" >&2
      print_log "$log"
      rm -f "$log"
      run_git_step "$dir" "rebase abort" rebase --abort >/dev/null 2>&1 || true
      return 1
    fi
    : >"$log"
    if git -C "$dir" -c core.editor=true rebase --continue >"$log" 2>&1; then
      rm -f "$log"
      return 0
    fi
  done

  echo "warning: rebase failed for $dir: git rebase $upstream" >&2
  print_log "$log"
  rm -f "$log"
  run_git_step "$dir" "rebase abort" rebase --abort >/dev/null 2>&1 || true
  return 1
}

sync_pull() {
  local dir="$1"
  local upstream="$2"
  local local_rev
  local upstream_rev
  local base_rev
  local upstream_remote

  upstream_remote="${upstream%%/*}"

  if ! run_git_step "$dir" fetch fetch "$upstream_remote"; then
    return 1
  fi

  local_rev="$(git -C "$dir" rev-parse HEAD 2>/dev/null)" || return 1
  upstream_rev="$(git -C "$dir" rev-parse "$upstream" 2>/dev/null)" || return 1

  if [ "$local_rev" = "$upstream_rev" ]; then
    return 0
  fi

  base_rev="$(git -C "$dir" merge-base HEAD "$upstream" 2>/dev/null)" || return 1

  if [ "$local_rev" = "$base_rev" ]; then
    run_git_step "$dir" fast-forward merge --ff-only "$upstream"
    return "$?"
  fi

  if [ "$upstream_rev" = "$base_rev" ]; then
    return 0
  fi

  if rebase_with_submodule_resolution "$dir" "$upstream"; then
    return 0
  fi

  return 1
}

sync_one() {
  local dir="$1"
  local branch
  local upstream

  if [ ! -d "$dir" ]; then
    echo "warning: skipping missing path: $dir" >&2
    return 2
  fi
  if ! git -C "$dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "warning: skipping non-git path: $dir" >&2
    return 2
  fi
  if has_rebase_or_merge "$dir"; then
    echo "warning: skipping $dir: merge/rebase/cherry-pick in progress" >&2
    return 2
  fi
  branch="$(current_branch "$dir")"
  if [ -z "$branch" ]; then
    echo "warning: skipping $dir: HEAD is detached; checkout the intended branch first" >&2
    return 2
  fi
  upstream="$(current_upstream "$dir")"
  if [ -z "$upstream" ]; then
    echo "warning: skipping $dir: branch $branch has no upstream" >&2
    return 2
  fi
  if is_dirty "$dir"; then
    echo "warning: skipping $dir: working tree has uncommitted changes" >&2
    return 2
  fi

  if [ "$verbose" -eq 1 ]; then
    echo "syncing $dir [$branch -> $upstream]"
  fi
  if [ "$do_pull" -eq 1 ]; then
    if ! sync_pull "$dir" "$upstream"; then
      return 1
    fi
  fi
  if [ "$do_push" -eq 1 ]; then
    if ! run_git_step "$dir" push push; then
      return 1
    fi
  fi
  return 0
}

collect_batch() {
  local i
  local rc
  for i in "${!pids[@]}"; do
    wait "${pids[$i]}"
    rc="$?"
    if [ -s "${logs[$i]}" ]; then
      cat "${logs[$i]}"
    fi
    rm -f "${logs[$i]}"
    case "$rc" in
      0)
        ok_count=$((ok_count + 1))
        ;;
      2)
        skip_count=$((skip_count + 1))
        status=1
        ;;
      *)
        fail_count=$((fail_count + 1))
        status=1
        ;;
    esac
  done
  pids=()
  logs=()
}

pids=()
logs=()

for dir in "${targets[@]}"; do
  log="$(mktemp "${TMPDIR:-/tmp}/sync-submodules.XXXXXX")" || exit 1
  (sync_one "$dir") >"$log" 2>&1 &
  pids+=("$!")
  logs+=("$log")
  if [ "${#pids[@]}" -ge "$jobs" ]; then
    collect_batch
  fi
done

if [ "${#pids[@]}" -gt 0 ]; then
  collect_batch
fi

if [ "$status" -ne 0 ] || [ "$verbose" -eq 1 ]; then
  echo "sync-submodules: ok=$ok_count skipped=$skip_count failed=$fail_count total=${#targets[@]}"
fi
exit "$status"
