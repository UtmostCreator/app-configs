#!/usr/bin/env bats
# Who owns Nix itself, Nix GC and a few CLI tools (T-0019): Home Manager
# profiles and the macOS Determinate-Nix/Homebrew declarations, checked from
# the evaluated flake. Nothing is built or activated.

# Evaluate each profile once per file: every `nix eval` of path:nix copies the
# flake into the store and re-evaluates it. A failure is recorded, not raised,
# so every test still reports it.
setup_file() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    export REPO_NIX="$REPO_ROOT/nix"
    local p
    for p in linux-desktop linux-cli wsl macos; do
        PROFILE="$p" nix eval --json --impure --expr '
          let
            flake = builtins.getFlake "path:${builtins.getEnv "REPO_NIX"}";
            hm = flake.homeConfigurations.${builtins.getEnv "PROFILE"}.config;
          in {
            packageNull = hm.nix.package == null;
            nixConf = hm.xdg.configFile ? "nix/nix.conf";
            settings = hm.nix.settings;
            gcAutomatic = hm.nix.gc.automatic;
            gcOptions = hm.nix.gc.options;
            packages = builtins.map (x: x.pname or x.name or "") hm.home.packages;
          }' >"$BATS_FILE_TMPDIR/hm-$p.json" 2>"$BATS_FILE_TMPDIR/hm-$p.err" || true
    done
    nix eval --json --impure --expr '
      let darwin = (builtins.getFlake "path:${builtins.getEnv "REPO_NIX"}").darwinConfigurations.macos.config;
      in {
        nixEnable = darwin.nix.enable;
        casks = builtins.map (c: c.name) darwin.homebrew.casks;
      }' >"$BATS_FILE_TMPDIR/darwin.json" 2>"$BATS_FILE_TMPDIR/darwin.err" || true
}

# hm <profile> <jq filter>: one fact from that profile's evaluation.
hm() {
    [ -s "$BATS_FILE_TMPDIR/hm-$1.json" ] || { cat "$BATS_FILE_TMPDIR/hm-$1.err" >&2; return 1; }
    jq -c "$2" "$BATS_FILE_TMPDIR/hm-$1.json"
}

darwin() {
    [ -s "$BATS_FILE_TMPDIR/darwin.json" ] || { cat "$BATS_FILE_TMPDIR/darwin.err" >&2; return 1; }
    jq -c "$1" "$BATS_FILE_TMPDIR/darwin.json"
}

@test "macos: Home Manager leaves nix.package null and writes no nix.conf (Determinate owns it)" {
    run hm macos .packageNull
    [ "$status" -eq 0 ]
    [ "$output" = true ]
    run hm macos .nixConf
    [ "$output" = false ]
}

@test "linux profiles: user nix.conf appends experimental features, no auto-optimise-store" {
    local p
    for p in linux-desktop linux-cli wsl; do
        run hm "$p" '.settings["extra-experimental-features"]'
        [ "$status" -eq 0 ]
        [ "$output" = '["nix-command","flakes"]' ]
        run hm "$p" '.settings | has("experimental-features") or has("auto-optimise-store")'
        [ "$output" = false ]
    done
}

@test "gc retention matches ops/cleanup.sh KEEP_DAYS on every profile" {
    local days p
    days="$(sed -n 's/^KEEP_DAYS="${KEEP_DAYS:-\([0-9][0-9]*\)}"$/\1/p' "$BATS_TEST_DIRNAME/../../ops/cleanup.sh")"
    [ -n "$days" ]
    for p in linux-desktop linux-cli wsl macos; do
        run hm "$p" .gcOptions
        [ "$status" -eq 0 ]
        [ "$output" = "\"--delete-older-than ${days}d\"" ]
    done
}

@test "gc timer: on for Linux profiles, off on macOS (launchd passes options as one argv)" {
    local p
    for p in linux-desktop linux-cli wsl; do
        run hm "$p" .gcAutomatic
        [ "$output" = true ]
    done
    run hm macos .gcAutomatic
    [ "$output" = false ]
}

@test "darwin: nix-darwin does not manage Nix (nix.enable = false)" {
    run darwin .nixEnable
    [ "$status" -eq 0 ]
    [ "$output" = false ]
}

@test "darwin: the disabled flameshot cask is not declared" {
    run darwin '.casks | index("flameshot")'
    [ "$status" -eq 0 ]
    [ "$output" = null ]
    # Guard against the check passing on an empty list.
    run darwin '.casks | index("firefox") != null'
    [ "$output" = true ]
}

@test "cli: tlrc is installed and tealdeer is not" {
    run hm linux-cli '.packages | index("tlrc") != null'
    [ "$status" -eq 0 ]
    [ "$output" = true ]
    run hm linux-cli '.packages | index("tealdeer")'
    [ "$output" = null ]
}

@test "cli: navi and glow come from Nix, not the mise optional installer" {
    run hm linux-cli '.packages | index("navi") != null and index("glow") != null'
    [ "$status" -eq 0 ]
    [ "$output" = true ]
    run grep -nE 'aqua:(denisidoro/navi|charmbracelet/glow)|for tool in .*(navi|glow)' \
        "$BATS_TEST_DIRNAME/../../mise.toml"
    [ "$status" -eq 1 ]
}
