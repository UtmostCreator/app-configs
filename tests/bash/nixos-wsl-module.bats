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

# eval_wsl <module path> <nix expression over res>: evaluates the module with the
# stock user ("nixos") defined at normal priority next to it, and prints the
# expression (a string).
eval_wsl() {
    nix eval --impure --raw --expr "
      let
        nixpkgs = (builtins.getFlake \"path:$REPO_ROOT/nix\").inputs.nixpkgs;
        lib = nixpkgs.lib;
        pkgs = nixpkgs.legacyPackages.x86_64-linux;
        stub = { lib, ... }: {
          options.wsl.defaultUser = lib.mkOption { type = lib.types.str; };
          # The NixOS-WSL option (release 2605.7.2 and master): list of { src, name, copy }.
          options.wsl.extraBin = lib.mkOption {
            type = lib.types.listOf (lib.types.submodule ({ config, ... }: {
              options.src = lib.mkOption { type = lib.types.str; };
              options.name = lib.mkOption { type = lib.types.str; default = baseNameOf config.src; };
              options.copy = lib.mkOption { type = lib.types.bool; default = false; };
            }));
            default = [ ];
          };
        };
        res = lib.evalModules {
          modules = [ stub { _module.args.pkgs = pkgs; } $1 { wsl.defaultUser = \"nixos\"; } ];
        };
      in $2
    "
}

@test "B1: wsl.defaultUser = nixos from the stock config loses to the module's mkForce" {
    run --separate-stderr eval_wsl "$WSL_MODULE" res.config.wsl.defaultUser
    [ "$status" -eq 0 ] || { echo "$stderr"; return 1; }
    [ "$output" = utmostcreator ]
}

@test "B1 control: without mkForce the same definitions conflict" {
    sed 's/lib\.mkForce //' "$WSL_MODULE" >"$BATS_TEST_TMPDIR/wsl-plain.nix"
    run --separate-stderr eval_wsl "$BATS_TEST_TMPDIR/wsl-plain.nix" res.config.wsl.defaultUser
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

# NixOS-WSL 2605.7.2 creates /bin/{bash,mount,sh,wslpath,...} but not /bin/true,
# while WSL generates wsl-mnt-guard.service with ExecStart=/bin/true. On NixOS
# that unit failed (203/EXEC) and made `nixos-rebuild switch` exit 4. NixOS-WSL
# master fixed it by adding true to wsl.extraBin; this module does the same.
@test "wsl.extraBin gets a store-path true, so the generated wsl-mnt-guard.service can start" {
    run --separate-stderr eval_wsl "$WSL_MODULE" 'builtins.concatStringsSep "," (map (e: "${e.name}=${e.src}") res.config.wsl.extraBin)'
    [ "$status" -eq 0 ] || { echo "$stderr"; return 1; }
    [[ "$output" =~ ^true=/nix/store/[a-z0-9]{32}-coreutils-[^/]*/bin/true$ ]]
}
