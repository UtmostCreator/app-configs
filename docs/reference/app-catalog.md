# Application list (single-script install)

Canonical list of every CLI tool and GUI app this repo installs, with the
**install owner per OS**. One command installs everything installable on the
current host:

```bash
bash ops/bootstrap.sh --yes
```

On **NixOS** run the NixOS-safe order instead (see `docs/platforms/nixos/install.md`);
either path ends with `home-manager switch`, which installs all Nix-owned
CLI **and** Linux GUI apps in one apply.

Legend: **Nix** = `nix/modules/home/*` (cross-platform) · **Nix(GUI-Linux)** =
`nix/modules/home/gui.nix` (Linux desktop only) · **cask** =
`nix/modules/darwin/homebrew.nix` (macOS only) · **macOS-only** = no Linux
build exists, never installed on Linux.

## GUI applications

| App | Linux | macOS | Notes |
| --- | --- | --- | --- |
| Ghostty | Nix(GUI-Linux) | cask | GPU terminal |
| VS Code | Nix(GUI-Linux) `vscode` | cask `visual-studio-code` | single IDE on all systems |
| Firefox | Nix(GUI-Linux) | cask | browser (parity: cask enabled) |
| Brave | Nix(GUI-Linux) official stable | cask `brave-browser@beta` | default browser; official release packaged by this repo |
| Flameshot | Nix(GUI-Linux) | not shipped on macOS (cask removed) | screenshots |
| Bruno | Nix(GUI-Linux) | cask | API client (Linux build exists) |
| QDirStat / GrandPerspective | Nix(GUI-Linux) `qdirstat` | cask `grandperspective` | disk usage analyser (Linux also has GNOME Baobab) |
| Double Commander / Nimble Commander | Nix(GUI-Linux) `doublecmd` | cask `nimble-commander` | dual-pane file manager |
| LocalSend | Nix(GUI-Linux) | cask | LAN file transfer; Linux receive needs port 53317 open |
| Czkawka / Krokiet | Nix(GUI-Linux) `czkawka` | — (formula exists, untested) | duplicate and similar-file finder |
| IntelliJ IDEA CE | — (excluded) | — (excluded) | intentionally not shipped; VS Code is the IDE |
| **Raycast** | **macOS-only** | cask | launcher — **not installed on Linux** |
| **AeroSpace** | **macOS-only** | cask | tiling WM — **not installed on Linux** |
| Sequel Ace | macOS-only | cask | MySQL GUI |
| BBEdit | macOS-only | cask | editor |
| BetterDisplay | macOS-only | cask | display control |
| Karabiner-Elements | macOS-only | cask | keyboard remap |
| Ice / AltTab / Stats / NoTunes / LinearMouse | macOS-only | cask (opt) | menu-bar/UX utilities |

Every reviewed option for file management, disk analysis, transfer and
duplicate finding, including **paid** ones (ForkLift, DaisyDisk, Transmit,
Path Finder, ...), is in [`app-options.yaml`](app-options.yaml) with a
free/freemium/paid label per OS and the reason it was picked or skipped.

> **Why Raycast and AeroSpace are not on this Linux PC:** their nixpkgs
> packages declare `meta.platforms = [ aarch64-darwin x86_64-darwin ]` only.
> They are declared in the darwin Homebrew module and intentionally excluded
> from `gui.nix`. Linux equivalents (if wanted) would be a separate slice
> (e.g. `albert`/`ulauncher` for a launcher, `i3`/`sway`/`hyprland` for tiling).

## CLI tools (Nix on every OS)

Terminal/shell: `fish`, `tmux`, `starship`, `atuin`, `zoxide`, `fzf`, `yazi`,
`btop`.
Search/files: `ripgrep` (rg), `ripgrep-all` (rga), `fd`, `bat`, `eza`,
`tlrc` (tldr), `jq`, `yq-go` (yq).
Git/dev: `gh`, `lazygit`, `delta` (git-delta), `difftastic` (difft),
`neovim` (nvim), `ast-grep`.
Lint/test/security: `shellcheck`, `shfmt`, `actionlint`, `lychee`, `bats`,
`semgrep`, `gitleaks`, `trivy`, `osv-scanner`, `scc`.
Containers/runtime: `docker` (CLI), `docker-buildx`, `colima`,
`node` (nodejs_22, **Nix on NixOS** — see install-nixos.md), `pnpm`.
DB/API: `mariadb` (mysql client), `stripe-cli` (stripe).
Language: `php` (8.4 with extensions — powers the AI workflow validators).
AI context packers (now Nix-installed, not optional): `repomix`,
`files-to-prompt`, `code2prompt`.
Misc: `p7zip`, `lnav`, `watchexec`.

Bootstrap-installed via `nix profile` (not in the modules): `chezmoi`,
`mise`, `home-manager`, `lefthook`.

## Shell

Interactive shell is **fish** (config: `~/.config/fish/config.fish`).
`~/.bashrc` auto-`exec`s into fish for interactive terminals, so you land in
fish without changing the system login shell. Escape hatch: `NO_FISH=1 bash`.
For the persistent NixOS login shell, see `docs/platforms/nixos/install.md` (system
`configuration.nix` snippet).

## Optional / per-project (not auto-installed)

- `mise run tools:optional:install` → `dive`, `fx`, `gum`
  (via aqua). `navi` and `glow` are Nix packages (`cli.nix`).
- `direnv` is **DROPPED** (mise per-project env replaces it).
- macOS-only, never installed on Linux: `duti` (default-app setter).

## Verify what is installed

```bash
bash ops/doctor.sh          # required + optional binaries
home-manager generations        # current Nix closure
command -v ghostty bruno flameshot code firefox fish tmux delta
```
