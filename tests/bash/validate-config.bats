#!/usr/bin/env bats
# ops/validate-config.sh: architecture invariants, run by the pre-commit hook.
# Each test builds a tiny repo (good tree) and breaks exactly one thing.
# VALIDATE_CONFIG_SCRIPT overrides the script under test (used to prove a
# fixture fails on an older version).

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    SCRIPT="${VALIDATE_CONFIG_SCRIPT:-$REPO_ROOT/ops/validate-config.sh}"
    R="$BATS_TEST_TMPDIR/repo"
    mkdir -p "$R/ops" "$R/home/.chezmoidata" "$R/repo-docs" "$R/nix/modules/home"
    cp "$SCRIPT" "$R/ops/validate-config.sh"
    git -C "$R" init -q
    printf 'home\n' >"$R/.chezmoiroot"
    printf 'name: x\n' >"$R/home/personal.yaml.example"
    for d in migration-source-of-truth migration-package-ownership; do
        printf '# Doc\n\n| a | b |\n|---|---|\n| 1 | done |\n\nEvery TBD row resolved.\n' >"$R/repo-docs/$d.md"
    done
    printf '{ pkgs, ... }:\n{\n  home.packages = with pkgs; [ jq ];\n}\n' >"$R/nix/modules/home/ok.nix"
    STUBS="$BATS_TEST_TMPDIR/bin"; mkdir -p "$STUBS"
}

validate() { git -C "$R" add -A; run bash "$R/ops/validate-config.sh"; }
# add a path the real .gitignore would hide
track() { mkdir -p "$(dirname "$R/$1")"; printf 'x: 1\n' >"$R/$1"; git -C "$R" add -f "$1"; }

@test "good tree passes" {
    validate
    [ "$status" -eq 0 ]
    [[ "$output" == *"all invariants pass"* ]]
}

@test "rule 1: .chezmoiroot with other content fails" {
    printf 'other\n' >"$R/.chezmoiroot"
    validate
    [ "$status" -ne 0 ]
    [[ "$output" == *".chezmoiroot must contain exactly 'home'"* ]]
}

@test "rule 1: .chezmoiroot with whitespace inside the word fails" {
    printf 'ho me\n' >"$R/.chezmoiroot"
    validate
    [ "$status" -ne 0 ]
    [[ "$output" == *".chezmoiroot must contain exactly 'home'"* ]]
}

@test "rule 1: missing .chezmoiroot fails" {
    rm "$R/.chezmoiroot"
    validate
    [ "$status" -ne 0 ]
    [[ "$output" == *".chezmoiroot missing"* ]]
}

@test "rule 2: home/.chezmoiscripts fails and the message names that directory" {
    mkdir "$R/home/.chezmoiscripts"; : >"$R/home/.chezmoiscripts/run_once_x.sh"
    validate
    [ "$status" -ne 0 ]
    [[ "$output" == *"home/.chezmoiscripts/ exists"* ]]
}

@test "rule 2: home/.chezmoiops also fails" {
    mkdir "$R/home/.chezmoiops"; : >"$R/home/.chezmoiops/run_once_x.sh"
    validate
    [ "$status" -ne 0 ]
    [[ "$output" == *"home/.chezmoiops/ exists"* ]]
}

@test "rule 4: an unignored personal.yaml in the working tree fails" {
    printf 'a: 1\n' >"$R/home/.chezmoidata/personal.yaml"
    validate
    [ "$status" -ne 0 ]
    [[ "$output" == *"NOT gitignored"* ]]
}

@test "rule 4: a gitignored personal.yaml is fine" {
    printf 'a: 1\n' >"$R/home/.chezmoidata/personal.yaml"
    printf 'home/.chezmoidata/personal.yaml\n' >"$R/.gitignore"
    validate
    [ "$status" -eq 0 ]
}

@test "rule 5: tracked secret paths fail" {
    local p
    for p in home/personal.yaml home/.chezmoidata/personal.yaml home/.chezmoidata/personal.local.yaml \
             projects.yaml home/projects.yaml .env .env.local config/.env.production; do
        track "$p"
        run bash "$R/ops/validate-config.sh"
        [ "$status" -ne 0 ] || { echo "not rejected: $p"; return 1; }
        [[ "$output" == *"tracked secret path"*"$p"* ]] || { echo "unreported: $p: $output"; return 1; }
        git -C "$R" rm -q -f --cached "$p"; rm -f "$R/$p"
    done
}

@test "rule 5: a tracked secret path is caught even when the working-tree file is gone" {
    track home/personal.yaml
    rm "$R/home/personal.yaml"
    run bash "$R/ops/validate-config.sh"   # the index still lists it
    [ "$status" -ne 0 ]
    [[ "$output" == *"tracked secret path"* ]]
}

@test "rule 5: examples and .env.example are allowed" {
    track .env.example
    track home/projects.yaml.example
    validate
    [ "$status" -eq 0 ]
}

@test "rule 9: an empty audit doc fails" {
    : >"$R/repo-docs/migration-source-of-truth.md"
    validate
    [ "$status" -ne 0 ]
    [[ "$output" == *"audit doc is empty"* ]]
}

@test "rule 9: TBD variants in table cells fail" {
    local cell
    for cell in '| TBD |' '|TBD|' '| tbd |' '| TBD (later) |' '| TBC |' '| TODO |' '| ? |'; do
        printf '# Doc\n\n| a | b |\n|---|---|\n| 1 %s\n' "$cell" >"$R/repo-docs/migration-package-ownership.md"
        validate
        [ "$status" -ne 0 ] || { echo "not rejected: $cell"; return 1; }
        [[ "$output" == *"unresolved TBD"* ]]
    done
}

@test "rule 9: the word TBD in prose and in longer cells is fine" {
    printf '# Doc\n\n| a | b |\n|---|---|\n| 1 | TBD rows are tracked elsewhere |\n\nEvery TBD row resolved.\n' \
        >"$R/repo-docs/migration-package-ownership.md"
    validate
    [ "$status" -eq 0 ]
}

@test "rule 10: an untracked nix file fails" {
    git -C "$R" add -A
    printf '{ }\n' >"$R/nix/modules/home/new.nix"
    run bash "$R/ops/validate-config.sh"
    [ "$status" -ne 0 ]
    [[ "$output" == *"untracked *.nix"* ]]
}

@test "git failing is a validation failure, not a silent pass" {
    printf '#!/bin/sh\nexit 3\n' >"$STUBS/git"; chmod +x "$STUBS/git"
    PATH="$STUBS:$PATH" run bash "$R/ops/validate-config.sh"
    [ "$status" -ne 0 ]
    [[ "$output" == *"git"* ]]
}

@test "git ls-files failing mid-run is reported" {
    printf '#!/bin/sh\ncase "$1" in ls-files) exit 3;; esac\nexec %s "$@"\n' "$(command -v git)" >"$STUBS/git"
    chmod +x "$STUBS/git"
    git -C "$R" add -A
    PATH="$STUBS:$PATH" run bash "$R/ops/validate-config.sh"
    [ "$status" -ne 0 ]
    [[ "$output" == *"git ls-files failed"* ]]
}
