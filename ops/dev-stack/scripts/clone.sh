#!/usr/bin/env sh
set -eu
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
. "$SCRIPT_DIR/lib/common.sh"
. "$SCRIPT_DIR/lib/repos.sh"

profile=${1:-}
[ -n "$profile" ] || usage_error "Usage: clone.sh <internal> [--update] [--branch <name>]"
assert_profile "$profile"
shift

update=false
branch_override=
while [ "$#" -gt 0 ]; do
	case "$1" in
		--update) update=true ;;
		--branch)
			shift
			require_value "--branch" "${1:-}"
			branch_override=$1
			;;
		-h|--help)
			printf 'Usage: clone.sh <internal> [--update] [--branch <name>]\n'
			exit 0
			;;
		*) usage_error "Unknown option: $1" ;;
	esac
	shift
done

step "Clone - profile: $profile"
for repository_name in $(get_profile_repos "$profile"); do
	folder=$(repo_field "$repository_name" folder)
	url=$(repo_field "$repository_name" url)
	branch=$(repo_field "$repository_name" branch)
	[ -n "$folder" ] && [ -n "$url" ] && [ -n "$branch" ] || die "Invalid repository configuration for '$repository_name'"
	[ -z "$branch_override" ] || branch=$branch_override
	target="$WORKSPACE_ROOT/$folder"

	info "[$repository_name] target: $target"
	if [ ! -e "$target" ]; then
		info "[$repository_name] cloning from $url @ $branch"
		git clone --branch "$branch" "$url" "$target" || die "[$repository_name] clone failed"
		ok "[$repository_name] cloned"
		continue
	fi
	if ! git -C "$target" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
		die "[$repository_name] $target exists but is not a Git checkout - remove or rename it, then rerun clone.sh"
	fi

	current_branch=$(git -C "$target" rev-parse --abbrev-ref HEAD 2>/dev/null || true)
	if [ "$current_branch" = "$branch" ]; then
		ok "[$repository_name] exists on correct branch '$branch'"
	else
		warn "[$repository_name] is on branch '$current_branch', expected '$branch'"
	fi
	if [ "$update" = true ]; then
		info "[$repository_name] fetching (--update)"
		if git -C "$target" fetch --quiet; then
			ok "[$repository_name] fetch complete"
		else
			warn "[$repository_name] fetch failed (ignored)"
		fi
	fi
done

printf '\n'
ok "Clone complete for profile '$profile'"
