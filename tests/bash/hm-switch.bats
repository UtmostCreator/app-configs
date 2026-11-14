#!/usr/bin/env bats
# ops/lib/hm-switch.sh: the one shared Home Manager switch. Every caller
# (update-all, install, bootstrap, the codebase-memory-mcp updater) goes
# through it, so the conflict check and -b hm-bak cannot be skipped by one.

# `! cmd` in the middle of a bats test does not fail it (set -e ignores a
# negated command), so assert absence explicitly.
refute_grep() { if grep -q "$@"; then echo "unexpected match: $*" >&2; return 1; fi; }

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    export HOME="$BATS_TEST_TMPDIR/home"
    export CALLS="$BATS_TEST_TMPDIR/calls"
    STUBS="$BATS_TEST_TMPDIR/bin"
    mkdir -p "$HOME/.nix-profile" "$STUBS" "$BATS_TEST_TMPDIR/out/home-path/bin"
    : >"$CALLS"
    printf '#!/usr/bin/env bash\nprintf "nix %%s\\n" "$*" >> "$CALLS"\nprintf "%%s\\n" "$BATS_TEST_TMPDIR/out"\n' >"$STUBS/nix"
    printf '#!/usr/bin/env bash\nprintf "home-manager %%s\\n" "$*" >> "$CALLS"\nexit "${FAIL_SWITCH:-0}"\n' >"$STUBS/home-manager"
    chmod +x "$STUBS/nix" "$STUBS/home-manager"
    PATH="$STUBS:$PATH"
    printf '{"elements":{}}\n' >"$HOME/.nix-profile/manifest.json"
    # shellcheck source=/dev/null
    source "$REPO_ROOT/ops/lib/hm-switch.sh"
}

add_conflict() {
    mkdir -p "$BATS_TEST_TMPDIR/parallel/bin"
    touch "$BATS_TEST_TMPDIR/parallel/bin/parallel" "$BATS_TEST_TMPDIR/out/home-path/bin/parallel"
    printf '{"elements":{"parallel":{"originalUrl":"flake:nixpkgs","storePaths":["%s"]}}}\n' \
        "$BATS_TEST_TMPDIR/parallel" >"$HOME/.nix-profile/manifest.json"
}

@test "a clean profile switches with -b hm-bak after the check" {
    run hm_switch /repo/nix linux-desktop
    [ "$status" -eq 0 ]
    grep -qx 'home-manager switch -b hm-bak --flake /repo/nix#linux-desktop' "$CALLS"
}

@test "a colliding nix-profile entry stops before the switch, naming the fix" {
    add_conflict
    run hm_switch /repo/nix linux-desktop
    [ "$status" -ne 0 ]
    [[ "$output" == *"nix profile remove parallel"* ]]
    refute_grep '^home-manager' "$CALLS"
}

@test "a missing jq is an error, not an empty conflict list" {
    run env PATH="$STUBS" "$BASH" -c "source '$REPO_ROOT/ops/lib/hm-switch.sh'; hm_check_conflicts /repo/nix p; echo status=\$?; echo \"\$HM_CHECK_MSG\""
    [[ "$output" == *"status=2"* ]]
    [[ "$output" == *"jq is not on PATH"* ]]
}

@test "a profile without a manifest is an error" {
    rm "$HOME/.nix-profile/manifest.json"
    run hm_switch /repo/nix linux-desktop
    [ "$status" -ne 0 ]
    [[ "$output" == *"manifest.json is missing"* ]]
    refute_grep '^home-manager' "$CALLS"
}

@test "a host with no nix profile at all has nothing to collide with" {
    rm -r "$HOME/.nix-profile"
    run hm_switch /repo/nix linux-desktop
    [ "$status" -eq 0 ]
    grep -q '^home-manager switch' "$CALLS"
}

@test "an activation package that cannot be built is an error" {
    printf '#!/usr/bin/env bash\nexit 1\n' >"$STUBS/nix"
    run hm_switch /repo/nix linux-desktop
    [ "$status" -ne 0 ]
    [[ "$output" == *"could not build"* ]]
    refute_grep '^home-manager' "$CALLS"
}

@test "a failed switch explains the existing .hm-bak abort" {
    FAIL_SWITCH=1 run hm_switch_raw /repo/nix linux-desktop
    [ "$status" -ne 0 ]
    [[ "$output" == *".hm-bak file already exists"* ]]
}

@test "hm_switch_describe prints the exact switch command line" {
    [ "$(hm_switch_describe /repo/nix wsl)" = "home-manager switch -b hm-bak --flake /repo/nix#wsl" ]
}

@test "no script, mise task or switch doc runs a bare 'home-manager switch --flake'" {
    cd "$REPO_ROOT"
    # Lines that apply a switch must carry -b hm-bak; --dry-run previews and
    # prose that merely names the command are exempt.
    run grep -nE 'home-manager switch.*--flake' \
        ops/*.sh ops/lib/*.sh mise.toml docs/platforms/nixos/*.md docs/reference/profiles.md \
        nix/modules/home/scripts/*.sh
    bad="$(printf '%s\n' "$output" | grep -v -e 'hm-bak' -e '--dry-run' -e 'hm-switch.sh' || true)"
    [ -z "$bad" ] || { echo "$bad" >&2; return 1; }
}
