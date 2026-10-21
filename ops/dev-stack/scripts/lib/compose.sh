#!/usr/bin/env sh

. "$SCRIPT_DIR/lib/env.sh"

# Exports the variables every Compose invocation needs and echoes the validated project name.
prepare_compose_env() {
    LOCAL_UID=$(get_env_value LOCAL_UID "$(id -u)")
    LOCAL_GID=$(get_env_value LOCAL_GID "$(id -g)")
    export LOCAL_UID LOCAL_GID
    if [ -z "${DEVSTACK_NPMRC_FILE:-}" ] && [ -f "$(npm_credentials_file)" ]; then
        DEVSTACK_NPMRC_FILE=$(npm_credentials_file)
        export DEVSTACK_NPMRC_FILE
    fi
    project_name=$(get_compose_project_name)
    case "$project_name" in
        ''|*[!a-z0-9_-]*) die "COMPOSE_PROJECT_NAME must start with a lowercase letter or number and contain only lowercase letters, numbers, '_' or '-'" ;;
    esac
}

# .env when present, otherwise the placeholder defaults in .env.example (e.g. before setup.sh runs).
stack_env_file() {
    if [ -f "$STACK_ROOT/.env" ]; then printf '%s\n' "$STACK_ROOT/.env"; else printf '%s\n' "$STACK_ROOT/.env.example"; fi
}

get_compose_project_name() {
    get_env_value COMPOSE_PROJECT_NAME devstack
}

# compose <internal|test> [docker compose args...]
compose() {
    profile=$1
    shift
    assert_compose_profile "$profile"

    (
        cd "$STACK_ROOT" || exit 1
        prepare_compose_env
        files="-f docker/compose.base.yml -f docker/compose.internal.yml"
        [ "$profile" = test ] && files="$files -f docker/compose.test.yml"
        [ "$(get_env_value DEVSTACK_PUBLISH_DATA_PORTS false)" = true ] && files="$files -f docker/compose.host-ports.yml"
        # shellcheck disable=SC2086 # the file list is intentionally word-split
        docker compose -p "$project_name" --env-file "$(stack_env_file)" $files "$@"
    )
}

# compose_tools [docker compose args...] - composer/node one-off containers
compose_tools() {
    (
        cd "$STACK_ROOT" || exit 1
        prepare_compose_env
        COMPOSE_IGNORE_ORPHANS=true
        export COMPOSE_IGNORE_ORPHANS
        docker compose -p "$project_name" --env-file "$(stack_env_file)" -f docker/compose.base.yml -f docker/compose.tools.yml "$@"
    )
}
