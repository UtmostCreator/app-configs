#!/usr/bin/env bats
# ops/lib/profile-conflicts.sh: find nix-profile entries whose files would
# collide with the new Home Manager package set. Such a collision makes
# `home-manager switch` fail after it already removed home-manager-path,
# which takes git and friends off PATH.

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    # shellcheck source=/dev/null
    source "$REPO_ROOT/ops/lib/profile-conflicts.sh"
    T="$BATS_TEST_TMPDIR"
    mkdir -p "$T/parallel/bin" "$T/chezmoi/bin" "$T/hm/home-path/bin" "$T/hmpath/bin"
    touch "$T/parallel/bin/parallel" "$T/parallel/bin/sem" "$T/chezmoi/bin/chezmoi"
    touch "$T/hm/home-path/bin/parallel" "$T/hm/home-path/bin/git"
    cat >"$T/manifest.json" <<JSON
{"version":3,"elements":{
 "parallel":{"active":true,"originalUrl":"flake:nixpkgs","storePaths":["$T/parallel"]},
 "chezmoi":{"active":true,"originalUrl":"flake:nixpkgs","storePaths":["$T/chezmoi"]},
 "home-manager-path":{"active":true,"storePaths":["$T/hmpath"]}}}
JSON
}

@test "reports a profile entry whose binary Home Manager now also ships" {
    run profile_hm_conflicts "$T/manifest.json" "$T/hm/home-path"
    [ "$status" -eq 0 ]
    [ "$output" = $'parallel\tbin/parallel' ]
}

@test "home-manager-path itself is never a conflict" {
    touch "$T/hmpath/bin/git"
    run profile_hm_conflicts "$T/manifest.json" "$T/hm/home-path"
    [ "$status" -eq 0 ]
    [[ "$output" != *home-manager-path* ]]
}

@test "no overlap prints nothing" {
    rm "$T/hm/home-path/bin/parallel"
    run profile_hm_conflicts "$T/manifest.json" "$T/hm/home-path"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "a missing manifest or home-path is not an error" {
    run profile_hm_conflicts "$T/nope.json" "$T/hm/home-path"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
    run profile_hm_conflicts "$T/manifest.json" "$T/nope"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "older list-style manifests (version 2) are read too" {
    cat >"$T/manifest2.json" <<JSON
{"version":2,"elements":[{"active":true,"attrPath":"legacyPackages.x86_64-linux.parallel","originalUrl":"flake:nixpkgs","storePaths":["$T/parallel"]}]}
JSON
    run profile_hm_conflicts "$T/manifest2.json" "$T/hm/home-path"
    [ "$output" = $'parallel\tbin/parallel' ]
}

@test "inactive elements are ignored" {
    cat >"$T/manifest-inactive.json" <<JSON
{"version":3,"elements":{"parallel":{"active":false,"storePaths":["$T/parallel"]}}}
JSON
    run profile_hm_conflicts "$T/manifest-inactive.json" "$T/hm/home-path"
    [ "$status" -eq 0 ] && [ -z "$output" ]
}

@test "collisions outside bin/ are reported too" {
    mkdir -p "$T/parallel/share/man/man1" "$T/hm/home-path/share/man/man1"
    touch "$T/parallel/share/man/man1/parallel.1" "$T/hm/home-path/share/man/man1/parallel.1"
    run profile_hm_conflicts "$T/manifest.json" "$T/hm/home-path"
    [[ "$output" == *$'parallel\tshare/man/man1/parallel.1'* ]]
}

@test "a symlink to a directory against a real directory is not a conflict" {
    # Nix merges directories: gnupg's sbin -> bin vs a real sbin/ in home-path.
    mkdir -p "$T/gnupg/bin" "$T/hm/home-path/sbin"
    touch "$T/gnupg/bin/gpg" "$T/hm/home-path/sbin/other"
    ln -s bin "$T/gnupg/sbin"
    cat >"$T/manifest-dir.json" <<JSON
{"version":3,"elements":{"gnupg":{"active":true,"storePaths":["$T/gnupg"]}}}
JSON
    run profile_hm_conflicts "$T/manifest-dir.json" "$T/hm/home-path"
    [ "$status" -eq 0 ] && [ -z "$output" ]
}

@test "the identical store path on both sides is still a conflict" {
    # Nix compares link paths, not targets: the same package twice is a priority conflict.
    rm "$T/hm/home-path/bin/parallel"
    ln -s "$T/parallel/bin/parallel" "$T/hm/home-path/bin/parallel"
    run profile_hm_conflicts "$T/manifest.json" "$T/hm/home-path"
    [ "$output" = $'parallel\tbin/parallel' ]
}

@test "store paths containing spaces are handled" {
    mkdir -p "$T/sp ace/bin"
    touch "$T/sp ace/bin/git"
    cat >"$T/manifest-sp.json" <<JSON
{"version":3,"elements":{"spacey":{"active":true,"storePaths":["$T/sp ace"]}}}
JSON
    run profile_hm_conflicts "$T/manifest-sp.json" "$T/hm/home-path"
    [ "$output" = $'spacey\tbin/git' ]
}
