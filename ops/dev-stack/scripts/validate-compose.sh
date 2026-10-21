#!/usr/bin/env sh
set -eu
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
. "$SCRIPT_DIR/lib/common.sh"
. "$SCRIPT_DIR/lib/compose.sh"

[ "$#" -ge 1 ] || usage_error "Usage: validate-compose.sh <internal|test|tools|all> [--host-ports]"
profile=$1
shift
host_ports=false
while [ "$#" -gt 0 ]; do
	case "$1" in
		--host-ports) host_ports=true ;;
		*) usage_error "Unknown option: $1" ;;
	esac
	shift
done

if [ "$profile" = all ]; then
	for matrix_target in internal test tools; do
		"$0" "$matrix_target" || exit $?
	done
	DEVSTACK_PUBLISH_DATA_PORTS=true "$0" internal --host-ports
	exit 0
fi
assert_compose_profile "$profile"

[ "$host_ports" = true ] && export DEVSTACK_PUBLISH_DATA_PORTS=true
tools_profile=false
case "$profile" in
	test) set -- --profile internal --profile workers --profile tools --profile test ;;
	tools) tools_profile=true ;;
	*) set -- --profile internal --profile workers ;;
esac

image_root=${IMAGE_REF_ROOT:-"$STACK_ROOT/docker/images"}
dockerfile_refs=$(find "$image_root" -name Dockerfile -type f -print | while IFS= read -r dockerfile; do
	awk '
		/^FROM[[:space:]]/ { print "FROM:" $2 }
		/^COPY[[:space:]]+--from=/ {
			ref = $0
			sub(/^.*--from=/, "", ref)
			sub(/[[:space:]].*$/, "", ref)
			print "COPY:" ref
		}
	' "$dockerfile"
done)
floating_dockerfile_refs=$(printf '%s\n' "$dockerfile_refs" | awk '
	/^COPY:[[:alnum:]._-]+$/ { next }
	/^FROM:/ && $0 !~ /@sha256:[[:xdigit:]]+$/ { print }
	/^COPY:/ && /:/ && $0 !~ /@sha256:[[:xdigit:]]+$/ { print }
')
if [ -n "$floating_dockerfile_refs" ]; then
	for image in $floating_dockerfile_refs; do fail "Floating Dockerfile image reference: $image"; done
	die "Pin every Dockerfile base and external stage to tag@sha256"
fi
if [ "${COMPOSE_VERSION_CHECKED:-false}" != true ]; then
	if docker compose version >/dev/null 2>&1; then :; else die "Docker Compose v2 not available"; fi
fi
step "Validating Compose configuration for '$profile'..."
if [ "$tools_profile" = true ]; then
	compose_tools --profile tools config --quiet
	ok "Compose configuration for 'tools' is valid"
	exit 0
fi
compose "$profile" "$@" config --quiet

service_count=$(compose "$profile" "$@" config --services | grep -c . || true)
hardened_count=$(compose "$profile" "$@" config | grep -c 'no-new-privileges:true' || true)
[ "$hardened_count" -ge "$service_count" ] || die "Only $hardened_count of $service_count services set no-new-privileges; extend a docker/compose.common.yml base service"
restart_count=$(compose "$profile" "$@" config | grep -Ec '^[[:space:]]+restart:' || true)
[ "$restart_count" -eq 0 ] || die "Compose configuration contains $restart_count restart policy entries"

floating_images=$(compose "$profile" "$@" config --images | awk '
    /^example-dev\// { next }
    !/@sha256:[[:xdigit:]]+$/ { print }
')
if [ -n "$floating_images" ]; then
	for image in $floating_images; do fail "Floating image reference: $image"; done
	die "Pin every third-party image to an explicit tag@sha256 digest"
fi
ok "Compose configuration for '$profile' is valid"
