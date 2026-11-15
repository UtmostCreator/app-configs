#!/usr/bin/env bats
# nix/modules/nixos/wsl.nix: the stock NixOS-WSL configuration.nix sets
# wsl.defaultUser = "nixos"; this module must win over it (mkForce). The
# NixOS-WSL options themselves are not available here, so the module is
# evaluated with a stub wsl option and nixpkgs lib from the flake.

bats_require_minimum_version 1.5.0

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    command -v nix >/dev/null || skip "nix not installed"
    WSL_MODULE="$REPO_ROOT/nix/modules/nixos/wsl.nix"
}

# eval_wsl <module path>: prints the resulting wsl.defaultUser with the stock
# user ("nixos") defined at normal priority next to the module.
eval_wsl() {
    nix eval --impure --raw --expr "
      let
        lib = (builtins.getFlake \"path:$REPO_ROOT/nix\").inputs.nixpkgs.lib;
        stub = { lib, ... }: {
          options.wsl.defaultUser = lib.mkOption { type = lib.types.str; };
        };
        res = lib.evalModules {
          modules = [ stub $1 { wsl.defaultUser = \"nixos\"; } ];
        };
      in res.config.wsl.defaultUser
    "
}

@test "B1: wsl.defaultUser = nixos from the stock config loses to the module's mkForce" {
    run --separate-stderr eval_wsl "$WSL_MODULE"
    [ "$status" -eq 0 ] || { echo "$stderr"; return 1; }
    [ "$output" = utmostcreator ]
}

@test "B1 control: without mkForce the same definitions conflict" {
    sed 's/lib\.mkForce //' "$WSL_MODULE" >"$BATS_TEST_TMPDIR/wsl-plain.nix"
    run --separate-stderr eval_wsl "$BATS_TEST_TMPDIR/wsl-plain.nix"
    [ "$status" -ne 0 ]
    [[ "$stderr" == *"conflicting definition values"* ]]
}

# One host profile (wsl) for Ubuntu-on-WSL and NixOS-WSL, two Home Manager
# outputs: wsl keeps targets.genericLinux (Ubuntu needs the XDG dirs, locale
# archive and Nix profile paths), wsl-nixos turns it off (NixOS provides them).
@test "wsl keeps targets.genericLinux; wsl-nixos turns it off" {
    run --separate-stderr nix eval --json \
        "path:$REPO_ROOT/nix#homeConfigurations.wsl.config.targets.genericLinux.enable"
    [ "$status" -eq 0 ] || { echo "$stderr"; return 1; }
    [ "$output" = true ]
    run --separate-stderr nix eval --json \
        "path:$REPO_ROOT/nix#homeConfigurations.wsl-nixos.config.targets.genericLinux.enable"
    [ "$status" -eq 0 ] || { echo "$stderr"; return 1; }
    [ "$output" = false ]
}
