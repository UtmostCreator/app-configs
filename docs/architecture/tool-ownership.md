# Tool ownership

Canonical statement of which tool owns which concern in this repository.
Companion to `docs/plans/migration/implementation.md`. Companion audit docs:
`repo-docs/migration-source-of-truth.md`, `repo-docs/migration-package-ownership.md`,
`repo-docs/migration-decisions.md`.

## Targets

- **macOS** — primary, full coverage (Home Manager + nix-darwin + Homebrew)
- **Linux desktop** — primary, full coverage (Home Manager standalone + GUI module)
- **Linux CLI / headless** — CLI-only coverage (Home Manager standalone, no GUI)
- **WSL2** — CLI/dev parity with macOS (WSL1 is refused); see
  `docs/platforms/wsl/setup.md`. Windows-side tooling is out of scope.
- **Windows native** — explicitly not supported.

## Principle: one owner per target path, per host

Every target path (file, unit, package, setting) has exactly one owner **on a
given host**. No path may be declared both in `home/` (chezmoi) and in a Home
Manager `xdg.configFile` / `home.file` for the same host. Home Manager may
declare only what the two tables under "Home Manager allowlist" list. A new
entry in an enforced family (`programs.*`, `services.*`, `xdg.configFile`)
needs an allowlist edit in `ops/validate-config.sh` (tracked as T-0014) plus a
row in this document. A new entry in an also-permitted family needs a row
only.

`ops/validate-config.sh` enforces this: a Home Manager `xdg.configFile` or
`home.file` target that is also a chezmoi target (any tracked file under
`home/`) fails unless `chezmoi managed` no longer lists the chezmoi copy, with
`home/.chezmoiignore` evaluated by chezmoi itself per host (hermetic scratch
source; template data only for `.chezmoi.os`, `hostProfile` and `gui`). Both
`gui` values must be ignored for each profile: all Linux profiles
(linux-desktop, linux-cli, wsl) in the default run, the evaluated profile's own
host with `--eval`. In the default (text) run a `home.file` declaration is
decided only when it is one attrset literal `{ ... }`, optionally behind a
single wrapper (`mkIf <cond>`, `optionalAttrs <cond>`, `mkOverride <n>`,
`mkDefault`, `mkForce`, `mkBefore`, `mkAfter`), or `mkMerge [ ... ]` of bare
literals, with literal keys and none of `inherit`, `//`, `let`, `with`, `rec`,
`import`, `or`, attribute selection or parentheses outside a wrapper's
condition. Anything else, and any `home` or `config.home` bound to something
other than an attrset literal, is printed as a NOTE and is only decided by
`--eval`; the default run then prints no `[OK]` for the `home.file` rule.

Known exceptions to the rule, all follow-ups:

- `flameshot/flameshot.ini` is declared by both owners, on different hosts.
  Home Manager owns it on Linux (`nix/modules/home/gui.nix:401`); chezmoi owns
  the macOS copy (`home/dot_config/flameshot/flameshot.ini`, excluded on Linux
  by `home/.chezmoiignore:41-44`). The flameshot cask is removed on macOS, so
  the macOS copy now configures an app that is not installed. Follow-up:
  delete it or restore the app.
- `home/dot_config/systemd/user/dsh-remote.service` is a chezmoi-owned
  systemd user unit. The allowlist says units belong to Home Manager. Follow-up:
  move it to Home Manager or record it as a chezmoi exception here.

## Ownership table

| Tool | Owns | Never owns |
|------|------|-----------|
| **chezmoi** | Human-edited preferences and the shell, git, editor and terminal files in `~` and `~/.config/`. File rendering only, no orchestration. | Package installation, side effects beyond writing files, any path Home Manager owns below. |
| **Nix + Home Manager** | Packages (`home.packages`); systemd user units and timers; generated integration config with no human-edited content; the items in the allowlist tables below. | Files chezmoi configures. Bootstrap-managed tools (`chezmoi`, `mise`, `home-manager`, `lefthook`). Anything not in the allowlist tables. |
| **mise** | Per-project tool versions, per-project env vars, repo tasks (`mise run sync`, `sync:apply`, `doctor`, `lint:*`, `repo:*`). | Global Node, pnpm, PHP and composer (Nix owns them). OS packages, dotfile content. |
| **nix-darwin** | macOS system defaults and the Homebrew bridge. Does not manage Nix (`nix.enable = false`; see Nix installation). | Linux/WSL config. |
| **Homebrew** (via nix-darwin) | macOS GUI apps, fonts, and CLIs with no usable darwin nixpkgs build or that need macOS integration. | Cross-platform CLIs that nixpkgs builds on darwin. |
| **NixOS system layer** (`ops/system-setup.sh`, `nix/modules/nixos`) | System services, users, system packages, daemon settings. | User dotfiles, user packages. |
| **Lefthook** | Git hooks. | Anything outside the git lifecycle. |
| **GitHub Actions** (`.github/workflows/ci.yml`) | Running `ops/ci-local.sh` on pushes to `main` and pull requests. | Building or activating hosts (sys-update does that). |
| **bootstrap.sh / install.sh** | Initial setup (see Lifecycle). | Day-to-day updates. |

## Home Manager allowlist

Beyond `home.packages`, Home Manager declares only the following. Line numbers
refer to `nix/` and `ops/` on main with T-0019 applied.

### Enforced allowlist (the contract for T-0014)

`ops/validate-config.sh` is meant to enforce these three families:
`programs.*`, `services.*` and `xdg.configFile`. Before T-0014, check 6
matched only single-line `programs.<x>.enable = true`, so it did not see the
multi-line modules below; T-0014 enforces this table instead. Until it lands
this table is the authority and reviewers hold new entries in these families
to it. Evaluation-based enforcement tolerates `programs.man` and
`services.vicinae`, which Home Manager modules enable implicitly.

| Item | Evidence |
|------|----------|
| `programs.home-manager` | `nix/lib/mkhome.nix:27` |
| `programs.vicinae` | `nix/modules/home/vicinae.nix:37` |
| `programs.openclaw` | `nix/modules/home/openclaw.nix:83` |
| `services.syncthing` | `nix/modules/home/gui.nix:476` |
| `xdg.configFile."flameshot/flameshot.ini"` (Linux) | `nix/modules/home/gui.nix:401` |
| `xdg.configFile."wireplumber/wireplumber.conf.d/51-kanto-ora4.conf"` | `nix/modules/home/gui.nix:527` |
| `xdg.configFile."gremlins/gremlins/.gremlins.yaml"` (the path gremlins v0.6.0 reads; a repo-level `.gremlins.yaml` still overrides it) | `nix/modules/home/dev.nix:182` |
| `xdg.configFile."mimeapps.list"` (Linux) | `nix/modules/home/default-apps.nix:106` |
| `xdg.configFile."systemd/user/*"` takeover entries (`force = true`, replacing formerly hand-made units) | `nix/modules/home/ai-cli-updates.nix:112-132` |

### Also permitted (not covered by the enforced families)

Other Home Manager settings in use. They are allowed, each with its evidence;
a new one needs a row here.

| Item | Evidence |
|------|----------|
| `systemd.user.services` / `systemd.user.timers` | `nix/modules/home/ai-cli-updates.nix:131`, `nix/modules/home/dev.nix:190-263`, `nix/modules/home/gui.nix:434,452`, `nix/modules/home/openclaw.nix:173` |
| `dconf.settings` (Linux GNOME) | `nix/modules/home/gnome-extensions.nix:48`, `nix/modules/home/gnome-files.nix:14`, `nix/modules/home/gnome-keybindings.nix:244` |
| `xdg.dataFile."applications/mimeapps.list"` (Linux) | `nix/modules/home/default-apps.nix:114` |
| `home.activation.mutableMimeApps` (Linux) | `nix/modules/home/default-apps.nix:119` |
| `home.activation.defaultBrowser` (macOS) | `nix/modules/home/default-browser-macos.nix:5` |
| `targets.genericLinux` (linux-cli, WSL) | `nix/hosts/linux-cli/home.nix:10,13`, `nix/hosts/wsl/home.nix:12,15` |
| `nix.*` client settings and user GC | see "Nix installation ownership per host" |

## Runtimes

- **Nix** owns the global runtimes: Node 22 (`nodejs_22`), pnpm, and PHP 8.4
  with composer. PHP and composer are bound together through one variable,
  `phpPkg = pkgs.php84` (`nix/modules/home/dev.nix:10`), installed as `phpPkg`
  and `phpPkg.packages.composer` (`dev.nix:117,120`), so they cannot drift
  apart. pnpm is a Nix package, not corepack (`dev.nix:124`); Node is at
  `dev.nix:112`.
- **mise** owns per-project tool versions, env vars and tasks. On NixOS mise
  must not own Node: the `core:node` backend cannot run the nodejs.org
  prebuilt binaries (stub ld-linux loader) and would compile from source
  (`nix/modules/home/dev.nix:113-115`,
  `home/dot_config/mise/config.toml.tmpl:2-5`). Pin a per-project runtime in
  mise only when Nix does not already supply it.
- Version bumps of global runtimes go through the flake (nixpkgs input or the
  package expression), never through `mise upgrade`.

## Other CLI tools

`navi`, `glow` and the tldr client are Nix packages
(`nix/modules/home/cli.nix:33,49,53`). The tldr client is `tlrc` (binary
`tldr`); `nix/modules/home/cli.nix` stays the source of truth if that
changes. `navi` and `glow` are not in the mise optional installer.

## Nix installation ownership per host

Home Manager's `nix.package` only gates writing a user `nix.conf` (Home
Manager needs a non-null `nix.package` to generate one). It is never put on
`PATH`, so it cannot shadow a system Nix. The rule is therefore not "Home
Manager must stay out of the NixOS Nix" but: **daemon settings belong to the
system, and Home Manager writes client settings only.**

| Host | Owns the Nix package and daemon settings | User `nix.conf` | Garbage collection |
|------|------------------------------------------|-----------------|--------------------|
| NixOS (linux-desktop) | The system configuration (`ops/system-setup.sh`: `trusted-users` at `:220`, `nix.gc` at `:222`, `nix.optimise.automatic` at `:224`; `nix/modules/nixos/substituters.nix:32`). | Home Manager writes `extra-experimental-features = nix-command flakes` (`nix/modules/common/nix-settings.nix:45`), which appends to the system value. | System `nix.gc` timer (`ops/system-setup.sh:222`) plus the Home Manager user timer. |
| Other Linux desktop, linux-cli, WSL | `/etc/nix/nix.conf` for daemon settings; Home Manager keeps `nix.package` (`nix-settings.nix:41`). | Home Manager, as above. | Home Manager user timer. |
| macOS | Determinate Nix. nix-darwin sets `nix.enable = false` (`nix/hosts/macos/darwin.nix:11`). | None: `myConfig.nixSystemManaged = true` (`nix/hosts/macos/home.nix:10`, option at `nix-settings.nix:23`) leaves `nix.package` null. | Determinate Nix. Home Manager sets no GC on macOS. |

- `myConfig.nixClientAutoOptimise` defaults to `false`
  (`nix-settings.nix:11-13`). `auto-optimise-store` is a restricted setting
  that the daemon ignores from a user `nix.conf` unless the user is trusted.
  Nothing in this repo sets it system-wide. `ops/system-setup.sh:224` adds
  `nix.optimise.automatic`, a different mechanism (a periodic store
  deduplication timer). On non-NixOS hosts neither is set unless you configure
  `/etc/nix/nix.conf` yourself.
- Home Manager user GC is a weekly systemd user timer with
  `--delete-older-than 14d` (`nix-settings.nix:69-71`), Linux only. The
  launchd agent passes the options as one argument, which
  `nix-collect-garbage` rejects. The command deletes this user's old
  generations, then all unreachable store paths, so it overlaps the NixOS
  system timer.
- Retention is 14 days, matching `ops/cleanup.sh:54` (`KEEP_DAYS`, default 14)
  and `ops/system-setup.sh:222`.

## Homebrew

Homebrew owns macOS GUI apps (`casks`), fonts, and CLIs (`brews`) that have no
usable darwin nixpkgs build or that need macOS integration. Each `brews` entry
carries a reason in `nix/modules/darwin/homebrew.nix:75-95` (`docker-compose`,
`mysql-client`, `duti`). `mysql-client` is keg-only, so its `bin` is added to
`environment.systemPath` (`homebrew.nix:96`). The `flameshot` cask is removed:
Flameshot is Linux-only here. A CLI without a stated reason belongs in Nix.
Homebrew upgrades run from `sys-update`, not from every rebuild
(`homebrew.nix:18-21`).

Follow-ups:

- The casks `1password-cli` and `copilot-cli` (`homebrew.nix:41-42`) are CLIs
  with no stated reason. State the reason (for example, macOS integration) or
  move them to Nix.
- `brewup` in `home/dot_zshrc.tmpl` is now only a name for `sys-update`, so
  Homebrew has one upgrade path. On a machine that still has the removed
  formulae and cask, clean up with
  `brew uninstall tldr glow; brew uninstall --cask flameshot`.

## NixOS system layer

`ops/system-setup.sh` and the NixOS modules in `nix/modules/nixos` own system
services, users and system packages: login shell, `trusted-users`, the GC
timer, time zone, Docker daemon and Tailscale (`ops/system-setup.sh:2-5`).
Standalone Home Manager cannot set these and must not try.

## Hard rules

- `.chezmoiroot` at the repo root, containing exactly `home`.
- Home Manager declares only what the two allowlist tables above permit, plus
  `home.packages`.
- Home Manager must NOT create or manage any of:
  `~/.zshrc`, `~/.config/fish/`, `~/.bashrc`, `~/.gitconfig`,
  `~/.config/starship/starship.toml`, `~/.config/mise/config.toml`,
  `~/.config/nvim`, `~/.config/ghostty`, `~/.local/bin`, VS Code user settings.
  (All of these are chezmoi-managed.)
- chezmoi must NOT install packages, switch Nix profiles, or run any
  orchestration.
- `direnv` is DROPPED — mise covers per-project env activation. Re-add
  only if a specific gap is documented.

## Lifecycle

| Command | Meaning |
|---------|---------|
| `bash ops/bootstrap.sh` | Initial setup of a machine (`ops/bootstrap.sh:2`). Dry-run by default; must stay safe to re-run. |
| `bash ops/install.sh` | Unattended and idempotent: re-running installs only what is missing and re-applies the declared state (`ops/install.sh:2,10`). |
| `mise run sync` / `mise run sync:apply` | `sync` is an alias for `sync:dry-run` (`mise.toml:91,196`). `sync:apply` (`mise.toml:142`) applies the **current declared config**: snapshot, chezmoi, Home Manager or darwin-rebuild, `mise install`, VS Code extensions (`ops/vscode-extensions.sh`, `mise.toml:184`), lefthook. They do not update flake inputs. |
| `bash ops/update-all.sh` | Report mode; changes nothing (`ops/update-all.sh:20`). |
| `bash ops/update-all.sh --apply` | Full update: flake inputs (`:448`), chezmoi, Home Manager, brew (`:566-567`), `mise upgrade` (`:603`) and more (`:21-22`). |
| `bash ops/update-all.sh rollback` | Partial recovery, see below. |

`mise upgrade` respects the version ranges configured in mise; only
`mise upgrade --bump` rewrites them.

### Rollback scope

`rollback` re-activates the previous Home Manager generation (if it is still in
the store), restores `nix/flake.lock` and the Brave release lock from the run's
backups, and prints the command that restores the dotfile snapshot by hand
(`ops/update-all.sh:106-171`). It does NOT undo Homebrew upgrades, `mise
upgrade`, or chezmoi file content. NixOS system generations and
darwin-rebuild generations are also outside its scope.

## Ownership transfer procedure

Moving a path from one owner to another:

1. Remove the old declaration (the chezmoi source, or the Home Manager entry)
   in the same change that adds the new one. If the new owner is Home Manager,
   add the allowlist and documentation rows.
2. Preview collisions: `chezmoi diff` and
   `nix build --no-link "path:$PWD/nix#homeConfigurations.$(bash ops/detect-host.sh).activationPackage"`.
   A hand-made file in the way needs a deliberate `force = true` takeover entry
   (see `nix/modules/home/ai-cli-updates.nix:112-132`). A hand-installed
   `nix profile` package that collides is removed first
   (`ops/update-all.sh:509-521`).
3. Apply: `mise run sync:apply` or `bash ops/update-all.sh --apply`.
4. Verify: `chezmoi diff` shows nothing for the moved path, the path now comes
   from the new owner, and `bash ops/validate-config.sh` passes.

## Validation

`bash ops/validate-config.sh` enforces part of the above (run automatically
via Lefthook pre-push). It does not flag native Windows files because those
are deferred / out-of-scope, not forbidden. (The legacy `.husky/` hook shims
were removed; Lefthook is the sole hook engine.)

Known stale code comment: `nix/lib/mkhome.nix:25-26` still says
`programs.home-manager.enable` is the only allowed `programs.<x>.enable` and
everything else is `home.packages` only. That is not true of the repo; fix the
comment together with T-0014.

## Secrets handling

This repo does NOT store secrets. Identity that drives templating lives in
`home/.chezmoidata/personal.yaml` which is gitignored. Only
`home/personal.yaml.example` is committed (it lives outside `.chezmoidata/` because chezmoi autoloads every YAML/TOML/JSON in that dir).
Per-host project data lives in `home/.chezmoidata/projects.yaml`, with the
schema in `home/projects.yaml.example`. That file is **not** gitignored yet:
`.gitignore` lists only `personal.yaml`, `personal.local.yaml` and
`.chezmoistate/`. Until the ignore entry is added, do not stage it. Several
docs and `mise.toml:421` already say it is gitignored; that is a follow-up.

For real per-host secrets (SSH keys, API tokens), chezmoi supports
`age`, `1Password`, and `Bitwarden` integrations. Choose explicitly when
needed. Until then, do not bolt on a secrets layer.

## Dependency update procedure

Quarterly or as needed:

```bash
# Refresh Nix inputs (Nix >= 2.19: positional arguments are input names)
nix flake update --flake ./nix
# or one input only:
nix flake update nixpkgs --flake ./nix
nix flake check ./nix

# Preview the impact
mise run sync         # alias for sync:dry-run

# Apply if preview looks right
mise run sync:apply
```

Per-tool version bumps:

```bash
# per-project mise tools (global Node, pnpm, PHP and composer come from
# the flake instead)
mise outdated
mise upgrade <tool>
```

Home Manager `stateVersion` should only be bumped when Home Manager
explicitly asks you to. It's a migration anchor, not a "latest" knob.

`nixpkgs` currently follows `nixpkgs-unstable`. To pin a stable release,
edit `nix/flake.nix` and run `nix flake update --flake ./nix`.
