#!/usr/bin/env bats
# Wiring of the window-action helpers on the Linux desktop (T-0031).
#
# Sources: nix/modules/home/gnome-keybindings.nix (custom keybindings)
#          nix/modules/home/gui.nix (vicinae-focus-tracker user unit)
#
# Characterization: pins the GNOME custom keybindings that call the window
# helpers (vicinae-toggle-app, vscode-recent-projects, vicinae-resize), with
# their Cyrillic twins, and the focus-tracker unit, exactly as evaluated from
# the real Home Manager config. A compositor-neutral refactor of the helpers
# must not change any of this on GNOME.
#
# Run:  bats tests/bash/window-actions-wiring.bats

setup_file() {
    command -v nix >/dev/null || skip "nix not installed"
    command -v jq >/dev/null || skip "jq not installed"
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    host="${WINDOW_ACTIONS_HOST:-linux-desktop}"
    export WIRING_JSON="$BATS_FILE_TMPDIR/wiring.json"
    nix eval --json "path:$REPO_ROOT/nix#homeConfigurations.$host.config" \
        --apply 'c:
          let
            prefix = "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/";
            len = builtins.stringLength prefix;
            paths = builtins.filter (n: builtins.substring 0 len n == prefix) (builtins.attrNames c.dconf.settings);
          in {
            profile = c.home.profileDirectory;
            keys = builtins.listToAttrs (map (n: {
              name = builtins.substring len (builtins.stringLength n) n;
              value = c.dconf.settings.${n};
            }) paths);
            list = toString c.dconf.settings."org/gnome/settings-daemon/plugins/media-keys".custom-keybindings;
            tracker = c.systemd.user.services.vicinae-focus-tracker;
          }' >"$WIRING_JSON"
}

field() { jq -r "$1" "$WIRING_JSON"; }

# Every custom keybinding whose command runs a window helper, one per line:
# key<TAB>binding<TAB>command, with the profile directory as @PROFILE@.
window_bindings() {
    jq -r '.profile as $p | .keys | to_entries[]
      | select(.value.command | test("vicinae-toggle-app|vscode-recent-projects|vicinae-resize"))
      | [.key, .value.binding, (.value.command | sub("^" + $p; "@PROFILE@"))] | @tsv' "$WIRING_JSON"
}

@test "window-helper keybindings: commands and bindings, with Cyrillic twins" {
    expected="$(printf '%s\t%s\t%s\n' \
        brave F1 '@PROFILE@/bin/vicinae-toggle-app brave-browser' \
        ghostty '<Alt><Shift>t' '@PROFILE@/bin/vicinae-toggle-app com.mitchellh.ghostty' \
        ghostty-cyr '<Alt><Shift>Cyrillic_ie' '@PROFILE@/bin/vicinae-toggle-app com.mitchellh.ghostty' \
        keepassxc '<Alt>1' '@PROFILE@/bin/vicinae-toggle-app org.keepassxc.KeePassXC keepassxc' \
        nautilus '<Super>e' '@PROFILE@/bin/vicinae-toggle-app org.gnome.Nautilus' \
        obsidian '<Alt><Shift>o' '@PROFILE@/bin/vicinae-toggle-app obsidian' \
        obsidian-cyr '<Alt><Shift>Cyrillic_shcha' '@PROFILE@/bin/vicinae-toggle-app obsidian' \
        resize '<Alt><Shift>f' '@PROFILE@/bin/vicinae-resize 75 100' \
        resize-cyr '<Alt><Shift>Cyrillic_a' '@PROFILE@/bin/vicinae-resize 75 100' \
        telegram '<Alt><Shift>r' '@PROFILE@/bin/vicinae-toggle-app org.telegram.desktop org.telegram.desktop' \
        telegram-cyr '<Alt><Shift>Cyrillic_ka' '@PROFILE@/bin/vicinae-toggle-app org.telegram.desktop org.telegram.desktop' \
        vesktop '<Alt><Shift>d' '@PROFILE@/bin/vicinae-toggle-app vesktop' \
        vesktop-cyr '<Alt><Shift>Cyrillic_ve' '@PROFILE@/bin/vicinae-toggle-app vesktop' \
        vscode '<Alt><Shift>e' '@PROFILE@/bin/vicinae-toggle-app code' \
        vscode-cyr '<Alt><Shift>Cyrillic_u' '@PROFILE@/bin/vicinae-toggle-app code' \
        vscode-recents '<Alt>e' 'vscode-recent-projects' \
        vscode-recents-cyr '<Alt>Cyrillic_u' 'vscode-recent-projects')"
    actual="$(window_bindings)"
    diff <(printf '%s\n' "$expected") <(printf '%s\n' "$actual")
}

@test "window-helper keybindings: the profile directory is an absolute path" {
    [[ "$(field .profile)" = /* ]]
}

@test "window-helper keybindings: each one is registered in custom-keybindings" {
    list="$(field .list)"
    count=0
    while IFS=$'\t' read -r key _; do
        echo "key: $key"
        [[ "$list" = *"/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/$key/"* ]]
        count=$((count + 1))
    done < <(window_bindings)
    [ "$count" -eq 17 ]
}

@test "window-helper keybindings: a Cyrillic twin differs only in its binding" {
    count=0
    while read -r twin; do
        base="${twin%-cyr}"
        echo "twin: $twin"
        [ "$(field ".keys[\"$twin\"].command")" = "$(field ".keys[\"$base\"].command")" ]
        [ "$(field ".keys[\"$twin\"].name")" = "$(field ".keys[\"$base\"].name")" ]
        [ "$(field ".keys[\"$twin\"].binding")" != "$(field ".keys[\"$base\"].binding")" ]
        count=$((count + 1))
    done < <(window_bindings | cut -f1 | grep -- '-cyr$')
    [ "$count" -eq 7 ]
}

@test "vicinae-focus-tracker unit: ExecStart is the tracker in the profile" {
    [ "$(field '.tracker.Service.ExecStart | if type == "array" then join("\n") else . end')" \
        = "$(field .profile)/bin/vicinae-focus-tracker" ]
}

@test "vicinae-focus-tracker unit: restarts on failure after 2 seconds" {
    [ "$(field .tracker.Service.Restart)" = "on-failure" ]
    [ "$(field .tracker.Service.RestartSec)" = "2" ]
}

@test "vicinae-focus-tracker unit: bound to graphical-session.target" {
    [ "$(field '.tracker.Install.WantedBy | join(",")')" = "graphical-session.target" ]
    [ "$(field '.tracker.Unit.PartOf | join(",")')" = "graphical-session.target" ]
    [ "$(field '.tracker.Unit.After | join(",")')" = "graphical-session.target" ]
}
