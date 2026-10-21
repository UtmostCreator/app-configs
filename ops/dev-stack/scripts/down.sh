#!/usr/bin/env sh
set -eu
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
. "$SCRIPT_DIR/lib/common.sh"
. "$SCRIPT_DIR/lib/compose.sh"

volumes=false
while [ "$#" -gt 0 ]; do
	case "$1" in
		--volumes) volumes=true ;;
		-h|--help) printf 'Usage: down.sh [--volumes]\n'; exit 0 ;;
		*) usage_error "Unknown option: $1" ;;
	esac
	shift
done

step "Stopping stack..."
compose_project=$(get_compose_project_name)
one_off_containers=$(docker ps -aq --filter "label=com.docker.compose.project=$compose_project" --filter "label=com.docker.compose.oneoff=True")
if [ -n "$one_off_containers" ]; then
	info "Removing Docker Compose one-off containers..."
	docker rm -f $one_off_containers || die "Failed to remove Docker Compose one-off containers"
	ok "Docker Compose one-off containers removed"
fi

if [ "$volumes" = true ]; then
	compose test --profile internal --profile workers --profile test down --volumes --remove-orphans
else
	compose test --profile internal --profile workers --profile test down --remove-orphans
fi
ok "Stack stopped"
