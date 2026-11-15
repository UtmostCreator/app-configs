#!/usr/bin/env bats
# T-0042 phase 2 (AC12): home/.chezmoiignore decides whether the macOS input
# configs (~/.config/karabiner, ~/.config/linearmouse) are deployed. They are
# ignored on every non-darwin host, and on darwin when the macInput group is
# off. macInput resolves from the local selection file, else from the profile
# file nix/profiles/<profile>.toml read from the repository, else (no profile
# file) stays on. The profile is the local file's, else the host default.
#
# The template is rendered hermetically: a scratch source tree laid out like the
# repository (home/ and nix/profiles/), an empty chezmoi config, and HOME and
# XDG_CONFIG_HOME inside the scratch directory. Nothing under the real home is
# read or written.
#
# Run:  bats tests/bash/chezmoiignore-selection.bats

setup() {
    command -v chezmoi >/dev/null || skip "chezmoi not installed"
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    [ -f "$REPO_ROOT/home/.chezmoiignore" ]

    T="$BATS_TEST_TMPDIR"
    mkdir -p "$T/repo/home" "$T/repo/nix/profiles" "$T/home" "$T/xdg"
    cp "$REPO_ROOT/home/.chezmoiignore" "$T/repo/home/.chezmoiignore"
    cp "$REPO_ROOT/nix/profiles/"*.toml "$T/repo/nix/profiles/"
    : >"$T/chezmoi.toml"
    SELDIR="$T/xdg/app-configs/selection"
}

# render <os> <hostProfile> <gui>: the rendered ignore list. The environment is
# scrubbed of the selection variables; tests add what they need through ENVX.
render() {
    local data
    data=$(printf '{"name":"Test","email":"test@example.com","signingKey":"","hostProfile":"%s","gui":%s,"chezmoi":{"os":"%s"}}' \
        "$2" "$3" "$1")
    env -u APP_CONFIGS_SELECTION_DIR -u XDG_CONFIG_HOME HOME="$T/home" XDG_CONFIG_HOME="$T/xdg" ${ENVX[@]+"${ENVX[@]}"} \
        chezmoi execute-template \
        --config "$T/chezmoi.toml" \
        --source "$T/repo/home" \
        --override-data "$data" <"$T/repo/home/.chezmoiignore"
}
ENVX=()

has() { grep -qxF -- "$1" <<<"$output"; }
lacks() {
    if grep -qxF -- "$1" <<<"$output"; then
        echo "unexpected ignore line: $1" >&2
        return 1
    fi
}

# both_ignored / none_ignored: the two macOS input config trees.
both_ignored() {
    has '.config/karabiner'
    has '.config/karabiner/**'
    has '.config/linearmouse'
    has '.config/linearmouse/**'
}
none_ignored() {
    lacks '.config/karabiner'
    lacks '.config/karabiner/**'
    lacks '.config/linearmouse'
    lacks '.config/linearmouse/**'
}

write_local() { mkdir -p "$SELDIR" && printf '%b' "$1" >"$SELDIR/selection.toml"; }
write_profile() { printf '%b' "$2" >"$T/repo/nix/profiles/$1.toml"; }

@test "darwin with the committed profiles (macInput on): neither is ignored" {
    run render darwin macos true
    [ "$status" -eq 0 ]
    none_ignored
}

@test "darwin with macInput off in the profile file: both are ignored" {
    write_profile work '[groups]\nmedia = true\nmacInput = false\n'
    run render darwin macos true
    [ "$status" -eq 0 ]
    both_ignored
}

@test "darwin with macInput = false in the local file: both are ignored" {
    write_local 'profile = "work"\n\n[groups]\nmacInput = false\n'
    run render darwin macos true
    [ "$status" -eq 0 ]
    both_ignored
}

@test "the local file overrides the profile file in both directions" {
    write_profile work '[groups]\nmacInput = false\n'
    write_local 'profile = "work"\n\n[groups]\nmacInput = true\n'
    run render darwin macos true
    [ "$status" -eq 0 ]
    none_ignored
    write_profile work '[groups]\nmacInput = true\n'
    write_local 'profile = "work"\n\n[groups]\nmacInput = false\n'
    run render darwin macos true
    [ "$status" -eq 0 ]
    both_ignored
}

@test "a local file naming only a profile takes macInput from that profile's file" {
    write_profile personal '[groups]\nmacInput = false\n'
    write_local 'profile = "personal"\n'
    run render darwin macos true
    [ "$status" -eq 0 ]
    both_ignored
    # The host default (work) is not consulted when the file names a profile.
    write_profile personal '[groups]\nmacInput = true\n'
    write_profile work '[groups]\nmacInput = false\n'
    run render darwin macos true
    [ "$status" -eq 0 ]
    none_ignored
}

@test "without a local file the host default profile is used (macos = work)" {
    write_profile work '[groups]\nmacInput = false\n'
    write_profile personal '[groups]\nmacInput = true\n'
    run render darwin macos true
    [ "$status" -eq 0 ]
    both_ignored
}

@test "non-darwin hosts always ignore both, whatever the selection says" {
    write_local 'profile = "work"\n\n[groups]\nmacInput = true\n'
    local h
    for h in linux-desktop linux-cli wsl; do
        run render linux "$h" true
        [ "$status" -eq 0 ]
        both_ignored
    done
    run render linux linux-desktop false
    [ "$status" -eq 0 ]
    both_ignored
}

@test "linux-desktop no longer deploys the LinearMouse config (it was ungated before)" {
    run render linux linux-desktop true
    [ "$status" -eq 0 ]
    has '.config/linearmouse'
    has '.config/linearmouse/**'
}

@test "no local file and no directory: renders, and an empty file changes nothing" {
    run render darwin macos true
    [ "$status" -eq 0 ]
    none_ignored
    write_local ''
    run render darwin macos true
    [ "$status" -eq 0 ]
    none_ignored
}

@test "a local file of the wrong shape falls through to the profile file" {
    write_profile work '[groups]\nmacInput = false\n'
    write_local 'profile = "work"\n\n[groups]\nmacInput = "no"\nmedia = false\n'
    run render darwin macos true
    [ "$status" -eq 0 ]
    both_ignored
}

@test "an unknown profile name in the local file never reads outside the profile files" {
    write_local 'profile = "../../etc/x"\n'
    run render darwin macos true
    [ "$status" -eq 0 ]
    none_ignored
}

@test "a missing profile file leaves macInput on (the committed default)" {
    rm "$T/repo/nix/profiles/work.toml"
    run render darwin macos true
    [ "$status" -eq 0 ]
    none_ignored
}

@test "a syntactically invalid local file fails the render on darwin and is never read elsewhere" {
    write_local 'profile = = work\n[groups\n'
    run render darwin macos true
    [ "$status" -ne 0 ]
    run render linux linux-desktop true
    [ "$status" -eq 0 ]
    both_ignored
}

@test "APP_CONFIGS_SELECTION_DIR points the template at another directory" {
    mkdir -p "$T/other"
    printf 'profile = "work"\n[groups]\nmacInput = false\n' >"$T/other/selection.toml"
    ENVX=(APP_CONFIGS_SELECTION_DIR="$T/other")
    run render darwin macos true
    [ "$status" -eq 0 ]
    both_ignored
    # The default location is not read while the variable is set.
    write_local 'profile = "work"\n[groups]\nmacInput = true\n'
    run render darwin macos true
    [ "$status" -eq 0 ]
    both_ignored
}

@test "the default location is XDG_CONFIG_HOME, else HOME/.config" {
    write_local 'profile = "work"\n[groups]\nmacInput = false\n'
    run render darwin macos true
    [ "$status" -eq 0 ]
    both_ignored
    # XDG_CONFIG_HOME unset: HOME/.config/app-configs/selection.
    mkdir -p "$T/home/.config/app-configs/selection"
    printf 'profile = "work"\n[groups]\nmacInput = false\n' >"$T/home/.config/app-configs/selection/selection.toml"
    local data='{"hostProfile":"macos","gui":true,"chezmoi":{"os":"darwin"}}'
    run env -u APP_CONFIGS_SELECTION_DIR -u XDG_CONFIG_HOME HOME="$T/home" chezmoi execute-template \
        --config "$T/chezmoi.toml" --source "$T/repo/home" --override-data "$data" <"$T/repo/home/.chezmoiignore"
    [ "$status" -eq 0 ]
    both_ignored
}

# AC-N3: the pre-existing os, gui and hostProfile rules.
@test "AC-N3: the existing os, gui and host profile rules are unchanged" {
    run render linux linux-desktop true
    has 'Library'
    has '.config/flameshot'
    lacks '.config/Code'
    lacks '.config/ghostty'
    run render linux wsl false
    has '.config/Code'
    has '.config/ghostty'
    has 'Library/Application Support/com.mitchellh.ghostty'
    run render linux linux-cli true
    lacks '.config/Code'
    has '.config/ghostty'
    run render darwin macos true
    lacks 'Library'
    lacks '.config/flameshot'
    has '.config/Code'
    has '.config/ghostty'
    has '.local/bin/dsh-remote-setup'
    run render darwin macos false
    has '.config/ghostty'
    has '.config/karabiner'
}

@test "AC12 parity: the template's host default profile equals myConfig.profile for every host" {
    command -v nix >/dev/null || skip "nix not installed"
    local h os out want got
    for h in linux-desktop linux-cli wsl macos; do
        os=linux
        if [ "$h" = macos ]; then os=darwin; fi
        out="$(render "$os" "$h" true)"
        got="$(sed -n 's/^# host default profile: //p' <<<"$out")"
        want="$(timeout 600 nix eval --raw "path:$REPO_ROOT/nix#homeConfigurations.$h.config.myConfig.profile")"
        [ -n "$got" ] || { echo "$h: no host default profile line"; return 1; }
        [ "$got" = "$want" ] || { echo "$h: template says '$got', nix says '$want'"; return 1; }
    done
}

@test "the committed profile files keep macInput on, so the default deploys the configs" {
    grep -qx 'macInput = true' "$REPO_ROOT/nix/profiles/work.toml"
    grep -qx 'macInput = true' "$REPO_ROOT/nix/profiles/personal.toml"
}
