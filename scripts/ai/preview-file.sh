#!/usr/bin/env bash
# Safe bounded file preview for AI agents and humans.
#
# Purpose:
# - Preview exactly one file.
# - Prefer precise ranges over large dumps.
# - Return compact JSON when --json or AI_OUTPUT=json is used.
# - Prevent token blowups from huge files, binary files, and minified lines.
#
# Non-goals:
# - No searching.
# - No editing.
# - No multi-file context packing.

set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

if [[ -f "$script_dir/common.sh" ]]; then
    # shellcheck source=scripts/ai/common.sh
    source "$script_dir/common.sh"
fi

if ! declare -F die >/dev/null 2>&1; then
    die() {
        printf 'preview-file: error: %s\n' "$*" >&2
        exit 2
    }
fi

if ! declare -F require_bins >/dev/null 2>&1; then
    require_bins() {
        local missing=0
        local bin
        for bin in "$@"; do
            if ! command -v "$bin" >/dev/null 2>&1; then
                printf 'preview-file: error: required command not found: %s\n' "$bin" >&2
                missing=1
            fi
        done
        [[ "$missing" -eq 0 ]] || exit 2
    }
fi

usage() {
    cat <<'EOF'
Usage:
  preview-file.sh FILE [options]
  preview-file.sh [options] FILE

Core:
  --lines N             Preview first N lines.
  --range A:B           Preview inclusive line range A:B.
  --around N            Preview around line N.
  --context N           Context lines for --around. Default: 40.

Safety:
  --max-lines N         Maximum lines emitted. Default: 300.
  --max-columns N       Truncate lines after N columns. Default: 300. Use 0 to disable.
  --max-bytes N         Block files larger than N bytes. Supports 1000, 1K, 1M, 1G. Default: 1M.
  --force               Allow binary-looking or oversized files.

Output:
  --json                Emit compact JSON envelope.
  --plain               Emit deterministic plain text.
  --bat                 Use bat for human preview when available.
  --color               Allow colour with --bat.
  --no-numbers          Disable line numbers.
  --dry-run             Show resolved preview metadata without content.
  --help, -h            Show this help.

Environment:
  AI_OUTPUT=json
  AI_PREVIEW_LINES=80
  AI_PREVIEW_HUMAN_LINES=200
  AI_PREVIEW_CONTEXT=40
  AI_PREVIEW_MAX_LINES=300
  AI_PREVIEW_MAX_COLUMNS=300
  AI_PREVIEW_MAX_BYTES=1M
EOF
}

is_uint() {
    [[ "${1:-}" =~ ^[0-9]+$ ]]
}

is_pos_int() {
    is_uint "$1" && (( "$1" >= 1 ))
}

parse_bytes() {
    local raw="${1:-}"
    local value suffix number

    value="$(printf '%s' "$raw" | tr '[:lower:]' '[:upper:]' | tr -d '[:space:]')"

    if [[ "$value" =~ ^([0-9]+)(B|K|KB|KI|KIB|M|MB|MI|MIB|G|GB|GI|GIB)?$ ]]; then
        number="${BASH_REMATCH[1]}"
        suffix="${BASH_REMATCH[2]:-B}"

        case "$suffix" in
            B|"")
                printf '%s\n' "$number"
                ;;
            K|KB|KI|KIB)
                printf '%s\n' $((number * 1024))
                ;;
            M|MB|MI|MIB)
                printf '%s\n' $((number * 1024 * 1024))
                ;;
            G|GB|GI|GIB)
                printf '%s\n' $((number * 1024 * 1024 * 1024))
                ;;
            *)
                return 1
                ;;
        esac

        return 0
    fi

    return 1
}

file_size_bytes() {
    local path="$1"

    stat -c '%s' -- "$path" 2>/dev/null \
        || stat -f '%z' "$path" 2>/dev/null \
        || wc -c < "$path" | tr -d '[:space:]'
}

json_array() {
    require_bins jq

    if [[ "$#" -eq 0 ]]; then
        printf '[]'
        return 0
    fi

    printf '%s\n' "$@" | jq -R . | jq -s .
}

json_output=false
format_explicit=false
use_bat=false
color=false
numbers=true
force=false
dry_run=false

file=""
lines=""
range_arg=""
around=""
context="${AI_PREVIEW_CONTEXT:-40}"
max_lines="${AI_PREVIEW_MAX_LINES:-300}"
max_columns="${AI_PREVIEW_MAX_COLUMNS:-300}"
max_bytes_raw="${AI_PREVIEW_MAX_BYTES:-1M}"

while [[ "$#" -gt 0 ]]; do
    case "$1" in
        --help|-h)
            usage
            exit 0
            ;;
        --json)
            json_output=true
            format_explicit=true
            shift
            ;;
        --plain)
            json_output=false
            use_bat=false
            format_explicit=true
            shift
            ;;
        --bat)
            json_output=false
            use_bat=true
            format_explicit=true
            shift
            ;;
        --color)
            color=true
            shift
            ;;
        --no-numbers)
            numbers=false
            shift
            ;;
        --force)
            force=true
            shift
            ;;
        --dry-run)
            dry_run=true
            shift
            ;;
        --lines)
            [[ "$#" -ge 2 ]] || die "--lines requires a value"
            lines="$2"
            shift 2
            ;;
        --lines=*)
            lines="${1#*=}"
            shift
            ;;
        --range)
            [[ "$#" -ge 2 ]] || die "--range requires a value"
            range_arg="$2"
            shift 2
            ;;
        --range=*)
            range_arg="${1#*=}"
            shift
            ;;
        --around)
            [[ "$#" -ge 2 ]] || die "--around requires a value"
            around="$2"
            shift 2
            ;;
        --around=*)
            around="${1#*=}"
            shift
            ;;
        --context)
            [[ "$#" -ge 2 ]] || die "--context requires a value"
            context="$2"
            shift 2
            ;;
        --context=*)
            context="${1#*=}"
            shift
            ;;
        --max-lines)
            [[ "$#" -ge 2 ]] || die "--max-lines requires a value"
            max_lines="$2"
            shift 2
            ;;
        --max-lines=*)
            max_lines="${1#*=}"
            shift
            ;;
        --max-columns)
            [[ "$#" -ge 2 ]] || die "--max-columns requires a value"
            max_columns="$2"
            shift 2
            ;;
        --max-columns=*)
            max_columns="${1#*=}"
            shift
            ;;
        --max-bytes|--max-size)
            [[ "$#" -ge 2 ]] || die "$1 requires a value"
            max_bytes_raw="$2"
            shift 2
            ;;
        --max-bytes=*|--max-size=*)
            max_bytes_raw="${1#*=}"
            shift
            ;;
        --)
            shift
            [[ "$#" -gt 0 ]] || die "-- requires a following file"
            if [[ -n "$file" ]]; then
                die "only one file may be provided"
            fi
            file="$1"
            shift
            ;;
        --*)
            die "unknown option: $1"
            ;;
        *)
            if [[ -n "$file" ]]; then
                die "only one file may be provided"
            fi
            file="$1"
            shift
            ;;
    esac
done

if [[ "$format_explicit" == false && "${AI_OUTPUT:-}" == "json" ]]; then
    json_output=true
fi

if [[ -z "$lines" ]]; then
    if [[ "$json_output" == true ]]; then
        lines="${AI_PREVIEW_LINES:-80}"
    else
        lines="${AI_PREVIEW_HUMAN_LINES:-200}"
    fi
fi

emit_error() {
    local message="$1"
    local exit_code="${2:-2}"
    local path="${file:-}"

    if [[ "$json_output" == true ]]; then
        require_bins jq

        jq -n \
            --arg schema "1" \
            --arg status "error" \
            --arg tool "preview-file" \
            --arg path "$path" \
            --argjson errors "$(json_array "$message")" \
            '{
                schema: $schema,
                status: $status,
                tool: $tool,
                path: $path,
                range: null,
                total_lines: null,
                truncated: false,
                content: "",
                limits: {},
                warnings: [],
                errors: $errors,
                meta: {}
            }'
    else
        printf 'preview-file: error: %s\n' "$message" >&2
    fi

    exit "$exit_code"
}

[[ -n "$file" ]] || emit_error "file required" 2
[[ -f "$file" ]] || emit_error "file not found: $file" 1

is_pos_int "$lines" || emit_error "--lines must be a positive integer" 2
is_uint "$context" || emit_error "--context must be a non-negative integer" 2
is_pos_int "$max_lines" || emit_error "--max-lines must be a positive integer" 2
is_uint "$max_columns" || emit_error "--max-columns must be a non-negative integer" 2

max_bytes="$(parse_bytes "$max_bytes_raw")" || emit_error "--max-bytes must be numeric or use K/M/G suffix" 2

size_bytes="$(file_size_bytes "$file")"
is_uint "$size_bytes" || size_bytes=0

warnings=()

normalized_path="${file#./}"
case "/$normalized_path" in
    *"/.git/"*|*"/.git")
        if [[ "$force" != true ]]; then
            emit_error ".git internals are blocked; use --force only with explicit approval" 2
        fi
        ;;
    *"/node_modules/"*|*"/vendor/"*|*"/dist/"*|*"/build/"*|*"/coverage/"*|*"/docs/ai/generated/"*)
        warnings+=("path looks generated, vendored, or high-volume; prefer narrow ranges")
        ;;
esac

case "$normalized_path" in
    *.min.js|*.min.css|*.map|package-lock.json|pnpm-lock.yaml|yarn.lock|composer.lock)
        warnings+=("file is commonly large/generated; output remains bounded")
        ;;
esac

if (( max_bytes > 0 && size_bytes > max_bytes )) && [[ "$force" != true ]]; then
    emit_error "file exceeds max-bytes limit: ${size_bytes} > ${max_bytes}; use --force with a narrow range if needed" 2
fi

if [[ -s "$file" ]] && ! LC_ALL=C grep -Iq . < "$file"; then
    if [[ "$force" != true ]]; then
        emit_error "binary-looking file blocked; use --force only with explicit approval" 2
    fi
    warnings+=("binary-looking file was forced; output may be unsafe or unreadable")
fi

total_lines="$(awk 'END { print NR + 0 }' < "$file")"
is_uint "$total_lines" || total_lines=0

start=1
end="$lines"

if [[ -n "$range_arg" ]]; then
    if [[ ! "$range_arg" =~ ^([0-9]+):([0-9]+)$ ]]; then
        emit_error "--range must use A:B format" 2
    fi

    start="${BASH_REMATCH[1]}"
    end="${BASH_REMATCH[2]}"

    is_pos_int "$start" || emit_error "--range start must be >= 1" 2
    is_pos_int "$end" || emit_error "--range end must be >= 1" 2
    (( end >= start )) || emit_error "--range end must be >= start" 2
fi

if [[ -n "$around" ]]; then
    is_pos_int "$around" || emit_error "--around must be a positive integer" 2

    if (( around <= context )); then
        start=1
    else
        start=$((around - context))
    fi

    end=$((around + context))
fi

if (( total_lines == 0 )); then
    start=1
    end=0
else
    if (( start > total_lines )); then
        warnings+=("requested start line is beyond end of file; clamped to total_lines")
        start="$total_lines"
    fi

    if (( end > total_lines )); then
        end="$total_lines"
    fi
fi

selected_count=0
if (( end >= start )); then
    selected_count=$((end - start + 1))
fi

truncated=false

if (( selected_count > max_lines )); then
    end=$((start + max_lines - 1))
    selected_count="$max_lines"
    truncated=true
    warnings+=("range exceeded max-lines; output was truncated")
fi

if (( total_lines > 0 && end < total_lines )); then
    truncated=true
fi

render_plain() {
    awk \
        -v start="$start" \
        -v end="$end" \
        -v max_columns="$max_columns" \
        -v numbers="$([[ "$numbers" == true ]] && printf 1 || printf 0)" '
        end == 0 { exit }
        NR < start { next }
        NR > end { exit }
        {
            line = $0

            if (max_columns > 0 && length(line) > max_columns) {
                line = substr(line, 1, max_columns) " …[truncated]"
            }

            if (numbers == 1) {
                printf "%6d  %s\n", NR, line
            } else {
                print line
            }
        }
    ' < "$file"
}

if [[ "$dry_run" == true ]]; then
    if [[ "$json_output" == true ]]; then
        require_bins jq

        jq -n \
            --arg schema "1" \
            --arg status "dry_run" \
            --arg tool "preview-file" \
            --arg path "$file" \
            --argjson start "$start" \
            --argjson end "$end" \
            --argjson total_lines "$total_lines" \
            --argjson truncated "$truncated" \
            --argjson max_lines "$max_lines" \
            --argjson max_columns "$max_columns" \
            --argjson max_bytes "$max_bytes" \
            --argjson size_bytes "$size_bytes" \
            --argjson warnings "$(json_array "${warnings[@]}")" \
            '{
                schema: $schema,
                status: $status,
                tool: $tool,
                path: $path,
                range: {
                    start: $start,
                    end: $end
                },
                total_lines: $total_lines,
                truncated: $truncated,
                content: "",
                limits: {
                    max_lines: $max_lines,
                    max_columns: $max_columns,
                    max_bytes: $max_bytes
                },
                warnings: $warnings,
                errors: [],
                meta: {
                    size_bytes: $size_bytes
                }
            }'
    else
        printf 'Would preview %s lines %s:%s total_lines=%s size_bytes=%s truncated=%s\n' \
            "$file" "$start" "$end" "$total_lines" "$size_bytes" "$truncated" >&2
    fi

    exit 0
fi

if [[ "$json_output" == true ]]; then
    require_bins jq

    content="$(render_plain)"

    jq -n \
        --arg schema "1" \
        --arg status "ok" \
        --arg tool "preview-file" \
        --arg path "$file" \
        --arg content "$content" \
        --argjson start "$start" \
        --argjson end "$end" \
        --argjson total_lines "$total_lines" \
        --argjson truncated "$truncated" \
        --argjson max_lines "$max_lines" \
        --argjson max_columns "$max_columns" \
        --argjson max_bytes "$max_bytes" \
        --argjson size_bytes "$size_bytes" \
        --argjson warnings "$(json_array "${warnings[@]}")" \
        '{
            schema: $schema,
            status: $status,
            tool: $tool,
            path: $path,
            range: {
                start: $start,
                end: $end
            },
            total_lines: $total_lines,
            truncated: $truncated,
            content: $content,
            limits: {
                max_lines: $max_lines,
                max_columns: $max_columns,
                max_bytes: $max_bytes
            },
            warnings: $warnings,
            errors: [],
            meta: {
                size_bytes: $size_bytes
            }
        }'

    exit 0
fi

for warning in "${warnings[@]}"; do
    printf 'preview-file: warning: %s\n' "$warning" >&2
done

if [[ "$use_bat" == true ]] && command -v bat >/dev/null 2>&1; then
    bat_args=(--style=numbers --line-range "${start}:${end}")

    if [[ "$color" == true ]]; then
        bat_args+=(--color=auto)
    else
        bat_args+=(--color=never)
    fi

    exec bat "${bat_args[@]}" -- "$file"
fi

render_plain
