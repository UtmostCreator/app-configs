{
  pkgs,
  inputs,
  lib,
  ...
}:
{
  # Vicinae launcher, managed via its official Home-Manager module
  # (programs.vicinae, provided by the `vicinae` flake input and imported in
  # nix/hosts/linux-desktop/home.nix), with declarative extension installation.
  #
  # Why the module instead of just a package:
  #   - `extensions` installs Vicinae extensions reproducibly at build time, so
  #     they ship with the repo (no per-machine in-app Store clicks). Here we
  #     ship `vscode-recents` (preview / open recent VS Code projects).
  #   - `systemd.autoStart` runs the Vicinae server as a user service — a single
  #     source of truth for startup.
  #
  # Package: uses the nixpkgs build (pkgs.vicinae), which is built by Hydra and
  # cached on cache.nixos.org — so it installs WITHOUT compiling Vicinae from
  # source. We deliberately do NOT use the `vicinae` flake's own build: for our
  # current lock it is a cache miss against vicinae.cachix.org and would trigger
  # a long C++/Qt source build. We still consume the flake's Home-Manager MODULE
  # (programs.vicinae) and the `vicinae-extensions` packages — only the binary
  # comes from nixpkgs. If you later want the newer upstream Vicinae, set
  # `package = inputs.vicinae.packages.${pkgs.stdenv.hostPlatform.system}.default`
  # and ensure vicinae.cachix.org actually has a matching build (else expect a
  # source compile).
  #
  # GNOME Wayland: USE_LAYER_SHELL=1 lets the launcher render as a layer surface.
  # The vicinae@dagimg-dot GNOME extension (gnome-extensions.nix) is still
  # required for window-management + clipboard integration and is unaffected.
  #
  # Linux-desktop only; guarded on isLinux so an accidental non-Linux import is
  # a no-op (Vicinae is Linux-only).
  config = lib.mkIf pkgs.stdenv.isLinux {
    programs.vicinae = {
      enable = true;
      # Hydra-cached nixpkgs build (no source compile). See note above.
      package = pkgs.vicinae;
      systemd = {
        enable = true;
        autoStart = true;
        environment = {
          USE_LAYER_SHELL = "1";
        };
      };
      # Declaratively installed extensions. Attr names match the folder names in
      # github:vicinaehq/extensions/extensions/<name>.
      extensions = with inputs.vicinae-extensions.packages.${pkgs.stdenv.hostPlatform.system}; [
        vscode-recents # open / preview recent VS Code projects
      ];
    };
  };
}
