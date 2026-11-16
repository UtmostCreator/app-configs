#!/usr/bin/env bats
# T-0009: ops/lib/chezmoi-source.sh is the one decision for "does this plain
# chezmoi call need --source=<repo>?" (chezmoi init --source does not persist
# sourceDir). ops/lib/selection-facts.sh, ops/readiness.sh, ops/update-all.sh,
# ops/audit.sh, ops/bootstrap.sh, ops/snapshot-home.sh and
# ops/unix/ssh-agent-setup.sh must all reach the same answer, for a configured,
# an unconfigured and a symlinked source. The per-script behaviour is in
# update-all-apply.bats, audit.bats, bootstrap-safety.bats and readiness.bats.

bats_require_minimum_version 1.5.0

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    export HOME="$BATS_TEST_TMPDIR/home"; mkdir -p "$HOME"
    # A repo with a .chezmoiroot, so the configured source is <repo>/home.
    REPO="$BATS_TEST_TMPDIR/repo"
    mkdir -p "$REPO/home"; printf 'home\n' >"$REPO/.chezmoiroot"
    S="$BATS_TEST_TMPDIR/bin"; mkdir -p "$S"
    for t in bash cat grep sed head cut wc dirname uname git tr readlink; do
        ln -s "$(command -v "$t")" "$S/$t"
    done
}

# chezmoi_as <source-path output | -fail | -empty>: a chezmoi whose plain
# `source-path` answers like that; verify succeeds only when it is consistent
# with how the caller reached it (no --source when configured), see readiness.
chezmoi_as() {
    case "$1" in
        -fail)  printf '#!/bin/sh\ncase "$*" in *source-path*) exit 1 ;; esac\nexit 0\n' >"$S/chezmoi" ;;
        -empty) printf '#!/bin/sh\ncase "$*" in *source-path*) exit 0 ;; esac\nexit 0\n' >"$S/chezmoi" ;;
        *)      printf '#!/bin/sh\ncase "$*" in *source-path*) echo "%s"; exit 0 ;; esac\nexit 0\n' "$1" >"$S/chezmoi" ;;
    esac
    chmod +x "$S/chezmoi"
}

# lib_args: what the library decides, "" or "--source=<repo>".
lib_args() {
    PATH="$S" bash -c 'source "$1/ops/lib/chezmoi-source.sh"; chezmoi_source_set "$2"; printf "%s" "${CHEZMOI_SOURCE_ARGS[*]-}"' _ "$REPO_ROOT" "$REPO"
}

# facts_args: what selection-facts decides for the same repo.
facts_args() {
    PATH="$S" bash -c '
        source "$1/ops/lib/selection.sh"; source "$1/ops/lib/selection-facts.sh"
        SELECTION_REPO_ROOT="$2"
        if _sel_chezmoi_is_configured_source; then printf ""; else printf "%s" "--source=$(_sel_repo)"; fi' _ "$REPO_ROOT" "$REPO"
}

# readiness_args: the arg readiness.sh gave `chezmoi verify` (read from a logging stub).
readiness_args() {
    local log="$BATS_TEST_TMPDIR/readiness-calls"; : >"$log"
    cp "$S/chezmoi" "$S/chezmoi.real"
    printf '#!/bin/sh\necho "$*" >>"%s"\nexec "%s/chezmoi.real" "$@"\n' "$log" "$S" >"$S/chezmoi"
    # readiness resolves its repo from its own location: run a copy rooted at $REPO
    mkdir -p "$REPO/ops"; cp -a "$REPO_ROOT/ops/readiness.sh" "$REPO/ops/"; mkdir -p "$REPO/ops/lib"; cp "$REPO_ROOT/ops/lib/chezmoi-source.sh" "$REPO/ops/lib/"
    HOST_PROFILE=linux-cli USER=tester PATH="$S" bash "$REPO/ops/readiness.sh" >/dev/null 2>&1 || true
    sed -n 's/^\(.*\)verify.*/\1/p' "$log" | sed 's/ *$//' | head -n1
}

scenarios() { # name | source-path answer | expected args
    printf '%s\n' \
        "unconfigured (source-path fails)|-fail|--source=$REPO" \
        "unconfigured (source-path empty)|-empty|--source=$REPO" \
        "configured at <repo>/home|$REPO/home|" \
        "configured at another checkout|$BATS_TEST_TMPDIR/other/home|--source=$REPO"
}

@test "T-0009: the library, selection-facts and readiness agree for configured and unconfigured sources" {
    local line name sp want
    while IFS='|' read -r name sp want; do
        chezmoi_as "$sp"
        [ "$(lib_args)" = "$want" ] || { echo "lib: $name -> '$(lib_args)' want '$want'"; return 1; }
        [ "$(facts_args)" = "$want" ] || { echo "selection-facts: $name -> '$(facts_args)' want '$want'"; return 1; }
        [ "$(readiness_args)" = "$want" ] || { echo "readiness: $name -> '$(readiness_args)' want '$want'"; return 1; }
    done < <(scenarios)
}

@test "T-0009: a symlinked configured source, or a symlinked repo, counts as configured everywhere" {
    ln -s "$REPO/home" "$BATS_TEST_TMPDIR/link-home"
    chezmoi_as "$BATS_TEST_TMPDIR/link-home"
    [ "$(lib_args)" = "" ]
    [ "$(facts_args)" = "" ]
    [ "$(readiness_args)" = "" ]
    ln -s "$REPO" "$BATS_TEST_TMPDIR/link-repo"
    chezmoi_as "$BATS_TEST_TMPDIR/link-repo/home"
    [ "$(lib_args)" = "" ]
    [ "$(facts_args)" = "" ]
}

@test "T-0009: a repo without .chezmoiroot is configured when source-path is the repo itself" {
    rm "$REPO/.chezmoiroot"
    chezmoi_as "$REPO"
    [ "$(lib_args)" = "" ]
    [ "$(facts_args)" = "" ]
    chezmoi_as "$REPO/home"
    [ "$(lib_args)" = "--source=$REPO" ]
    [ "$(facts_args)" = "--source=$REPO" ]
}

@test "T-0009: a failing readlink means not configured, in the library and in selection-facts" {
    chezmoi_as "$REPO/home"
    rm "$S/readlink"; printf '#!/bin/sh\nexit 1\n' >"$S/readlink"; chmod +x "$S/readlink"
    [ "$(lib_args)" = "--source=$REPO" ]
    [ "$(facts_args)" = "--source=$REPO" ]
}

@test "T-0009: without chezmoi on PATH the decision is --source=<repo>" {
    rm -f "$S/chezmoi"
    [ "$(lib_args)" = "--source=$REPO" ]
}

# lib_state: CHEZMOI_SOURCE_STATE and CHEZMOI_SOURCE_PATH the library sets.
lib_state() {
    PATH="$S" bash -c 'source "$1/ops/lib/chezmoi-source.sh"; chezmoi_source_set "$2"; printf "%s|%s" "$CHEZMOI_SOURCE_STATE" "$CHEZMOI_SOURCE_PATH"' _ "$REPO_ROOT" "$REPO"
}

@test "T-0009: the state is configured, unconfigured or other (an existing directory that is not this repo)" {
    chezmoi_as "$REPO/home";            [ "$(lib_state)" = "configured|" ]
    chezmoi_as -fail;                   [ "$(lib_state)" = "unconfigured|" ]
    chezmoi_as -empty;                  [ "$(lib_state)" = "unconfigured|" ]
    # real chezmoi prints its default path with rc 0 even when the directory is missing
    chezmoi_as "$HOME/.local/share/chezmoi"
    [ ! -e "$HOME/.local/share/chezmoi" ]
    [ "$(lib_state)" = "unconfigured|" ]
    [ "$(lib_args)" = "--source=$REPO" ]
    mkdir -p "$BATS_TEST_TMPDIR/main/home"
    chezmoi_as "$BATS_TEST_TMPDIR/main/home"
    [ "$(lib_state)" = "other|$BATS_TEST_TMPDIR/main/home" ]
    [ "$(lib_args)" = "--source=$REPO" ]   # read-only callers keep the current decision
    # the default path, once it exists as a directory, is another checkout too
    mkdir -p "$HOME/.local/share/chezmoi"
    chezmoi_as "$HOME/.local/share/chezmoi"
    [ "$(lib_state)" = "other|$HOME/.local/share/chezmoi" ]
}

@test "T-0009: chezmoi_source_hint shell-quotes the path" {
    REPO="$BATS_TEST_TMPDIR/my repo"; mkdir -p "$REPO/home"; printf 'home\n' >"$REPO/.chezmoiroot"
    chezmoi_as -fail
    run env PATH="$S" bash -c 'source "$1/ops/lib/chezmoi-source.sh"; chezmoi_source_set "$2"; printf "%s" "$(chezmoi_source_hint)"' _ "$REPO_ROOT" "$REPO"
    [ "$output" = "--source=$BATS_TEST_TMPDIR/my\\ repo " ]
}

@test "T-0009: chezmoi_source_hint prints the arg and a space only when it is needed" {
    chezmoi_as -fail
    run env PATH="$S" bash -c 'source "$1/ops/lib/chezmoi-source.sh"; chezmoi_source_set "$2"; printf "[%s]" "$(chezmoi_source_hint)"' _ "$REPO_ROOT" "$REPO"
    [ "$output" = "[--source=$REPO ]" ]
    chezmoi_as "$REPO/home"
    run env PATH="$S" bash -c 'source "$1/ops/lib/chezmoi-source.sh"; chezmoi_source_set "$2"; printf "[%s]" "$(chezmoi_source_hint)"' _ "$REPO_ROOT" "$REPO"
    [ "$output" = "[]" ]
}

@test "T-0009: the library uses no bash 4 feature (it runs from install.sh on a fresh Mac)" {
    if grep -nE '\$\{[A-Za-z_]+(,,|\^\^)|(declare|local|typeset) +-[A-Za-z]*[An]|(^|[^[:alnum:]_])(mapfile|readarray)([^[:alnum:]_]|$)|&>>|\|&' "$REPO_ROOT/ops/lib/chezmoi-source.sh"; then return 1; fi
}
