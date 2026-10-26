{
  description = "Personal dev environment for macOS, Linux desktop, Linux CLI, and WSL2";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    # TEMPORARY: last nixpkgs rev before patchelf 0.15.2 -> 0.19.2, which breaks
    # uncached builds that patch prebuilt binaries (semgrep-core aborts, the
    # OpenClaw node runtime segfaults). Only the packages named in
    # nix/overlays/default.nix and profileOverlays below come from here.
    nixpkgs-last-good.url = "github:NixOS/nixpkgs/f20cd90e28fe0403873f473b29e42662cd86e8c4";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Vicinae launcher flake — we consume ONLY its Home-Manager module
    # (programs.vicinae) used by the linux-desktop host
    # (nix/modules/home/vicinae.nix). The Vicinae BINARY comes from nixpkgs
    # (pkgs.vicinae, Hydra-cached) to avoid a source compile, so we do not rely
    # on the upstream flake's build or its Cachix cache. We still avoid
    # `inputs.nixpkgs.follows = "nixpkgs"` here, matching Vicinae's documented
    # guidance and keeping the door open to the upstream build later.
    # See https://docs.vicinae.com/nixos.
    vicinae.url = "github:vicinaehq/vicinae";

    # Community Vicinae extensions, installed declaratively via
    # programs.vicinae.extensions (e.g. vscode-recents). Light packages, so we
    # follow nixpkgs here for consistency with the rest of the flake.
    vicinae-extensions = {
      url = "github:vicinaehq/extensions";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # OpenClaw gateway (Telegram bot) — we consume its Home-Manager module
    # (programs.openclaw) and overlay (pkgs.openclaw, pkgs.openclawRuntimePlugins)
    # for the linux-desktop host (nix/modules/home/openclaw.nix). The overlay
    # builds against our nixpkgs, so follow it instead of locking a second copy.
    nix-openclaw = {
      url = "github:openclaw/nix-openclaw";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      home-manager,
      nix-darwin,
      treefmt-nix,
      ...
    }:
    let
      vars = import ./vars/default.nix;
      mkHome = import ./lib/mkhome.nix { inherit inputs; };

      # Formatter config (treefmt-nix), evaluated per supported system so
      # `nix fmt` and `nix flake check` work on both Linux and macOS hosts.
      formatterSystems = [
        "x86_64-linux"
        "aarch64-darwin"
      ];
      forAllSystems = nixpkgs.lib.genAttrs formatterSystems;
      treefmtEval = forAllSystems (
        system: treefmt-nix.lib.evalModule nixpkgs.legacyPackages.${system} ./treefmt.nix
      );

      # Per-profile extra overlays. nix-openclaw's overlay adds top-level
      # attrs (openclaw, qmd, ...), so only the profile that uses it gets it.
      # TEMPORARY: the OpenClaw stack is built from nixpkgs-last-good (see the
      # input) and only the attrs the HM module reads are re-exported. Swap
      # back to `[ inputs.nix-openclaw.overlays.default ]` once
      # `nix build ./nix#homeConfigurations.linux-desktop.activationPackage`
      # builds with it on current nixpkgs.
      openclawFromLastGood =
        _final: prev:
        let
          pinned = import inputs.nixpkgs-last-good {
            inherit (prev.stdenv.hostPlatform) system;
            overlays = [ inputs.nix-openclaw.overlays.default ];
          };
        in
        {
          inherit (pinned)
            openclaw
            openclaw-gateway
            openclawPackages
            openclawRuntimePlugins
            ;
        };
      profileOverlays = {
        linux-desktop = [ openclawFromLastGood ];
      };

      mkProfile =
        name:
        let
          profile = vars.profiles.${name};
        in
        mkHome {
          inherit (profile) system homeDirectory stateVersion;
          username = vars.username;
          modules = [ (./hosts + "/${name}/home.nix") ];
          overlays = profileOverlays.${name} or [ ];
        };
    in
    {
      # `nix fmt` formats the tree; `nix flake check` verifies formatting.
      formatter = forAllSystems (system: treefmtEval.${system}.config.build.wrapper);
      checks = forAllSystems (system: {
        formatting = treefmtEval.${system}.config.build.check self;
      });

      homeConfigurations = {
        linux-desktop = mkProfile "linux-desktop";
        linux-cli = mkProfile "linux-cli";
        wsl = mkProfile "wsl";
        # macOS standalone HM still exposed for hosts not running nix-darwin.
        macos = mkProfile "macos";
      };

      darwinConfigurations.macos = nix-darwin.lib.darwinSystem {
        system = vars.profiles.macos.system;
        specialArgs = { inherit inputs vars; };
        modules = [
          ./hosts/macos/darwin.nix
          home-manager.darwinModules.home-manager
          {
            users.users.${vars.username}.home = vars.profiles.macos.homeDirectory;
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.${vars.username} = import ./hosts/macos/home.nix;
          }
        ];
      };
    };
}
