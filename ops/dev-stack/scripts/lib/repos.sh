#!/usr/bin/env sh

get_profile_repos() {
    profile=$1
    awk -v profile="$profile" '
        /^profiles:/ { in_profiles = 1; next }
        in_profiles && /^repositories:/ { exit }
        in_profiles && $0 ~ "^  " profile ":" { in_profile = 1; next }
        in_profile && /^[[:space:]]+repos:/ { in_repos = 1; next }
        in_repos && /^[[:space:]]+-[[:space:]]+/ {
            sub(/^[[:space:]]+-[[:space:]]+/, "")
            print
            next
        }
        in_repos { exit }
    ' "$REPOS_YAML"
}

get_repo_config() {
    repository_name=$1
    awk -v repository_name="$repository_name" '
        /^repositories:/ { in_repositories = 1; next }
        in_repositories && $0 ~ "^  " repository_name ":" { in_repository = 1; next }
        in_repository && /^  [^[:space:]]/ { exit }
        in_repository && /^[[:space:]]+folder:/ { sub(/^[^:]*:[[:space:]]*/, ""); print "folder=" $0 }
        in_repository && /^[[:space:]]+url:/ { sub(/^[^:]*:[[:space:]]*/, ""); print "url=" $0 }
        in_repository && /^[[:space:]]+branch:/ { sub(/^[^:]*:[[:space:]]*/, ""); print "branch=" $0 }
    ' "$REPOS_YAML"
}

# repo_field <repository> <folder|url|branch>
repo_field() {
	get_repo_config "$1" | awk -F= -v field="$2" '$1 == field { print substr($0, index($0, "=") + 1) }'
}

normalize_repo_url() {
	url=$1
	url=$(printf '%s\n' "$url" | tr '[:upper:]' '[:lower:]')
	url=${url#ssh://git@}
	url=${url#git@}
	url=${url#https://}
	url=${url#http://}
	url=${url#github.com:}
	url=${url#github.com/}
	url=${url%.git}
	printf '%s\n' "$url"
}

assert_repo_checkout() {
	repository_name=$1
	folder=$(repo_field "$repository_name" folder)
	expected_url=$(repo_field "$repository_name" url)
	repository_path="$WORKSPACE_ROOT/$folder"
	[ -d "$repository_path" ] || die "Repo '$repository_name' not found at $repository_path - run clone.sh first"
	git -C "$repository_path" rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "$repository_name is not a Git checkout"
	actual_url=$(git -C "$repository_path" remote get-url origin 2>/dev/null || true)
	[ -n "$actual_url" ] || die "$repository_name has no origin remote"
	[ "$(normalize_repo_url "$actual_url")" = "$(normalize_repo_url "$expected_url")" ] ||
		die "$repository_name origin '$actual_url' does not match manifest '$expected_url'"
	[ -f "$repository_path/composer.json" ] || die "$repository_name is missing composer.json"
	case "$repository_name" in
		example-app)
			[ -f "$repository_path/artisan" ] || die "$repository_name is missing artisan"
			;;
	esac
}

assert_clean_composer_files() {
	repository_name=$1
	folder=$(repo_field "$repository_name" folder)
	repository_path="$WORKSPACE_ROOT/$folder"
	dirty_files=$(git -C "$repository_path" status --porcelain -- composer.json composer.lock)
	[ -z "$dirty_files" ] || die "$repository_name has uncommitted Composer manifest changes; restore or commit composer.json and composer.lock before installing dependencies"
}

assert_profile_repositories() {
	profile=$1
	for repository_name in $(get_profile_repos "$profile"); do
		assert_repo_checkout "$repository_name"
	done
}