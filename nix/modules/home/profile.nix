{ lib, ... }:
{
  # Host "profile" selector for opt-in app sets.
  #
  # Set `myConfig.profile = "personal";` in a host's home.nix (e.g.
  # nix/hosts/linux-desktop/home.nix) to pull in personal-only GUI apps
  # (see nix/modules/home/gui.nix: vesktop + telegram-desktop).
  #
  # Default is "work", which ships nothing personal. This keeps personal chat
  # apps off shared/work machines unless explicitly opted in.
  options.myConfig.profile = lib.mkOption {
    type = lib.types.enum [ "work" "personal" ];
    default = "work";
    example = "personal";
    description = ''
      Machine profile. "personal" enables personal-only applications such as
      Vesktop (Discord + Vencord) and Telegram in the Linux GUI module.
      "work" (default) installs none of them.
    '';
  };
}
