{
  imports = [
    ../../modules/common
    ../../modules/home
    ../../modules/home/gui.nix
    ../../modules/home/default-browser-macos.nix
  ];

  # Determinate Nix owns the Nix package and nix.conf (see darwin.nix).
  myConfig.nixSystemManaged = true;
}
