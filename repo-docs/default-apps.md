# Default applications

How this repo sets the OS "default app" for a file type or URL scheme, per
platform. Goal: Brave for the web + PDFs, VS Code for source/text files.

## Linux desktop — declarative (implemented)

Linux uses **XDG MIME associations** (`~/.config/mimeapps.list`). home-manager's
`xdg.mimeApps` owns that file, so defaults are reproducible instead of a manual
GNOME "Default Applications" click-through.

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
xdg-mime query default application/pdf      # -> brave-browser.desktop
xdg-mime query default x-scheme-handler/https
xdg-mime query default text/x-php           # -> code.desktop
xdg-settings get default-web-browser        # GNOME web-browser default
```

> Note: `code.desktop` does not itself advertise a `MimeType=` list, so mapping
> source types to it is done explicitly in `defaultApplications`. This works for
> "Open" defaults; some file managers may still show a "not associated" hint.

## macOS — TODO (not implemented)

nix-darwin / home-manager have **no clean declarative default-app option** on
macOS. Defaults live in Launch Services and are normally set imperatively with
[`duti`](https://github.com/moretension/duti) (UTI-based) or `defaultbrowser`.

Planned approach for a future slice (not shipped yet):

1. Add `duti` (already noted macOS-only in `repo-docs/app-list.md`).
2. Set handlers by bundle id + UTI, e.g.:

   ```bash
   # Browser + web schemes -> Brave
   duti -s com.brave.Browser public.html      all
   duti -s com.brave.Browser http             all
   duti -s com.brave.Browser https            all
   # PDFs -> Brave
   duti -s com.brave.Browser com.adobe.pdf    all
   # Source/text -> VS Code
   duti -s com.microsoft.VSCode public.plain-text all
   duti -s com.microsoft.VSCode public.source-code all
   ```

3. Run those once (e.g. a nix-darwin `system.activationScripts` block or a
   `mise` task). This is imperative state, so it is **out of scope** for the
   declarative `xdg.mimeApps` module above and tracked here as a follow-up.

> Bundle ids: Brave Beta cask installs `com.brave.Browser.beta`; the stable
> Brave is `com.brave.Browser`. Confirm with
> `osascript -e 'id of app "Brave Browser Beta"'` before wiring duti.
