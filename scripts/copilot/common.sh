#!/usr/bin/env bash
# Shared library for repository AI tooling scripts.

set -euo pipefail

COPILOT_LOG_DIR="${COPILOT_LOG_DIR:-.copilot-logs}"
COPILOT_CONTEXT_DIR="${COPILOT_CONTEXT_DIR:-.repomix-context}"
COPILOT_SESSION_DIR="${COPILOT_SESSION_DIR:-${COPILOT_LOG_DIR}/sessions}"
COPILOT_SNAPSHOT_DIR="${COPILOT_SNAPSHOT_DIR:-${COPILOT_LOG_DIR}/snapshots}"

if [[ -z "${NO_COLOR:-}" ]] && [[ -t 2 ]]; then
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

agent_session_init() {
    local name="${1:-$(basename "$0" .sh)}"
    SESSION_ID="${SESSION_ID:-${name}-$(date +%Y%m%d-%H%M%S)-$$}"
    SESSION_DIR="${COPILOT_SESSION_DIR}/${SESSION_ID}"
    SESSION_LOG="${SESSION_DIR}/session.jsonl"
    mkdir -p "$SESSION_DIR" "$COPILOT_LOG_DIR" "$COPILOT_SNAPSHOT_DIR"
    log_json "session.start" '{}' || true
}

log_json() {
    local event="${1:-event}"
    local payload="${2:-{}}"
    local entry
    entry="$(jq -cn \
        --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        --arg session "${SESSION_ID:-unknown}" \
        --arg script "$(basename "${BASH_SOURCE[1]:-unknown}")" \
        --arg event "$event" \
        --argjson data "$payload" \
        '{ts:$ts, session:$session, script:$script, event:$event, data:$data}')"
    mkdir -p "$COPILOT_LOG_DIR"
    printf '%s\n' "$entry" >>"${COPILOT_LOG_DIR}/tool-usage.jsonl"
    if [[ -n "${SESSION_LOG:-}" ]]; then
        printf '%s\n' "$entry" >>"$SESSION_LOG"
    fi
}

log_info() { printf '%b[INFO]%b  %s\n' "$_C_CYAN" "$_C_RESET" "$*" >&2; }
log_ok() { printf '%b[OK]%b    %s\n' "$_C_GREEN" "$_C_RESET" "$*" >&2; }
log_warn() { printf '%b[WARN]%b  %s\n' "$_C_YELLOW" "$_C_RESET" "$*" >&2; }
log_error() { printf '%b[ERROR]%b %s\n' "$_C_RED" "$_C_RESET" "$*" >&2; }

die() {
    log_error "$*"
    log_json "error" "$(jq -cn --arg msg "$*" '{msg:$msg}')" || true
    exit 1
}

section() {
    printf '\n%b==> %s%b\n' "$_C_BOLD" "$*" "$_C_RESET" >&2
}

require_bins() {
    local missing=()
    local bin
    for bin in "$@"; do
        command -v "$bin" >/dev/null 2>&1 || missing+=("$bin")
    done
    if ((${#missing[@]} > 0)); then
        die "required tools not found: ${missing[*]}"
    fi
}

require_clean_tree() {
    git rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "not inside a git repository"
    if ! git diff --quiet || ! git diff --cached --quiet; then
        die "working tree is not clean; commit or stash changes first"
    fi
}

git_root() {
    git rev-parse --show-toplevel 2>/dev/null || pwd
}

run_with_timeout() {
    local seconds="${1:?seconds required}"
    shift
    local timeout_bin=""
    if command -v gtimeout >/dev/null 2>&1; then
        timeout_bin="gtimeout"
    elif command -v timeout >/dev/null 2>&1; then
        timeout_bin="timeout"
    fi

    if [[ -n "$timeout_bin" ]]; then
        "$timeout_bin" "$seconds" "$@"
    else
        "$@"
    fi
}

estimate_tokens() {
    local file="${1:?file required}"
    local bytes
    bytes="$(wc -c <"$file" | tr -d ' ')"
    echo $((bytes / 4))
}

within_token_budget() {
    local file="${1:?file required}"
    local max="${2:-128000}"
    local tokens
    tokens="$(estimate_tokens "$file")"
    ((tokens <= max))
}

secrets_scan() {
    local target="${1:-.}"
    if command -v gitleaks >/dev/null 2>&1; then
        gitleaks detect --source "$target" --redact --no-banner --exit-code 1 >/dev/null 2>&1
    else
        log_warn "gitleaks not installed; skipping secrets scan"
        return 0
    fi
}

snapshot_create() {
    local label="${1:-snap}"
    local session="${SESSION_ID:-manual}"
    local snap_file
    snap_file="${COPILOT_SNAPSHOT_DIR}/${session}-${label}-$(date +%H%M%S).patch"
    mkdir -p "$COPILOT_SNAPSHOT_DIR"
    git diff --binary HEAD >"$snap_file"
    if [[ ! -s "$snap_file" ]]; then
        git rev-parse HEAD >"${snap_file%.patch}.ref"
        rm -f "$snap_file"
        snap_file="${snap_file%.patch}.ref"
    fi
    log_json "snapshot.create" "$(jq -cn --arg file "$snap_file" '{file:$file}')" || true
    printf '%s\n' "$snap_file"
}

snapshot_apply() {
    local snap_file="${1:?snapshot file required}"
    [[ -f "$snap_file" ]] || die "snapshot not found: $snap_file"
    if [[ "$snap_file" == *.ref ]]; then
        local ref
        ref="$(<"$snap_file")"
        git checkout "$ref" -- .
    else
        git apply --whitespace=fix "$snap_file"
    fi
    log_json "snapshot.apply" "$(jq -cn --arg file "$snap_file" '{file:$file}')" || true
}
