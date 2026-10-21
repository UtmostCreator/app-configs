#!/usr/bin/env sh
set -eu
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
. "$SCRIPT_DIR/lib/common.sh"

profile=${1:-}
[ -n "$profile" ] || usage_error "Usage: bootstrap-linux.sh <internal> [--clean]"
assert_profile "$profile"
shift

clean=false
while [ "$#" -gt 0 ]; do
	case "$1" in
		--clean) clean=true ;;
		-h|--help) printf 'Usage: bootstrap-linux.sh <internal> [--clean]\n'; exit 0 ;;
		*) usage_error "Unknown option: $1" ;;
	esac
	shift
done

if [ "$clean" = true ]; then
	step "Removing existing stack containers and volumes..."
	"$SCRIPT_DIR/down.sh" --volumes
fi

"$SCRIPT_DIR/doctor.sh" "$profile"
"$SCRIPT_DIR/clone.sh" "$profile"
"$SCRIPT_DIR/setup.sh" "$profile"
"$SCRIPT_DIR/test.sh" "$profile"