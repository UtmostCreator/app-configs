# Vicinae extensions (Raycast-compatible)

Vicinae is the Linux launcher this repo ships (`nix/modules/home/gui.nix`,
Linux-desktop only; it autostarts via `~/.config/autostart/vicinae.desktop`).
Vicinae runs **most Raycast extensions** — that compatibility is built into
Vicinae itself, so nothing extra is needed at the Nix level to enable it.

This repo ships the supporting toolchain and a one-command helper:

- Runtime: `vicinae` (gui.nix) + `node`/`npm` (dev.nix `nodejs_22`) + `git`
  (common/packages.nix) — everything the Vicinae dev workflow needs.
- Helper: `ops/vicinae-extension.sh`, exposed as the `vicinae-ext` command
  (chezmoi `~/.local/bin/vicinae-ext`).

There are three ways to install an extension.

## Path 0 — Declarative (Home Manager, shipped with the repo)

The cleanest, reproducible path for **community Vicinae extensions**
(`github:vicinaehq/extensions`): they are installed at build time via the
official Vicinae Home-Manager module, so they ship with `home-manager switch`
— no per-machine clicking.

This repo wires it in `nix/modules/home/vicinae.nix` (`services.vicinae`):

```nix
services.vicinae.extensions =
  with inputs.vicinae-extensions.packages.${pkgs.stdenv.hostPlatform.system};
  [ vscode-recents ];
```

Already shipped this way:

- **`vscode-recents`** (author *ShyAssassin*, "Visual Studio Code Recent
  Projects") — intended for `Alt+E` once a working recent-projects entrypoint is
  verified. `Alt+E` is intentionally unbound in
  `nix/modules/home/gnome-keybindings.nix` until then.

Extension attr names are the folder names under
`github:vicinaehq/extensions/extensions/<name>`. Note: the Vicinae binary here
comes from nixpkgs (`pkgs.vicinae`, Hydra-cached) — only the *extensions* and
the *module* come from the Vicinae flakes, to avoid a source compile. See the
notes in `nix/modules/home/vicinae.nix`.

> **KNOWN ISSUE / FOLLOW-UP (vscode-recents entrypoint not registering).**
> The `vscode-recents` extension is installed on disk
> (`~/.local/share/vicinae/extensions/vicinae-extension-vscode-recents-0`,
> symlinked to the nix store) but Vicinae **v0.21.3 (nixpkgs build) does not
> register it as a launchable entrypoint/deeplink**. Every deeplink form tested
> fails with `… does not refer to a valid entrypoint` (e.g.
> `vicinae://launch/vscode-recents/open-recents`), and the
> `vicinae://extensions/ShyAssassin/vscode-recents` form returns exit 0 but does
> nothing ("not found in store"). Likely cause: version skew between the nixpkgs
> server (0.21.3, `@vicinae/api` consumer) and the newer `vicinae-extensions`
> flake build (`@vicinae/api ^0.20.4`), or the entrypoint index only populates
> for store-installed extensions. **No fallback binding is shipped:** `Alt+E`
> must show recent projects when enabled, not toggle VS Code. **To resolve:**
> either switch `services.vicinae.package` to the upstream `vicinae` flake build
> (matches the extension API version, but triggers a source compile — see
> `nix/modules/home/vicinae.nix`), or wait for a newer `pkgs.vicinae`, then
> rebind `Alt+E` to the verified `vicinae://launch/<provider>/open-recents`
> deeplink.

Use Path A/B below for Raycast extensions not in the Vicinae community repo, or
for development/debugging from source.

## Path A — Vicinae Store (easiest, no build)

Ready-to-use extensions install directly from the in-app store.

```bash
vicinae server --replace   # ensure the server is running (autostarts at login)
vicinae toggle             # open the launcher
```

Search for the **Store** command, find the extension, and install. Store
extensions are pre-bundled and run immediately (they cannot be debugged from
source — use Path B for that).

## Path B — Raycast extension from source (build/develop)

Use this for extensions not in the Vicinae store, or to develop/debug. The
helper automates the official Vicinae flow
(https://vicinae.com/docs → Raycast Compatibility):

```bash
vicinae-ext --list                                   # list available extensions
vicinae-ext --list | grep -i code                    # find the one you want
vicinae-ext visual-studio-code-recent-projects       # dev session (npx vici develop)
vicinae-ext visual-studio-code-recent-projects --build   # production build, no watch
```

What it does (idempotent):

1. Verifies `vicinae`, `node`, `npm`, `git` are present.
2. Clones (shallow) `https://github.com/raycast/extensions` into
   `${XDG_CACHE_HOME:-~/.cache}/vicinae/raycast-extensions` (override with
   `VICINAE_EXT_CACHE`).
3. In `extensions/<name>`: runs `npm install`, then
   `npm install --save-dev @vicinae/api` (the Vicinae SDK that provides `vici`).
4. Runs `npx vici develop` (default) or `npx vici build` (`--build`).

Notes (from the Vicinae docs):

- Do **not** run `npm run dev` — that invokes Raycast's `ray` binary, which only
  works with Raycast. Use `npx vici develop` (the helper does this).
- Keep extension code importing from `@raycast/api`; `@vicinae/api` is only the
  dev/tooling layer.
- Don't install the same extension from the Store *and* run it from source —
  you'll get duplicate entries in the UI.

## The VS Code extension you asked for

`https://www.raycast.com/thomas/visual-studio-code` (Visual Studio Code — open
recent projects). Try the store first; otherwise build from source:

```bash
vicinae-ext --list | grep -i visual-studio-code
vicinae-ext visual-studio-code-recent-projects
```

(The exact directory name lives under `extensions/` in the raycast/extensions
repo; `--list` shows the current name if it differs.)

## Verify

```bash
command -v vicinae node npm git    # toolchain present
vicinae toggle                     # launcher opens; extension appears in the list
```
