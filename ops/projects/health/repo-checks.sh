#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/../workspace/config.sh"

REPO_KEY="${1:-}"
PATTERNS=()

case "$REPO_KEY" in
  backend)
    REPO_NAME="backend"
    REPO_DIR="$WS_BACKEND_APP_DIR"
    PATTERNS=("DEV-*" "release-*")
    ;;
  ui-components)
    REPO_NAME="ui-components"
    REPO_DIR="$WS_UI_COMPONENTS_DIR"
    PATTERNS=("DEV-*" "lib-2.0.*")
    ;;
  payments)
    REPO_NAME="payments"
    REPO_DIR="$WS_PAYMENTS_DIR"
    PATTERNS=("DEV-*")
    ;;
  web-frontend)
    REPO_NAME="web-frontend"
    REPO_DIR="$WS_FRONTEND_APP_DIR"
    PATTERNS=("DEV-*" "frontend-*")
    ;;
  integration)
    REPO_NAME="integration"
    REPO_DIR="$WS_INTEGRATION_APP_DIR"
    PATTERNS=("DEV-*" "phase3.*" "release-*")
    ;;
  *)
    echo "Usage: $0 {backend|ui-components|payments|web-frontend|integration}"
    exit 1
    ;;
esac

if [[ ! -d "$REPO_DIR/.git" ]]; then
  echo "[$REPO_NAME] repository not found at $REPO_DIR"
  exit 1
fi

version_sort_branches() {
  if [[ $# -eq 0 ]]; then
    return 0
  fi

  printf '%s\n' "$@" | sort -V
}

latest_branch() {
  if [[ $# -eq 0 ]]; then
    return 0
  fi

  version_sort_branches "$@" | tail -n 1
}

branch_is_present() {
  local target="$1"
  shift || true
  local branch

  for branch in "$@"; do
    if [[ "$branch" == "$target" ]]; then
      return 0
    fi
  done

  return 1
}

print_up_to_five_newest_last() {
  local -a branches=("$@")
  local -a recent=()
  local i

  # Input is expected newest-first. Keep at most the 5 most-recent items.
  for branch in "${branches[@]}"; do
    recent+=("$branch")
    (( ${#recent[@]} >= 5 )) && break
  done

  # Print oldest->newest inside this recent subset so newest is the last item.
  for (( i=${#recent[@]}-1; i>=0; i-- )); do
    printf '%s\n' "${recent[$i]}"
  done
}

print_repo_log_references() {
  local today="$(date +%F)"
  local log_path=""
  local -a log_paths=()

  case "$REPO_NAME" in
    backend)
      log_paths+=("$WS_BACKEND_APP_DIR/storage/logs/laravel.log")
      log_paths+=("$WS_BACKEND_LOG_FILE")
      ;;
    web-frontend)
      log_paths+=("$WS_FRONTEND_LOG_FILE")
      ;;
    integration)
      log_paths+=("$WS_INTEGRATION_APP_DIR/storage/logs/laravel-${today}.log")
      log_paths+=("$WS_INTEGRATION_APP_DIR/storage/logs/laravel.log")
      ;;
  esac

  if [[ ${#log_paths[@]} -gt 0 ]]; then
    echo "[$REPO_NAME] log file references:"
    for log_path in "${log_paths[@]}"; do
      if [[ -f "$log_path" ]]; then
        echo "$log_path"
      else
        echo "$log_path (missing)"
      fi
    done
    return 0
  fi

  echo "[$REPO_NAME] no direct log file reference configured for this repo"
  echo "[$REPO_NAME] suggestion: run log-workspace in another terminal window to inspect shared logs"
}

cd "$REPO_DIR"

echo "[$REPO_NAME] git fetch --prune origin"
git fetch --prune origin

echo ""
echo "[$REPO_NAME] git status --short --branch"
git status --short --branch

remote_branch_rows=()
remote_branches=()
local_branches=()
new_remote=()
pattern_label="${PATTERNS[*]}"

for pattern in "${PATTERNS[@]}"; do
  while IFS= read -r row; do
    [[ -n "$row" ]] && remote_branch_rows+=("$row")
  done < <(git for-each-ref --sort=-committerdate --format='%(committerdate:unix)|%(refname:strip=3)' "refs/remotes/origin/$pattern")
done

if [[ ${#remote_branch_rows[@]} -gt 0 ]]; then
  seen_remote_branches=""
  for row in "${remote_branch_rows[@]}"; do
    branch="${row#*|}"
    [[ -n "$branch" ]] || continue

    case "|$seen_remote_branches|" in
      *"|$branch|"*)
        ;;
      *)
        remote_branches+=("$branch")
        seen_remote_branches+="|$branch"
        ;;
    esac
  done
fi

if [[ ${#remote_branches[@]} -gt 0 ]]; then
  remote_unique=()
  while IFS= read -r branch; do
    [[ -n "$branch" ]] && remote_unique+=("$branch")
  done < <(printf '%s\n' "${remote_branches[@]}" | awk 'NF && !seen[$0]++')
  remote_branches=("${remote_unique[@]}")
fi

for pattern in "${PATTERNS[@]}"; do
  while IFS= read -r branch; do
    [[ -n "$branch" ]] && local_branches+=("$branch")
  done < <(git for-each-ref --format='%(refname:strip=2)' "refs/heads/$pattern")
done

if [[ ${#local_branches[@]} -gt 0 ]]; then
  local_unique=()
  while IFS= read -r branch; do
    [[ -n "$branch" ]] && local_unique+=("$branch")
  done < <(printf '%s\n' "${local_branches[@]}" | awk 'NF && !seen[$0]++')
  local_branches=("${local_unique[@]}")
fi

for branch in "${remote_branches[@]}"; do
  if ! branch_is_present "$branch" "${local_branches[@]}"; then
    new_remote+=("$branch")
  fi
done

echo ""
print_repo_log_references

echo ""
if [[ ${#new_remote[@]} -gt 0 ]]; then
  echo "[$REPO_NAME] new origin branches not available locally (up to 5 most recent):"
  print_up_to_five_newest_last "${new_remote[@]}"
else
  echo "[$REPO_NAME] no new origin branches matching ${pattern_label}"
fi

echo ""
if [[ ${#remote_branches[@]} -gt 0 ]]; then
  latest_remote="$(latest_branch "${remote_branches[@]}")"
  current_branch="$(git branch --show-current)"
  echo "[$REPO_NAME] latest matching origin branch: $latest_remote"
  if [[ "$current_branch" != "$latest_remote" ]]; then
    echo "[$REPO_NAME] suggestion: git switch $latest_remote"
  else
    echo "[$REPO_NAME] suggestion: stay on $current_branch"
  fi
else
  echo "[$REPO_NAME] no origin branches matching ${pattern_label}"
fi
