{ inputs }:
final: prev: {
  # Brave was removed from nixpkgs in November 2026. Keep the official Linux
  # release under repository ownership; sys-update refreshes its release lock.
  brave = final.callPackage ../packages/brave { };

  # TEMPORARY pin (2026-10-26): semgrep-core 1.180.0 in nixpkgs-unstable 674a202
  # aborts in fixupPhase (patchelf 0.19.2 assertion `splitIndex == -1`), and
  # Hydra has no cached build. Take semgrep from the `nixpkgs-last-good` input.
  # Remove this attr once `nix build --inputs-from ./nix nixpkgs#semgrep`
  # succeeds again.
  semgrep = inputs.nixpkgs-last-good.legacyPackages.${prev.stdenv.hostPlatform.system}.semgrep;

  # TEMPORARY (2026-11-05): nixpkgs-unstable ships opencode 2.2.5 with a stale
  # Linux node_modules fixed-output hash, so the build fails with a hash
  # mismatch. nixpkgs master fixed it in c399e1b7fb90 ("opencode: fix hash",
  # 2026-11-04) using the hash below. The version guard makes this a no-op for
  # any other opencode version; remove it once nixpkgs-unstable has that commit.
  opencode =
    if prev.opencode.version == "2.2.5" && prev.stdenv.hostPlatform.isLinux then
      prev.opencode.overrideAttrs (old: {
        node_modules = old.node_modules.overrideAttrs {
          outputHash = "sha256-prx9dX7kUvs/E3zopkaPk5LXh3xJAy5sZeum/W8L7cA=";
        };
      })
    else
      prev.opencode;

  # TEMPORARY (2026-11-16): Ghostty 1.4.0 segfaults at startup under the ibus
  # GTK4 input-method module (ibus 1.5.33, GTK 4.24). ibus_im_context_set_client_widget
  # and gtk_text_view_init recurse until the stack overflows. Other GTK4 apps are
  # unaffected. Run Ghostty with GTK's built-in simple IM (GTK4 id
  # gtk-im-context-simple) instead. Keyboard layouts switched by GNOME Shell
  # (not ibus) are unaffected. The variable is inherited by everything started
  # from a Ghostty shell, so GTK apps launched from a tab also lose ibus input.
  # The D-Bus and systemd activation files hard-code the package's own bin path,
  # so they are rewritten to point at the wrapper too. The version guard makes
  # this a no-op after an upgrade. Recheck with
  #   GTK_IM_MODULE=ibus <unwrapped ghostty>
  # and remove this attr once it starts.
  # A review cited Red Hat bug 2512529 / ibus PR 2929 as the upstream report;
  # not verified here, so check it before relying on it to drop this attr.
  # See docs/platforms/nixos/desktop-stability.md.
  ghostty =
    if prev.ghostty.version == "1.4.0" && prev.stdenv.hostPlatform.isLinux then
      prev.symlinkJoin {
        name = "ghostty-${prev.ghostty.version}-simple-im";
        paths = [ prev.ghostty ];
        nativeBuildInputs = [ prev.makeWrapper ];
        postBuild = ''
          rm "$out/bin/ghostty"
          makeWrapper ${prev.ghostty}/bin/ghostty "$out/bin/ghostty" --set GTK_IM_MODULE gtk-im-context-simple
          for f in share/dbus-1/services/com.mitchellh.ghostty.service \
                   share/systemd/user/app-com.mitchellh.ghostty.service; do
            rm "$out/$f"
            sed "s|${prev.ghostty}/bin/ghostty|$out/bin/ghostty|g" "${prev.ghostty}/$f" > "$out/$f"
          done
        '';
        inherit (prev.ghostty) version meta;
      }
    else
      prev.ghostty;
}
