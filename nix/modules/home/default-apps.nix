{ lib, pkgs, ... }:
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
in
{
  # Declarative default applications (Linux desktop only).
  #
  # Linux uses XDG MIME associations (~/.config/mimeapps.list). home-manager's
  # xdg.mimeApps owns that file when enabled, so defaults stop being a manual
  # GNOME "Default Applications" click-through and become reproducible.
  #
  # This module is imported ONLY by the linux-desktop host. macOS has no clean
  # declarative default-app mechanism in nix-darwin/home-manager; the duti-based
  # approach is documented as a TODO in repo-docs/default-apps.md.
  #
  # Guarded on isLinux so an accidental import on Darwin is a no-op rather than
  # writing a Linux mimeapps.list into a macOS home.
  xdg.mimeApps = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
    enable = true;
    defaultApplications = mkAssoc brave braveTypes // mkAssoc code codeTypes;
  };
}
