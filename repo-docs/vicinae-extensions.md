# Vicinae extensions (Raycast-compatible)

Vicinae is the Linux launcher this repo ships (`nix/modules/home/gui.nix`,
Linux-desktop only; it autostarts via `~/.config/autostart/vicinae.desktop`).
Vicinae runs **most Raycast extensions** — that compatibility is built into
Vicinae itself, so nothing extra is needed at the Nix level to enable it.

This repo ships the supporting toolchain and a one-command helper:

- Runtime: `vicinae` (gui.nix) + `node`/`npm` (dev.nix `nodejs_22`) + `git`
  (common/packages.nix) — everything the Vicinae dev workflow needs.
- Helper: `scripts/vicinae-extension.sh`, exposed as the `vicinae-ext` command
  (chezmoi `~/.local/bin/vicinae-ext`).

There are two ways to install an extension.

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
