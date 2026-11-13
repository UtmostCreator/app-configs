{ lib, pkgs, ... }:
{
  # Launch Services is user state. HM activation runs as the user, after the
  # nix-darwin Homebrew activation has installed Brave Beta and duti.
  home.activation.defaultBrowser = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin (
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      run env PATH=/opt/homebrew/bin:/usr/local/bin:$PATH \
        ${pkgs.bash}/bin/bash ${./scripts/set-default-browser-macos.sh}
    ''
  );
}
