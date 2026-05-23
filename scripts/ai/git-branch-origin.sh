#!/usr/bin/env bash
set -euo pipefail

# git-branch-origin
#
# Purpose:
#   Find the branch a local Git branch was created from.
#
# Important:
#   Git does not permanently store true branch ancestry.
#   This script is "always correct" in strict mode because it only returns
#   a branch when Git still has direct evidence. Otherwise it returns Unknown.
#
# Usage:
#   git branch-origin
#   git branch-origin <branch>
#   git branch-origin --guess <branch>
#
# Exit codes:
#   0  exact result, or heuristic result when --guess is used
#   2  unknown / not provable
#   64 usage error

mode="strict"
branch_arg=""

usage() {
  cat <<'EOF'
Usage:
  git branch-origin [--guess] [branch]

Examples:
  git branch-origin
  git branch-origin test
  git branch-origin --guess test

Modes:
  strict, default:
    Prints only exact branch-origin evidence.
    If Git cannot prove the source branch, prints Unknown and exits 2.

  --guess:
    If exact evidence is unavailable, returns a best-effort candidate.
    This can be useful, but it is not guaranteed.
EOF
}

unknown() {
  printf 'Unknown: %s\n' "$*" >&2
  exit 2
}

usage_error() {
  usage >&2
  exit 64
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --guess)
      mode="guess"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    -*)
      usage_error
      ;;
    *)
      if [[ -n "$branch_arg" ]]; then
        usage_error
      fi
      branch_arg="$1"
      shift
      ;;
  esac
done

if ! git rev-parse --git-dir >/dev/null 2>&1; then
  unknown "not inside a Git repository"
fi

if [[ -z "$branch_arg" ]]; then
  branch_arg="$(git symbolic-ref --quiet --short HEAD 2>/dev/null || true)"
fi

if [[ -z "$branch_arg" ]]; then
  unknown "no branch provided and HEAD is detached"
fi

is_hexish() {
  [[ "$1" =~ ^[0-9a-fA-F]{7,40}$ ]]
}

resolve_target_branch_ref() {
  local name="$1"

  case "$name" in
    refs/heads/*)
      if git show-ref --verify --quiet "$name"; then
        printf '%s\n' "$name"
        return 0
      fi
      return 1
      ;;
    refs/remotes/*|remotes/*)
      return 3
      ;;
  esac

  if git show-ref --verify --quiet "refs/heads/$name"; then
    printf 'refs/heads/%s\n' "$name"
    return 0
  fi

  return 1
}

resolve_branch_ref() {
  local name="$1"
  local matches=()

  case "$name" in
    refs/heads/*|refs/remotes/*)
      if git show-ref --verify --quiet "$name"; then
        printf '%s\n' "$name"
        return 0
      fi
      return 1
      ;;
    remotes/*)
      local full="refs/$name"
      if git show-ref --verify --quiet "$full"; then
        printf '%s\n' "$full"
        return 0
      fi
      return 1
      ;;
  esac

  if git show-ref --verify --quiet "refs/heads/$name"; then
    matches+=("refs/heads/$name")
  fi

  if git show-ref --verify --quiet "refs/remotes/$name"; then
    matches+=("refs/remotes/$name")
  fi

  case "${#matches[@]}" in
    1)
      printf '%s\n' "${matches[0]}"
      return 0
      ;;
    0)
      return 1
      ;;
    *)
      return 3
      ;;
  esac
}

format_ref() {
  local ref="$1"

  case "$ref" in
    refs/heads/*)
      printf '%s\n' "${ref#refs/heads/}"
      ;;
    refs/remotes/*)
      printf '%s\n' "${ref#refs/remotes/}"
      ;;
    *)
      printf '%s\n' "$ref"
      ;;
  esac
}

target_ref="$(resolve_target_branch_ref "$branch_arg" 2>/dev/null || true)"

if [[ -z "$target_ref" ]]; then
  unknown "local branch '$branch_arg' not found; remote-tracking branches do not usually have reliable local creation provenance"
fi

target_short="${target_ref#refs/heads/}"

extract_between_prefix_suffix() {
  local text="$1"
  local prefix="$2"
  local suffix="$3"

  if [[ "${text:0:${#prefix}}" != "$prefix" ]]; then
    return 1
  fi

  if [[ "${text: -${#suffix}}" != "$suffix" ]]; then
    return 1
  fi

  local middle_len=$(( ${#text} - ${#prefix} - ${#suffix} ))

  if (( middle_len <= 0 )); then
    return 1
  fi

  printf '%s\n' "${text:${#prefix}:middle_len}"
}

emit_if_exact_branch_ref() {
  local candidate="$1"
  local source_ref=""
  local status=0

  source_ref="$(resolve_branch_ref "$candidate" 2>/dev/null)" || status=$?

  if [[ "$status" -eq 0 && -n "$source_ref" ]]; then
    if [[ "$source_ref" == "$target_ref" ]]; then
      return 1
    fi

    format_ref "$source_ref"
    exit 0
  fi

  return 1
}

# 1. Handle branch copies exactly when Git recorded:
#    Branch: copied refs/heads/source to refs/heads/target
copy_record="$(
  git reflog show --format='%H%x09%gs' "$target_ref" 2>/dev/null \
    | awk -F '\t' '$2 ~ /^Branch: copied / { print; exit }'
)" || copy_record=""

if [[ -n "$copy_record" ]]; then
  copy_subject="${copy_record#*$'\t'}"

  copied_from="$(
    extract_between_prefix_suffix \
      "$copy_subject" \
      "Branch: copied " \
      " to $target_ref" 2>/dev/null || true
  )"

  if [[ -n "$copied_from" ]]; then
    emit_if_exact_branch_ref "$copied_from" || true
  fi
fi

# 2. Find the oldest branch creation entry:
#    branch: Created from main
#    branch: Created from HEAD
creation_record="$(
  git reflog show --format='%H%x09%gs' "$target_ref" 2>/dev/null \
    | awk -F '\t' '$2 ~ /^branch: Created from / { record = $0 } END { print record }'
)" || creation_record=""

if [[ -z "$creation_record" ]]; then
  unknown "branch creation entry not found in reflog for '$target_short'"
fi

base_commit="${creation_record%%$'\t'*}"
creation_subject="${creation_record#*$'\t'}"
created_from="${creation_subject#branch: Created from }"

# 3. Exact case:
#    branch: Created from main
#    branch: Created from origin/main
if [[ "$created_from" != "HEAD" ]]; then
  emit_if_exact_branch_ref "$created_from" || true

  if is_hexish "$created_from"; then
    unknown "branch was created from commit '$created_from', not from a provable branch"
  fi

  if [[ "$mode" != "guess" ]]; then
    unknown "recorded source '$created_from' is not a current unambiguous branch ref"
  fi
fi

# 4. Exact case for:
#    branch: Created from HEAD
#
#    Try HEAD reflog:
#    checkout: moving from main to test
find_head_reflog_source() {
  local base="$1"
  local branch="$2"

  git reflog show --format='%H%x09%gs' HEAD 2>/dev/null \
    | awk -F '\t' -v base="$base" -v branch="$branch" '
        $1 == base {
          subject = $2
          prefix = "checkout: moving from "
          suffix = " to " branch

          if (index(subject, prefix) == 1) {
            suffix_start = length(subject) - length(suffix) + 1

            if (suffix_start > length(prefix) && substr(subject, suffix_start) == suffix) {
              from = substr(subject, length(prefix) + 1, length(subject) - length(prefix) - length(suffix))
            }
          }
        }

        END {
          if (from != "") {
            print from
          }
        }
      '
}

if [[ "$created_from" == "HEAD" ]]; then
  from_head="$(find_head_reflog_source "$base_commit" "$target_short" || true)"

  if [[ -n "$from_head" ]]; then
    emit_if_exact_branch_ref "$from_head" || true
  fi
fi

# 5. Strict mode stops here.
#    Anything below is heuristic and therefore not always correct.
if [[ "$mode" != "guess" ]]; then
  unknown "Git does not contain enough exact evidence; use --guess only if a heuristic answer is acceptable"
fi

printf 'Warning: exact origin is unavailable; returning heuristic guess.\n' >&2

add_unique_candidate() {
  local ref="$1"

  case "$ref" in
    "$target_ref")
      return
      ;;
    refs/remotes/*/HEAD)
      return
      ;;
  esac

  local existing
  for existing in "${candidates[@]}"; do
    if [[ "$existing" == "$ref" ]]; then
      return
    fi
  done

  candidates+=("$ref")
}

candidates=()

# Stronger heuristic: branches currently pointing exactly at the creation commit.
while IFS= read -r ref; do
  [[ -n "$ref" ]] && add_unique_candidate "$ref"
done < <(
  git for-each-ref \
    --points-at "$base_commit" \
    --format='%(refname)' \
    refs/heads refs/remotes 2>/dev/null
)

# Broader heuristic: branches that contain the creation commit.
if [[ "${#candidates[@]}" -eq 0 ]]; then
  while IFS= read -r ref; do
    [[ -n "$ref" ]] && add_unique_candidate "$ref"
  done < <(
    git for-each-ref \
      --contains "$base_commit" \
      --format='%(refname)' \
      refs/heads refs/remotes 2>/dev/null
  )
fi

if [[ "${#candidates[@]}" -eq 0 ]]; then
  unknown "no branch candidate contains creation commit '$base_commit'"
fi

prefer_candidate() {
  local wanted="$1"
  local candidate

  for candidate in "${candidates[@]}"; do
    if [[ "$candidate" == "$wanted" ]]; then
      format_ref "$candidate"
      exit 0
    fi
  done
}

# Prefer repository default branch when available.
default_remote_ref="$(git symbolic-ref --quiet refs/remotes/origin/HEAD 2>/dev/null || true)"

if [[ -n "$default_remote_ref" ]]; then
  default_name="${default_remote_ref#refs/remotes/origin/}"

  prefer_candidate "refs/heads/$default_name"
  prefer_candidate "$default_remote_ref"
fi

# Prefer common long-lived branches.
preferred_names=(
  main
  master
  develop
  development
  dev
  staging
  stage
  release
  hotfix
  support
)

for name in "${preferred_names[@]}"; do
  prefer_candidate "refs/heads/$name"
  prefer_candidate "refs/remotes/origin/$name"
done

# Last heuristic fallback.
format_ref "${candidates[0]}"
