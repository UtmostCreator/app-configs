#!/usr/bin/env bats
# Terminal and AI-agent memory limits scale with RAM (Linux desktop).
#
# Sources: nix/modules/home/gui.nix (app-terminals.slice, tab scopes)
#          nix/modules/home/ai-cli-updates.nix (remote-control services)
#          home/.chezmoitemplates/ghostty/config.body.tmpl
#
# Regression: the limits were fixed byte sizes (slice 18G/22G, tabs and
# agents 12G/16G) tuned for one 32 GB desktop. On a RAM upgrade or a smaller
# machine they were either too loose or too tight. systemd resolves a
# percentage in MemoryHigh=/MemoryMax= against physical RAM, so the limits
# now follow the machine: the shared budget is soft 60% / hard 70% (at least
# 30% stays free for GNOME and browsers), and each tab or agent is soft 40% /
# hard 50% inside it. Swap caps stay fixed sizes.
#
# Run:  bats tests/bash/terminal-memory-limits.bats

setup_file() {
    command -v nix >/dev/null || skip "nix not installed"
    command -v jq >/dev/null || skip "jq not installed"
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    host="${MEMORY_LIMITS_HOST:-linux-desktop}"
    export LIMITS_JSON="$BATS_FILE_TMPDIR/limits.json"
    nix eval --json "path:$REPO_ROOT/nix#homeConfigurations.$host.config" \
        --apply 'c: {
          slice = c.systemd.user.slices.app-terminals.Slice;
          ghostty = c.xdg.configFile."systemd/user/app-ghostty-surface-transient-.scope.d/50-memory.conf".text;
          vte = c.xdg.configFile."systemd/user/vte-spawn-.scope.d/50-memory.conf".text;
          claudeRc = c.xdg.configFile."systemd/user/claude-remote-control@.service.d/50-memory.conf".text;
          codexRc = c.xdg.configFile."systemd/user/codex-remote-control.service.d/50-memory.conf".text;
          claudeSlice = c.xdg.configFile."systemd/user/claude-remote-control@.service.d/60-slice.conf".text;
          codexSlice = c.xdg.configFile."systemd/user/codex-remote-control.service.d/60-slice.conf".text;
        }' >"$LIMITS_JSON"
}

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
}

field() { jq -r "$1" "$LIMITS_JSON"; }

@test "app-terminals.slice: soft 60% and hard 70% of RAM, fixed swap" {
    [ "$(field .slice.MemoryHigh)" = "60%" ]
    [ "$(field .slice.MemoryMax)" = "70%" ]
    [ "$(field .slice.MemorySwapMax)" = "8G" ]
    [ "$(field .slice.MemoryAccounting)" = "true" ]
}

@test "per-scope limits: every tab and agent unit is soft 40% and hard 50% of RAM" {
    for unit in ghostty vte claudeRc codexRc; do
        text="$(field ".$unit")"
        echo "$unit: $text"
        grep -qx 'MemoryHigh=40%' <<<"$text"
        grep -qx 'MemoryMax=50%' <<<"$text"
        grep -qx 'MemorySwapMax=4G' <<<"$text"
    done
}

@test "per-scope limits: no byte-valued MemoryHigh or MemoryMax remains" {
    for unit in ghostty vte claudeRc codexRc; do
        text="$(field ".$unit")"
        run grep -E '^Memory(High|Max)=[0-9]+[KMGT]?$' <<<"$text"
        [ "$status" -eq 1 ]
    done
}

@test "slice membership: tab scopes and remote-control services join app-terminals.slice" {
    for unit in ghostty vte claudeSlice codexSlice; do
        grep -qx 'Slice=app-terminals.slice' <<<"$(field ".$unit")"
    done
}

@test "ghostty config: no fixed-byte linux-cgroup-memory-limit overrides the scope drop-in" {
    run grep -nE '^[[:space:]]*linux-cgroup-memory-limit[[:space:]]*=' "$REPO_ROOT/home/.chezmoitemplates/ghostty/config.body.tmpl"
    [ "$status" -eq 1 ]
}
