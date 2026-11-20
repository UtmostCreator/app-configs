#!/usr/bin/env bash
ISOLATION_GUARDED_COMMANDS=(brew mas softwareupdate darwin-rebuild nixos-rebuild launchctl)

isolation_guard_make() {
    local dir="$1"
    shift
    local names=("$@") name
    mkdir -p "$dir"
    if ((${#names[@]} == 0)); then
        for name in "${ISOLATION_GUARDED_COMMANDS[@]}"; do
            command -v "$name" >/dev/null 2>&1 && names+=("$name")
        done
    fi
    for name in ${names[@]+"${names[@]}"}; do
        printf '#!/bin/sh\nprintf "[test-guard] blocked real %s %%s: stub it in the test\\n" "$*" >&2\nexit 97\n' "$name" >"$dir/$name"
        chmod +x "$dir/$name"
    done
}

isolation_sandbox_profile() {
    local real_home="$1" scratch="$2" extra_deny_exec="${3:-}" extra_line=""
    [[ -z "$extra_deny_exec" ]] || extra_line="
  (literal \"$extra_deny_exec\")"
    cat <<PROFILE
(version 1)
(allow default)
(deny file-write*
  (subpath "$real_home")
  (subpath "/opt/homebrew")
  (subpath "/usr/local")
  (subpath "/Library")
  (subpath "/Applications")
  (subpath "/private/etc"))
(allow file-write*
  (subpath "$scratch")
  (regex #"^/dev/"))
(deny process-exec
  (subpath "/opt/homebrew/Library/Homebrew")
  (literal "/bin/launchctl")
  (literal "/usr/sbin/softwareupdate")
  (literal "/usr/bin/sudo")$extra_line)
PROFILE
}

isolation_fingerprint() {
    local prefix="${ISOLATION_BREW_PREFIX:-/opt/homebrew}" repo="${1:-.}"
    local tool
    for tool in find shasum cut sort; do
        command -v "$tool" >/dev/null 2>&1 || { echo "fingerprint unavailable: $tool is missing"; return 0; }
    done
    if [[ -d "$prefix/Cellar" ]]; then
        printf 'brew-head %s\n' "$(git -C "$prefix" rev-parse HEAD 2>/dev/null || echo none)"
        printf 'cellar %s\n' "$(find "$prefix/Cellar" -mindepth 1 -maxdepth 1 | LC_ALL=C sort | shasum | cut -d' ' -f1)"
        printf 'cellar-versions %s\n' "$(find "$prefix/Cellar" -mindepth 2 -maxdepth 2 | LC_ALL=C sort | shasum | cut -d' ' -f1)"
        printf 'bin %s\n' "$(find "$prefix/bin" -mindepth 1 -maxdepth 1 | LC_ALL=C sort | shasum | cut -d' ' -f1)"
    fi
    if [[ -d "$HOME/Library/LaunchAgents" ]]; then
        printf 'launchagents %s\n' "$(find "$HOME/Library/LaunchAgents" -mindepth 1 -maxdepth 1 | LC_ALL=C sort | shasum | cut -d' ' -f1)"
    fi
    printf 'repo-head %s\n' "$(git -C "$repo" rev-parse HEAD 2>/dev/null || echo none)"
    printf 'repo-status %s\n' "$(git -C "$repo" status --porcelain 2>/dev/null | shasum | cut -d' ' -f1)"
}
