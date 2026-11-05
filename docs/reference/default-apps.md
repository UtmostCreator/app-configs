# Default applications

How this repo sets the OS "default app" for a file type or URL scheme, per
platform. Goal: Brave for the web + PDFs, VS Code for source/text files.

## Linux desktop — declared defaults with writable overrides (implemented)

Linux uses **XDG MIME associations** (`~/.config/mimeapps.list`). home-manager's
standard `xdg.mimeApps` module makes that file a read-only Nix-store link. That
breaks GNOME's **Set as Default** action because GLib follows the link and tries
to create its atomic-replacement file inside `/nix/store`.

This repo instead has Home Manager link both XDG MIME locations to a writable
file at `~/.local/state/home-manager/mimeapps.list`. Each activation re-applies
the mappings declared below, while defaults added for other MIME types through
GNOME remain intact. On migration, an existing `~/.config/mimeapps.list` is
copied first so manual choices are preserved.

- Module: `nix/modules/home/default-apps.nix`
- Imported by: `nix/hosts/linux-desktop/home.nix` only (guarded on `isLinux`).
- Applied by: `home-manager switch` (same apply that installs the GUI apps).

Current mapping:

| Type / scheme | Default app | `.desktop` id |
| --- | --- | --- |
| `application/pdf` | Brave | `brave-browser.desktop` |
| `text/html`, `application/xhtml+xml` | Brave | `brave-browser.desktop` |
| `x-scheme-handler/http`, `https`, `about`, `unknown` | Brave | `brave-browser.desktop` |
| `text/plain`, `text/markdown`, `application/json`, PHP/JS/TS/Python/shell/C/C++/Java/Go/Rust/CSS/XML/TOML/SQL/Lua/Ruby | VS Code | `code.desktop` |

Verify after `home-manager switch`:

```bash
readlink -e ~/.config/mimeapps.list
# -> ~/.local/state/home-manager/mimeapps.list (a writable regular file)
xdg-mime query default application/pdf      # -> brave-browser.desktop
xdg-mime query default x-scheme-handler/https
xdg-mime query default text/x-php           # -> code.desktop
xdg-settings get default-web-browser        # GNOME web-browser default
```

> Note: `code.desktop` does not itself advertise a `MimeType=` list, so mapping
> source types to it is done explicitly in `defaultApplications`. This works for
> "Open" defaults; some file managers may still show a "not associated" hint.

## Brave + local dev servers

Since Brave is the default browser/web handler here, a heads-up for local
development: Brave Shields and per-site content settings can block or break a
local server (e.g. `http://localhost:3000`, `http://app.test`,
`http://*.localhost`), typically showing up as blocked scripts, mixed-content
errors, or refused requests.

If a local dev URL misbehaves, allow it explicitly:

1. Open the per-site permissions page:

   ```text
   brave://settings/content/siteDetails
   ```

   (or click the Shields / lock icon in the address bar while on the dev URL).

2. For the dev origin, set the needed permissions (e.g. allow JavaScript,
   insecure content, cookies) and/or lower Brave Shields to **Down** for that
   site only.

This is a per-user runtime setting, not something this repo provisions — it is
documented here so the default-browser choice does not surprise local dev work.

## macOS — Brave Beta on every activation

Homebrew installs `brave-browser@beta` and `duti`. The user Home Manager
activation in `nix/modules/home/default-browser-macos.nix` registers
`/Applications/Brave Browser Beta.app` with Launch Services, then uses `duti`
to set `com.brave.Browser.beta` for HTTP, HTTPS, HTML, XHTML and PDF. It checks
the resulting HTML handler. This runs on each `darwin-rebuild switch` and on
standalone macOS Home Manager activation (after installing the cask and duti).
The activation fails if the app is absent or setting a handler fails.

```bash
duti -d public.html  # com.brave.Browser.beta
duti -d com.adobe.pdf
```

## Linux Brave package and updates

Nixpkgs removed Brave in November 2026 because there were no committers among
its maintainers to unblock security issues. The repository now packages the
official stable `.deb` using the Nixpkgs wrapper adapted in
`nix/packages/brave/`. `release.json` pins the version, official GitHub asset
URLs and SHA-256 digests. `sys-update` refreshes this lock from Brave's latest
stable GitHub release before checking and building the host configuration.
Nix verifies the binary digest during the build. A successful update commits
both release locks; rollback restores both.

`nix flake check` now evaluates the matching Home Manager profiles, and
`sys-update` builds the selected host closure before applying dotfiles. A
future incompatible package update stops before activation. Arbitrary upstream
changes can still fail a build; this prevents this Brave removal from recurring
and catches other package failures before applying configuration.

The original Linux defaults were introduced in commit `26951c2`; commit
`b6040de` made the MIME file writable while reapplying declared defaults.
