#!/usr/bin/env sh
set -eu

SCRIPT_DIR="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)"
. "$SCRIPT_DIR/lib/common.sh"

verify_image() {
	image=$1
	expected_minor=$2
	shift 2
	command_exists docker || die "Docker is required"
	docker image inspect "$image" >/dev/null 2>&1 || die "Image is not built: $image"
	version=$(docker run --rm "$image" php -r 'printf("%d.%d", PHP_MAJOR_VERSION, PHP_MINOR_VERSION);')
	[ "$version" = "$expected_minor" ] || die "$image reports PHP $version, expected $expected_minor"
	modules=$(docker run --rm "$image" php -m)
	for extension in "$@"; do
		printf '%s\n' "$modules" | grep -qx "$extension" || die "$image is missing PHP extension '$extension'"
	done
	ok "$image PHP $version extension contract passed"
}

verify_image example-dev/php-cli:8.3 8.3 pdo_mysql mbstring zip redis

node_version=$(docker run --rm example-dev/php-cli:8.3 node --version)
case "$node_version" in
	v22.22.2) ok "example-dev/php-cli:8.3 Node $node_version" ;;
	*) die "example-dev/php-cli:8.3 has unexpected Node version $node_version" ;;
esac
