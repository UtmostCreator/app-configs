# shellcheck shell=bash
# ssh-agent auto-loader for bash and zsh (Linux + macOS).
#
# Behavior:
# - macOS: relies on the launchd-started agent + Keychain (`UseKeychain yes`
#   in ~/.ssh/config). The passphrase is asked at most once ever; macOS
#   stores it in the user keychain. We just `ssh-add --apple-use-keychain`
#   the configured keys if they are not already loaded.
# - Linux: if `keychain` is installed, use it (passphrase asked once per
#   boot, reused across every shell). Otherwise fall back to a single
#   long-lived ssh-agent whose socket path is cached in
#   ~/.ssh/agent.env so all shells share it.
#
# Configuration:
#   Override the keys to load by exporting APP_CONFIGS_SSH_KEYS before
#   sourcing, e.g. in ~/.zshrc *before* this file:
#     export APP_CONFIGS_SSH_KEYS="github.uc.ll5 work_ed25519"
#   Paths are resolved against $HOME/.ssh/.
#
# Source this file from ~/.bashrc or ~/.zshrc:
#   [ -f "$HOME/.config/app-configs/ssh-agent.sh" ] && . "$HOME/.config/app-configs/ssh-agent.sh"

# Only run for interactive shells. Non-interactive (scripts, scp targets,
# rsync helpers) must never prompt for a passphrase.
case $- in
    *i*) ;;
    *) return 0 ;;
esac

# Resolve keys to load. Default to a single conventional key name; users
# override via APP_CONFIGS_SSH_KEYS.
: "${APP_CONFIGS_SSH_KEYS:=github.uc.ll5}"

_app_configs_ssh_uname="$(uname -s 2>/dev/null || echo unknown)"

_app_configs_ssh_key_paths() {
    # Echo absolute paths of configured keys that exist on disk.
    local k
    for k in $APP_CONFIGS_SSH_KEYS; do
        case "$k" in
            /*) [ -f "$k" ] && printf '%s\n' "$k" ;;
            *)  [ -f "$HOME/.ssh/$k" ] && printf '%s\n' "$HOME/.ssh/$k" ;;
        esac
    done
}

_app_configs_ssh_macos() {
    # macOS path: agent is already running under launchd. Add keys to it
    # using the Keychain integration so the passphrase is stored once.
    local fp loaded path
    loaded="$(ssh-add -l 2>/dev/null || true)"
    while IFS= read -r path; do
        [ -z "$path" ] && continue
        fp="$(ssh-keygen -lf "$path" 2>/dev/null | awk '{print $2}')"
        if [ -n "$fp" ] && printf '%s' "$loaded" | grep -q "$fp"; then
            continue
        fi
        # --apple-use-keychain is the modern flag; -K is the legacy alias.
        if ssh-add --apple-use-keychain "$path" >/dev/null 2>&1; then
            :
        else
            ssh-add -K "$path" >/dev/null 2>&1 || ssh-add "$path"
        fi
    done < <(_app_configs_ssh_key_paths)
}

_app_configs_ssh_linux_keychain() {
    # keychain caches the agent across shells; passphrase asked once per boot.
    # Pass key basenames (no path) — keychain resolves them under ~/.ssh.
    local keys=""
    local k
    for k in $APP_CONFIGS_SSH_KEYS; do
        case "$k" in
            /*) [ -f "$k" ] && keys="$keys $k" ;;
            *)  [ -f "$HOME/.ssh/$k" ] && keys="$keys $k" ;;
        esac
    done
    # shellcheck disable=SC2086
    eval "$(keychain --eval --quiet --agents ssh $keys)"
}

_app_configs_ssh_linux_plain() {
    # Fallback: single shared ssh-agent whose env is persisted to a file.
    local env_file="$HOME/.ssh/agent.env"
    # Reuse a running agent if its socket is alive.
    if [ -r "$env_file" ]; then
        # shellcheck disable=SC1090
        . "$env_file" >/dev/null
    fi
    if ! ssh-add -l >/dev/null 2>&1; then
        case "$?" in
            2)
                # Agent unreachable. Start a fresh one and persist its env.
                umask 077
                ssh-agent -s >"$env_file"
                # shellcheck disable=SC1090
                . "$env_file" >/dev/null
                ;;
        esac
    fi
    # Load any configured keys that aren't loaded yet.
    local loaded fp path
    loaded="$(ssh-add -l 2>/dev/null || true)"
    while IFS= read -r path; do
        [ -z "$path" ] && continue
        fp="$(ssh-keygen -lf "$path" 2>/dev/null | awk '{print $2}')"
        if [ -n "$fp" ] && printf '%s' "$loaded" | grep -q "$fp"; then
            continue
        fi
        ssh-add "$path"
    done < <(_app_configs_ssh_key_paths)
}

case "$_app_configs_ssh_uname" in
    Darwin)
        _app_configs_ssh_macos
        ;;
    Linux|FreeBSD|OpenBSD|NetBSD)
        if command -v keychain >/dev/null 2>&1; then
            _app_configs_ssh_linux_keychain
        else
            _app_configs_ssh_linux_plain
        fi
        ;;
    *)
        # Unknown OS: best-effort plain agent.
        _app_configs_ssh_linux_plain
        ;;
esac

unset _app_configs_ssh_uname
unset -f _app_configs_ssh_key_paths _app_configs_ssh_macos \
    _app_configs_ssh_linux_keychain _app_configs_ssh_linux_plain 2>/dev/null || true
