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

# -- NixOS-WSL module (nix/modules/nixos/wsl.nix) ---------------------------

@test "wsl.nix forces the vars username over the stock NixOS-WSL default" {
    expected="$(nix eval --raw -f "$VARS" username)"
    [ -n "$expected" ]
    grep -qE "^[[:space:]]*wsl\.defaultUser = lib\.mkForce \"$expected\";" "$REPO_ROOT/nix/modules/nixos/wsl.nix"
}

# The username literal that ops/lib/preflight.sh matches with sed when Nix is
# not installed yet. It must match nix/vars/default.nix exactly once.
username_re() {
    sed -nE "s/^PREFLIGHT_USERNAME_RE='(.*)'\$/\\1/p" "$REPO_ROOT/ops/lib/preflight.sh"
}

@test "the preflight username literal matches nix/vars/default.nix exactly once, with the vars username" {
    re="$(username_re)"
    [ -n "$re" ]
    run grep -cE "$re" "$VARS"
    [ "$output" = 1 ]
    run grep -E "$re" "$VARS"
    [[ "$output" == *'"utmostcreator"'* ]]
    [ "$(nix eval --raw -f "$VARS" username)" = utmostcreator ]
}

@test "the preflight username literal: an indented line and a CRLF line match; two matches or none do not give exactly one" {
    re="$(username_re)"
    [ -n "$re" ]
    printf '{\n    username = "u1";\n}\n' >"$BATS_TEST_TMPDIR/indented.nix"
    [ "$(grep -cE "$re" "$BATS_TEST_TMPDIR/indented.nix")" = 1 ]
    printf '{\r\n  username = "u2";\r\n}\r\n' >"$BATS_TEST_TMPDIR/crlf.nix"
    [ "$(grep -cE "$re" "$BATS_TEST_TMPDIR/crlf.nix")" = 1 ]
    printf '{\n  username = "a";\n  username = "b";\n}\n' >"$BATS_TEST_TMPDIR/two.nix"
    [ "$(grep -cE "$re" "$BATS_TEST_TMPDIR/two.nix")" = 2 ]
    printf '{\n  name = "a";\n}\n' >"$BATS_TEST_TMPDIR/none.nix"
    [ "$(grep -cE "$re" "$BATS_TEST_TMPDIR/none.nix" || true)" = 0 ]
}
