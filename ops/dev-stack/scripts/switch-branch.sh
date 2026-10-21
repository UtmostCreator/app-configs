#!/usr/bin/env sh
set -eu
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
. "$SCRIPT_DIR/lib/common.sh"
. "$SCRIPT_DIR/lib/repos.sh"

repository_name=${1:-}
[ -n "$repository_name" ] || usage_error "Usage: switch-branch.sh <repository> [--to-configured|--branch <name>]"
shift

folder=$(repo_field "$repository_name" folder)
configured_branch=$(repo_field "$repository_name" branch)
[ -n "$folder" ] && [ -n "$configured_branch" ] || usage_error "Unknown repository '$repository_name'"

target_branch=$configured_branch
while [ "$#" -gt 0 ]; do
	case "$1" in
		--to-configured) ;;
		--branch)
			shift
			require_value "--branch" "${1:-}"
			target_branch=$1
			;;
		-h|--help)
			printf 'Usage: switch-branch.sh <repository> [--to-configured|--branch <name>]\n'
			exit 0
			;;
		*) usage_error "Unknown option: $1" ;;
	esac
	shift
done

git check-ref-format --branch "$target_branch" >/dev/null 2>&1 || usage_error "Invalid branch name '$target_branch'"
repository_path="$WORKSPACE_ROOT/$folder"
git -C "$repository_path" rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "[$repository_name] is not a Git checkout: $repository_path"

if [ -n "$(git -C "$repository_path" status --porcelain --untracked-files=all)" ]; then
	die "[$repository_name] has local changes; commit, stash, or remove them before switching branches"
fi

current_branch=$(git -C "$repository_path" symbolic-ref --short -q HEAD 2>/dev/null || true)
if [ -z "$current_branch" ]; then
	current_branch="detached@$(git -C "$repository_path" rev-parse --short HEAD)"
fi

step "Switch branch - repository: $repository_name  target: $target_branch"
info "[$repository_name] fetching origin..."
git -C "$repository_path" fetch --quiet origin || die "[$repository_name] fetch failed"

if git -C "$repository_path" show-ref --verify --quiet "refs/heads/$target_branch"; then
	git -C "$repository_path" switch "$target_branch" || die "[$repository_name] could not switch to '$target_branch'"
else
	git -C "$repository_path" show-ref --verify --quiet "refs/remotes/origin/$target_branch" || die "[$repository_name] branch '$target_branch' was not found on origin"
	git -C "$repository_path" switch --track --create "$target_branch" "origin/$target_branch" || die "[$repository_name] could not create tracking branch '$target_branch'"
fi

ok "[$repository_name] switched from '$current_branch' to '$target_branch'"
