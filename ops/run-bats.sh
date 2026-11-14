#!/usr/bin/env bash
# Body of `mise run test:bash`: run the bats suite, and fail (not skip) when
# bats is missing so the task never reports success without running tests.
#
# The suite runs against a throwaway HOME, XDG base dirs, global git config,
# tmux socket dir and runtime dir, so a test that forgets to isolate itself
# writes to scratch space instead of the real ~/.config, ~/.local/state,
# ~/.gitconfig, tmux server or systemd user bus. PATH is kept as is: tests
# need the real Nix profile.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if ! command -v bats >/dev/null 2>&1; then
    echo "[test:bash] bats not found; shell tests did NOT run." >&2
    echo "[test:bash] Install: bats is provided by nix/modules/home/dev.nix; run sys-update." >&2
    exit 1
fi

scratch="$(mktemp -d "${TMPDIR:-/tmp}/run-bats.XXXXXX")"
trap 'rm -rf "$scratch"' EXIT

export HOME="$scratch/home"
# Unset rather than point the XDG base dirs at the scratch HOME: tests that
# give themselves their own HOME expect ~/.config and friends to follow it.
unset XDG_CONFIG_HOME XDG_DATA_HOME XDG_STATE_HOME XDG_CACHE_HOME GIT_CONFIG_GLOBAL
export XDG_RUNTIME_DIR="$scratch/runtime"
export TMUX_TMPDIR="$scratch/tmux"
# Never reach the developer's tmux server, ssh agent or session bus.
unset TMUX TMUX_PANE SSH_AUTH_SOCK DBUS_SESSION_BUS_ADDRESS
mkdir -p "$HOME" "$XDG_RUNTIME_DIR" "$TMUX_TMPDIR"
chmod 700 "$XDG_RUNTIME_DIR" "$TMUX_TMPDIR"
printf '[user]\n\tname = bats\n\temail = bats@example.invalid\n[init]\n\tdefaultBranch = main\n[commit]\n\tgpgsign = false\n' \
    >"$HOME/.gitconfig"

# The log-workspace / log-errors suites live next to their scripts; run
# them too, or they silently stop being exercised.
args=(tests/bash ops/projects/logging/test)

status=0
bats "${args[@]}" "$@" || status=$?

# Tests must write inside their own temp dirs. Anything left in the shared
# scratch HOME would have landed in the real HOME on a plain `bats` run.
# Exempt: the git identity and ~/.cache (disposable).
shopt -s dotglob nullglob
leaks=()
for path in "$HOME"/*; do
    case "${path#"$HOME"/}" in
        .gitconfig | .cache) ;;
        *) leaks+=("${path#"$HOME"/}") ;;
    esac
done
if (( ${#leaks[@]} > 0 )); then
    echo "[test:bash] tests wrote outside their temp dirs, into HOME:" >&2
    printf '[test:bash]   ~/%s\n' "${leaks[@]}" >&2
    echo "[test:bash] Give those tests their own HOME (e.g. HOME=\$BATS_TEST_TMPDIR)." >&2
    (( status != 0 )) || status=1
fi
exit "$status"
