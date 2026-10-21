#!/usr/bin/env sh
set -eu

STACK_ROOT="$(CDPATH='' cd -- "$(dirname -- "$0")/../.." && pwd)"
SCRIPT_DIR="$STACK_ROOT/scripts"
WORKSPACE_ROOT="$STACK_ROOT"
REPOS_YAML="$STACK_ROOT/config/repositories.yml"
. "$STACK_ROOT/scripts/lib/common.sh"
. "$STACK_ROOT/scripts/lib/repos.sh"

[ "$(normalize_repo_url 'git@github.com:example-org/example-app.git')" = example-org/example-app ]
[ "$(normalize_repo_url 'https://github.com/example-org/example-app')" = example-org/example-app ]
[ "$(normalize_repo_url 'HTTPS://GITHUB.COM/example-org/example-app.git')" = example-org/example-app ]
[ "$(normalize_repo_url 'git@github.com:other/example-app.git')" != example-org/example-app ]

if sh -c '. "$1/lib/common.sh"; assert_profile test' sh "$STACK_ROOT/scripts" >/dev/null 2>&1; then
	printf 'lifecycle profile guard accepted test\n' >&2
	exit 1
fi
assert_compose_profile test

fixture_dir=$(mktemp -d "${TMPDIR:-/tmp}/repo-validation.XXXXXX")
trap 'rm -rf "$fixture_dir"' EXIT HUP INT TERM

wrong_origin_workspace="$fixture_dir/wrong-origin"
mkdir -p "$wrong_origin_workspace/example-app"
git -C "$wrong_origin_workspace/example-app" init -q
git -C "$wrong_origin_workspace/example-app" remote add origin git@github.com:other/example-app.git
: > "$wrong_origin_workspace/example-app/composer.json"
: > "$wrong_origin_workspace/example-app/artisan"
if sh -c '
	SCRIPT_DIR=$2
	. "$SCRIPT_DIR/lib/common.sh"
	. "$SCRIPT_DIR/lib/repos.sh"
	WORKSPACE_ROOT=$1
	assert_repo_checkout example-app
' sh "$wrong_origin_workspace" "$STACK_ROOT/scripts" "$REPOS_YAML" >/dev/null 2>&1; then
	printf 'wrong repository origin unexpectedly accepted\n' >&2
	exit 1
fi

source_repo="$fixture_dir/source"
worktree_workspace="$fixture_dir/worktree"
git init -q "$source_repo"
git -C "$source_repo" config user.email fixture@example.com
git -C "$source_repo" config user.name fixture
: > "$source_repo/composer.json"
: > "$source_repo/artisan"
git -C "$source_repo" add composer.json artisan
git -C "$source_repo" commit -qm 'fixture'
git -C "$source_repo" remote add origin git@github.com:example-org/example-app.git
mkdir -p "$worktree_workspace"
git -C "$source_repo" worktree add -q -b fixture-worktree "$worktree_workspace/example-app"
[ -f "$worktree_workspace/example-app/.git" ] || {
	printf 'worktree fixture does not use a .git file\n' >&2
	exit 1
}
sh -c '
	SCRIPT_DIR=$2
	. "$SCRIPT_DIR/lib/common.sh"
	. "$SCRIPT_DIR/lib/repos.sh"
	WORKSPACE_ROOT=$1
	assert_repo_checkout example-app
' sh "$worktree_workspace" "$STACK_ROOT/scripts" "$REPOS_YAML"

sh -c '
	SCRIPT_DIR=$2
	. "$SCRIPT_DIR/lib/common.sh"
	. "$SCRIPT_DIR/lib/repos.sh"
	WORKSPACE_ROOT=$1
	assert_clean_composer_files example-app
' sh "$worktree_workspace" "$STACK_ROOT/scripts"
printf '\n' >> "$worktree_workspace/example-app/composer.json"
if dirty_output=$(sh -c '
	SCRIPT_DIR=$2
	. "$SCRIPT_DIR/lib/common.sh"
	. "$SCRIPT_DIR/lib/repos.sh"
	WORKSPACE_ROOT=$1
	assert_clean_composer_files example-app
' sh "$worktree_workspace" "$STACK_ROOT/scripts" 2>&1); then
	printf 'dirty Composer manifest unexpectedly accepted\n' >&2
	exit 1
fi
printf '%s\n' "$dirty_output" | grep -q 'composer.json and composer.lock'

if grep -Eq 'file_put_contents\(\$path|\.composer\.(json|lock)\.local-stack' "$SCRIPT_DIR/install-deps.sh"; then
	printf 'install-deps reintroduced tracked Composer file mutation\n' >&2
	exit 1
fi

printf 'repository validation fixtures passed.\n'
