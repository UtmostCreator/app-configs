{
  description = "Personal dev environment for macOS, Linux desktop, Linux CLI, and WSL2";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

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

      mkProfile =
        name:
        let
          profile = vars.profiles.${name};
        in
        mkHome {
          inherit (profile) system homeDirectory stateVersion;
          username = vars.username;
          modules = [ (./hosts + "/${name}/home.nix") ];
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
