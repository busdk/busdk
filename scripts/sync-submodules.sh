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
submodule_keys=()
submodule_paths=()
submodule_branches=()
superproject_pull_done=0

usage() {
  cat <<'EOF'
Usage: scripts/sync-submodules.sh [--pull-only|--push-only] [--no-pull] [--no-push] [--no-promote-pins] [--jobs N] [--verbose] [path ...]

Synchronize the BusDK superproject and submodules in one pass.

By default this quietly fetches, fast-forwards when possible, rebases cleanly
diverged branches onto their upstreams when possible, and then pushes the
superproject plus every submodule listed in .gitmodules, running targets in a
rolling parallel worker pool. If path arguments are given, only those paths are
synchronized. Use "." to include the superproject in a focused run. Pass
--verbose to print each target and the final success summary.

When a superproject pull adds new .gitmodules entries, their submodules are
discovered and initialized serially before parallel synchronization begins.

After a pull updates submodule worktrees, changed superproject gitlinks are
staged by default so the checked-in BusDK pins can be committed explicitly.
Use --no-promote-pins to leave gitlinks unstaged.
EOF
}

load_submodule_metadata() {
  local config_key
  local path
  local key
  local branch
  local i

  submodule_keys=()
  submodule_paths=()
  submodule_branches=()

  while IFS=' ' read -r config_key path; do
    [ -n "${config_key:-}" ] || continue
    key="$config_key"
    key="${key#submodule.}"
    key="${key%.path}"
    submodule_keys+=("$key")
    submodule_paths+=("$path")
    submodule_branches+=("")
  done < <(git config --file .gitmodules --get-regexp '^submodule\..*\.path$')

  while IFS=' ' read -r config_key branch; do
    [ -n "${config_key:-}" ] || continue
    key="$config_key"
    key="${key#submodule.}"
    key="${key%.branch}"
    for i in "${!submodule_keys[@]}"; do
      if [ "${submodule_keys[$i]}" = "$key" ]; then
        submodule_branches[$i]="$branch"
        break
      fi
    done
  done < <(git config --file .gitmodules --get-regexp '^submodule\..*\.branch$' 2>/dev/null || true)
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

explicit_target_count="${#targets[@]}"

populate_default_targets() {
  local dir

  targets=()
  for dir in "${submodule_paths[@]}"; do
    targets+=("$dir")
  done
  targets+=(".")
}

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

git_dir_for() {
  git -C "$1" rev-parse --absolute-git-dir 2>/dev/null
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
  local i

  for i in "${!submodule_paths[@]}"; do
    if [ "${submodule_paths[$i]}" = "$path" ]; then
      printf '%s\n' "${submodule_keys[$i]}"
      return 0
    fi
  done

  return 1
}

submodule_branch_for_path() {
  local path="$1"
  local i

  for i in "${!submodule_paths[@]}"; do
    if [ "${submodule_paths[$i]}" = "$path" ]; then
      [ -n "${submodule_branches[$i]}" ] || return 1
      printf '%s\n' "${submodule_branches[$i]}"
      return 0
    fi
  done

  return 1
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
  local branch_rev
  local current
  local head
  local origin_rev

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

  branch="$(submodule_branch_for_path "$dir" || true)"
  [ -n "$branch" ] || return 0

  current="$(current_branch "$dir" || true)"
  head="$(git -C "$dir" rev-parse HEAD 2>/dev/null)" || return 1
  branch_rev="$(git -C "$dir" rev-parse --verify "$branch^{commit}" 2>/dev/null || true)"
  origin_rev="$(git -C "$dir" rev-parse --verify "origin/$branch^{commit}" 2>/dev/null || true)"

  if [ -n "$current" ] && [ "$current" != "$branch" ]; then
    if [ -n "$branch_rev" ] && [ "$branch_rev" = "$head" ]; then
      git -C "$dir" checkout -q "$branch" || return 1
    elif [ -n "$origin_rev" ] && [ "$origin_rev" = "$head" ]; then
      checkout_submodule_at_rev "$dir" "$head" || return 1
    elif [ -n "$branch_rev" ] &&
      git -C "$dir" merge-base --is-ancestor "$head" "$branch_rev" 2>/dev/null; then
      git -C "$dir" checkout -q "$branch" || return 1
    elif [ -n "$origin_rev" ] &&
      git -C "$dir" merge-base --is-ancestor "$head" "$origin_rev" 2>/dev/null; then
      checkout_submodule_at_rev "$dir" "$origin_rev" || return 1
    fi
  fi

  current="$(current_branch "$dir" || true)"
  if [ "$current" = "$branch" ] &&
    [ -z "$(current_upstream "$dir")" ] &&
    [ -n "$origin_rev" ]; then
    git -C "$dir" branch --set-upstream-to="origin/$branch" "$branch" >/dev/null 2>&1 || true
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
  [ -n "$(git -C "$1" status --porcelain --ignore-submodules=none 2>/dev/null)" ]
}

superproject_is_clean_or_has_only_safe_submodule_drift() {
  local path
  local head_mode
  local index_mode
  local recorded_rev
  local head_rev

  for path in "${submodule_paths[@]}"; do
    [ -d "$path" ] || continue
    is_own_worktree "$path" || continue
    if has_rebase_or_merge "$path"; then
      echo "warning: cannot pull superproject first: submodule $path has merge/rebase/cherry-pick in progress" >&2
      return 1
    fi
    if [ -n "$(git -C "$path" ls-files -u 2>/dev/null)" ]; then
      echo "warning: cannot pull superproject first: submodule $path has unresolved conflicts" >&2
      return 1
    fi
    if is_dirty "$path"; then
      echo "warning: cannot pull superproject first: submodule $path has uncommitted or untracked changes" >&2
      return 1
    fi
  done

  if ! is_dirty "."; then
    return 0
  fi

  while IFS= read -r path; do
    [ -n "$path" ] || continue
    echo "warning: cannot pull superproject first: superproject path $path is untracked" >&2
    return 1
  done < <(git ls-files --others --exclude-standard)

  if ! git diff --cached --quiet --ignore-submodules=none; then
    while IFS= read -r path; do
      [ -n "$path" ] || continue
      head_mode="$(git ls-tree HEAD -- "$path" | awk '{ print $1; exit }')"
      index_mode="$(git ls-files -s -- "$path" | awk '{ print $1; exit }')"
      if submodule_key_for_path "$path" >/dev/null; then
        if [ "$head_mode" = "160000" ] && [ "$index_mode" = "160000" ]; then
          echo "warning: cannot pull superproject first: submodule $path has staged gitlink changes" >&2
        else
          echo "warning: cannot pull superproject first: declared submodule $path has staged non-gitlink changes" >&2
        fi
      else
        echo "warning: cannot pull superproject first: superproject path $path has staged changes" >&2
      fi
      return 1
    done < <(git diff --cached --name-only --ignore-submodules=none)
    echo "warning: cannot pull superproject first: working tree has staged changes" >&2
    return 1
  fi
  if git diff --quiet --ignore-submodules=none; then
    echo "warning: cannot pull superproject first: working tree has uncommitted changes" >&2
    return 1
  fi

  while IFS= read -r path; do
    [ -n "$path" ] || continue
    head_mode="$(git ls-tree HEAD -- "$path" | awk '{ print $1; exit }')"
    index_mode="$(git ls-files -s -- "$path" | awk '{ print $1; exit }')"
    if ! submodule_key_for_path "$path" >/dev/null; then
      echo "warning: cannot pull superproject first: superproject path $path has uncommitted changes" >&2
      return 1
    fi
    if [ "$head_mode" != "160000" ] || [ "$index_mode" != "160000" ]; then
      echo "warning: cannot pull superproject first: declared submodule $path has unstaged non-gitlink changes" >&2
      return 1
    fi
    if [ ! -d "$path" ] || ! is_own_worktree "$path"; then
      echo "warning: cannot pull superproject first: submodule $path is not initialized as its own worktree" >&2
      return 1
    fi
    if has_rebase_or_merge "$path"; then
      echo "warning: cannot pull superproject first: submodule $path has merge/rebase/cherry-pick in progress" >&2
      return 1
    fi
    if [ -n "$(git -C "$path" ls-files -u 2>/dev/null)" ]; then
      echo "warning: cannot pull superproject first: submodule $path has unresolved conflicts" >&2
      return 1
    fi
    if is_dirty "$path"; then
      echo "warning: cannot pull superproject first: submodule $path has uncommitted or untracked changes" >&2
      return 1
    fi
    recorded_rev="$(git rev-parse ":$path" 2>/dev/null || true)"
    head_rev="$(git -C "$path" rev-parse HEAD 2>/dev/null || true)"
    if [ -z "$recorded_rev" ] || [ -z "$head_rev" ] ||
      ! git -C "$path" cat-file -e "$recorded_rev^{commit}" 2>/dev/null ||
      ! git -C "$path" merge-base --is-ancestor "$recorded_rev" "$head_rev" 2>/dev/null; then
      echo "warning: cannot pull superproject first: submodule $path HEAD is not safely ahead of its recorded gitlink" >&2
      return 1
    fi
  done < <(git diff --name-only --ignore-submodules=none)

  return 0
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

rebase_commit_touches_only_submodule_pins() {
  local dir="$1"
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

fetch_missing_submodule_conflict_revs() {
  local submodule_dir="$1"
  shift
  local rev
  local missing=0

  for rev in "$@"; do
    [ -n "$rev" ] || continue
    if ! git -C "$submodule_dir" cat-file -e "$rev^{commit}" 2>/dev/null; then
      missing=1
      break
    fi
  done

  [ "$missing" -eq 1 ] || return 0
  run_git_step "$submodule_dir" "fetch missing submodule conflict revisions" fetch --no-recurse-submodules origin || return 1

  for rev in "$@"; do
    [ -n "$rev" ] || continue
    git -C "$submodule_dir" cat-file -e "$rev^{commit}" 2>/dev/null || return 1
  done
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

  if git diff --cached --quiet --ignore-submodules=none; then
    return 1
  fi

  while IFS= read -r path; do
    [ -n "$path" ] || continue
    head_mode="$(git ls-tree HEAD -- "$path" | awk '{ print $1; exit }')"
    index_mode="$(git ls-files -s -- "$path" | awk '{ print $1; exit }')"
    [ "$head_mode" = "160000" ] || return 1
    [ "$index_mode" = "160000" ] || return 1
  done < <(git diff --cached --name-only --ignore-submodules=none)
}

unstaged_changes_are_only_clean_submodule_pins() {
  local path
  local head_mode
  local index_mode

  if git diff --quiet --ignore-submodules=none; then
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
  done < <(git diff --name-only --ignore-submodules=none)

  return 0
}

stage_unstaged_submodule_pins() {
  local pathspecs=()
  local path

  unstaged_changes_are_only_clean_submodule_pins || return 0
  while IFS= read -r path; do
    [ -n "$path" ] || continue
    pathspecs+=("$path")
  done < <(git diff --name-only --ignore-submodules=none)

  [ "${#pathspecs[@]}" -gt 0 ] || return 0
  git add -- "${pathspecs[@]}"
}

commit_promoted_submodule_pins() {
  [ "$do_push" -eq 1 ] || return 0
  if ! git diff --cached --quiet --ignore-submodules=none && ! cached_changes_are_only_submodule_pins; then
    return 0
  fi
  if ! git diff --quiet --ignore-submodules=none; then
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

record_rebase_submodule_checkout() {
  local dir="$1"
  local path="$2"
  local snapshot="$3"
  local head
  local branch

  if awk -F '\t' -v want="$path" '$1 == want { found = 1 } END { exit !found }' "$snapshot"; then
    return 0
  fi
  head="$(git -C "$dir/$path" rev-parse HEAD 2>/dev/null)" || return 1
  branch="$(current_branch "$dir/$path" || true)"
  printf '%s\t%s\t%s\n' "$path" "$head" "$branch" >>"$snapshot"
}

restore_rebase_submodule_checkouts() {
  local dir="$1"
  local snapshot="$2"
  local path
  local head
  local branch
  local branch_head
  local status=0

  while IFS="$(printf '\t')" read -r path head branch; do
    [ -n "$path" ] || continue
    if ! is_own_worktree "$dir/$path" || has_rebase_or_merge "$dir/$path" || is_dirty "$dir/$path"; then
      echo "warning: cannot restore rebase submodule checkout: $path is unavailable or dirty" >&2
      status=1
      continue
    fi
    branch_head=""
    if [ -n "$branch" ]; then
      branch_head="$(git -C "$dir/$path" rev-parse --verify "$branch^{commit}" 2>/dev/null || true)"
    fi
    if [ -n "$branch" ] && [ "$branch_head" = "$head" ]; then
      git -C "$dir/$path" checkout -q "$branch" || status=1
    else
      git -C "$dir/$path" checkout -q "$head" || status=1
    fi
  done <"$snapshot"

  return "$status"
}

resolve_rebase_submodule_conflicts() {
  local dir="$1"
  local original_head="$2"
  local snapshot="$3"
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
  if rebase_commit_touches_only_submodule_pins "$dir"; then
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
    if ! fetch_missing_submodule_conflict_revs "$dir/$path" "$desired_rev" "$ours_rev" "$theirs_rev"; then
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
    if [ -z "$candidate_rev" ]; then
      if git -C "$dir/$path" merge-base --is-ancestor "$ours_rev" "$theirs_rev" 2>/dev/null; then
        candidate_rev="$theirs_rev"
      elif git -C "$dir/$path" merge-base --is-ancestor "$theirs_rev" "$ours_rev" 2>/dev/null; then
        candidate_rev="$ours_rev"
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
    if ! record_rebase_submodule_checkout "$dir" "$path" "$snapshot"; then
      return 1
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
  local snapshot

  original_head="$(git -C "$dir" rev-parse HEAD 2>/dev/null)" || return 1
  log="$(mktemp "${TMPDIR:-/tmp}/sync-submodules.XXXXXX")" || return 1
  snapshot="$(mktemp "${TMPDIR:-/tmp}/sync-submodules-rebase.XXXXXX")" || {
    rm -f "$log"
    return 1
  }
  if git -C "$dir" rebase "$upstream" >"$log" 2>&1; then
    rm -f "$log" "$snapshot"
    return 0
  fi

  while has_rebase_or_merge "$dir"; do
    if ! resolve_rebase_submodule_conflicts "$dir" "$original_head" "$snapshot"; then
      echo "warning: rebase failed for $dir: git rebase $upstream" >&2
      print_log "$log"
      rm -f "$log"
      run_git_step "$dir" "rebase abort" rebase --abort >/dev/null 2>&1 || true
      restore_rebase_submodule_checkouts "$dir" "$snapshot" || true
      rm -f "$snapshot"
      return 1
    fi
    : >"$log"
    if git -C "$dir" -c core.editor=true rebase --continue >"$log" 2>&1; then
      rm -f "$log" "$snapshot"
      return 0
    fi
  done

  echo "warning: rebase failed for $dir: git rebase $upstream" >&2
  print_log "$log"
  rm -f "$log"
  run_git_step "$dir" "rebase abort" rebase --abort >/dev/null 2>&1 || true
  restore_rebase_submodule_checkouts "$dir" "$snapshot" || true
  rm -f "$snapshot"
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

targets_include_superproject() {
  local dir

  for dir in "${targets[@]}"; do
    [ "$dir" = "." ] && return 0
  done

  return 1
}

pull_superproject_before_submodules() {
  local branch
  local upstream

  [ "$do_pull" -eq 1 ] || return 0
  targets_include_superproject || return 0

  if ! git -C "." rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "warning: cannot pull superproject first: . is not a git worktree" >&2
    return 1
  fi
  if ! is_own_worktree "."; then
    echo "warning: cannot pull superproject first: . resolves to another git worktree" >&2
    return 1
  fi
  if has_rebase_or_merge "."; then
    echo "warning: cannot pull superproject first: merge/rebase/cherry-pick in progress" >&2
    return 1
  fi
  branch="$(current_branch ".")"
  if [ -z "$branch" ]; then
    echo "warning: cannot pull superproject first: HEAD is detached; checkout the intended branch first" >&2
    return 1
  fi
  upstream="$(current_upstream ".")"
  if [ -z "$upstream" ]; then
    echo "warning: cannot pull superproject first: branch $branch has no upstream" >&2
    return 1
  fi
  if ! superproject_is_clean_or_has_only_safe_submodule_drift; then
    return 1
  fi

  if [ "$verbose" -eq 1 ]; then
    echo "syncing . [$branch -> $upstream] before submodules"
  fi
  sync_pull "." "$upstream" || return 1
  superproject_pull_done=1
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
    if [ "$dir" = "." ] && [ "$superproject_pull_done" -eq 1 ]; then
      :
    else
      if ! sync_pull "$dir" "$upstream"; then
        return 1
      fi
    fi
  fi
  if [ "$do_push" -eq 1 ]; then
    if ! run_git_step "$dir" push push; then
      return 1
    fi
  fi
  return 0
}

record_result() {
  local rc
  local log

  rc="$1"
  log="$2"

  if [ -s "$log" ]; then
    cat "$log"
  fi
  rm -f "$log"
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
}

launch_target() {
  local dir="$1"
  local log

  log="$(mktemp "${TMPDIR:-/tmp}/sync-submodules.XXXXXX")" || exit 1
  (
    sync_one "$dir" >"$log" 2>&1
    printf '%s\t%s\n' "$?" "$log" >&4
  ) &
  active_count=$((active_count + 1))
}

collect_one() {
  local rc
  local log

  if ! IFS="$(printf '\t')" read -r rc log <&3; then
    echo "warning: failed to read worker completion" >&2
    status=1
    return 1
  fi
  record_result "$rc" "$log"
  active_count=$((active_count - 1))
}

drain_workers() {
  while [ "$active_count" -gt 0 ]; do
    collect_one || break
  done
}

load_submodule_metadata
if [ "$explicit_target_count" -eq 0 ]; then
  populate_default_targets
fi
order_superproject_last

if ! pull_superproject_before_submodules; then
  fail_count=1
  status=1
  if [ "$status" -ne 0 ] || [ "$verbose" -eq 1 ]; then
    echo "sync-submodules: ok=$ok_count skipped=$skip_count failed=$fail_count total=${#targets[@]}"
  fi
  exit "$status"
fi

if [ "$superproject_pull_done" -eq 1 ]; then
  load_submodule_metadata
  if [ "$explicit_target_count" -eq 0 ]; then
    populate_default_targets
  fi
  order_superproject_last
fi

scheduler_tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/sync-submodules.XXXXXX")" || exit 1
completion_fifo="$scheduler_tmp_dir/completions"
mkfifo "$completion_fifo" || exit 1
exec 3<>"$completion_fifo"
exec 4>"$completion_fifo"
active_count=0

initialize_missing_submodule_targets || true

for dir in "${targets[@]}"; do
  if [ "$dir" = "." ]; then
    syncs_superproject=1
    drain_workers
    promote_changed_submodule_pins
  fi
  launch_target "$dir"
  if [ "$active_count" -ge "$jobs" ]; then
    collect_one || break
  fi
done

drain_workers

wait >/dev/null 2>&1 || true
exec 3<&-
exec 4>&-
rm -rf "$scheduler_tmp_dir"

if [ "$syncs_superproject" -eq 0 ]; then
  promote_changed_submodule_pins
fi

if [ "$status" -ne 0 ] || [ "$verbose" -eq 1 ]; then
  echo "sync-submodules: ok=$ok_count skipped=$skip_count failed=$fail_count total=${#targets[@]}"
fi
exit "$status"
