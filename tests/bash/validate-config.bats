#!/usr/bin/env bats
# ops/validate-config.sh invariants 6-8 run against a scratch repo
# (VALIDATE_CONFIG_ROOT), never the real nix modules.

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    command -v rg >/dev/null 2>&1 || skip "rg not installed"
    export HOME="$BATS_TEST_TMPDIR/home"; mkdir -p "$HOME"
    FIX="$BATS_TEST_TMPDIR/fix"
    mkdir -p "$FIX/nix/modules/home" "$FIX/home"
    git -C "$FIX" init -q -b main
    echo home >"$FIX/.chezmoiroot"
    : >"$FIX/home/personal.yaml.example"
    mkdir -p "$FIX/repo-docs"
    : >"$FIX/repo-docs/migration-source-of-truth.md"
    : >"$FIX/repo-docs/migration-package-ownership.md"
}

run_validate() {
    # invariant 10 rejects untracked *.nix, so track the fixture first
    git -C "$FIX" add -A
    VALIDATE_CONFIG_ROOT="$FIX" run bash "$REPO_ROOT/ops/validate-config.sh"
}

@test "multi-line home.packages entries for bootstrap tools are rejected" {
    local tool
    for tool in lefthook chezmoi mise home-manager direnv; do
        printf '{ pkgs, ... }: {\n  home.packages = with pkgs; [\n    git\n    %s\n  ];\n}\n' "$tool" \
            >"$FIX/nix/modules/home/x.nix"
        run_validate
        [ "$status" -ne 0 ] || { echo "$tool passed"; return 1; }
        [[ "$output" == *"$tool"* ]]
    done
}

@test "pkgs.<tool> list entries and trailing comments are rejected too" {
    printf '[\n  pkgs.chezmoi # dotfiles\n]\n' >"$FIX/nix/modules/home/x.nix"
    run_validate
    [ "$status" -ne 0 ]
}

@test "a comment merely mentioning a tool is fine" {
    printf '# mise, chezmoi, direnv are installed by bootstrap\n{ }\n' >"$FIX/nix/modules/home/x.nix"
    run_validate
    [ "$status" -eq 0 ]
}

@test "attrset-form programs.<x> = { ... } is rejected unless allowlisted" {
    printf '{\n  programs.git = {\n    enable = true;\n  };\n}\n' >"$FIX/nix/modules/home/x.nix"
    run_validate
    [ "$status" -ne 0 ]
    [[ "$output" == *"programs.git"* ]]
}

@test "dotted programs.<x>.enable is rejected unless allowlisted" {
    printf '{\n  programs.git.enable = true;\n}\n' >"$FIX/nix/modules/home/x.nix"
    run_validate
    [ "$status" -ne 0 ]
}

@test "allowlisted programs (home-manager, vicinae, openclaw) pass in both forms" {
    printf '{\n  programs.home-manager.enable = true;\n  programs.vicinae = {\n    enable = true;\n  };\n  programs.openclaw = { enable = true; };\n}\n' \
        >"$FIX/nix/modules/home/x.nix"
    run_validate
    [ "$status" -eq 0 ]
}

@test "a missing rg fails instead of passing silently" {
    local bin="$BATS_TEST_TMPDIR/nobin" t
    mkdir -p "$bin"
    for t in bash git tr grep sed awk cat dirname env; do
        ln -sf "$(command -v "$t")" "$bin/$t"
    done
    VALIDATE_CONFIG_ROOT="$FIX" PATH="$bin" run "$bin/bash" "$REPO_ROOT/ops/validate-config.sh"
    [ "$status" -ne 0 ]
    [[ "$output" == *"rg"* ]]
}

@test "the real repository still passes" {
    run bash "$REPO_ROOT/ops/validate-config.sh"
    [ "$status" -eq 0 ]
}
