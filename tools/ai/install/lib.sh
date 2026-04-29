#!/usr/bin/env bash
set -euo pipefail

install_log() {
    printf '[install-ai-kit] %s\n' "$*"
}

install_die() {
    printf 'Error: %s\n' "$*" >&2
    exit 1
}

normalize_bool() {
    case "${1:-0}" in
    1 | true | TRUE | yes | YES) printf '1\n' ;;
    *) printf '0\n' ;;
    esac
}

copy_file() {
    local source_root="$1"
    local target_root="$2"
    local force="$3"
    local dry_run="$4"
    local src_rel="$5"
    local dest_rel="$6"
    local src="$source_root/$src_rel"
    local dest="$target_root/$dest_rel"

    [[ -f "$src" ]] || install_die "missing source file: $src_rel"

    if [[ -f "$dest" && "$force" -ne 1 ]]; then
        install_log "skip existing file (use --force to overwrite): $dest_rel"
        return 0
    fi

    if [[ "$dry_run" -eq 1 ]]; then
        install_log "copy file: $src_rel -> $dest_rel"
        return 0
    fi

    mkdir -p "$(dirname "$dest")"
    cp "$src" "$dest"
    install_log "copied file: $dest_rel"
}

copy_dir() {
    local source_root="$1"
    local target_root="$2"
    local force="$3"
    local dry_run="$4"
    local src_rel="$5"
    local dest_rel="$6"
    local src="$source_root/$src_rel"
    local dest="$target_root/$dest_rel"

    [[ -d "$src" ]] || install_die "missing source directory: $src_rel"

    if [[ -e "$dest" && "$force" -ne 1 ]]; then
        install_log "skip existing directory (use --force to overwrite): $dest_rel"
        return 0
    fi

    if [[ "$dry_run" -eq 1 ]]; then
        install_log "copy directory: $src_rel -> $dest_rel"
        return 0
    fi

    rm -rf "$dest"
    mkdir -p "$(dirname "$dest")"
    cp -R "$src" "$dest"
    install_log "copied directory: $dest_rel"
}
