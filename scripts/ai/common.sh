#!/usr/bin/env bash
# Shared library for repository AI tooling scripts.
# common.sh v2: default-deny execution gate, bounded output, audit logging, rollback safety.

set -euo pipefail

AI_TOOL_NAME="${AI_TOOL_NAME:-$(basename "${0:-ai-tool}")}"

COPILOT_LOG_DIR="${COPILOT_LOG_DIR:-${AI_LOG_DIR:-.ai-logs}}"
COPILOT_CONTEXT_DIR="${COPILOT_CONTEXT_DIR:-.repomix-context}"
COPILOT_SESSION_DIR="${COPILOT_SESSION_DIR:-${COPILOT_LOG_DIR}/sessions}"
COPILOT_SNAPSHOT_DIR="${COPILOT_SNAPSHOT_DIR:-${COPILOT_LOG_DIR}/snapshots}"
COPILOT_EVENT_LOG="${COPILOT_EVENT_LOG:-${COPILOT_LOG_DIR}/tool-usage.jsonl}"

AI_CMD_TIMEOUT="${AI_CMD_TIMEOUT:-120}"
AI_OUTPUT_MAX_BYTES="${AI_OUTPUT_MAX_BYTES:-200000}"
AI_TOKEN_BUDGET="${AI_TOKEN_BUDGET:-128000}"
AI_LOCK_TIMEOUT_SECONDS="${AI_LOCK_TIMEOUT_SECONDS:-10}"
AI_LOG_MAX_BYTES="${AI_LOG_MAX_BYTES:-10485760}"
AI_FAIL_ON_MISSING_SECRET_SCANNER="${AI_FAIL_ON_MISSING_SECRET_SCANNER:-0}"
AI_REQUIRE_SCOPE_FOR_WRITE="${AI_REQUIRE_SCOPE_FOR_WRITE:-1}"
AI_REDACT_STDOUT="${AI_REDACT_STDOUT:-0}"
AI_SESSION_AUTO_TRAP="${AI_SESSION_AUTO_TRAP:-1}"

if [[ -z "${NO_COLOR:-}" && -t 2 ]]; then
    _C_RESET=$'\033[0m'
    _C_RED=$'\033[0;31m'
    _C_YELLOW=$'\033[0;33m'
    _C_GREEN=$'\033[0;32m'
    _C_CYAN=$'\033[0;36m'
    _C_BOLD=$'\033[1m'
else
    _C_RESET=''
    _C_RED=''
    _C_YELLOW=''
    _C_GREEN=''
    _C_CYAN=''
    _C_BOLD=''
fi

log_info() { printf '%b[INFO]%b  %s\n' "$_C_CYAN" "$_C_RESET" "$*" >&2; }
log_ok() { printf '%b[OK]%b    %s\n' "$_C_GREEN" "$_C_RESET" "$*" >&2; }
log_warn() { printf '%b[WARN]%b  %s\n' "$_C_YELLOW" "$_C_RESET" "$*" >&2; }
log_error() { printf '%b[ERROR]%b %s\n' "$_C_RED" "$_C_RESET" "$*" >&2; }
section() { printf '\n%b==> %s%b\n' "$_C_BOLD" "$*" "$_C_RESET" >&2; }

command_exists() { command -v "$1" >/dev/null 2>&1; }
hard_die() { log_error "$*"; exit 1; }

require_bins() {
    local missing=()
    local bin

    for bin in "$@"; do
        command_exists "$bin" || missing+=("$bin")
    done

    ((${#missing[@]} == 0)) || hard_die "required tools not found: ${missing[*]}"
}

require_bash_version() {
    local required="${1:-4}"
    local major="${BASH_VERSINFO[0]:-0}"

    ((major >= required)) || hard_die "Bash ${required}+ required; current version is ${BASH_VERSION:-unknown}"
}

common_require_core() {
    require_bash_version 4
    require_bins jq git
}

json_available() { command_exists jq; }

find_timeout_bin() {
    if command_exists gtimeout; then
        printf '%s\n' gtimeout
    elif command_exists timeout; then
        printf '%s\n' timeout
    else
        return 1
    fi
}

find_fd_bin() {
    if command_exists fd; then
        printf '%s\n' fd
    elif command_exists fdfind; then
        printf '%s\n' fdfind
    else
        return 1
    fi
}

now_ms() {
    local value

    value="$(date +%s%3N 2>/dev/null || true)"

    if [[ "$value" =~ ^[0-9]+$ ]]; then
        printf '%s\n' "$value"
        return 0
    fi

    if command_exists python3; then
        python3 - <<'PY' 2>/dev/null && return 0
import time
print(int(time.time() * 1000))
PY
    fi

    printf '%s000\n' "$(date +%s)"
}

redact_sensitive_text() {
    sed -E \
        -e 's/((token|password|passwd|secret|api[_-]?key|authorization|bearer)[[:space:]]*[:=][[:space:]]*)[^"[:space:]]+/\1REDACTED/Ig' \
        -e 's/(Authorization:[[:space:]]*Bearer[[:space:]]+)[A-Za-z0-9._~+\/=-]+/\1REDACTED/Ig' \
        -e 's/(-----BEGIN [A-Z ]+ PRIVATE KEY-----)[^-]*(-----END [A-Z ]+ PRIVATE KEY-----)/\1 REDACTED \2/g' \
        -e 's/[A-Za-z0-9_\/+=-]{48,}/REDACTED_LONG_SECRET/g'
}

redact_json_payload() {
    jq '
      def redact:
        if type == "object" then
          with_entries(
            if (.key | test("token|password|passwd|secret|api[_-]?key|authorization|bearer|private[_-]?key"; "i"))
            then .value = "REDACTED"
            else .value |= redact
            end
          )
        elif type == "array" then map(redact)
        elif type == "string" then
          if test("[A-Za-z0-9_\\/+=-]{48,}") then "REDACTED_LONG_SECRET" else . end
        else . end;
      redact
    '
}

json_compact_or_raw() {
    local payload="${1:-{}}"

    if jq -e . >/dev/null 2>&1 <<<"$payload"; then
        jq -c . <<<"$payload" | redact_json_payload | jq -c .
    else
        jq -cn --arg raw "$(printf '%s' "$payload" | redact_sensitive_text)" '{raw:$raw}'
    fi
}

emit_envelope() {
    local status="${1:?status required}"
    local tool="${2:?tool required}"
    local data="${3:-{}}"
    local warnings="${4:-[]}"
    local errors="${5:-[]}"
    local elapsed_ms="${6:-0}"
    local truncated="${7:-false}"

    common_require_core

    jq -cn \
        --arg schema "1" \
        --arg status "$status" \
        --arg tool "$tool" \
        --argjson data "$(json_compact_or_raw "$data")" \
        --argjson warnings "$warnings" \
        --argjson errors "$errors" \
        --argjson elapsed_ms "$elapsed_ms" \
        --argjson truncated "$truncated" \
        '{
            schema: $schema,
            status: $status,
            tool: $tool,
            data: $data,
            warnings: $warnings,
            errors: $errors,
            meta: {
                elapsed_ms: $elapsed_ms,
                truncated: $truncated
            }
        }'
}

emit_blocked_envelope() {
    local message="${1:?message required}"

    common_require_core

    jq -cn \
        --arg message "$message" \
        '{
            schema: "1",
            status: "unsafe_blocked",
            tool: "facade",
            data: {},
            warnings: [],
            errors: [$message],
            meta: {
                elapsed_ms: 0,
                truncated: false
            }
        }'
}

rotate_log_if_needed_locked() {
    local file="${1:?file required}"
    local max_bytes="${AI_LOG_MAX_BYTES:-10485760}"
    local size

    [[ -f "$file" ]] || return 0

    size="$(wc -c <"$file" | tr -d ' ')"

    if ((size > max_bytes)); then
        mv "$file" "${file}.$(date +%Y%m%d-%H%M%S).bak"
    fi
}

_append_locked_flock() {
    local file="${1:?file required}"
    local entry="${2:?entry required}"
    local lock_file="${file}.lock"

    mkdir -p "$(dirname "$file")"

    (
        flock -x 9
        rotate_log_if_needed_locked "$file"
        printf '%s\n' "$entry" >>"$file"
    ) 9>"$lock_file"
}

_append_locked_mkdir() {
    local file="${1:?file required}"
    local entry="${2:?entry required}"
    local lock_dir="${file}.lockdir"
    local start
    local now

    mkdir -p "$(dirname "$file")"

    start="$(date +%s)"

    while ! mkdir "$lock_dir" 2>/dev/null; do
        now="$(date +%s)"

        if ((now - start >= AI_LOCK_TIMEOUT_SECONDS)); then
            log_warn "could not acquire log lock for $file; writing without lock"
            rotate_log_if_needed_locked "$file"
            printf '%s\n' "$entry" >>"$file"
            return 0
        fi

        sleep 0.1
    done

    rotate_log_if_needed_locked "$file"
    printf '%s\n' "$entry" >>"$file"
    rmdir "$lock_dir" 2>/dev/null || rm -rf "$lock_dir"
}

append_jsonl_safe() {
    local file="${1:?file required}"
    local entry="${2:?entry required}"

    if command_exists flock; then
        _append_locked_flock "$file" "$entry"
    else
        _append_locked_mkdir "$file" "$entry"
    fi
}

append_log_entry() {
    local entry="${1:?entry required}"

    mkdir -p "$COPILOT_LOG_DIR"
    append_jsonl_safe "$COPILOT_EVENT_LOG" "$entry"

    if [[ -n "${SESSION_LOG:-}" ]]; then
        append_jsonl_safe "$SESSION_LOG" "$entry"
    fi
}

git_root() {
    git rev-parse --show-toplevel 2>/dev/null || pwd
}

repo_root() {
    git_root
}

log_json() {
    local event="${1:-event}"
    local payload="${2:-{}}"
    local caller="${3:-${AI_TOOL_NAME:-unknown}}"
    local payload_json
    local entry
    local repo_root_value
    local git_branch_value
    local git_commit_value

    json_available || return 127

    mkdir -p "$COPILOT_LOG_DIR"

    payload_json="$(json_compact_or_raw "$payload")"
    repo_root_value="$(git_root 2>/dev/null || pwd)"
    git_branch_value="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || printf 'unknown')"
    git_commit_value="$(git rev-parse HEAD 2>/dev/null || printf 'unknown')"

    entry="$(jq -cn \
        --arg event_version "2.0" \
        --arg event_type "$event" \
        --arg trace_id "${TRACE_ID:-unknown}" \
        --arg session_id "${SESSION_ID:-unknown}" \
        --arg task_id "${TASK_ID:-unknown}" \
        --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        --arg actor_id "${ACTOR_ID:-$caller}" \
        --arg delegated_by "${DELEGATED_BY:-}" \
        --arg tool_name "$caller" \
        --arg repo_root "$repo_root_value" \
        --arg git_branch "$git_branch_value" \
        --arg git_commit "$git_commit_value" \
        --argjson data "$payload_json" \
        '{
            event_version: $event_version,
            event_type: $event_type,
            trace_id: $trace_id,
            session_id: $session_id,
            task_id: $task_id,
            timestamp: $timestamp,
            actor: {
                type: "agent",
                id: $actor_id,
                delegated_by: (if $delegated_by == "" then null else $delegated_by end)
            },
            tool: {
                name: $tool_name,
                category: null,
                args_hash: null,
                mutates_state: false
            },
            authorization: {
                policy_version: null,
                decision: "unknown",
                approval_required: null,
                approved_by: null,
                reason: null
            },
            execution: {
                status: "unknown",
                latency_ms: null,
                retry_count: 0,
                exit_code: null,
                output_truncated: null
            },
            failure: {
                category: null,
                message: null,
                resolution: null
            },
            repository: {
                root: $repo_root,
                git_branch: (if $git_branch == "" or $git_branch == "unknown" then null else $git_branch end),
                git_commit: (if $git_commit == "" or $git_commit == "unknown" then null else $git_commit end)
            },
            output: {
                preview: null
            },
            details: (if ($data | type) == "object" then $data else {raw: $data} end)
        }')"

    append_log_entry "$entry"
}

die() {
    local msg="$*"

    log_error "$msg"
    log_json "error" "$(jq -cn --arg msg "$msg" '{msg:$msg}')" "$AI_TOOL_NAME" || true
    exit 1
}

agent_session_finish() {
    local exit_code="$?"

    if [[ "${AI_SESSION_FINISHED:-0}" != "1" ]]; then
        AI_SESSION_FINISHED=1
        log_json "session.end" "$(jq -cn --argjson exit_code "$exit_code" '{exit_code:$exit_code}')" "$AI_TOOL_NAME" || true
    fi

    return "$exit_code"
}

install_session_exit_trap() {
    [[ "${AI_SESSION_TRAP_INSTALLED:-0}" == "1" ]] && return 0

    local existing
    existing="$(trap -p EXIT || true)"

    if [[ -n "$existing" && "${AI_FORCE_SESSION_TRAP:-0}" != "1" ]]; then
        log_warn "existing EXIT trap detected; not installing session.end trap"
        return 0
    fi

    trap agent_session_finish EXIT
    AI_SESSION_TRAP_INSTALLED=1
}

agent_session_init() {
    local name="${1:-${AI_TOOL_NAME:-$(basename "$0" .sh)}}"

    common_require_core

    [[ "${AI_SESSION_INITIALIZED:-0}" == "1" ]] && return 0

    SESSION_ID="${SESSION_ID:-${name}-$(date +%Y%m%d-%H%M%S)-$$}"
    TRACE_ID="${TRACE_ID:-trc-${SESSION_ID}}"
    TASK_ID="${TASK_ID:-tsk-${SESSION_ID}}"
    SESSION_DIR="${COPILOT_SESSION_DIR}/${SESSION_ID}"
    SESSION_LOG="${SESSION_DIR}/session.jsonl"

    mkdir -p "$SESSION_DIR" "$COPILOT_LOG_DIR" "$COPILOT_SNAPSHOT_DIR"

    AI_SESSION_INITIALIZED=1
    export SESSION_ID TRACE_ID TASK_ID SESSION_DIR SESSION_LOG AI_SESSION_INITIALIZED

    log_json "session.start" '{}' "$name" || true

    [[ "$AI_SESSION_AUTO_TRAP" == "1" ]] && install_session_exit_trap
}

require_approval() {
    local action="${1:?action required}"
    local env_name="${2:-AI_APPROVE_DESTRUCTIVE}"

    if [[ "${!env_name:-0}" != "1" ]]; then
        log_json "policy.blocked" "$(jq -cn --arg action "$action" --arg env "$env_name" '{action:$action,required_env:$env}')" "$AI_TOOL_NAME" || true

        if [[ "${AI_OUTPUT:-}" == "json" ]]; then
            emit_blocked_envelope "$action requires explicit approval: set ${env_name}=1"
        else
            log_error "$action requires explicit approval: set ${env_name}=1"
        fi

        exit 2
    fi
}

require_scope_for_write() {
    if [[ "$AI_REQUIRE_SCOPE_FOR_WRITE" == "1" && -z "${AI_TASK_SCOPE:-}" && "${AI_ALLOW_WRITE_WITHOUT_SCOPE:-0}" != "1" ]]; then
        require_approval "write-capable command without AI_TASK_SCOPE" "AI_APPROVE_WRITE_WITHOUT_SCOPE"
    fi
}

command_basename() {
    basename -- "${1:-}"
}

classify_command() {
    local cmd="${1:?command required}"
    local base
    local sub

    base="$(command_basename "$cmd")"
    sub="${2:-}"

    case "$base" in
        rg|fd|fdfind|cat|bat|sed|awk|jq|yq)
            printf 'read\n'
            ;;
        git)
            case "$sub" in
                status|diff|show|log|grep|rev-parse|ls-files|branch)
                    printf 'read\n'
                    ;;
                reset|clean|checkout|restore|apply|merge|rebase|commit|push|pull|fetch)
                    printf 'destructive\n'
                    ;;
                *)
                    printf 'unknown\n'
                    ;;
            esac
            ;;
        rm|rmdir|mv|truncate|dd)
            printf 'destructive\n'
            ;;
        curl|wget|ssh|scp|rsync)
            printf 'network\n'
            ;;
        brew|apt|apt-get|winget|choco)
            printf 'install\n'
            ;;
        npm|pnpm|yarn|composer)
            case "$sub" in
                install|add|update|remove|upgrade|require|global)
                    printf 'install\n'
                    ;;
                test|run|exec|lint|validate|check)
                    printf 'write\n'
                    ;;
                *)
                    printf 'unknown\n'
                    ;;
            esac
            ;;
        php|node|python|python3|bash|sh|zsh|make|just)
            printf 'write\n'
            ;;
        *)
            printf 'unknown\n'
            ;;
    esac
}

approval_env_for_category() {
    case "$1" in
        destructive) printf 'AI_APPROVE_DESTRUCTIVE\n' ;;
        network) printf 'AI_APPROVE_NETWORK\n' ;;
        install) printf 'AI_APPROVE_INSTALL\n' ;;
        unknown) printf 'AI_APPROVE_UNKNOWN_COMMAND\n' ;;
        *) printf '\n' ;;
    esac
}

enforce_command_policy() {
    local label="${1:?label required}"
    local category
    local env_name
    local cmd_json

    shift

    [[ $# -gt 0 ]] || die "no command provided for policy enforcement"

    category="$(classify_command "$@")"
    env_name="$(approval_env_for_category "$category")"
    cmd_json="$(printf '%s\n' "$@" | jq -R . | jq -s .)"

    log_json "policy.command_classified" "$(jq -cn \
        --arg label "$label" \
        --arg category "$category" \
        --argjson command "$cmd_json" \
        '{label:$label,category:$category,command:$command}')" "$AI_TOOL_NAME" || true

    case "$category" in
        read)
            return 0
            ;;
        write)
            require_scope_for_write
            return 0
            ;;
        destructive|network|install|unknown)
            require_approval "command category '$category' for: $*" "$env_name"
            ;;
        *)
            require_approval "unclassified command: $*" "AI_APPROVE_UNKNOWN_COMMAND"
            ;;
    esac
}

guard_command_before_run() {
    local label="${1:?label required}"
    shift

    enforce_command_policy "$label" "$@"
}

realpath_safe() {
    local path="${1:?path required}"

    if command_exists python3; then
        python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$path"
    elif command_exists realpath; then
        realpath "$path"
    else
        (
            cd "$(dirname "$path")"
            printf '%s/%s\n' "$PWD" "$(basename "$path")"
        )
    fi
}

assert_inside_repo() {
    local path="${1:?path required}"
    local root
    local abs

    root="$(realpath_safe "$(repo_root)")"
    abs="$(realpath_safe "$path")"

    case "$abs" in
        "$root"|"$root"/*)
            return 0
            ;;
        *)
            die "path escapes repository root: $path"
            ;;
    esac
}

repo_relative_path() {
    local path="${1:?path required}"
    local root
    local abs

    root="$(realpath_safe "$(repo_root)")"
    abs="$(realpath_safe "$path")"

    case "$abs" in
        "$root")
            printf '.\n'
            ;;
        "$root"/*)
            printf '%s\n' "${abs#"$root"/}"
            ;;
        *)
            die "path escapes repository root: $path"
            ;;
    esac
}

assert_relative_safe_path() {
    local path="${1:?path required}"

    case "$path" in
        ""|/*|../*|*/../*|*"/.."|.git|.git/*)
            die "unsafe relative path: $path"
            ;;
    esac
}

path_matches_protected_pattern() {
    local path="${1:?path required}"
    local lower

    lower="${path,,}"

    case "$lower" in
        .env|.env.*|.github|.github/*|.opencode|.opencode/*|agents.md|claude.md|docs/ai/generated|docs/ai/generated/*|*.key|*.pem|*.crt|*secret*|*token*)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

require_path_write_allowed() {
    local path="${1:?path required}"
    local rel

    rel="$(repo_relative_path "$path")"
    assert_relative_safe_path "$rel"

    if path_matches_protected_pattern "$rel"; then
        require_approval "write to protected path '$rel'" "AI_APPROVE_PROTECTED_PATH"
    fi
}

require_clean_tree() {
    git rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "not inside a git repository"

    if ! git diff --quiet || ! git diff --cached --quiet; then
        die "working tree is not clean; commit or stash changes first"
    fi
}

run_with_timeout() {
    local seconds="${1:?seconds required}"
    local timeout_bin

    shift

    if timeout_bin="$(find_timeout_bin 2>/dev/null)"; then
        "$timeout_bin" "$seconds" "$@"
        return $?
    fi

    if [[ "${AI_ALLOW_NO_TIMEOUT:-0}" == "1" ]]; then
        log_warn "timeout unavailable; AI_ALLOW_NO_TIMEOUT=1, running unbounded"
        "$@"
        return $?
    fi

    log_warn "timeout unavailable; refusing unbounded execution"
    return 124
}

bounded_capture_drain() {
    local max_bytes="${1:?max bytes required}"
    local output_file="${2:?output file required}"
    local truncated_file="${3:?truncated flag file required}"

    require_bins python3

    python3 - "$max_bytes" "$output_file" "$truncated_file" <<'PY'
import sys

max_bytes = int(sys.argv[1])
out_path = sys.argv[2]
flag_path = sys.argv[3]

written = 0
truncated = False
chunk_size = 65536

with open(out_path, "wb") as out:
    while True:
        chunk = sys.stdin.buffer.read(chunk_size)
        if not chunk:
            break

        remaining = max_bytes - written

        if remaining > 0:
            out.write(chunk[:remaining])
            written += min(len(chunk), remaining)

        if len(chunk) > remaining:
            truncated = True

        if written >= max_bytes and chunk:
            truncated = True

with open(flag_path, "w", encoding="utf-8") as f:
    f.write("true" if truncated else "false")
PY
}

wait_for_capture_flag() {
    local file="${1:?file required}"
    local i

    for i in {1..50}; do
        [[ -s "$file" ]] && return 0
        sleep 0.02
    done

    printf 'true\n' >"$file"
}

truncate_file_preview() {
    local file="${1:?file required}"
    local max="${2:-$AI_OUTPUT_MAX_BYTES}"

    head -c "$max" "$file" | redact_sensitive_text || true
}

estimate_file_tokens_fallback() {
    local file="${1:?file required}"
    local bytes

    bytes="$(wc -c <"$file" | tr -d ' ')"
    printf '%s\n' $(((bytes + 3) / 4))
}

estimate_tokens_string() {
    local input="${1:-}"
    local bytes

    bytes="$(printf '%s' "$input" | wc -c | tr -d ' ')"
    printf '%s\n' $(((bytes + 3) / 4))
}

estimate_tokens() {
    local file="${1:?file required}"
    local estimated=""

    if [[ -n "${TOKEN_ESTIMATOR_CMD:-}" ]]; then
        estimated="$($TOKEN_ESTIMATOR_CMD "$file" 2>/dev/null || true)"

        if [[ "$estimated" =~ ^[0-9]+$ ]]; then
            printf '%s\n' "$estimated"
            return 0
        fi

        log_warn "TOKEN_ESTIMATOR_CMD failed; falling back to bytes/4"
    fi

    estimate_file_tokens_fallback "$file"
}

within_token_budget() {
    local file="${1:?file required}"
    local max="${2:-$AI_TOKEN_BUDGET}"
    local tokens

    tokens="$(estimate_tokens "$file")"
    ((tokens <= max))
}

run_logged() {
    local label="${1:?label required}"

    shift

    common_require_core
    require_bins python3

    guard_command_before_run "$label" "$@"

    local timeout_seconds="${AI_CMD_TIMEOUT:-120}"
    local max_bytes="${AI_OUTPUT_MAX_BYTES:-200000}"
    local stdout_file
    local stderr_file
    local stdout_truncated_file
    local stderr_truncated_file
    local started
    local ended
    local exit_code
    local stdout_preview
    local stderr_preview
    local stdout_truncated
    local stderr_truncated
    local cmd_json

    stdout_file="$(mktemp)"
    stderr_file="$(mktemp)"
    stdout_truncated_file="$(mktemp)"
    stderr_truncated_file="$(mktemp)"

    started="$(now_ms)"

    set +e
    run_with_timeout "$timeout_seconds" "$@" \
        > >(bounded_capture_drain "$max_bytes" "$stdout_file" "$stdout_truncated_file") \
        2> >(bounded_capture_drain "$max_bytes" "$stderr_file" "$stderr_truncated_file")
    exit_code=$?
    set -e

    wait_for_capture_flag "$stdout_truncated_file"
    wait_for_capture_flag "$stderr_truncated_file"

    ended="$(now_ms)"

    stdout_preview="$(truncate_file_preview "$stdout_file" "$max_bytes")"
    stderr_preview="$(truncate_file_preview "$stderr_file" "$max_bytes")"
    stdout_truncated="$(cat "$stdout_truncated_file")"
    stderr_truncated="$(cat "$stderr_truncated_file")"
    cmd_json="$(printf '%s\n' "$@" | jq -R . | jq -s .)"

    log_json "tool.run" "$(jq -cn \
        --arg label "$label" \
        --argjson command "$cmd_json" \
        --argjson exit_code "$exit_code" \
        --argjson latency_ms "$((ended - started))" \
        --arg stdout_preview "$stdout_preview" \
        --arg stderr_preview "$stderr_preview" \
        --argjson stdout_truncated "$stdout_truncated" \
        --argjson stderr_truncated "$stderr_truncated" \
        '{
            label: $label,
            command: $command,
            exit_code: $exit_code,
            latency_ms: $latency_ms,
            stdout_preview: $stdout_preview,
            stderr_preview: $stderr_preview,
            stdout_truncated: $stdout_truncated,
            stderr_truncated: $stderr_truncated
        }')" "$AI_TOOL_NAME" || true

    if [[ "$AI_REDACT_STDOUT" == "1" ]]; then
        redact_sensitive_text <"$stdout_file"
    else
        cat "$stdout_file"
    fi

    rm -f "$stdout_file" "$stderr_file" "$stdout_truncated_file" "$stderr_truncated_file"
    return "$exit_code"
}

run_json_command() {
    local label="${1:?label required}"
    local output
    local exit_code

    shift

    set +e
    output="$(run_logged "$label" "$@")"
    exit_code=$?
    set -e

    if ((exit_code != 0)); then
        emit_envelope "error" "$label" '{}' '[]' "$(jq -cn --arg msg "command failed with exit code $exit_code" '[$msg]')" 0 false
        return "$exit_code"
    fi

    if jq -e . >/dev/null 2>&1 <<<"$output"; then
        printf '%s\n' "$output"
    else
        emit_envelope "error" "$label" '{}' '[]' "$(jq -cn --arg msg 'command did not emit valid JSON' '[$msg]')" 0 false
        return 2
    fi
}