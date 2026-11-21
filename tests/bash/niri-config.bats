#!/usr/bin/env bats
# The niri user config, owned by chezmoi: home/dot_config/niri/config.kdl is
# deployed to ~/.config/niri/config.kdl. It is niri's shipped default (pinned
# nixpkgs, 26.04) with the fewest changes that fit this desktop: the same US
# and Russian layouts and Super+Space switch as GNOME, the installed terminal
# and launcher instead of the default's alacritty and fuzzel, and no bar or
# lock autostart (those wait for the shell choice, ADR-0013).
#
# Home Manager must not own this file, and /etc/niri/config.kdl is not used.
# GNOME's own config is untouched by it: niri reads only this file.
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
    niri="$(nix build --no-link --print-out-paths "path:$REPO_ROOT/nix#nixosConfigurations.linux-desktop-pilot.pkgs.niri")"
    run "$niri/bin/niri" validate -c "$KDL"
    echo "$output"
    [ "$status" -eq 0 ]
}

@test "niri config: US and Russian layouts with the Super+Space switch, as in GNOME" {
    active '^[[:space:]]*layout "us,ru"$'
    active '^[[:space:]]*options "grp:win_space_toggle"$'
    grep -q 'xkb-options = \[ "grp:win_space_toggle" \];' "$REPO_ROOT/nix/modules/home/gnome-keybindings.nix"
}

@test "niri config: the terminal and launcher binds start what is installed" {
    active 'Mod\+T .*spawn "ghostty"'
    active 'Alt\+Space .*spawn "vicinae" "toggle"'
    inactive 'spawn "alacritty"'
    inactive 'spawn "fuzzel"'
}

@test "niri config: no bar and no lock yet (they wait for the shell choice)" {
    [ -f "$KDL" ]
    inactive 'spawn-at-startup "waybar"'
    inactive 'spawn "swaylock"'
}

@test "niri config: a plain file owned by chezmoi, not a template and not Home Manager's" {
    [ -f "$KDL" ]
    [ ! -e "$REPO_ROOT/home/dot_config/niri/config.kdl.tmpl" ]
    # Code only: comments may mention /etc/niri to say it is not used.
    hits="$(git -C "$REPO_ROOT" grep -nE 'configFile\."niri|/etc/niri|environment\.etc\."niri' -- 'nix/*.nix' 'nix/**/*.nix' \
        | grep -vE '^[^:]+:[0-9]+:[[:space:]]*#' || true)"
    echo "$hits"
    [ -z "$hits" ]
}

# render <os> <hostProfile> <gui>: print the rendered ignore list.
render() {
    command -v chezmoi >/dev/null || skip "chezmoi not installed"
    : >"$BATS_TEST_TMPDIR/chezmoi.toml"
    mkdir -p "$BATS_TEST_TMPDIR/source"
    local data
    data=$(printf '{"name":"Test","email":"test@example.com","signingKey":"","hostProfile":"%s","gui":%s,"chezmoi":{"os":"%s"}}' \
        "$2" "$3" "$1")
    chezmoi execute-template --config "$BATS_TEST_TMPDIR/chezmoi.toml" \
        --source "$BATS_TEST_TMPDIR/source" --override-data "$data" <"$IGNORE"
}

@test "niri config: deployed on a Linux desktop only" {
    run render linux linux-desktop true
    [ "$status" -eq 0 ]
    run grep -qxF '.config/niri' <<<"$output"
    [ "$status" -eq 1 ]
    for args in "darwin macos true" "linux wsl false" "linux linux-cli false" "linux linux-desktop false"; do
        # shellcheck disable=SC2086
        run render $args
        [ "$status" -eq 0 ]
        grep -qxF '.config/niri' <<<"$output"
        grep -qxF '.config/niri/**' <<<"$output"
    done
}
