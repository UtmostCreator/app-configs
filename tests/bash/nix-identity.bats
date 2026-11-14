#!/usr/bin/env bats
# One Nix identity: homeDirectory derives from the username, and the docker
# module (copied standalone into /etc/nixos, so it cannot import vars) keeps a
# literal default that must match nix/vars/default.nix.

bats_require_minimum_version 1.5.0

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    command -v nix >/dev/null || skip "nix not installed"
    VARS="$REPO_ROOT/nix/vars/default.nix"
}

@test "docker.nix default user equals the vars username" {
    expected="$(nix eval --raw -f "$VARS" username)"
    # Scope to the `user = lib.mkOption` block so another default is not read.
    actual="$(sed -nE '/^[[:space:]]*user = lib\.mkOption/,/^[[:space:]]*};/{
        s/^[[:space:]]*default = "([^"]+)";.*/\1/p
    }' "$REPO_ROOT/nix/modules/nixos/docker.nix")"
    [ -n "$expected" ]
    [ "$actual" = "$expected" ]
}

@test "every profile homeDirectory ends with the username" {
    user="$(nix eval --raw -f "$VARS" username)"
    # --separate-stderr: nix may print notices on stderr (the GitHub runner
    # does); only stdout is the JSON.
    run --separate-stderr nix eval --json -f "$VARS" profiles \
        --apply 'builtins.mapAttrs (_: p: p.homeDirectory)'
    [ "$status" -eq 0 ] || { echo "$stderr"; return 1; }
    [ "$(jq 'length' <<<"$output")" -ge 1 ]
    run jq -e --arg u "$user" 'all(.[]; endswith("/" + $u))' <<<"$output"
    [ "$status" -eq 0 ]
}

@test "changing username in vars changes every homeDirectory" {
    copy="$BATS_TEST_TMPDIR/vars.nix"
    sed -E 's/^([[:space:]]*username = ")[^"]+(";)/\1bats-probe\2/' "$VARS" >"$copy"
    grep -q 'username = "bats-probe";' "$copy"
    run --separate-stderr nix eval --json -f "$copy" profiles \
        --apply 'builtins.mapAttrs (_: p: p.homeDirectory)'
    [ "$status" -eq 0 ] || { echo "$stderr"; return 1; }
    [ "$(jq 'length' <<<"$output")" -ge 1 ]
    run jq -e 'all(.[]; endswith("/bats-probe"))' <<<"$output"
    [ "$status" -eq 0 ]
}
