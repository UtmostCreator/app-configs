#!/usr/bin/env bats
# The legacy GNOME pilot uses the chezmoi config at home/dot_config/niri/config.kdl is
# deployed to ~/.config/niri/config.kdl. It is niri's shipped default (pinned
# nixpkgs, 26.04) with the fewest changes that fit this desktop: the same US
# and Russian layouts and Super+Space switch as GNOME, the installed terminal
# and launcher instead of the default's alacritty and fuzzel, and no bar or
# lock autostart (those wait for the shell choice, ADR-0013).
#
# The separate linux-niri host owns its own KDL through integrated Home Manager.
# Its system output supplies the validator for both KDLs. The legacy parity
# checks below retire with the GNOME pilot.
#
# Run:  bats tests/bash/niri-config.bats

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    KDL="$REPO_ROOT/home/dot_config/niri/config.kdl"
    IGNORE="$REPO_ROOT/home/.chezmoiignore"
}

# active <regex>: succeed when a line that is not a // comment matches.
active() { grep -vE '^[[:space:]]*//' "$KDL" | grep -qE -- "$1"; }
inactive() {
    if active "$1"; then
        echo "unexpected active line matching: $1" >&2
        return 1
    fi
}

@test "niri config: the pinned niri accepts it (niri validate)" {
    command -v nix >/dev/null || skip "nix not installed"
    niri="$(nix build --no-link --print-out-paths "path:$REPO_ROOT/nix#nixosConfigurations.linux-niri.config.programs.niri.package")"
    run "$niri/bin/niri" validate -c "$REPO_ROOT/nix/hosts/linux-niri/config.kdl"
    echo "$output"
    [ "$status" -eq 0 ]
    run "$niri/bin/niri" validate -c "$KDL"
    echo "$output"
    [ "$status" -eq 0 ]
}

@test "legacy GNOME pilot: chezmoi Niri KDL matches the GNOME layout switch" {
    active '^[[:space:]]*layout "us,ru"$'
    active '^[[:space:]]*options "grp:win_space_toggle"$'
    grep -q 'xkb-options = \[ "grp:win_space_toggle" \];' "$REPO_ROOT/nix/modules/home/gnome-keybindings.nix"
}

@test "legacy GNOME pilot: the terminal and launcher binds start the installed applications" {
    active 'Mod\+T .*spawn "ghostty"'
    active 'Alt\+Space .*spawn "vicinae" "toggle"'
    inactive 'spawn "alacritty"'
    inactive 'spawn "fuzzel"'
}

@test "legacy GNOME pilot: the example KDL leaves its bar and locker inactive" {
    [ -f "$KDL" ]
    inactive 'spawn-at-startup "waybar"'
    inactive 'spawn "swaylock"'
}

@test "niri config: only the dedicated Niri profile can declare its own Home Manager KDL" {
    [ -f "$KDL" ]
    [ ! -e "$REPO_ROOT/home/dot_config/niri/config.kdl.tmpl" ]
    # Code only: comments may mention /etc/niri to say it is not used.
    hits="$(git -C "$REPO_ROOT" grep -nE 'configFile\."niri/[^"]+"(\.[a-zA-Z]+)?[[:space:]]*=|/etc/niri|environment\.etc\."niri' -- 'nix/*.nix' 'nix/**/*.nix' \
        | grep -vE '^[^:]+:[0-9]+:[[:space:]]*#|^nix/hosts/linux-niri/home.nix:' || true)"
    echo "$hits"
    [ -z "$hits" ]
}

# render <os> <hostProfile> <gui>: print the rendered ignore list.
render() {
    command -v chezmoi >/dev/null || skip "chezmoi not installed"
    : >"$BATS_TEST_TMPDIR/chezmoi.toml"
    mkdir -p "$BATS_TEST_TMPDIR/source"
    local data
    data=$(printf '{"name":"Test","email":"test@example.com","signingKey":"","hostProfile":"%s","gui":%s,"chezmoi":{"os":"%s","hostname":"%s"}}' \
        "$2" "$3" "$1" "${4:-fixture}")
    chezmoi execute-template --config "$BATS_TEST_TMPDIR/chezmoi.toml" \
        --source "$BATS_TEST_TMPDIR/source" --override-data "$data" <"$IGNORE"
}

@test "chezmoi: deploy the legacy KDL only on the standalone Linux desktop" {
    run render linux linux-desktop true
    [ "$status" -eq 0 ]
    run grep -qxF '.config/niri' <<<"$output"
    [ "$status" -eq 1 ]
    for args in "darwin macos true" "linux wsl false" "linux linux-cli false" "linux linux-desktop false" "linux linux-niri true" "linux linux-desktop true linux-niri"; do
        # shellcheck disable=SC2086
        run render $args
        [ "$status" -eq 0 ]
        grep -qxF '.config/niri' <<<"$output"
        grep -qxF '.config/niri/**' <<<"$output"
    done
}
