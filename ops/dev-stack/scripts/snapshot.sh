#!/usr/bin/env sh
set -eu

SCRIPT_DIR="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)"
. "$SCRIPT_DIR/lib/common.sh"
. "$SCRIPT_DIR/lib/compose.sh"
. "$SCRIPT_DIR/lib/repos.sh"

output=${1:-"$STACK_ROOT/docs/generated/stack-snapshot-$(date -u +%Y%m%dT%H%M%SZ).txt"}
mkdir -p "$(dirname -- "$output")"

{
	printf 'snapshot_utc=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
	printf 'stack_sha=%s\n' "$(git -C "$STACK_ROOT" rev-parse HEAD)"
	if [ -n "$(git -C "$STACK_ROOT" status --porcelain)" ]; then printf 'stack_dirty=true\n'; else printf 'stack_dirty=false\n'; fi
	printf 'compose_project=%s\n' "$(get_compose_project_name)"
	printf 'docker_version=%s\n' "$(docker version --format '{{.Server.Version}}' 2>/dev/null || printf unavailable)"
	printf 'compose_version=%s\n' "$(docker compose version --short 2>/dev/null || printf unavailable)"
	printf '\n[repositories]\n'
	for repository_name in $(get_profile_repos internal); do
		repository_path="$WORKSPACE_ROOT/$(repo_field "$repository_name" folder)"
		if git -C "$repository_path" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
			printf '%s_sha=%s\n' "$repository_name" "$(git -C "$repository_path" rev-parse HEAD)"
			if [ -n "$(git -C "$repository_path" status --porcelain)" ]; then printf '%s_dirty=true\n' "$repository_name"; else printf '%s_dirty=false\n' "$repository_name"; fi
		fi
	done
	printf '\n[images]\n'
	compose internal --profile internal --profile workers config --images | sort
	printf '\n[services]\n'
	compose internal --profile internal --profile workers ps -a --format '{{.Service}} state={{.State}}'
	printf '\n[ports]\n'
	compose internal --profile internal --profile workers ps -a --format '{{.Service}} ports={{.Publishers}}'
	printf '\n[php]\n'
	image=example-dev/php-cli:8.3
	if docker image inspect "$image" >/dev/null 2>&1; then
		printf '%s_php_version=%s\n' "$image" "$(docker run --rm "$image" php -r 'printf("%d.%d.%d", PHP_MAJOR_VERSION, PHP_MINOR_VERSION, PHP_RELEASE_VERSION);')"
	fi
} > "$output"

case "$output" in
	"$STACK_ROOT"/*) relative=${output#"$STACK_ROOT"/} ;;
	*) relative=$output ;;
esac
ok "Snapshot written to $relative"
