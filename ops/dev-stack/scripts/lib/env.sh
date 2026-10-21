#!/usr/bin/env sh

read_env_file_value() {
    awk -v key="$1" '
        /^[[:space:]]*#/ || /^[[:space:]]*$/ { next }
        {
            line = $0
            sub(/^[[:space:]]*/, "", line)
            split(line, parts, "=")
            current_key = parts[1]
            gsub(/[[:space:]]+$/, "", current_key)
            if (current_key != key) next
            value = substr(line, index(line, "=") + 1)
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
            first = substr(value, 1, 1)
            last = substr(value, length(value), 1)
            if ((first == "\"" || first == "'\''") && last == first) {
                value = substr(value, 2, length(value) - 2)
            }
            print value
            exit
        }
    ' "$2"
}

validate_stack_env_file() {
    env_file=$1
    [ -f "$env_file" ] || return 0
    awk '
        /^[[:space:]]*#/ || /^[[:space:]]*$/ { next }
        {
            line = $0
            sub(/^[[:space:]]*/, "", line)
            if (line !~ /^[A-Za-z_][A-Za-z0-9_]*[[:space:]]*=/) {
                print "invalid assignment syntax: " $0
                failed = 1
                next
            }
            key = line
            sub(/[[:space:]]*=.*/, "", key)
            if (key ~ /^export[[:space:]]+/) {
                print "export prefix is not supported: " $0
                failed = 1
            }
            value = line
            sub(/^[^=]*=[[:space:]]*/, "", value)
            if (value ~ /\$/) {
                print "interpolation is not supported: " $0
                failed = 1
            }
            first = substr(value, 1, 1)
            last = substr(value, length(value), 1)
            if (first == "\"" || first == "'\''") {
                if (last != first) {
                    print "unmatched quote: " $0
                    failed = 1
                }
            } else if (value ~ /[[:space:]]#[^#]*$/) {
                print "unquoted inline comment is not supported: " $0
                failed = 1
            }
        }
        END { exit failed }
    ' "$env_file"
}

# Lookup order: environment, stack .env, .env.example (single source of defaults), then the caller's fallback.
get_env_value() {
    variable_name=$1
    default_value=${2:-}
    env_file=${3:-"$STACK_ROOT/.env"}

    environment_value=$(printenv "$variable_name" 2>/dev/null || true)
    if [ -n "$environment_value" ]; then
        printf '%s\n' "$environment_value"
        return 0
    fi

    for candidate_file in "$env_file" "$STACK_ROOT/.env.example"; do
        [ -f "$candidate_file" ] || continue
        file_value=$(read_env_file_value "$variable_name" "$candidate_file")
        if [ -n "$file_value" ]; then
            printf '%s\n' "$file_value"
            return 0
        fi
    done

    printf '%s\n' "$default_value"
}

app_env_names() {
    case "$1" in
        internal) printf '%s\n' example-app ;;
    esac
}

# Must run before any compose command that boots application code with a developer .env.
assert_safe_app_environment() {
    safety_profile=$1
    shift
    if [ "$#" -eq 0 ]; then
        # shellcheck disable=SC2046
        set -- $(app_env_names "$safety_profile")
    fi
    [ "$#" -gt 0 ] || die "No application environments are registered for profile '$safety_profile'"
    safety_failed=false
    for safety_app in "$@"; do
        if sh "$STACK_ROOT/scripts/validate-env.sh" "$safety_app" "$WORKSPACE_ROOT/$safety_app/.env"; then
            ok "$safety_app .env passed safety validation"
        else
            safety_failed=true
        fi
    done
    [ "$safety_failed" = false ] || die "Unsafe application environment - fix the settings reported above before starting application containers"
}

npm_credentials_file() {
    if [ -n "${DEVSTACK_NPM_CONFIG_USERCONFIG:-}" ]; then
        printf '%s\n' "$DEVSTACK_NPM_CONFIG_USERCONFIG"
        return 0
    fi
    config_home=${XDG_CONFIG_HOME:-"$HOME/.config"}
    printf '%s\n' "$config_home/devstack/npmrc"
}

get_env_port() {
    variable_name=$1
    default_value=$2
    value=$(get_env_value "$variable_name" "$default_value")
    case "$value" in
        ''|*[!0-9]*) printf '%s\n' "$default_value" ;;
        *) printf '%s\n' "$value" ;;
    esac
}

port_is_in_use() {
    port=$1
    if command_exists nc; then
        nc -z -w 1 127.0.0.1 "$port" >/dev/null 2>&1
    elif command_exists curl; then
        curl --connect-timeout 1 --max-time 1 -sS "telnet://127.0.0.1:$port" >/dev/null 2>&1
    else
        return 1
    fi
}

set_env_value() {
    variable_name=$1
    value=$2
    env_file=${3:-"$STACK_ROOT/.env"}
    temporary_file="$env_file.tmp.$$"

    if [ -f "$env_file" ]; then
        awk -v key="$variable_name" -v replacement="$value" '
            $0 ~ "^[[:space:]]*" key "[[:space:]]*=" {
                print key "=" replacement
                found = 1
                next
            }
            { print }
            END {
                if (!found) print key "=" replacement
            }
        ' "$env_file" > "$temporary_file"
    else
        printf '%s=%s\n' "$variable_name" "$value" > "$temporary_file"
    fi
    mv "$temporary_file" "$env_file"
}

ensure_redis_host_port() {
    profile=${1:-}
    [ "$(get_env_value DEVSTACK_PUBLISH_DATA_PORTS false)" = true ] || return 0
    if [ -n "$profile" ] && command_exists docker; then
        redis_container_id=$(compose "$profile" ps -q redis 2>/dev/null || true)
        if [ -n "$redis_container_id" ] && [ "$(docker inspect --format '{{.State.Running}}' "$redis_container_id" 2>/dev/null || true)" = true ]; then
            return 0
        fi
    fi

    requested_port=$(get_env_port REDIS_HOST_PORT 6380)

    if [ -n "${REDIS_HOST_PORT:-}" ] && port_is_in_use "$requested_port"; then
        die "REDIS_HOST_PORT=$requested_port is already in use. Unset it or choose a free port."
    fi
}