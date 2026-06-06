{ inputs, ... }:
{
  imports = [
    ../../modules/common
    ../../modules/home
    ../../modules/home/gui.nix
    ../../modules/home/default-apps.nix
    ../../modules/home/gnome-files.nix
    ../../modules/home/gnome-extensions.nix
    ../../modules/home/gnome-keybindings.nix
    # Vicinae launcher via its official Home-Manager module (services.vicinae),
    # plus our config + declarative extensions (nix/modules/home/vicinae.nix).
    inputs.vicinae.homeManagerModules.default
    ../../modules/home/vicinae.nix
  ];

  # Personal machine: pull in personal-only GUI apps (Vesktop, Telegram,
  # syncthing) declared in gui.nix behind `config.myConfig.profile == "personal"`.
  # See nix/modules/home/profile.nix for the option.
  myConfig.profile = "personal";
}
