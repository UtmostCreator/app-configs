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

    disko = {
      url = "github:nix-community/disko/v1.13.0";
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

    # Local install selection (T-0042). The committed default is the empty
    # file nix/selection/selection.toml, which means "no selection". Scripts
    # that find ~/.config/app-configs/selection/selection.toml pass
    # `--override-input selection path:<dir>`; the override implies
    # --no-write-lock-file, so this lock node never changes. Read only by
    # nix/modules/home/profile.nix via builtins.fromTOML.
    selection = {
      url = "path:./selection";
      flake = false;
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
      # `nix fmt` formats the tree.
      formatter = forAllSystems (system: treefmtEval.${system}.config.build.wrapper);

      # CHECK LEVELS (what each command proves, cheapest first):
      #   1. EVALUATION, any host: `nix flake check ./nix --all-systems --no-build`
      #      evaluates every system's checks, so a module broken for another
      #      platform fails here, but nothing is built and no remote builder is
      #      needed. The home-*/darwin-* checks below are writeText sentinels
      #      over a drvPath: tiny per-system derivations that this level never
      #      builds.
      #   2. NATIVE CHECK BUILD: plain `nix flake check ./nix` builds only the
      #      current system's checks (formatting plus the sentinels); other
      #      systems, e.g. aarch64-darwin on Linux, are skipped. Building a
      #      sentinel does NOT build the host closure; it only proves the
      #      configuration evaluates.
      #   3. REAL BUILD: `nix build --no-link
      #      ./nix#homeConfigurations.<profile>.activationPackage` builds the
      #      closure. CI does this for linux-cli, wsl and wsl-nixos; sys-update builds
      #      the real host. Darwin closures need a darwin builder.
      checks = forAllSystems (
        system:
        {
          formatting = treefmtEval.${system}.config.build.check self;
        }
        // nixpkgs.lib.mapAttrs' (
          name: profile:
          nixpkgs.lib.nameValuePair "home-${name}" (
            # Evaluation-level check only (see CHECK LEVELS above): forces
            # evaluation of the profile without building its closure. The
            # sentinel is itself a per-system derivation, so building it for
            # another system (no --no-build) needs a builder for that system.
            nixpkgs.legacyPackages.${system}.writeText "home-${name}-evaluation" (
              builtins.unsafeDiscardStringContext self.homeConfigurations.${name}.activationPackage.drvPath
            )
          )
        ) (nixpkgs.lib.filterAttrs (_: profile: profile.system == system) vars.profiles)
        // nixpkgs.lib.optionalAttrs (system == "x86_64-linux") {
          niri-config =
            let
              host = self.nixosConfigurations.linux-niri;
              cfg = host.config;
              home = cfg.home-manager.users.${vars.username};
            in
            assert cfg.programs.niri.enable && cfg.services.greetd.enable;
            assert
              !(
                cfg.services.desktopManager.gnome.enable
                || cfg.services.displayManager.gdm.enable
                || cfg.programs.niri.useNautilus
              );
            host.pkgs.runCommand "linux-niri-config" { } ''
              ${cfg.programs.niri.package}/bin/niri validate -c ${home.xdg.configFile."niri/config.kdl".source}
              touch "$out"
            '';
        }
        // nixpkgs.lib.optionalAttrs (system == vars.profiles.macos.system) {
          darwin-macos = nixpkgs.legacyPackages.${system}.writeText "darwin-macos-evaluation" (
            builtins.unsafeDiscardStringContext self.darwinConfigurations.macos.system.drvPath
          );
        }
      );

      # Pinned nix-darwin CLI (from the nix-darwin input) so bootstrap can run
      # it before darwin-rebuild is installed:
      #   sudo nix run <repo>/nix#darwin-rebuild -- switch --flake <repo>/nix#macos
      packages.${vars.profiles.macos.system}.darwin-rebuild =
        nix-darwin.packages.${vars.profiles.macos.system}.darwin-rebuild;

      packages.x86_64-linux.disko = inputs.disko.packages.x86_64-linux.disko;

      packages.x86_64-linux.niri-installer-iso =
        (nixpkgs.lib.nixosSystem {
          specialArgs = {
            installTools = self.packages.x86_64-linux;
            targetSystem = self.nixosConfigurations.linux-niri.config.system.build.toplevel;
          };
          modules = [ ./hosts/linux-niri/installer-iso.nix ];
        }).config.system.build.isoImage;

      # The install-time device can change when moving an SSD from USB to
      # internal storage. Both the installer and the host import this layout.
      diskoConfigurations.linux-niri =
        { targetDisk, ... }:
        assert nixpkgs.lib.assertMsg (
          builtins.match "/dev/disk/by-id/[A-Za-z0-9][A-Za-z0-9._:+-]*" targetDisk != null
          && builtins.match ".*-part[0-9]+" targetDisk == null
        ) "Pass the verified whole-disk by-id path using --argstr targetDisk.";
        import ./hosts/linux-niri/layout.nix targetDisk;

      packages.x86_64-linux.niri-install-test = import ./tests/niri-install.nix {
        host = self.nixosConfigurations.linux-niri;
        inherit vars;
      };

      packages.x86_64-linux.niri-workflow-apps =
        let
          inherit (self.nixosConfigurations.linux-niri) pkgs;
        in
        pkgs.linkFarmFromDrvs "niri-workflow-apps" (import ./hosts/linux-niri/workflow-apps.nix pkgs);

      packages.x86_64-linux.niri-dux-trial = import ./hosts/linux-niri/dux-trial.nix {
        inherit (self.nixosConfigurations.linux-niri) pkgs;
      };

      homeConfigurations = {
        linux-desktop = mkProfile "linux-desktop";
        linux-cli = mkProfile "linux-cli";
        wsl = mkProfile "wsl";
        wsl-nixos = mkProfile "wsl-nixos";
        # macOS standalone HM still exposed for hosts not running nix-darwin.
        macos = mkProfile "macos";
      };

      # niri pilot (PC 2), build-only: GNOME default, niri as a second session.
      # `nix flake check` evaluates it. See nix/hosts/linux-desktop-pilot.
      nixosConfigurations.linux-desktop-pilot = nixpkgs.lib.nixosSystem {
        specialArgs = { inherit self vars; };
        modules = [ ./hosts/linux-desktop-pilot/system.nix ];
      };

      nixosConfigurations.linux-niri = nixpkgs.lib.nixosSystem {
        specialArgs = { inherit inputs self vars; };
        modules = [
          ./hosts/linux-niri/system.nix
          inputs.disko.nixosModules.disko
          ./hosts/linux-niri/disk.nix
          ./hosts/linux-niri/hardware.nix
        ];
      };

      packages.x86_64-linux.install-claude = self.nixosConfigurations.linux-niri.pkgs.claude-code;
      packages.x86_64-linux.niri-session-vm-test = import ./tests/niri-session.nix {
        pkgs = nixpkgs.legacyPackages.x86_64-linux;
        inherit inputs self vars;
      };

      # VM smoke test for the pilot: boots it in QEMU (GDM, GNOME default,
      # niri login). Built on demand, not by `nix flake check`:
      #   nix build --no-link -L "git+file://$PWD?dir=nix#packages.x86_64-linux.pilot-vm-test"
      packages.x86_64-linux.pilot-vm-test = import ./tests/pilot-vm.nix {
        pkgs = nixpkgs.legacyPackages.x86_64-linux;
        inherit self vars;
      };

      darwinConfigurations.macos = nix-darwin.lib.darwinSystem {
        system = vars.profiles.macos.system;
        specialArgs = { inherit inputs vars; };
        modules = [
          ./hosts/macos/darwin.nix
          home-manager.darwinModules.home-manager
          {
            nixpkgs.config.allowUnfree = true;
            nixpkgs.overlays = [ (import ./overlays { inherit inputs; }) ];
            system.primaryUser = vars.username;
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = {
              inherit inputs;
              username = vars.username;
            };
            home-manager.users.${vars.username} = {
              imports = [ ./hosts/macos/home.nix ];
              home = {
                username = vars.username;
                inherit (vars.profiles.macos) homeDirectory stateVersion;
              };
            };
          }
        ];
      };
    };
}
