#!/usr/bin/env bash
# Idempotent installer for the Linux/macOS ssh-agent auto-loader.
#
# What it does:
#   1. Detects the current shell (bash / zsh / fish) and OS (Linux / Darwin).
#   2. On Linux, ensures `keychain` is available (or warns how to install it).
#   3. On macOS, ensures ~/.ssh/config has `UseKeychain yes` and
#      `AddKeysToAgent yes` for Host *.
#   4. Copies the appropriate snippet from the chezmoi source tree
#      (home/dot_config/app-configs/ssh-agent.sh and
#      home/dot_config/fish/conf.d/ssh-agent.fish) into the right deploy
#      location.
#   5. Adds a single source line to the user's rc file (bash/zsh) if not
#      already present. Fish is auto-loaded from conf.d.
#
# Re-runnable. Pass --remove to uninstall.
#
# Usage:
#   bash ops/unix/ssh-agent-setup.sh             # install
#   bash ops/unix/ssh-agent-setup.sh --remove    # uninstall
#   APP_CONFIGS_SSH_KEYS="<github-key> work" \
#       bash ops/unix/ssh-agent-setup.sh         # set default key list

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && cd .. && pwd)"
# Bash/zsh snippet lives at home/dot_config/app-configs/ssh-agent.sh and the
# fish snippet at home/dot_config/fish/conf.d/ssh-agent.fish (chezmoi source
# tree). The deployed paths under $HOME are $DEPLOY_DIR/ssh-agent.sh and
# $HOME/.config/fish/conf.d/ssh-agent.fish, set by chezmoi or by this script
# when chezmoi is not in use.
SNIPPET_SH="$ROOT_DIR/home/dot_config/app-configs/ssh-agent.sh"
SNIPPET_FISH="$ROOT_DIR/home/dot_config/fish/conf.d/ssh-agent.fish"
DEPLOY_DIR="$HOME/.config/app-configs"
MARKER_BEGIN="# >>> app-configs ssh-agent >>>"
MARKER_END="# <<< app-configs ssh-agent <<<"

log()  { printf '[ssh-agent-setup] %s\n' "$*"; }
warn() { printf '[ssh-agent-setup][WARN] %s\n' "$*" >&2; }
die()  { printf '[ssh-agent-setup][ERROR] %s\n' "$*" >&2; exit 1; }

usage() {
    printf 'Usage: %s [--remove|-r | --help|-h]\n' "${0##*/}"
}

# Exactly zero or one known flag; anything else is a typo that must not
# silently run an install.
ACTION="install"
case "$#:${1:-}" in
    0:)             ;;
    1:--remove|1:-r) ACTION="remove" ;;
    1:--help|1:-h)  usage; exit 0 ;;
    *)              usage >&2; warn "unknown or extra argument(s): $*"; exit 2 ;;
esac

detect_os() {
    case "$(uname -s)" in
        Darwin) echo darwin ;;
        Linux)  echo linux ;;
        *)      echo unknown ;;
    esac
}

# Detect which interactive shell config to wire into. APP_CONFIGS_SSH_SHELL
# (bash|zsh|fish) overrides; otherwise prefer the user's login shell from
# /etc/passwd and fall back to $SHELL. An unsupported shell is an error, not
# a silent bash default that would edit the wrong rc file.
detect_shell() {
    local sh name
    sh="${APP_CONFIGS_SSH_SHELL:-}"
    if [ -z "$sh" ]; then
        sh="$(getent passwd "$USER" 2>/dev/null | awk -F: '{print $7}' || true)"
        [ -n "$sh" ] || sh="${SHELL:-}"
    fi
    name="$(basename "$sh")"
    case "$name" in
        fish|zsh|bash) echo "$name" ;;
        *) die "Unsupported shell '$name'. Set APP_CONFIGS_SSH_SHELL=bash|zsh|fish to choose which rc file to wire." ;;
    esac
}

# strip_block <file>: print <file> without the managed block (and the one
# blank separator line right before it). Fails unless
# the markers are well formed: at most one begin/end pair, begin before end,
# no nesting, no stray or unterminated marker. This keeps a damaged file from
# being truncated.
strip_block() {
    awk -v b="$MARKER_BEGIN" -v e="$MARKER_END" '
        function fail(msg) { print msg > "/dev/stderr"; bad = 1; exit 2 }
        $0 == b { if (inb)  fail("nested begin marker")
                  if (seen) fail("duplicate begin marker")
                  held = 0   # the blank separator the installer wrote
                  inb = 1; seen = 1; next }
        $0 == e { if (!inb) fail("end marker without begin marker")
                  inb = 0; next }
        inb     { next }
        $0 == "" { if (held) print ""; held = 1; next }
                { if (held) print ""; held = 0; print }
        END     { if (bad) exit 2
                  if (inb) { print "begin marker without end marker" > "/dev/stderr"; exit 2 }
                  if (held) print "" }
    ' "$1"
}

# remove_block <file>: drop the managed block in place. Aborts the whole run,
# leaving the file untouched, when the markers are not a single clean pair.
# Writes through `cat >` so the file keeps its mode, owner and symlink.
remove_block() {
    local f="$1" tmp bak
    [ -f "$f" ] || return 0
    grep -qF -e "$MARKER_BEGIN" -e "$MARKER_END" "$f" || return 0
    tmp="$(mktemp "${TMPDIR:-/tmp}/ssh-agent-setup.XXXXXX")"
    if ! strip_block "$f" >"$tmp"; then
        rm -f "$tmp"
        die "$f has missing, duplicate or nested app-configs ssh-agent markers; fix it by hand. $f was not changed."
    fi
    # The in-place write is not atomic, so keep the original until the result
    # is verified. On failure the backup is kept and its path is reported.
    bak="$(mktemp "${TMPDIR:-/tmp}/ssh-agent-setup.backup.XXXXXX")"
    cp "$f" "$bak"
    if ! cat "$tmp" >"$f" || ! cmp -s "$tmp" "$f"; then
        rm -f "$tmp"
        die "Rewriting $f failed; the original is saved as backup $bak. Restore it with: cat '$bak' > '$f'"
    fi
    rm -f "$tmp" "$bak"
}

# The installer owns only the marked block, never other lines. The directive
# order matters: IgnoreUnknown must come before UseKeychain so non-Apple ssh
# builds do not reject the unknown option.
ensure_macos_ssh_config() {
    local cfg="$HOME/.ssh/config"
    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"
    if [ ! -f "$cfg" ]; then
        (umask 077; : > "$cfg")
    fi
    remove_block "$cfg"
    # ssh keeps the first IgnoreUnknown it sees; one earlier than our block
    # that does not list UseKeychain would override ours.
    if grep -iE '^[[:space:]]*IgnoreUnknown[[:space:]]' "$cfg" | grep -viq 'UseKeychain'; then
        warn "$cfg has an IgnoreUnknown line without UseKeychain; ssh uses the first one, so add UseKeychain to it."
    fi
    log "Writing managed 'Host *' Keychain block in ~/.ssh/config"
    {
        printf '\n%s\n' "$MARKER_BEGIN"
        printf 'Host *\n'
        printf '    AddKeysToAgent yes\n'
        printf '    IgnoreUnknown UseKeychain\n'
        printf '    UseKeychain yes\n'
        printf '%s\n' "$MARKER_END"
    } >> "$cfg"
}

remove_macos_ssh_config_block() {
    remove_block "$HOME/.ssh/config"
}

check_keychain_linux() {
    if command -v keychain >/dev/null 2>&1; then
        log "Found 'keychain' on PATH (preferred)."
        return 0
    fi
    warn "'keychain' not installed. Snippet will fall back to a plain shared agent."
    warn "Install it for the best UX (passphrase asked once per boot):"
    if command -v apt-get >/dev/null 2>&1; then
        warn "  sudo apt-get install -y keychain"
    elif command -v dnf >/dev/null 2>&1; then
        warn "  sudo dnf install -y keychain"
    elif command -v pacman >/dev/null 2>&1; then
        warn "  sudo pacman -S --needed keychain"
    elif command -v zypper >/dev/null 2>&1; then
        warn "  sudo zypper install -y keychain"
    fi
}

# chezmoi_managed <path>: true when chezmoi owns the target. Such files must
# never be edited here: chezmoi would see a hand edit (sys-update then
# refuses to run) and the next apply would undo it anyway. The managed rc
# templates already source the loader.
chezmoi_managed() {
    command -v chezmoi >/dev/null 2>&1 && chezmoi source-path "$1" >/dev/null 2>&1
}

install_posix_snippet() {
    local rc="$1"  # path to ~/.bashrc or ~/.zshrc
    if chezmoi_managed "$DEPLOY_DIR/ssh-agent.sh"; then
        log "$DEPLOY_DIR/ssh-agent.sh is managed by chezmoi; not copying it."
    else
        mkdir -p "$DEPLOY_DIR"
        install -m 0644 "$SNIPPET_SH" "$DEPLOY_DIR/ssh-agent.sh"
        log "Installed snippet to $DEPLOY_DIR/ssh-agent.sh"
    fi
    if chezmoi_managed "$rc"; then
        log "$rc is managed by chezmoi and already sources the loader; not editing it."
        return 0
    fi

    touch "$rc"
    if grep -qF "$MARKER_BEGIN" "$rc"; then
        log "Source block already present in $rc; refreshing."
    fi
    remove_block "$rc"
    {
        printf '\n%s\n' "$MARKER_BEGIN"
        if [ -n "${APP_CONFIGS_SSH_KEYS:-}" ]; then
            printf 'export APP_CONFIGS_SSH_KEYS=%q\n' "$APP_CONFIGS_SSH_KEYS"
        fi
        # Literal $HOME so the rc stays portable across home paths.
        # shellcheck disable=SC2016
        printf '%s\n' '[ -f "$HOME/.config/app-configs/ssh-agent.sh" ] && . "$HOME/.config/app-configs/ssh-agent.sh"'
        printf '%s\n' "$MARKER_END"
    } >> "$rc"
    log "Wired $rc to source the snippet."
}

# remove_installed_file <path> <repo-source>: delete a deployed loader only
# when this installer created it. chezmoi-managed files are never touched, and
# a file that differs from the repo snippet was written by someone else.
remove_installed_file() {
    local path="$1" src="$2"
    [ -f "$path" ] || return 0
    if chezmoi_managed "$path"; then
        log "$path is managed by chezmoi; keeping it."
    elif cmp -s "$path" "$src"; then
        rm -f "$path"
        log "Removed $path"
    else
        warn "$path differs from the installer's copy; keeping it."
    fi
}

remove_posix_snippet() {
    local rc="$1"
    [ -f "$rc" ] || return 0
    if chezmoi_managed "$rc"; then
        return 0
    fi
    remove_block "$rc"
    log "Removed snippet block from $rc (if present)"
}

install_fish_snippet() {
    local conf_d="$HOME/.config/fish/conf.d"
    if chezmoi_managed "$conf_d/ssh-agent.fish"; then
        log "$conf_d/ssh-agent.fish is managed by chezmoi; not overwriting it."
    else
        mkdir -p "$conf_d"
        install -m 0644 "$SNIPPET_FISH" "$conf_d/ssh-agent.fish"
        log "Installed snippet to $conf_d/ssh-agent.fish"
    fi
    if [[ "${APP_CONFIGS_SSH_KEYS:-}" =~ [^[:space:]] ]] && command -v fish >/dev/null 2>&1; then
        # The value travels as argv ($argv[1]) and is split on whitespace
        # into a fish list; it is never parsed as fish code. The `--` ends
        # fish's own option parsing so a value such as --init-command=... is
        # data too.
        # shellcheck disable=SC2016
        fish -c 'set -Ux APP_CONFIGS_SSH_KEYS (string match -r -a "\S+" -- $argv[1])' \
            -- "$APP_CONFIGS_SSH_KEYS" \
            || die "fish failed to set APP_CONFIGS_SSH_KEYS"
        log "Set fish universal var APP_CONFIGS_SSH_KEYS"
    fi
}

remove_fish_snippet() {
    remove_installed_file "$HOME/.config/fish/conf.d/ssh-agent.fish" "$SNIPPET_FISH"
}

main() {
    local os shell rc
    os="$(detect_os)"
    log "OS=$os  action=$ACTION"

    if [ "$ACTION" = "install" ]; then
        # Resolve the shell first so an unsupported one aborts before any
        # file is touched. --remove needs no shell: it cleans every rc.
        shell="$(detect_shell)"
        log "shell=$shell"
        case "$os" in
            darwin) ensure_macos_ssh_config ;;
            linux)  check_keychain_linux ;;
            *)      warn "Unknown OS; proceeding with generic POSIX setup." ;;
        esac

        case "$shell" in
            fish)
                install_fish_snippet
                ;;
            zsh)
                rc="$HOME/.zshrc"
                install_posix_snippet "$rc"
                ;;
            bash)
                if [ "$os" = "darwin" ] && [ -f "$HOME/.bash_profile" ]; then
                    install_posix_snippet "$HOME/.bash_profile"
                else
                    install_posix_snippet "$HOME/.bashrc"
                fi
                ;;
            *)
                die "Unsupported shell '$shell'." ;;
        esac

        log "Done. Open a new terminal to activate."
    else
        remove_posix_snippet "$HOME/.bashrc"
        remove_posix_snippet "$HOME/.bash_profile"
        remove_posix_snippet "$HOME/.zshrc"
        remove_installed_file "$DEPLOY_DIR/ssh-agent.sh" "$SNIPPET_SH"
        remove_fish_snippet
        [ "$os" = "darwin" ] && remove_macos_ssh_config_block
        rmdir "$DEPLOY_DIR" 2>/dev/null || true
        log "Uninstall complete."
    fi
}

main "$@"
