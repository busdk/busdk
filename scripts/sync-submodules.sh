#!/bin/bash
set -u

cd "$(dirname "$0")/.."

do_pull=1
do_push=1
promote_pins=1
status=0
ok_count=0
skip_count=0
fail_count=0
promoted_pin_count=0
jobs=8
verbose=0
targets=()
syncs_superproject=0

usage() {
  cat <<'EOF'
Usage: scripts/sync-submodules.sh [--pull-only|--push-only] [--no-pull] [--no-push] [--no-promote-pins] [--jobs N] [--verbose] [path ...]

Synchronize the BusDK superproject and submodules in one pass.

By default this quietly fetches, fast-forwards when possible, rebases cleanly
diverged branches onto their upstreams when possible, and then pushes the
superproject plus every submodule listed in .gitmodules, running targets in
parallel batches. If path arguments are given, only those paths are
synchronized. Use "." to include the superproject in a focused run. Pass
--verbose to print each target and the final success summary.

After a pull updates submodule worktrees, changed superproject gitlinks are
staged by default so the checked-in BusDK pins can be committed explicitly.
Use --no-promote-pins to leave gitlinks unstaged.
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
    --no-promote-pins)
      promote_pins=0
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
  while IFS= read -r dir; do
    targets+=("$dir")
  done < <(git config --file .gitmodules --get-regexp '^submodule\..*\.path$' | awk '{print $2}')
  targets+=(".")
fi

order_superproject_last() {
  local target
  local seen_superproject=0
  local ordered=()

  for target in "${targets[@]}"; do
    if [ "$target" = "." ]; then
      seen_superproject=1
      continue
    fi
    ordered+=("$target")
  done
  if [ "$seen_superproject" -eq 1 ]; then
    ordered+=(".")
  fi
  targets=("${ordered[@]}")
}

order_superproject_last

git_dir_for() {
  git -C "$1" rev-parse --git-dir 2>/dev/null
}

real_path() {
  (cd "$1" && pwd -P)
}

is_own_worktree() {
  local dir="$1"
  local top
  local dir_real
  local top_real

  top="$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null)" || return 1
  dir_real="$(real_path "$dir")" || return 1
  top_real="$(real_path "$top")" || return 1
  [ "$dir_real" = "$top_real" ]
}

submodule_key_for_path() {
  local path="$1"
  git config --file .gitmodules --get-regexp '^submodule\..*\.path$' 2>/dev/null |
    awk -v path="$path" '
      $2 == path {
        key = $1
        sub(/^submodule\./, "", key)
        sub(/\.path$/, "", key)
        print key
        exit
      }
    '
}

submodule_branch_for_path() {
  local key
  key="$(submodule_key_for_path "$1")"
  [ -n "$key" ] || return 1
  git config --file .gitmodules --get "submodule.$key.branch" 2>/dev/null
}

checkout_submodule_at_rev() {
  local dir="$1"
  local desired_rev="$2"
  local branch

  branch="$(submodule_branch_for_path "$dir" || true)"
  if [ -n "$branch" ]; then
    git -C "$dir" checkout -q -B "$branch" "$desired_rev" || return 1
    if git -C "$dir" rev-parse "origin/$branch" >/dev/null 2>&1; then
      git -C "$dir" branch --set-upstream-to="origin/$branch" "$branch" >/dev/null 2>&1 || true
    fi
    return 0
  fi

  git -C "$dir" checkout -q "$desired_rev"
}

upgrade_submodule_to_recorded_pin() {
  local dir="$1"
  local recorded_rev
  local head

  [ "$dir" != "." ] || return 0
  [ -n "$(submodule_key_for_path "$dir")" ] || return 0
  [ -d "$dir" ] || return 0
  is_own_worktree "$dir" || return 0
  has_rebase_or_merge "$dir" && return 0
  is_dirty "$dir" && return 0

  recorded_rev="$(git rev-parse ":$dir" 2>/dev/null || true)"
  [ -n "$recorded_rev" ] || return 0
  head="$(git -C "$dir" rev-parse HEAD 2>/dev/null)" || return 0
  [ "$head" != "$recorded_rev" ] || return 0
  if ! git -C "$dir" cat-file -e "$recorded_rev^{commit}" 2>/dev/null; then
    return 0
  fi

  if git -C "$dir" merge-base --is-ancestor "$head" "$recorded_rev" 2>/dev/null; then
    checkout_submodule_at_rev "$dir" "$recorded_rev"
  fi
}

ensure_submodule_target_ready() {
  local dir="$1"
  local branch
  local head

  [ "$dir" != "." ] || return 0
  [ -n "$(submodule_key_for_path "$dir")" ] || return 0

  if ! is_own_worktree "$dir"; then
    if ! run_git_step "." "submodule update --init" submodule update --init -- "$dir"; then
      return 1
    fi
  fi

  if ! is_own_worktree "$dir"; then
    echo "warning: $dir did not initialize as its own git worktree" >&2
    return 1
  fi

  if ! upgrade_submodule_to_recorded_pin "$dir"; then
    return 1
  fi

  if [ -z "$(current_branch "$dir")" ]; then
    branch="$(submodule_branch_for_path "$dir" || true)"
    if [ -n "$branch" ]; then
      head="$(git -C "$dir" rev-parse HEAD 2>/dev/null)" || return 1
      if [ "$(git -C "$dir" rev-parse "$branch" 2>/dev/null)" = "$head" ]; then
        git -C "$dir" checkout -q "$branch" || return 1
      elif [ "$(git -C "$dir" rev-parse "origin/$branch" 2>/dev/null)" = "$head" ]; then
        if git -C "$dir" rev-parse "$branch" >/dev/null 2>&1; then
          if git -C "$dir" merge-base --is-ancestor "$branch" "$head" 2>/dev/null; then
            checkout_submodule_at_rev "$dir" "$head" || return 1
          elif git -C "$dir" merge-base --is-ancestor "$head" "$branch" 2>/dev/null; then
            git -C "$dir" checkout -q "$branch" || return 1
          else
            return 1
          fi
        else
          git -C "$dir" checkout -q -b "$branch" --track "origin/$branch" || return 1
        fi
      elif git -C "$dir" rev-parse "$branch" >/dev/null 2>&1 &&
        git -C "$dir" merge-base --is-ancestor "$branch" "$head" 2>/dev/null; then
        checkout_submodule_at_rev "$dir" "$head" || return 1
      elif git -C "$dir" rev-parse "origin/$branch" >/dev/null 2>&1; then
        if git -C "$dir" merge-base --is-ancestor "origin/$branch" "$head" 2>/dev/null; then
          checkout_submodule_at_rev "$dir" "$head" || return 1
        elif git -C "$dir" merge-base --is-ancestor "$head" "origin/$branch" 2>/dev/null; then
          checkout_submodule_at_rev "$dir" "origin/$branch" || return 1
        fi
      fi
    fi
  fi
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

initialize_missing_submodule_targets() {
  local dir
  local init_targets=()

  for dir in "${targets[@]}"; do
    [ "$dir" != "." ] || continue
    [ -n "$(submodule_key_for_path "$dir")" ] || continue
    if [ ! -d "$dir" ] || ! is_own_worktree "$dir"; then
      init_targets+=("$dir")
    fi
  done

  [ "${#init_targets[@]}" -gt 0 ] || return 0
  run_git_step "." "submodule update --init" submodule update --init -- "${init_targets[@]}"
}

submodule_conflict_paths() {
  local dir="$1"
  git -C "$dir" ls-files -u | awk '$1 == "160000" { print $4 }' | sort -u
}

has_non_submodule_conflicts() {
  local dir="$1"
  [ -n "$(git -C "$dir" ls-files -u | awk '$1 != "160000" { print; exit }')" ]
}

path_list_contains() {
  local needle="$1"
  local haystack="$2"
  local path

  while IFS= read -r path; do
    [ "$path" = "$needle" ] && return 0
  done <<<"$haystack"
  return 1
}

rebase_commit_touches_only_paths() {
  local dir="$1"
  local paths="$2"
  local commit
  local changed_path
  local changed_paths
  local mode

  commit="$(git -C "$dir" rev-parse -q --verify REBASE_HEAD 2>/dev/null || true)"
  [ -n "$commit" ] || return 1

  changed_paths="$(git -C "$dir" diff-tree --no-commit-id --name-only -r "$commit" 2>/dev/null)" || return 1
  [ -n "$changed_paths" ] || return 1

  while IFS= read -r changed_path; do
    [ -n "$changed_path" ] || continue
    path_list_contains "$changed_path" "$paths" || return 1
    mode="$(git -C "$dir" ls-tree "$commit" -- "$changed_path" | awk '{ print $1; exit }')"
    [ "$mode" = "160000" ] || return 1
  done <<<"$changed_paths"
}

submodule_head_contains_any_known_rev() {
  local submodule_dir="$1"
  local head_rev="$2"
  shift 2
  local rev

  for rev in "$@"; do
    [ -n "$rev" ] || continue
    if git -C "$submodule_dir" cat-file -e "$rev^{commit}" 2>/dev/null &&
      git -C "$submodule_dir" merge-base --is-ancestor "$rev" "$head_rev" 2>/dev/null; then
      return 0
    fi
  done

  return 1
}

promote_changed_submodule_pins() {
  local dir
  local head_rev
  local index_rev
  local pathspecs=()

  [ "$do_pull" -eq 1 ] || return 0
  [ "$promote_pins" -eq 1 ] || return 0

  for dir in "${targets[@]}"; do
    [ "$dir" != "." ] || continue
    [ -n "$(submodule_key_for_path "$dir")" ] || continue
    [ -d "$dir" ] || continue
    if ! is_own_worktree "$dir"; then
      continue
    fi
    if has_rebase_or_merge "$dir" || is_dirty "$dir"; then
      continue
    fi
    head_rev="$(git -C "$dir" rev-parse HEAD 2>/dev/null)" || continue
    index_rev="$(git rev-parse ":$dir" 2>/dev/null || true)"
    [ -n "$index_rev" ] || continue
    [ "$head_rev" != "$index_rev" ] || continue
    if git -C "$dir" merge-base --is-ancestor "$head_rev" "$index_rev" 2>/dev/null; then
      checkout_submodule_at_rev "$dir" "$index_rev" || continue
      continue
    fi
    git -C "$dir" merge-base --is-ancestor "$index_rev" "$head_rev" 2>/dev/null || continue
    pathspecs+=("$dir")
  done

  [ "${#pathspecs[@]}" -gt 0 ] || return 0

  if git add -- "${pathspecs[@]}"; then
    promoted_pin_count="${#pathspecs[@]}"
    printf 'sync-submodules: staged %s submodule pin(s); commit the superproject to record them.\n' "$promoted_pin_count"
    return 0
  fi

  echo "warning: failed to stage changed submodule pins" >&2
  fail_count=$((fail_count + 1))
  status=1
  return 1
}

cached_changes_are_only_submodule_pins() {
  local path
  local head_mode
  local index_mode

  if git diff --cached --quiet; then
    return 1
  fi

  while IFS= read -r path; do
    [ -n "$path" ] || continue
    head_mode="$(git ls-tree HEAD -- "$path" | awk '{ print $1; exit }')"
    index_mode="$(git ls-files -s -- "$path" | awk '{ print $1; exit }')"
    [ "$head_mode" = "160000" ] || return 1
    [ "$index_mode" = "160000" ] || return 1
  done < <(git diff --cached --name-only)
}

unstaged_changes_are_only_clean_submodule_pins() {
  local path
  local head_mode
  local index_mode

  if git diff --quiet; then
    return 1
  fi

  while IFS= read -r path; do
    [ -n "$path" ] || continue
    head_mode="$(git ls-tree HEAD -- "$path" | awk '{ print $1; exit }')"
    index_mode="$(git ls-files -s -- "$path" | awk '{ print $1; exit }')"
    [ "$head_mode" = "160000" ] || return 1
    [ "$index_mode" = "160000" ] || return 1
    [ -n "$(submodule_key_for_path "$path")" ] || return 1
    [ -d "$path" ] || return 1
    is_own_worktree "$path" || return 1
    has_rebase_or_merge "$path" && return 1
    is_dirty "$path" && return 1
  done < <(git diff --name-only)

  return 0
}

stage_unstaged_submodule_pins() {
  local pathspecs=()
  local path

  unstaged_changes_are_only_clean_submodule_pins || return 0
  while IFS= read -r path; do
    [ -n "$path" ] || continue
    pathspecs+=("$path")
  done < <(git diff --name-only)

  [ "${#pathspecs[@]}" -gt 0 ] || return 0
  git add -- "${pathspecs[@]}"
}

commit_promoted_submodule_pins() {
  [ "$do_push" -eq 1 ] || return 0
  if ! git diff --cached --quiet && ! cached_changes_are_only_submodule_pins; then
    return 0
  fi
  if ! git diff --quiet; then
    unstaged_changes_are_only_clean_submodule_pins || return 0
    stage_unstaged_submodule_pins || return 0
  fi
  cached_changes_are_only_submodule_pins || return 0
  run_git_step "." "commit promoted submodule pins" commit -m "BusDK: sync submodule pins"
}

checkout_submodule_resolution() {
  local dir="$1"
  local path="$2"
  local desired_rev="$3"
  local branch
  local candidate

  branch="$(current_branch "$dir/$path")"
  if [ -n "$branch" ] && [ "$(git -C "$dir/$path" rev-parse "$branch" 2>/dev/null)" = "$desired_rev" ]; then
    git -C "$dir/$path" checkout -q "$branch"
    return "$?"
  fi

  while IFS= read -r candidate; do
    [ -n "$candidate" ] || continue
    if [ "$(git -C "$dir/$path" rev-parse "$candidate" 2>/dev/null)" = "$desired_rev" ]; then
      git -C "$dir/$path" checkout -q "$candidate"
      return "$?"
    fi
  done < <(git -C "$dir/$path" for-each-ref --format='%(refname:short)' refs/heads)

  git -C "$dir/$path" checkout -q "$desired_rev"
}

resolve_rebase_submodule_conflicts() {
  local dir="$1"
  local original_head="$2"
  local path
  local desired_rev
  local ours_rev
  local theirs_rev
  local head_rev
  local candidate_rev
  local allow_branch_head_resolution
  local paths
  local pin_only_rebase_conflict

  paths="$(submodule_conflict_paths "$dir")"
  if [ -z "$paths" ] || has_non_submodule_conflicts "$dir"; then
    return 1
  fi
  if rebase_commit_touches_only_paths "$dir" "$paths"; then
    pin_only_rebase_conflict=1
  else
    pin_only_rebase_conflict=0
  fi

  while IFS= read -r path; do
    [ -n "$path" ] || continue
    desired_rev="$(git -C "$dir" rev-parse "$original_head:$path" 2>/dev/null)" || return 1
    ours_rev="$(git -C "$dir" ls-files -u -- "$path" | awk '$3 == 2 { print $2; exit }')"
    theirs_rev="$(git -C "$dir" ls-files -u -- "$path" | awk '$3 == 3 { print $2; exit }')"
    if [ -z "$desired_rev" ] || [ -z "$ours_rev" ] || [ -z "$theirs_rev" ]; then
      return 1
    fi
    candidate_rev=""
    if [ -d "$dir/$path" ] &&
      is_own_worktree "$dir/$path" &&
      ! has_rebase_or_merge "$dir/$path" &&
      ! is_dirty "$dir/$path"; then
      head_rev="$(git -C "$dir/$path" rev-parse HEAD 2>/dev/null)" || head_rev=""
      if [ -n "$head_rev" ] &&
        git -C "$dir/$path" cat-file -e "$ours_rev^{commit}" 2>/dev/null &&
        git -C "$dir/$path" cat-file -e "$theirs_rev^{commit}" 2>/dev/null &&
        git -C "$dir/$path" merge-base --is-ancestor "$ours_rev" "$head_rev" 2>/dev/null &&
        git -C "$dir/$path" merge-base --is-ancestor "$theirs_rev" "$head_rev" 2>/dev/null; then
        candidate_rev="$head_rev"
      fi
    fi
    allow_branch_head_resolution=0
    if [ -z "$candidate_rev" ] &&
      [ "$pin_only_rebase_conflict" -eq 1 ] &&
      [ -d "$dir/$path" ] &&
      is_own_worktree "$dir/$path" &&
      ! has_rebase_or_merge "$dir/$path" &&
      ! is_dirty "$dir/$path"; then
      head_rev="$(git -C "$dir/$path" rev-parse HEAD 2>/dev/null)" || head_rev=""
      if [ -n "$head_rev" ] &&
        submodule_head_contains_any_known_rev "$dir/$path" "$head_rev" "$desired_rev" "$ours_rev" "$theirs_rev"; then
        candidate_rev="$head_rev"
        allow_branch_head_resolution=1
      fi
    fi
    if [ -z "$candidate_rev" ]; then
      candidate_rev="$desired_rev"
    fi
    if ! git -C "$dir/$path" cat-file -e "$candidate_rev^{commit}" 2>/dev/null; then
      return 1
    fi
    if [ "$allow_branch_head_resolution" -eq 0 ]; then
      if ! git -C "$dir/$path" merge-base --is-ancestor "$ours_rev" "$candidate_rev" 2>/dev/null; then
        return 1
      fi
      if ! git -C "$dir/$path" merge-base --is-ancestor "$theirs_rev" "$candidate_rev" 2>/dev/null; then
        return 1
      fi
    fi
    if ! checkout_submodule_resolution "$dir" "$path" "$candidate_rev"; then
      return 1
    fi
    if ! git -C "$dir" update-index --cacheinfo 160000 "$candidate_rev" "$path"; then
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

  if ! run_git_step "$dir" fetch fetch --no-recurse-submodules "$upstream_remote"; then
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
    if [ "$dir" != "." ] && [ -n "$(submodule_key_for_path "$dir")" ]; then
      if ! run_git_step "." "submodule update --init" submodule update --init -- "$dir"; then
        return 1
      fi
    fi
  fi
  if [ ! -d "$dir" ]; then
    echo "warning: skipping missing path: $dir" >&2
    return 2
  fi
  if ! ensure_submodule_target_ready "$dir"; then
    return 1
  fi
  if ! git -C "$dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "warning: skipping non-git path: $dir" >&2
    return 2
  fi
  if ! is_own_worktree "$dir"; then
    echo "warning: skipping $dir: path resolves to another git worktree" >&2
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
    if [ "$dir" = "." ] && commit_promoted_submodule_pins && ! is_dirty "$dir"; then
      :
    else
    echo "warning: skipping $dir: working tree has uncommitted changes" >&2
    return 2
    fi
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

initialize_missing_submodule_targets || true

for dir in "${targets[@]}"; do
  if [ "$dir" = "." ]; then
    syncs_superproject=1
    if [ "${#pids[@]}" -gt 0 ]; then
      collect_batch
    fi
    promote_changed_submodule_pins
  fi
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

if [ "$syncs_superproject" -eq 0 ]; then
  promote_changed_submodule_pins
fi

if [ "$status" -ne 0 ] || [ "$verbose" -eq 1 ]; then
  echo "sync-submodules: ok=$ok_count skipped=$skip_count failed=$fail_count total=${#targets[@]}"
fi
exit "$status"
