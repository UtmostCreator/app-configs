# Nix-specific pieces & cross-distro replacements

Honest assessment: **almost nothing in this repo is locked to Nix.** The CLI
tools are all upstream open-source projects available on every distro via
`apt`/`dnf`/`pacman`/`brew`/`cargo`/`npm`. What *is* Nix-specific is the
**mechanism** (flakes + Home Manager + the `/nix/store` model), not the
software. This page lists the genuinely Nix-coupled bits and the best
replacement on a non-Nix Linux distro or macOS.

## 1. Nix-mechanism features (no like-for-like elsewhere)

These are the reasons to use Nix; they have no exact equivalent on Ubuntu/
Fedora/Arch. If you leave NixOS, you lose these and fall back to the
alternatives shown.

| Nix feature (used here) | What it gives you | Best replacement off Nix |
| --- | --- | --- |
| `home-manager switch` (declarative user env) | One command installs all CLI/GUI + dotfiles, reproducibly | chezmoi (dotfiles) + a package list installed by `apt`/`brew`; lose atomic rollback |
| `nixos-rebuild switch` + generations | Atomic system config + instant rollback | `apt`/`dnf` + Btrfs/Timeshift snapshots, or Fedora **Silverblue** (`rpm-ostree`) for image-based rollback |
| `flake.lock` pinned inputs | Bit-reproducible package set across machines | Docker images, or `asdf`/`mise` pins (weaker — no full closure) |
| `/nix/store` + `nix store optimise` | Many versions coexist; dedup by hard-link | None; distros mutate a single global package set |
| `nix.gc` generation GC | Time-windowed cleanup keeping rollbacks | Manual `apt autoremove` / snapshot pruning (no generation model) |
| `nix develop` / dev shells | Per-project reproducible toolchains | `mise` + Docker devcontainers, or `devenv`/`direnv` |

> Cross-distro takeaway: on Ubuntu/Fedora/macOS, install the **Nix package
> manager** (not full NixOS) and keep using flakes + Home Manager for the
> reproducibility benefits, while the OS itself stays conventional. This repo's
> `nix/` flake already exposes `homeConfigurations` that work on any Linux/WSL/
> macOS host with Nix installed — only the **system** layer
> (`nixos-rebuild`) is NixOS-only.

## 2. Packages whose Nix attr name differs from the common name

Same software, different package identifier. If you reinstall on another distro,
use the right name:

| In this repo (nixpkgs attr) | Binary | apt / dnf | brew | Notes |
| --- | --- | --- | --- | --- |
| `yq-go` | `yq` | `yq` (or Go release) | `yq` | Go yq, not the Python one |
| `tealdeer` | `tldr` | `tealdeer` (cargo) | `tealdeer` | Rust tldr client |
| `ripgrep-all` | `rga` | cargo `ripgrep-all` | `ripgrep-all` | |
| `delta` (git-delta) | `delta` | `git-delta` | `git-delta` | |
| `difftastic` | `difft` | cargo `difftastic` | `difftastic` | |
| `stripe-cli` | `stripe` | stripe apt repo | `stripe/stripe-cli/stripe` | |
| `mariadb` (for client) | `mysql` | `mariadb-client` | `mysql-client` | we only want the client |
| `nixfmt-rfc-style` | `nixfmt` | — (Nix only) | — | Nix formatter; N/A off Nix |
| `nodejs_22` | `node` | nodesource / `mise` | `node@22` | **on NixOS provided by Nix**, not mise (see install-nixos.md) |

## 3. Nix-only tooling we added (no point off Nix)

These exist only to maintain the Nix config. On a non-Nix machine you simply
would not have or need them:

| Package | Purpose | Off-Nix replacement |
| --- | --- | --- |
| `statix` | Lint Nix code | N/A (no Nix code) |
| `deadnix` | Find dead Nix bindings | N/A |
| `nixfmt-rfc-style` | Format Nix | N/A |
| `nix-index` (`nix-locate`) | Find which package ships a file | `apt-file search` / `dnf provides` / `pkgfile` |
| `nh` | Friendlier `nixos-rebuild`/HM wrapper | N/A |

## 4. GUI apps: Nix on Linux vs cask on macOS vs distro packages

The GUI apps are portable software; only the **install channel** differs.

| App | NixOS / Nix-on-Linux | Other Linux | macOS |
| --- | --- | --- | --- |
| Ghostty | `nix gui.nix` | Flatpak / distro repo | Homebrew cask |
| VS Code | `nix gui.nix` (`vscode`) | `apt`/`dnf`/Flatpak/snap | cask |
| Firefox | `nix gui.nix` | distro default | cask |
| Flameshot | `nix gui.nix` | `apt`/`dnf install flameshot` | cask |
| Bruno | `nix gui.nix` | Flatpak / AppImage / `.deb` | cask |
| Raycast | **macOS only** (no Linux build) | albert / ulauncher (replacement) | cask |
| AeroSpace | **macOS only** | i3 / sway / Hyprland (replacement) | cask |

(See `docs/app-list.md` for the full per-OS matrix.)

## 5. Things that assume Nix paths

A few config details assume the Nix model. If you port the dotfiles to a
non-Nix host, adjust:

- **zsh plugins** (`zsh-autosuggestions`, `zsh-syntax-highlighting`) are
  sourced from `~/.nix-profile/share/...` on Nix. Off Nix, install via the
  distro/brew and update the source path. (On fish we use the built-ins, so
  fish needs no change.)
- **fish/zsh `mise activate`, `starship init`, `atuin init`** are
  binary-agnostic — they work anywhere those binaries are on PATH.
- The repo deliberately does **not** hard-code `/nix/store` paths in dotfiles;
  everything resolves via PATH, so the dotfiles are portable.

## Bottom line

- The **software** is portable. The **reproducibility machinery** (flakes,
  Home Manager generations, `nixos-rebuild` rollbacks, store dedup) is the
  Nix-specific value and has only partial replacements elsewhere
  (snapshots, Silverblue, Docker, mise).
- To leave Nix with the least pain: keep **chezmoi** for dotfiles and **mise**
  for runtimes (both already cross-platform here), and reinstall the package
  list with your distro's manager using the name map in section 2.
