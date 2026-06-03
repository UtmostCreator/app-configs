# Application list (single-script install)

Canonical list of every CLI tool and GUI app this repo installs, with the
**install owner per OS**. One command installs everything installable on the
current host:

```bash
bash scripts/bootstrap.sh --yes
```

On **NixOS** run the NixOS-safe order instead (see `repo-docs/install-nixos.md`);
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
| Brave | Nix(GUI-Linux) stable | cask `brave-browser@beta` | privacy browser; nixpkgs ships stable only |
| Flameshot | Nix(GUI-Linux) | cask | screenshots |
| Bruno | Nix(GUI-Linux) | cask | API client (Linux build exists) |
| IntelliJ IDEA CE | — (excluded) | — (excluded) | intentionally not shipped; VS Code is the IDE |
| **Raycast** | **macOS-only** | cask | launcher — **not installed on Linux** |
| **AeroSpace** | **macOS-only** | cask | tiling WM — **not installed on Linux** |
| Sequel Ace | macOS-only | cask | MySQL GUI |
| BBEdit | macOS-only | cask | editor |
| BetterDisplay | macOS-only | cask | display control |
| Karabiner-Elements | macOS-only | cask | keyboard remap |
| Ice / AltTab / Stats / NoTunes / LinearMouse | macOS-only | cask (opt) | menu-bar/UX utilities |

> **Why Raycast and AeroSpace are not on this Linux PC:** their nixpkgs
> packages declare `meta.platforms = [ aarch64-darwin x86_64-darwin ]` only.
> They are declared in the darwin Homebrew module and intentionally excluded
> from `gui.nix`. Linux equivalents (if wanted) would be a separate slice
> (e.g. `albert`/`ulauncher` for a launcher, `i3`/`sway`/`hyprland` for tiling).

## CLI tools (Nix on every OS)

Terminal/shell: `fish`, `tmux`, `starship`, `atuin`, `zoxide`, `fzf`, `yazi`,
`btop`.
Search/files: `ripgrep` (rg), `ripgrep-all` (rga), `fd`, `bat`, `eza`,
`tealdeer` (tldr), `jq`, `yq-go` (yq).
Git/dev: `gh`, `lazygit`, `delta` (git-delta), `difftastic` (difft),
`neovim` (nvim), `ast-grep`.
Lint/test/security: `shellcheck`, `shfmt`, `actionlint`, `lychee`, `bats`,
`semgrep`, `gitleaks`, `scc`.
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
For the persistent NixOS login shell, see `repo-docs/install-nixos.md` (system
`configuration.nix` snippet).

## Optional / per-project (not auto-installed)

- `mise run tools:optional:install` → `dive`, `fx`, `navi`, `glow`, `gum`
  (via aqua).
- `direnv` is **DROPPED** (mise per-project env replaces it).
- macOS-only, never installed on Linux: `duti` (default-app setter).

## Verify what is installed

```bash
bash scripts/doctor.sh          # required + optional binaries
home-manager generations        # current Nix closure
command -v ghostty bruno flameshot code firefox fish tmux delta
```
