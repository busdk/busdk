#!/usr/bin/env sh
set -eu

script_dir="$(CDPATH= cd "$(dirname "$0")" && pwd)"
script_path="$script_dir/$(basename "$0")"
publish_jobs="${PUBLISH_JOBS:-8}"

usage() {
  cat <<'EOF'
Usage: scripts/publish.sh [--jobs N]

Publish BusDK develop to main, tag the superproject and submodules, and push
the release refs. Submodule checks, promotion, and tag pushes run in parallel
batches. Set PUBLISH_JOBS or pass --jobs to tune parallelism.
EOF
}

case "${1:-}" in
  -h|--help)
    usage
    exit 0
    ;;
  --jobs)
    if [ -z "${2:-}" ]; then
      echo "error: --jobs requires a positive integer" >&2
      exit 2
    fi
    publish_jobs="$2"
    shift 2
    ;;
esac

case "$publish_jobs" in
  ''|*[!0-9]*|0)
    echo "error: publish parallelism must be a positive integer: $publish_jobs" >&2
    exit 2
    ;;
esac

promote_ref_to_main() {
  repo_label=$1
  source_label=$2
  source_ref=$3
  original_branch="$(git symbolic-ref -q --short HEAD || true)"
  original_head="$(git rev-parse --verify HEAD)"
  source_commit="$(git rev-parse --verify "${source_ref}^{commit}")"

  restore_original_checkout() {
    if [ -n "$original_branch" ]; then
      git checkout -q "$original_branch"
    else
      git checkout -q "$original_head"
    fi
  }

  if ! git rev-parse --verify refs/heads/main >/dev/null; then
    if git rev-parse --verify refs/remotes/origin/main >/dev/null; then
      git branch --track main origin/main >/dev/null
    else
      echo "$repo_label: missing local main branch and origin/main; aborting" >&2
      exit 1
    fi
  fi

  main_before="$(git rev-parse refs/heads/main)"
  origin_main_ref=""
  if git rev-parse --verify refs/remotes/origin/main >/dev/null; then
    origin_main_ref="$(git rev-parse refs/remotes/origin/main)"
  fi

  git checkout -q main

  if git merge-base --is-ancestor HEAD "$source_commit"; then
    git rebase "$source_commit"
  elif git merge-base --is-ancestor "$source_commit" HEAD; then
    echo "$repo_label: main already contains $source_label at $source_commit"
  elif [ -n "$origin_main_ref" ] && [ "$main_before" != "$origin_main_ref" ] && git merge-base --is-ancestor "$origin_main_ref" "$source_commit"; then
    git rebase "$source_commit"
  else
    echo "$repo_label: main and $source_label have diverged; refusing to rewrite published main" >&2
    echo "$repo_label: merge or rebase main manually, then rerun publish" >&2
    restore_original_checkout
    exit 1
  fi

  main_after="$(git rev-parse HEAD)"
  if [ "$main_after" = "$main_before" ]; then
    echo "$repo_label: main unchanged at $main_after"
  else
    echo "$repo_label: moved main from $main_before to $main_after"
  fi
  restore_original_checkout
  git push origin main
}

if [ "${1:-}" = "--promote-current-repo" ]; then
  promote_ref_to_main "${2:-$(basename "$PWD")}" "current HEAD" HEAD
  exit 0
fi

submodule_list_file() {
  list_file=$1
  git submodule foreach --recursive --quiet '
    printf "%s	%s\n" "$name" "$PWD"
  ' >"$list_file"
}

submodule_task() {
  task=$1
  submodule_name=$2
  submodule_path=$3

  case "$task" in
    clean)
      cd "$submodule_path"
      if [ -n "$(git status --porcelain --untracked-files=normal)" ]; then
        echo "$submodule_name has uncommitted changes; aborting" >&2
        git status --short --untracked-files=normal >&2
        exit 1
      fi
      ;;
    promote)
      cd "$submodule_path"
      "$script_path" --promote-current-repo "$submodule_name"
      ;;
    tag)
      cd "$submodule_path"
      TAG="$next_tag"
      HEAD_SHA="$(git rev-parse HEAD)"
      if git rev-parse -q --verify "refs/tags/${TAG}" >/dev/null; then
        TAG_SHA="$(git rev-parse "refs/tags/${TAG}")"
        if [ "$TAG_SHA" = "$HEAD_SHA" ]; then
          echo "$submodule_name: tag ${TAG} already exists at ${HEAD_SHA}"
          exit 0
        fi
        echo "$submodule_name: tag ${TAG} exists at ${TAG_SHA}, expected ${HEAD_SHA}" >&2
        exit 1
      fi
      git tag "${TAG}"
      git push origin "refs/tags/${TAG}"
      echo "$submodule_name: pushed tag ${TAG} at ${HEAD_SHA}"
      ;;
    *)
      echo "unknown submodule task: $task" >&2
      exit 2
      ;;
  esac
}

wait_publish_batch() {
  batch_status=0
  while IFS='	' read -r pid output_file label; do
    if wait "$pid"; then
      task_status=0
    else
      task_status=1
      batch_status=1
    fi
    if [ -s "$output_file" ]; then
      cat "$output_file"
    fi
    rm -f "$output_file"
    if [ "$task_status" -ne 0 ]; then
      echo "publish failed while processing submodule: $label" >&2
    fi
  done <"$batch_file"
  : >"$batch_file"
  batch_count=0
  return "$batch_status"
}

run_submodules_parallel() {
  task=$1
  tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/busdk-publish.XXXXXX")"
  list_file="$tmp_dir/submodules.tsv"
  batch_file="$tmp_dir/batch.tsv"
  batch_count=0
  index=0

  trap 'rm -rf "$tmp_dir"' INT TERM EXIT
  submodule_list_file "$list_file"
  : >"$batch_file"

  while IFS='	' read -r submodule_name submodule_path; do
    output_file="$tmp_dir/out-$index.log"
    (
      submodule_task "$task" "$submodule_name" "$submodule_path"
    ) >"$output_file" 2>&1 &
    printf "%s	%s	%s\n" "$!" "$output_file" "$submodule_name" >>"$batch_file"
    batch_count=$((batch_count + 1))
    index=$((index + 1))
    if [ "$batch_count" -ge "$publish_jobs" ]; then
      wait_publish_batch || exit 1
    fi
  done <"$list_file"

  if [ "$batch_count" -gt 0 ]; then
    wait_publish_batch || exit 1
  fi

  rm -rf "$tmp_dir"
  trap - INT TERM EXIT
}

if [ -n "$(git status --porcelain --untracked-files=normal)" ]; then
  echo "working tree has uncommitted changes; aborting" >&2
  git status --short --untracked-files=normal >&2
  exit 1
fi

if [ "$(git symbolic-ref -q --short HEAD || true)" != "develop" ]; then
  echo "publish must run from the superproject develop branch; aborting" >&2
  exit 1
fi

run_submodules_parallel clean

make publish-preflight

if [ -n "$(git status --porcelain --untracked-files=normal)" ]; then
  echo "working tree changed after tests; aborting" >&2
  git status --short --untracked-files=normal >&2
  exit 1
fi

git submodule sync --recursive
git submodule update --init --recursive

run_submodules_parallel clean

run_submodules_parallel promote
promote_ref_to_main "superproject" "develop" refs/heads/develop

latest_tag="$(git tag --list 'v*' --sort=-v:refname | { read -r first || true; printf '%s' "$first"; })"

if [ -z "$latest_tag" ]; then
  next_tag="v0.0.1"
else
  case "$latest_tag" in
    v[0-9]*.[0-9]*.[0-9]*)
      base="${latest_tag#v}"
      old_ifs="$IFS"
      IFS=.
      set -- $base
      IFS="$old_ifs"
      major="${1:-}"
      minor="${2:-}"
      patch="${3:-}"
      if [ -z "$major" ] || [ -z "$minor" ] || [ -z "$patch" ]; then
        echo "unsupported tag format: $latest_tag" >&2
        exit 1
      fi
      next_tag="v${major}.${minor}.$((patch + 1))"
      ;;
    *)
      echo "unsupported tag format: $latest_tag" >&2
      exit 1
      ;;
  esac
fi

if git rev-parse -q --verify "refs/tags/${next_tag}" >/dev/null; then
  echo "tag ${next_tag} already exists; aborting" >&2
  exit 1
fi

git tag "$next_tag"

run_submodules_parallel tag

git push origin "$next_tag"
echo "Created and pushed tag $next_tag (including submodules)"
