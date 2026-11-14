# shellcheck shell=bash
# Helpers shared by the contract tests (arg-contract, path-contract,
# managed-writers, single-owner). Load with: load ../lib/contract
#
# repo_files [PATHSPEC...]  tracked + untracked (not ignored) files that exist
#                           in the working tree, one per line, repo-relative.
# repo_copy DEST            copy that file set to DEST, so a test can inject a
#                           bug into the copy and prove the check notices it.
# entry_scripts ROOT        scripts reachable from an entry point (see below).
# mise_run_blocks ROOT      the text of every `run = ...` block in mise.toml.

repo_files() {
    local f
    git -C "$REPO_ROOT" ls-files --cached --others --exclude-standard -- "$@" |
        while IFS= read -r f; do [ -e "$REPO_ROOT/$f" ] && printf '%s\n' "$f"; done
}

repo_copy() {
    mkdir -p "$1"
    repo_files | tar -C "$REPO_ROOT" -cf - -T - | tar -C "$1" -xf -
}

# From `run =` to the next table header: the commands, not the descriptions.
mise_run_blocks() {
    awk '/^\[tasks/{r=0} /^run = /{r=1} r' "$1/mise.toml"
}

# Scripts reachable from an entry point, relative to ROOT, one per line.
# Entry points: `run =` blocks in mise.toml, the helpers shipped in
# home/dot_local/bin (plain files), the ops script each templated wrapper
# (sys-*.tmpl, vicinae-ext.tmpl) execs, and the scripts fish functions and zsh
# aliases call. ops/lib/* are sourced libraries, not entry points.
entry_scripts() {
    local root="$1" f
    {
        mise_run_blocks "$root" |
            grep -oE '(^|[^A-Za-z0-9_./-])(ops|scripts)/[A-Za-z0-9_./-]+\.(sh|py)' |
            grep -oE '(ops|scripts)/[A-Za-z0-9_./-]+\.(sh|py)'
        (cd "$root" && ls home/dot_local/bin/executable_* 2>/dev/null) | grep -v '\.tmpl$'
        for f in "$root"/home/dot_local/bin/executable_*.tmpl \
                 "$root"/home/dot_config/fish/conf.d/*.tmpl \
                 "$root"/home/dot_config/fish/conf.d/*.fish \
                 "$root"/home/dot_ws.zsh.tmpl; do
            [ -f "$f" ] || continue
            sed -E \
                -e 's#\$\{?(WS_PROJECTS_DIR)\}?#ops/projects#g' \
                -e 's#\$\{?(WS_LOGGING_DIR)\}?#ops/projects/logging#g' \
                -e 's#\$\{?(WS_HEALTH_DIR)\}?#ops/projects/health#g' \
                -e 's#\$\{?(DOTFILES_DIR|dots)\}?/##g' "$f" |
                grep -oE '(^|[^A-Za-z0-9_./-])(ops|scripts)/[A-Za-z0-9_./-]+\.sh' |
                grep -oE '(ops|scripts)/[A-Za-z0-9_./-]+\.sh'
        done
    } | grep -v '^ops/lib/' | sort -u |
        while IFS= read -r s; do [ -f "$root/$s" ] && printf '%s\n' "$s"; done
}
