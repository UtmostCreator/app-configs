#!/usr/bin/env sh
set -eu

STACK_ROOT="$(CDPATH='' cd -- "$(dirname -- "$0")/../.." && pwd)"

floating_compose_images=$(awk '
	/^[[:space:]]+image:/ {
		image = $2
		if (image !~ /^example-dev\// && image !~ /@sha256:[[:xdigit:]]+$/) print FILENAME ":" NR ":" image
	}
' "$STACK_ROOT"/docker/compose*.yml "$STACK_ROOT"/docker/compose.*.yml 2>/dev/null || true)
[ -z "$floating_compose_images" ] || {
	printf '%s\n' "$floating_compose_images" >&2
	exit 1
}

for dockerfile in "$STACK_ROOT"/docker/images/*/Dockerfile; do
	while IFS= read -r reference; do
		case "$reference" in
			FROM:*\@sha256:[[:xdigit:]]*) ;;
			COPY:node|COPY:composer) ;;
			COPY:*@sha256:[[:xdigit:]]*) ;;
			*) printf 'floating Dockerfile reference: %s (%s)\n' "$reference" "$dockerfile" >&2; exit 1 ;;
		esac
	done <<EOF
$(awk '/^FROM[[:space:]]/ { print "FROM:" $2 } /^COPY[[:space:]]+--from=/ { ref=$0; sub(/^.*--from=/, "", ref); sub(/[[:space:]].*$/, "", ref); print "COPY:" ref }' "$dockerfile")
EOF
done

if grep -R -nE 'gpg --recv-key|curl .*[|][[:space:]]*(ba)?sh|getcomposer\\.org/installer|composer:latest' "$STACK_ROOT/docker/images"; then
	exit 1
fi

fixture_dir=$(mktemp -d "${TMPDIR:-/tmp}/image-refs.XXXXXX")
trap 'rm -rf "$fixture_dir"' EXIT HUP INT TERM
printf 'FROM ubuntu:22.04\n' > "$fixture_dir/Dockerfile"
invalid_output="$fixture_dir/invalid.out"
if IMAGE_REF_ROOT="$fixture_dir" "$STACK_ROOT/scripts/validate-compose.sh" internal >"$invalid_output" 2>&1; then
	printf 'tag-only Dockerfile base unexpectedly accepted\n' >&2
	exit 1
fi
grep -q 'Floating Dockerfile image reference: FROM:ubuntu:22.04' "$invalid_output"

printf 'image reference fixtures passed.\n'
