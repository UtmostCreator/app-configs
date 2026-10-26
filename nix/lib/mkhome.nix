{ inputs }:

{
  system,
  username,
  homeDirectory,
  stateVersion,
  modules,
  overlays ? [ ],
  extraSpecialArgs ? { },
}:

let
  pkgs = import inputs.nixpkgs {
    inherit system;
    config.allowUnfree = true;
    overlays = [ (import ../overlays { inherit inputs; }) ] ++ overlays;
  };
in
inputs.home-manager.lib.homeManagerConfiguration {
  inherit pkgs;
  modules = modules ++ [
    {
      home = { inherit username homeDirectory stateVersion; };
      # The ONLY allowed programs.<x>.enable; everything else is
      # `home.packages = [ ... ]` only per v2 architecture.
      programs.home-manager.enable = true;
    }
  ];
  extraSpecialArgs = extraSpecialArgs // {
    inherit inputs username;
  };
}
