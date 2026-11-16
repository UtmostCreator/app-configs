#!/usr/bin/env bats
# Memory cap on the systemd user app.slice (nix/modules/home/memory-limit.nix).
#
# Terminals, editors, browsers and the AI CLI sessions all run in app.slice;
# the desktop shell runs in session.slice. Capping app.slice below the
# machine's RAM and swap makes a runaway job hit a cgroup OOM inside
# app.slice instead of a global OOM that can stop the desktop shell.
#   - every Linux Home Manager host gets the drop-in;
#   - RAM is capped at 90 %, and swap is capped too: a RAM cap alone lets the
#     slice fill all swap, which is how the global OOM was reached.
#
# Run:  bats tests/bash/app-slice-memory-limit.bats

# Evaluate the facts once per file: every `nix eval` of path:nix copies the
# flake into the store and re-evaluates it.
setup_file() {
    export HM_JSON="$BATS_FILE_TMPDIR/hm.json"
    REPO_NIX="$(cd "$BATS_TEST_DIRNAME/../../nix" && pwd)" nix eval --json --impure --expr '
      let
        flake = builtins.getFlake "path:${builtins.getEnv "REPO_NIX"}";
        dropIn = host:
          let files = flake.homeConfigurations.${host}.config.xdg.configFile;
          in files."systemd/user/app.slice.d/50-memory-limit.conf".text or "";
      in {
        desktop = dropIn "linux-desktop";
        cli = dropIn "linux-cli";
      }' >"$HM_JSON" 2>"$BATS_FILE_TMPDIR/hm.err" || true
}

# drop_in <host-key>: the drop-in text for one host, from the evaluation above.
drop_in() {
    [ -s "$HM_JSON" ] || { cat "$BATS_FILE_TMPDIR/hm.err" >&2; return 1; }
    jq -r --arg k "$1" '.[$k]' "$HM_JSON"
}

@test "linux-desktop: app.slice caps RAM at 90% inside a [Slice] section" {
    run drop_in desktop
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "[Slice]" ]
    grep -qx 'MemoryMax=90%' <<<"$output"
}

@test "linux-desktop: app.slice caps swap as well, below all of it" {
    run drop_in desktop
    [ "$status" -eq 0 ]
    pct="$(sed -n 's/^MemorySwapMax=\([0-9][0-9]*\)%$/\1/p' <<<"$output")"
    [ -n "$pct" ]
    [ "$pct" -lt 100 ]
}

@test "linux-cli: headless Linux hosts get the same limit" {
    run drop_in cli
    [ "$status" -eq 0 ]
    [ "$output" = "$(drop_in desktop)" ]
    grep -qx 'MemoryMax=90%' <<<"$output"
}
