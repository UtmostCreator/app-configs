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

# hm_eval <attr-expr>: evaluate an expression against the linux-desktop
# Home Manager config, bound as `hm`.
hm_eval() {
    nix eval --json --impure --expr "
      let hm = (builtins.getFlake \"path:$REPO_ROOT/nix\").homeConfigurations.linux-desktop.config;
      in $1"
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
    # Merged across modules, the list evaluates to a GVariant string ("@as [...]").
    run hm_eval 'let v = hm.dconf.settings."org/gnome/shell".enabled-extensions;
      in builtins.match ".*grand-theft-focus@zalckos[.]github[.]com.*" (toString v) == null'
    [ "$status" -eq 0 ]
    [ "$output" = true ]
}

@test "gnome: grand-theft-focus package is not installed" {
    run hm_eval '!(builtins.any (p: (p.pname or "") == "gnome-shell-extension-grand-theft-focus") hm.home.packages)'
    [ "$status" -eq 0 ]
    [ "$output" = true ]
}
