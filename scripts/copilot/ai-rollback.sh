#!/usr/bin/env bash
# Review and apply repository-local rollback snapshots created by AI tooling sessions.

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

SNAPSHOT_DIR="${COPILOT_SNAPSHOT_DIR:-.copilot-logs/snapshots}"

usage() {
    cat <<'EOF'
Usage:
  ai-rollback.sh list
  ai-rollback.sh show SESSION_OR_SNAPSHOT
  ai-rollback.sh apply SESSION_OR_SNAPSHOT
  ai-rollback.sh prune [--days N]
EOF
}

resolve_snapshot() {
    local input="$1"
    if [[ -f "$input" ]]; then
        printf '%s\n' "$input"
        return 0
    fi

    local match
    match="$(find "$SNAPSHOT_DIR" -maxdepth 1 \( -name "${input}*.patch" -o -name "${input}*.ref" \) | sort -r | head -1)"
    [[ -n "$match" ]] || die "no snapshot found matching: $input"
    printf '%s\n' "$match"
}

cmd_list() {
    if [[ ! -d "$SNAPSHOT_DIR" ]]; then
        log_warn "No snapshot directory found at $SNAPSHOT_DIR"
        exit 0
    fi

    local count=0
    printf '%-55s  %-12s  %s\n' "SNAPSHOT" "SIZE" "DATE"
    printf '%s\n' "$(printf '=%.0s' {1..80})"

    while IFS= read -r snap; do
        local base size ts
        base="$(basename "$snap")"
        size="$(du -sh "$snap" 2>/dev/null | cut -f1)"
        ts="$(stat -c '%y' "$snap" 2>/dev/null | cut -c1-16 || stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$snap" 2>/dev/null)"
        printf '%-55s  %-12s  %s\n' "$base" "$size" "$ts"
        count=$((count + 1))
    done < <(find "$SNAPSHOT_DIR" -maxdepth 1 \( -name '*.patch' -o -name '*.ref' \) | sort -r)

    printf '\n%d snapshot(s) found\n' "$count"
}

cmd_show() {
    local input="${1:?session or snapshot required}"
    local snap
    snap="$(resolve_snapshot "$input")"
    log_info "Snapshot: $snap"

    if [[ "$snap" == *.ref ]]; then
        local ref
        ref="$(<"$snap")"
        log_info "Type: ref"
        git show --stat "$ref"
    else
        log_info "Type: patch"
        git apply --stat "$snap" 2>/dev/null || sed -n '1,120p' "$snap"
    fi
}

cmd_apply() {
    local input="${1:?session or snapshot required}"
    local snap
    snap="$(resolve_snapshot "$input")"

    log_warn "Rollback modifies the working tree. Use only with explicit approval for destructive recovery actions."
    if [[ -t 0 ]] && [[ "${CI:-}" != "true" ]]; then
        printf '%b[WARN]%b Continue with rollback? [y/N] ' "$_C_YELLOW" "$_C_RESET" >&2
        read -r confirm
        [[ "$confirm" =~ ^[Yy]$ ]] || {
            log_info "Aborted."
            exit 0
        }
    fi

    snapshot_apply "$snap"
    log_ok "Rollback applied"
    git --no-pager diff --stat || true
    log_json "rollback.apply" "$(jq -cn --arg snapshot "$snap" '{snapshot:$snapshot}')"
}

cmd_prune() {
    local days=14
    while [[ $# -gt 0 ]]; do
        case "$1" in
        --days)
            days="$2"
            shift 2
            ;;
        --days=*)
            days="${1#*=}"
            shift
            ;;
        *) die "unknown option: $1" ;;
        esac
    done

    log_info "Pruning snapshots older than $days days"
    local count=0
    while IFS= read -r snap; do
        rm -f "$snap"
        count=$((count + 1))
    done < <(find "$SNAPSHOT_DIR" -maxdepth 1 \( -name '*.patch' -o -name '*.ref' \) -mtime +"$days" 2>/dev/null)
    log_ok "Pruned $count snapshot(s)"
}

cmd="${1:-}"
[[ -n "$cmd" ]] || {
    usage
    exit 1
}
shift || true

case "$cmd" in
list) cmd_list ;;
show) cmd_show "${1:-}" ;;
apply) cmd_apply "${1:-}" ;;
prune) cmd_prune "$@" ;;
--help | -h) usage ;;
*)
    usage
    die "unknown command: $cmd"
    ;;
esac
