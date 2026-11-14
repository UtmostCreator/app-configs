#!/usr/bin/env bash
# Body of `mise run test:bash`: run the bats suite, and fail (not skip) when
# bats is missing so the task never reports success without running tests.
#
# The suite runs against a throwaway HOME, XDG base dirs, global git config,
# tmux socket dir and runtime dir, so a test that forgets to isolate itself
# writes to scratch space instead of the real ~/.config, ~/.local/state,
# ~/.gitconfig, tmux server or systemd user bus. PATH is kept as is: tests
# need the real Nix profile.
#
# Files and tests run in parallel (bats --jobs) when GNU parallel is
# available. RUN_BATS_JOBS=<n> picks the job count; RUN_BATS_JOBS=1 runs
# sequentially. Passing -j/--jobs yourself overrides both.
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
unset XDG_CONFIG_HOME XDG_DATA_HOME XDG_STATE_HOME GIT_CONFIG_GLOBAL
# Except the cache: GNU parallel (bats --jobs) exports XDG_CACHE_HOME="" when
# it is unset, and Nix then writes its eval/fetcher caches to ./nix/ in the
# repository. A cache shared by the whole run is harmless.
export XDG_CACHE_HOME="$HOME/.cache"
export XDG_RUNTIME_DIR="$scratch/runtime"
export TMUX_TMPDIR="$scratch/tmux"
# Never reach the developer's tmux server, ssh agent or session bus.
unset TMUX TMUX_PANE SSH_AUTH_SOCK DBUS_SESSION_BUS_ADDRESS
mkdir -p "$HOME" "$XDG_RUNTIME_DIR" "$TMUX_TMPDIR"
chmod 700 "$XDG_RUNTIME_DIR" "$TMUX_TMPDIR"
printf '[user]\n\tname = bats\n\temail = bats@example.invalid\n[init]\n\tdefaultBranch = main\n[commit]\n\tgpgsign = false\n' \
    >"$HOME/.gitconfig"

# The log-workspace suite lives next to its scripts; run
# them too, or they silently stop being exercised.
args=(tests/bash ops/projects/logging/test)

jobs="${RUN_BATS_JOBS:-}"
if [[ -z "$jobs" ]]; then
    jobs="$(nproc 2>/dev/null || echo 1)"
fi
user_jobs=0
for arg in "$@"; do
    case "$arg" in -j | --jobs | --jobs=*) user_jobs=1 ;; esac
done
if [[ "$user_jobs" == 0 && "$jobs" =~ ^[0-9]+$ && "$jobs" -gt 1 ]] \
    && command -v parallel >/dev/null 2>&1 \
    && [[ "$(parallel --version 2>/dev/null </dev/null)" == *"GNU parallel"* ]]; then
    args=(--jobs "$jobs" "${args[@]}")
fi

status=0
bats "${args[@]}" "$@" || status=$?

# Tests must write inside their own temp dirs. Anything left in the shared
# scratch HOME would have landed in the real HOME on a plain `bats` run.
# Exempt: the git identity, GNU parallel's state and ~/.cache (disposable,
# and shared by tests that set their own HOME under bats --jobs).
shopt -s dotglob nullglob
leaks=()
for path in "$HOME"/*; do
    case "${path#"$HOME"/}" in
        .gitconfig | .parallel | .cache) ;;
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
