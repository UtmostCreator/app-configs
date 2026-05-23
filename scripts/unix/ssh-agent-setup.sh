#!/usr/bin/env bash
# Idempotent installer for the Linux/macOS ssh-agent auto-loader.
#
# What it does:
#   1. Detects the current shell (bash / zsh / fish) and OS (Linux / Darwin).
#   2. On Linux, ensures `keychain` is available (or warns how to install it).
#   3. On macOS, ensures ~/.ssh/config has `UseKeychain yes` and
#      `AddKeysToAgent yes` for Host *.
#   4. Copies the appropriate snippet from configs/shell/ssh-agent/ into
#      the right deploy location.
#   5. Adds a single source line to the user's rc file (bash/zsh) if not
#      already present. Fish is auto-loaded from conf.d.
#
# Re-runnable. Pass --remove to uninstall.
#
# Usage:
#   bash scripts/unix/ssh-agent-setup.sh             # install
#   bash scripts/unix/ssh-agent-setup.sh --remove    # uninstall
#   APP_CONFIGS_SSH_KEYS="github.uc.ll5 work" \
#       bash scripts/unix/ssh-agent-setup.sh         # set default key list

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && cd .. && pwd)"
SNIPPET_DIR="$ROOT_DIR/configs/shell/ssh-agent"
DEPLOY_DIR="$HOME/.config/app-configs"
MARKER_BEGIN="# >>> app-configs ssh-agent >>>"
MARKER_END="# <<< app-configs ssh-agent <<<"

ACTION="install"
if [ "${1:-}" = "--remove" ] || [ "${1:-}" = "-r" ]; then
    ACTION="remove"
fi

log()  { printf '[ssh-agent-setup] %s\n' "$*"; }
warn() { printf '[ssh-agent-setup][WARN] %s\n' "$*" >&2; }
die()  { printf '[ssh-agent-setup][ERROR] %s\n' "$*" >&2; exit 1; }

detect_os() {
    case "$(uname -s)" in
        Darwin) echo darwin ;;
        Linux)  echo linux ;;
        *)      echo unknown ;;
    esac
}

# Detect which interactive shell config to wire into. Prefer the user's
# login shell from /etc/passwd; fall back to $SHELL.
detect_shell() {
    local sh
    sh="$(getent passwd "$USER" 2>/dev/null | awk -F: '{print $7}' || true)"
    [ -n "$sh" ] || sh="${SHELL:-}"
    case "$(basename "$sh")" in
        fish) echo fish ;;
        zsh)  echo zsh ;;
        bash) echo bash ;;
        *)    echo bash ;;
    esac
}

ensure_macos_ssh_config() {
    local cfg="$HOME/.ssh/config"
    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"
    [ -f "$cfg" ] || { umask 077; : > "$cfg"; }
    if ! grep -qE '^[[:space:]]*UseKeychain[[:space:]]+yes' "$cfg"; then
        log "Adding 'Host *' Keychain block to ~/.ssh/config"
        {
            printf '\n%s\n' "$MARKER_BEGIN"
            printf 'Host *\n'
            printf '    AddKeysToAgent yes\n'
            printf '    UseKeychain yes\n'
            printf '    IgnoreUnknown UseKeychain\n'
            printf '%s\n' "$MARKER_END"
        } >> "$cfg"
        chmod 600 "$cfg"
    fi
}

remove_macos_ssh_config_block() {
    local cfg="$HOME/.ssh/config"
    [ -f "$cfg" ] || return 0
    awk -v b="$MARKER_BEGIN" -v e="$MARKER_END" '
        $0 == b { skip = 1; next }
        $0 == e { skip = 0; next }
        !skip   { print }
    ' "$cfg" > "$cfg.tmp" && mv "$cfg.tmp" "$cfg"
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

install_posix_snippet() {
    local rc="$1"  # path to ~/.bashrc or ~/.zshrc
    mkdir -p "$DEPLOY_DIR"
    install -m 0644 "$SNIPPET_DIR/ssh-agent.sh" "$DEPLOY_DIR/ssh-agent.sh"
    log "Installed snippet to $DEPLOY_DIR/ssh-agent.sh"

    touch "$rc"
    if grep -qF "$MARKER_BEGIN" "$rc"; then
        log "Source block already present in $rc; refreshing."
        awk -v b="$MARKER_BEGIN" -v e="$MARKER_END" '
            $0 == b { skip = 1; next }
            $0 == e { skip = 0; next }
            !skip   { print }
        ' "$rc" > "$rc.tmp" && mv "$rc.tmp" "$rc"
    fi
    {
        printf '\n%s\n' "$MARKER_BEGIN"
        if [ -n "${APP_CONFIGS_SSH_KEYS:-}" ]; then
            printf 'export APP_CONFIGS_SSH_KEYS=%q\n' "$APP_CONFIGS_SSH_KEYS"
        fi
        printf '[ -f "%s/ssh-agent.sh" ] && . "%s/ssh-agent.sh"\n' \
            "$DEPLOY_DIR" "$DEPLOY_DIR"
        printf '%s\n' "$MARKER_END"
    } >> "$rc"
    log "Wired $rc to source the snippet."
}

remove_posix_snippet() {
    local rc="$1"
    [ -f "$rc" ] || return 0
    awk -v b="$MARKER_BEGIN" -v e="$MARKER_END" '
        $0 == b { skip = 1; next }
        $0 == e { skip = 0; next }
        !skip   { print }
    ' "$rc" > "$rc.tmp" && mv "$rc.tmp" "$rc"
    rm -f "$DEPLOY_DIR/ssh-agent.sh"
    log "Removed snippet from $rc"
}

install_fish_snippet() {
    local conf_d="$HOME/.config/fish/conf.d"
    mkdir -p "$conf_d"
    install -m 0644 "$SNIPPET_DIR/ssh-agent.fish" "$conf_d/ssh-agent.fish"
    log "Installed snippet to $conf_d/ssh-agent.fish"
    if [ -n "${APP_CONFIGS_SSH_KEYS:-}" ] && command -v fish >/dev/null 2>&1; then
        # shellcheck disable=SC2016
        fish -c "set -Ux APP_CONFIGS_SSH_KEYS $APP_CONFIGS_SSH_KEYS" || true
        log "Set fish universal var APP_CONFIGS_SSH_KEYS=$APP_CONFIGS_SSH_KEYS"
    fi
}

remove_fish_snippet() {
    rm -f "$HOME/.config/fish/conf.d/ssh-agent.fish"
    log "Removed fish snippet"
}

main() {
    local os shell rc
    os="$(detect_os)"
    shell="$(detect_shell)"
    log "OS=$os  shell=$shell  action=$ACTION"

    if [ "$ACTION" = "install" ]; then
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
        remove_fish_snippet
        [ "$os" = "darwin" ] && remove_macos_ssh_config_block
        rmdir "$DEPLOY_DIR" 2>/dev/null || true
        log "Uninstall complete."
    fi
}

main "$@"
