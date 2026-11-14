#!/usr/bin/env bats
# Desktop behaviour the Linux desktop host relies on:
#   - Ghostty opens a new tab on Ctrl+T (Linux only; macOS keeps Cmd+T).
#   - Background attention requests (e.g. Telegram messages) do not force
#     windows into the foreground through the grand-theft-focus extension.
#
# Run:  bats tests/bash/desktop-ux.bats

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    GHOSTTY_TMPL="$REPO_ROOT/home/dot_config/ghostty/config.tmpl"
    command -v chezmoi >/dev/null
}

render_ghostty() {
    printf '{}\n' >"$BATS_TEST_TMPDIR/chezmoi.json"
    chezmoi --config "$BATS_TEST_TMPDIR/chezmoi.json" \
        --persistent-state "$BATS_TEST_TMPDIR/state.boltdb" \
        --source "$REPO_ROOT/home" execute-template <"$GHOSTTY_TMPL"
}

# Evaluate the linux-desktop Home Manager facts once per file: every
# `nix eval` of path:nix copies the flake into the store and re-evaluates it.
# A failure is recorded, not raised, so the template tests still run.
setup_file() {
    export HM_JSON="$BATS_FILE_TMPDIR/hm.json"
    REPO_NIX="$(cd "$BATS_TEST_DIRNAME/../../nix" && pwd)" nix eval --json --impure --expr '
      let hm = (builtins.getFlake "path:${builtins.getEnv "REPO_NIX"}").homeConfigurations.linux-desktop.config;
      in {
        # Merged across modules, the list evaluates to a GVariant string ("@as [...]").
        gtfNotEnabled = let v = hm.dconf.settings."org/gnome/shell".enabled-extensions;
          in builtins.match ".*grand-theft-focus@zalckos[.]github[.]com.*" (toString v) == null;
        gtfNotInstalled = !(builtins.any (p: (p.pname or "") == "gnome-shell-extension-grand-theft-focus") hm.home.packages);
      }' >"$HM_JSON" 2>"$BATS_FILE_TMPDIR/hm.err" || true
}

# hm_value <key>: one fact from the evaluation above.
hm_value() {
    [ -s "$HM_JSON" ] || { cat "$BATS_FILE_TMPDIR/hm.err" >&2; return 1; }
    jq -c --arg k "$1" '.[$k]' "$HM_JSON"
}

@test "ghostty: ctrl+t opens a new tab on Linux" {
    [ "$(uname -s)" = Linux ] || skip "Linux-only binding"
    run render_ghostty
    [ "$status" -eq 0 ]
    grep -qx 'keybind = ctrl+t=new_tab' <<<"$output"
}

@test "ghostty: rendered config passes ghostty's own validation" {
    command -v ghostty >/dev/null || skip "ghostty not installed"
    render_ghostty >"$BATS_TEST_TMPDIR/config"
    run ghostty +validate-config --config-file="$BATS_TEST_TMPDIR/config"
    [ "$status" -eq 0 ]
}

@test "gnome: grand-theft-focus is disabled" {
    run hm_value gtfNotEnabled
    [ "$status" -eq 0 ]
    [ "$output" = true ]
}

@test "gnome: grand-theft-focus package is not installed" {
    run hm_value gtfNotInstalled
    [ "$status" -eq 0 ]
    [ "$output" = true ]
}
