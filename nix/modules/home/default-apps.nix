{
  config,
  lib,
  pkgs,
  ...
}:
let
  # Desktop-entry IDs verified present on this host (NixOS GNOME) under
  # /run/current-system/sw/share/applications and ~/.nix-profile/share/applications:
  #   brave-browser.desktop  (declares application/pdf + http/https + text/html)
  #   code.desktop           (VS Code)
  brave = "brave-browser.desktop";
  code = "code.desktop";

  # Programming / text file types that should open in VS Code by default.
  # These MIME types are what shared-mime-info commonly assigns to source
  # files; mapping them to code.desktop makes "Open" default to VS Code even
  # though code.desktop does not itself advertise a MimeType= list.
  codeTypes = [
    "text/plain"
    "text/markdown"
    "text/x-markdown"
    "application/json"
    "application/x-yaml"
    "text/x-php"
    "application/x-php"
    "application/x-httpd-php"
    "text/javascript"
    "application/javascript"
    "application/x-javascript"
    "application/typescript"
    "text/x-python"
    "text/x-python3"
    "application/x-shellscript"
    "text/x-shellscript"
    "text/x-csrc"
    "text/x-c++src"
    "text/x-chdr"
    "text/x-java"
    "text/x-go"
    "text/x-rust"
    "text/css"
    "text/xml"
    "application/xml"
    "application/toml"
    "text/x-sql"
    "text/x-lua"
    "text/x-ruby"
  ];

  # Brave handles the web + PDFs (brave-browser.desktop declares these).
  braveTypes = [
    "application/pdf"
    "text/html"
    "application/xhtml+xml"
    "x-scheme-handler/http"
    "x-scheme-handler/https"
    "x-scheme-handler/about"
    "x-scheme-handler/unknown"
  ];

  mkAssoc = entry: types: lib.genAttrs types (_: entry);

  defaultApplications = mkAssoc brave braveTypes // mkAssoc code codeTypes;

  # Home Manager's xdg.mimeApps module links mimeapps.list directly into the
  # Nix store. GLib follows that link when changing a default application and
  # then tries to create its atomic-replacement file beside the store target,
  # which fails because /nix/store is read-only. Keep the visible XDG files
  # managed by Home Manager, but point them at this mutable user-state file.
  mutableMimeApps = "${config.xdg.stateHome}/home-manager/mimeapps.list";
  mutableMimeAppsDir = builtins.dirOf mutableMimeApps;

  initialMimeApps = (pkgs.formats.ini { }).generate "mimeapps.list" {
    "Default Applications" = lib.mapAttrs (
      _: applications: lib.concatStringsSep ";" (lib.toList applications)
    ) defaultApplications;
  };

  applyDeclaredDefaults = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (
      mime: applications:
      let
        value = lib.concatStringsSep ";" (lib.toList applications);
      in
      ''
        run ${pkgs.crudini}/bin/crudini --ini-options=nospace --inplace \
          --set "$mutable_file" "Default Applications" \
          ${lib.escapeShellArg mime} ${lib.escapeShellArg value}
      ''
    ) defaultApplications
  );
in
{
  # Default applications (Linux desktop only).
  #
  # Keep both standard locations linked to one mutable file. In particular,
  # this must not use xdg.mimeApps: that module intentionally generates a
  # read-only store link, which prevents GNOME from changing defaults.
  #
  # This module is imported ONLY by the linux-desktop host. macOS has no clean
  # declarative default-app mechanism in nix-darwin/home-manager; the duti-based
  # approach is documented as a TODO in repo-docs/default-apps.md.
  #
  # Guarded on isLinux so an accidental import on Darwin is a no-op rather than
  # writing a Linux mimeapps.list into a macOS home.
  xdg.configFile."mimeapps.list" = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
    source = config.lib.file.mkOutOfStoreSymlink mutableMimeApps;
    # Migrate a regular file too, while preserving its contents below.
    force = true;
  };

  # Deprecated, but still read by some applications. Point it at the same
  # mutable file so the two locations cannot drift apart.
  xdg.dataFile."applications/mimeapps.list" = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
    source = config.lib.file.mkOutOfStoreSymlink mutableMimeApps;
    force = true;
  };

  home.activation.mutableMimeApps = lib.mkIf pkgs.stdenv.hostPlatform.isLinux (
    # Run before linkGeneration replaces the old store link. If the user has
    # already made mimeapps.list writable, copy it first so their choices are
    # retained during this one-time migration.
    lib.hm.dag.entryBetween [ "linkGeneration" ] [ "writeBoundary" ] ''
      mutable_file=${lib.escapeShellArg mutableMimeApps}
      visible_file=${lib.escapeShellArg "${config.xdg.configHome}/mimeapps.list"}

      run mkdir -p ${lib.escapeShellArg mutableMimeAppsDir}
      if [[ ! -e "$mutable_file" && ! -L "$mutable_file" ]]; then
        if [[ -e "$visible_file" ]]; then
          run install -m 0644 "$visible_file" "$mutable_file"
        else
          run install -m 0644 ${initialMimeApps} "$mutable_file"
        fi
      fi

      # Re-apply only the mappings declared here. Defaults added for other MIME
      # types through GNOME remain intact across Home Manager activations.
      ${applyDeclaredDefaults}
    ''
  );
}
