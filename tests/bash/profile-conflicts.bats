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
    [[ "$output" != *home-manager-path* ]]
}

@test "no overlap prints nothing" {
    rm "$T/hm/home-path/bin/parallel"
    run profile_hm_conflicts "$T/manifest.json" "$T/hm/home-path"
    [ -z "$output" ]
}

@test "a missing manifest or home-path is not an error" {
    run profile_hm_conflicts "$T/nope.json" "$T/hm/home-path"
    [ "$status" -eq 0 ] && [ -z "$output" ]
    run profile_hm_conflicts "$T/manifest.json" "$T/nope"
    [ "$status" -eq 0 ] && [ -z "$output" ]
}

@test "older list-style manifests (version 2) are read too" {
    cat >"$T/manifest2.json" <<JSON
{"version":2,"elements":[{"active":true,"attrPath":"legacyPackages.x86_64-linux.parallel","originalUrl":"flake:nixpkgs","storePaths":["$T/parallel"]}]}
JSON
    run profile_hm_conflicts "$T/manifest2.json" "$T/hm/home-path"
    [ "$output" = $'parallel\tbin/parallel' ]
}
