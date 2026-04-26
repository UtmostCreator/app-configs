#!/usr/bin/env bash
# Guarded edit wrapper for broad repository modifications.

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

usage() {
    cat <<'EOF'
Usage:
  ai-edit.sh ast-grep LANG PATTERN REWRITE [root]
  ai-edit.sh comby MATCH REWRITE [root]
  ai-edit.sh sd FROM TO [root]

Environment:
  APPLY=1
  VERIFY=1
EOF
}

show_diff() {
    git --no-pager diff --stat
    git --no-pager diff --color=always | sed -n '1,240p'
}

write_session_manifest() {
    local status="$1"
    local manifest_path="$SESSION_DIR/edit-session.json"
    local changed_files_json='[]'

    if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        changed_files_json="$(git diff --name-only | jq -R . | jq -s .)"
    fi

    jq -n \
        --arg session "${SESSION_ID:-unknown}" \
        --arg mode "$mode" \
        --arg root "$root" \
        --arg status "$status" \
        --arg snapshot "$snapshot" \
        --arg apply "$apply" \
        --arg verify "$verify" \
        --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        --argjson changedFiles "$changed_files_json" \
        '{
      session: $session,
      mode: $mode,
      root: $root,
      status: $status,
      snapshot: $snapshot,
      apply: ($apply == "1"),
      verify: ($verify == "1"),
      ts: $ts,
      changedFiles: $changedFiles
    }' >"$manifest_path"

    log_json "edit.manifest" "$(cat "$manifest_path")"
}

mode="${1:-}"
[[ -n "$mode" ]] || {
    usage
    exit 2
}
shift || true

agent_session_init "ai-edit"
require_clean_tree
snapshot="$(snapshot_create pre-edit)"
log_info "Snapshot: $snapshot"

apply="${APPLY:-0}"
verify="${VERIFY:-0}"
root='.'

case "$mode" in
ast-grep)
    require_bins ast-grep
    lang="${1:?lang required}"
    pattern="${2:?pattern required}"
    rewrite="${3:?rewrite required}"
    root="${4:-.}"

    if [[ "$apply" == "1" ]]; then
        ast-grep run --lang "$lang" --pattern "$pattern" --rewrite "$rewrite" "$root" --update-all
    else
        write_session_manifest "dry-run"
        ast-grep run --lang "$lang" --pattern "$pattern" --rewrite "$rewrite" "$root"
        printf '\nDry-run only. Re-run with APPLY=1 to modify files.\n'
        exit 0
    fi
    ;;
comby)
    require_bins comby
    match="${1:?match required}"
    rewrite="${2:?rewrite required}"
    root="${3:-.}"

    if [[ "$apply" == "1" ]]; then
        comby "$match" "$rewrite" -matcher .generic -in-place "$root"
    else
        write_session_manifest "dry-run"
        comby "$match" "$rewrite" -matcher .generic "$root"
        printf '\nDry-run only. Re-run with APPLY=1 to modify files.\n'
        exit 0
    fi
    ;;
sd)
    require_bins rg sd
    from="${1:?from required}"
    to="${2:?to required}"
    root="${3:-.}"

    if [[ "$apply" == "1" ]]; then
        mapfile -t files < <(rg -l --hidden -g '!vendor' -g '!node_modules' -g '!dist' -g '!.git' "$from" "$root")
        ((${#files[@]} > 0)) || die "no files matched replacement pattern"
        for target_file in "${files[@]}"; do
            sd "$from" "$to" "$target_file"
        done
    else
        write_session_manifest "dry-run"
        rg -n --hidden -g '!vendor' -g '!node_modules' -g '!dist' -g '!.git' "$from" "$root"
        printf '\nDry-run only. Re-run with APPLY=1 to modify files.\n'
        exit 0
    fi
    ;;
*)
    usage
    die "unknown mode: $mode"
    ;;
esac

show_diff
write_session_manifest "applied"
log_json "edit.apply" "$(jq -cn --arg mode "$mode" --arg snapshot "$snapshot" '{mode:$mode, snapshot:$snapshot}')"

if [[ "$verify" == "1" ]]; then
    "$(dirname "${BASH_SOURCE[0]}")/ai-verify.sh" .
fi
