# Future upgrade plan

Borrow candidates discovered by reviewing two external NixOS configs:

- `nixos-config` (Rodey's — Hyprland desktop, sops-nix, cachix)
- `nix-config-pavlo` (the architectural sibling of this repo: `mksystem`,
  `vars`, fish, sops, disko, niri)

Each item has **Benefit (0–100)** and **Difficulty (0–100)**. Already-shipped
near-zero items are listed at the bottom for reference.

> Status legend: PLANNED = agreed, not yet built · NEEDS-DECISION = awaiting a
> choice from the owner · SHIPPED = already done.

---

## 1. sops-nix secrets — PLANNED

**Benefit 85 · Difficulty 65.**

Encrypted secrets committed in-repo, decrypted at runtime. This is the one
critical capability the repo lacks. It would let real secrets (e.g. the
`GITHUB_PAT` referenced by `home/dot_config/opencode/opencode.jsonc`, git
credentials, API tokens) be managed declaratively instead of via loose env vars
or gitignored chezmoi data.

Two reference designs:

- nix-config-pavlo `modules/common/sops.nix`: per-host secrets file
  `secrets/<hostName>/secrets.yaml`, age key derived from a per-host SSH key
  (`~/.ssh/id_ed25519_<host>`).
- nixos-config `modules/core/secrets.nix`: shared + per-host secrets, age key
  auto-imported from `/etc/ssh/ssh_host_ed25519_key`, `generateKey = true`,
  secrets at `/run/secrets/<name>`.

Work required:
1. Add `sops-nix` flake input.
2. Add the helper CLIs `sops` + `ssh-to-age` to `dev.nix` (needed to create/edit
   encrypted files and derive age recipients from SSH host keys).
3. Add `.sops.yaml` with age recipients (admin recovery key + per-host keys).
4. Add a NixOS module under `nix/modules/nixos/` (system layer, wired via
   `sys-setup` into `/etc/nixos`) — NOT Home Manager, since secret
   materialization to `/run/secrets` is a system concern.
5. Document the age-key bootstrap (`ssh-to-age`) in a repo-doc.

Risk: medium. Additive; nothing breaks if no secrets file exists (guard with
`builtins.pathExists`, as both references do).

---

## 2. GnuPG agent + SSH support — PLANNED (system layer)

**Benefit 60 · Difficulty 35.**

Reference: nixos-config `modules/core/program.nix`:

```nix
programs.gnupg.agent = {
  enable = true;
  enableSSHSupport = true;
};
programs.nix-ld.enable = true;   # run dynamically-linked prebuilt binaries
```

Why this is a PLAN item and not a near-zero package add: `programs.gnupg.agent`
is a **NixOS system option**, and this repo's Home Manager modules enforce a
"packages only / no `programs.<x>.enable`" invariant (see
`scripts/validate-config.sh` #6). The correct home is a NixOS module under
`nix/modules/nixos/` applied via `sys-setup` — i.e. the same system layer that
owns timezone/substituters. `nix-ld` is also worth adding there (lets non-Nix
prebuilt binaries run, e.g. some language toolchains).

Work required: new `nix/modules/nixos/programs.nix` with `gnupg.agent` +
`nix-ld`; wire via `sys-setup`.

---

## 3. diffnav (git diff TUI) + alternatives — NEEDS-DECISION

**Benefit 45 · Difficulty 10.**

nixos-config uses `diffnav` (a pager/TUI over git diff, used as `git diff |
diffnav`). It is small/young. Bigger-community alternatives to weigh first:

| Tool | Community | Notes |
| --- | --- | --- |
| `delta` (git-delta) | very large (~25k★) | Already shipped here. Side-by-side, syntax highlight, navigate. Covers most of diffnav's value. |
| `difftastic` | large (~22k★) | Already shipped. Structural (AST) diff. |
| `diffnav` | small | TUI file-tree over a diff; nicer "browse a big diff" UX than delta alone. |

Recommendation: you already ship `delta` + `difftastic`, which cover ~80% of
diffnav. Add `diffnav` only if you specifically want the file-tree-browse UX.
See item 4 (delta config) first — better delta settings may remove the need.

---

## 4. delta side-by-side + richer config — NEEDS-DECISION (next step)

**Benefit 50 · Difficulty 15.**

nixos-config configures delta declaratively:

```nix
programs.delta = {
  enable = true;
  options = {
    line-numbers = true;
    side-by-side = true;
    navigate = true;       # n/N to jump between files
    diff-so-fancy = true;
  };
};
```

This repo ships the `delta` *package* but does not configure it via
`programs.delta` (which would trip the pkg-only invariant) — so config would go
in the git dotfiles (chezmoi `~/.config/git/config` or `~/.gitconfig`) instead.
Decision needed: enable side-by-side + navigate in your gitconfig. This is the
recommended "next step after confirming" per the owner.

---

## 5. Git aliases — NEEDS-DECISION

**Benefit 45 · Difficulty 15.**

nixos-config ships ~50 zsh git aliases. A full list + per-alias description and
a keep/replace recommendation was delivered separately. Fold the chosen subset
into this repo's shell aliases (fish + zsh templates) rather than copying the
zsh-only block verbatim.

---

## 6. mkSystem + nixosConfigurations (own /etc/nixos) — PLANNED

**Benefit 75 · Difficulty 55.**

Both reference repos define hosts in ~1 line via a `mkSystem`/`mksystem.nix`
helper (the system-layer sibling of this repo's `nix/lib/mkhome.nix`).
nix-config-pavlo's `lib/mksystem.nix` is the closest match (same `vars` +
`specialArgs` idiom already used here).

Today this repo has NO `nixosConfigurations` and the live system is a
hand-edited `/etc/nixos`. Adopting `mkSystem` would let this repo own the NixOS
system layer reproducibly (timezone, substituters, gnupg, sops, browser-policies
all become first-class instead of `sys-setup` patches). Biggest architectural
step; do as a dedicated slice. Optional companions seen in pavlo: `disko`
(declarative partitioning) and `lanzaboote` (secure boot, item #8) — only if
wanted.

**Adopt pavlo's `vars.hosts` data model alongside it.** nix-config-pavlo's
`vars/default.nix` centralizes per-host metadata:

```nix
hosts = {
  phoenix  = { system = "x86_64-linux"; role = "workstation"; signingPubkey = "ssh-ed25519 …"; };
  openclaw = { system = "x86_64-linux"; role = "server"; };
};
```

`mkSystem name {}` then reads `vars.hosts.${name}` for system/role/keys. This is
the clean data model that powers one-line host definitions and per-host SSH
signing (item #7) — copy it when doing this slice. Your repo already has the
sibling `vars.profiles` for Home Manager, so this is a natural extension.

---

## 7. SSH-based git commit signing — PLANNED

**Benefit 40 · Difficulty 20.**

nix-config-pavlo `modules/home/git.nix` signs commits with an SSH key
(`gpg.format = "ssh"`, `signByDefault = true`, `allowed_signers` file). Cleaner
than GPG signing. Worth considering alongside item 2. Reference snippet:

```nix
programs.git.settings.gpg.ssh.allowedSignersFile =
  "${config.xdg.configHome}/git/allowed_signers";
programs.git.signing = { key = "~/.ssh/id_ed25519_<host>.pub"; signByDefault = true; format = "ssh"; };
xdg.configFile."git/allowed_signers".text = "<email> <ssh-pubkey>\n";
```

Note: this repo manages gitconfig via chezmoi, so the signing config would go in
`home/dot_gitconfig.tmpl` (+ an `allowed_signers` file), not a `programs.git`
HM block (which would trip the package-only invariant).

## 8. lanzaboote (UEFI Secure Boot) — PLANNED

**Benefit 40 · Difficulty 65.**

nix-config-pavlo uses `lanzaboote` (flake input + `lanzaboote.nixosModules.lanzaboote`)
to sign the boot chain for UEFI Secure Boot. System layer; pairs with mkSystem
(#6) since it only makes sense once this repo owns `/etc/nixos`. Requires
enrolling keys (`sbctl`) and disabling the stock systemd-boot. Niche but high
security value on hardware that supports it.

## 9. llm-agents.nix (AI CLI bundle) — PLANNED

**Benefit 60 · Difficulty 30.**

nix-config-pavlo pulls a whole AI-CLI bundle from one flake input
(`github:numtide/llm-agents.nix`): `claude-code`, `coderabbit-cli`, plus
nixpkgs `gemini-cli`, `codex`, `ollama`. Strongly fits this repo's AI-workflow
focus and complements the already-shipped `opencode`. Easy-ish: add the flake
input and select packages into `dev.nix`. Decide which agents you actually want
(avoid shipping all of them by default).

## 10. syncthing as a running service — PLANNED (follow-up to shipped package)

**Benefit 40 · Difficulty 30.**

The `syncthing` *package* now ships under the personal profile (CLI + Web UI at
http://localhost:8384). To run it continuously, enable it as a service:

- NixOS system: `services.syncthing.enable = true;` (+ `user`, `dataDir`,
  declarative `settings.folders`/`devices`). System layer → `nix/modules/nixos/`.
- Or Home Manager user service: `services.syncthing.enable = true;` (would need a
  HM services module; note the repo's package-only invariant only blocks
  `programs.<x>.enable`, so a `services.syncthing` block is allowed if a HM
  module is added).

Decide system-service vs user-service, then wire device IDs/folders (device IDs
are not secret, but consider sops for any tokens).

## 11. Extra CLI / utility tools (pavlo) — NEEDS-DECISION (cherry-pick)

**Benefit 40 · Difficulty 10.**

Useful tools from nix-config-pavlo's `packages.nix` worth cherry-picking into
`cli.nix`/`dev.nix` (decide per tool; all low-effort package adds):

| Tool | What it is | Note |
| --- | --- | --- |
| `nix-tree` | interactive nix store dependency browser | complements `nvd`/`nom` |
| `nix-du` | what's taking space in the nix store (dot graph) | store cleanup |
| `nix-top` | live view of running nix builds | build monitoring |
| `bottom` (`btm`) | system monitor (TUI) | overlaps your `btop` — pick one |
| `nmap` | network scanner | ad-hoc network debugging |
| `normcap` | OCR screen-grab (select text from images) | nice QoL (GUI) |
| `bitwarden-cli` (`bw`) | Bitwarden CLI | only if you use Bitwarden |
| `typst` | modern LaTeX-alternative typesetting | docs/PDF authoring |

Recommendation: `nix-tree`/`nix-du`/`nix-top` are the highest-fit (match your
Nix-maintenance toolchain). `bottom` is redundant with `btop`. The rest are
personal-taste.

---

## 12. Hyprland (Wayland tiling WM) vs GNOME+Vicinae — NEEDS-DECISION (deferred)

**Benefit 70 · Difficulty 80.**

Evaluated GNOME (Wayland) + Vicinae vs Hyprland + Vicinae specifically for a
keyboard-driven window-resize + launcher workflow, optimised for long-term
stability and maintainability. **Decision: stay on GNOME + Vicinae for now**
(window resize is implemented via the Vicinae GNOME extension's D-Bus API +
GNOME custom keybindings — see `nix/modules/home/gui.nix` resize script and
`nix/modules/home/gnome-keybindings.nix`). Hyprland is deferred, not rejected.

### Comparison (0–100; higher = better)

| Axis | GNOME+Vicinae | Hyprland+Vicinae | Evidence |
| --- | ---: | ---: | --- |
| Resize capability / precision | 85 | 95 | GNOME proven live (75% w / full h / centered via `MoveResize`); Hyprland native `resizeactive`, no script |
| Resize stability long-term | 55 | 90 | GNOME depends on 3rd-party ext pinned to shell-version 46–50; Hyprland uses its own stable dispatcher API |
| Maintainability in THIS repo | 80 | 30 | GNOME already declarative in Home-Manager; Hyprland needs NixOS-level session config this repo doesn't own |
| Vicinae compatibility | 85 | 75 | GNOME working (needs the ext); Hyprland drops the ext, uses native wlr-layer-shell path (unverified live) |
| Migration effort / rollback | 90 | 40 | GNOME = status quo, trivially reversible; Hyprland = compositor swap, large blast radius |
| Ecosystem maturity | 80 | 65 | GNOME very mature but extension-API churn; Hyprland resize core/stable but config format moves between versions |

### Biggest long-term risk per approach

- **GNOME:** `gnomeExtensions.vicinae` (`vicinae@dagimg-dot`) is pinned to GNOME
  shell-version **46–50** (its `metadata.json`). On a GNOME **51+** upgrade it
  stops loading until upstream republishes and nixpkgs catches up — taking
  Vicinae window/clipboard integration **and** the resize keybinding down
  together. Mitigation: delay GNOME major bumps until the extension's
  `shell-version` includes the target release (see guardrail note in
  `nix/modules/home/gnome-extensions.nix`); keep the resize script tolerant of
  the D-Bus service being absent (it is).
- **Hyprland:** lives at the **NixOS system layer this repo does not manage**
  (only `homeConfigurations` in `flake.nix`; no `nixosConfigurations`). Adopting
  it splits desktop config across two governance domains and means owning the
  whole replacement desktop stack.

### What you'd have to build/own to move to Hyprland (true cost)

Depends on **item #6 (mkSystem + nixosConfigurations)** landing first.
System layer: `programs.hyprland` + Wayland session, `xdg-desktop-portal-hyprland`,
a polkit agent, login/greeter (greetd/tuigreet). Home-Manager layer (replacing
what GNOME gives for free): waybar (bar), mako/dunst (notifications), hyprlock
(lock), hypridle (idle), hyprpaper/swww (wallpaper), grim/slurp (screenshots;
verify Flameshot on Hyprland), nm-applet/blueman + tray, `monitor=` output rules.
Kept/simplified: launcher stays Vicinae; resize becomes native (delete the
script + dconf keybinding + drop `gnomeExtensions.vicinae`/`gnome-extensions.nix`).

### When to switch to Hyprland (move triggers)

Move when **any** of these becomes true:

- You adopt **item #6** and start owning the NixOS system layer anyway (Hyprland
  then fits the new governance model instead of fighting it).
- The `vicinae@dagimg-dot` extension becomes **chronically unmaintained** against
  new GNOME releases (resize/clipboard break for an extended period after a bump).
- Tiling / keyboard-driven window management becomes a **primary daily workflow**,
  not just occasional resize — i.e. you want automatic tiling, per-workspace
  layouts, vim-style focus movement (`Super+H/J/K/L`), and instant resize
  (`Super+Shift+H/J/K/L`) as muscle memory.

### Functionality Hyprland would add (why you'd want it)

- Native, version-stable window resize/move with exact geometry (no extension,
  no D-Bus shim, no script).
- Real dynamic/manual tiling, per-workspace layouts, window rules.
- Fully keyboard-driven window control (focus + move + resize + workspace).
- Animations, blur, fine-grained per-output config — all declarative in one
  `hyprland.conf`.
- Lower long-term breakage on upgrades for the *window-management* piece
  specifically (the part that's fragile under GNOME today).

---

## Already shipped (near-zero, done)

- **Binary caches**: `nix/modules/nixos/substituters.nix` (nix-community +
  garnix). System layer, applied via `sys-setup`/`nixos-rebuild`.
- **Build diffs**: `nvd` + `nix-output-monitor` (`nom`) in `dev.nix`.
- **CLI tools**: `onefetch`, `ffmpeg`, `yt-dlp`, `imagemagick`, `viu`, `entr`,
  `dust` (du replacement, chosen over ncdu) in `cli.nix`/`dev.nix`.
- **treefmt-nix + flake checks**: `nix/treefmt.nix` + flake `formatter`/`checks`
  (nixfmt). `nix fmt` formats the tree; `nix flake check` fails on unformatted
  Nix. Tree formatted once on adoption.
- **Git aliases**: `gd` (diff), `gcfp`/`fixprev` (commit --fixup HEAD), `grs`
  (reset --soft HEAD~) in `home/dot_gitconfig.tmpl`.
- **syncthing** (package) under the personal profile (see item 10 to run it).
- **navi**: interactive cheatsheet launcher in `cli.nix` (complements tldr).
- **fish niceties**: vi keybindings + `GPG_TTY` + `fishPlugins.autopair` in
  `config.fish.tmpl`/`cli.nix`. (fzf-fish deliberately skipped — would conflict
  with the existing `fzf --fish` + Atuin Ctrl-T/Ctrl-R bindings.)
- **browser-policies**: `nix/modules/nixos/browser-policies.nix` — opt-in
  (`myConfig.browserPolicies.enable`) managed Brave/Chromium privacy + Brave
  Search policies. BrowserSignin omitted (left to user / Brave Sync).

## Explicitly rejected (do not add)

- `gen-commit` — low trust (tiny project). Use built-in/other tooling.
- `ncdu` — replaced by `dust`.
- waybar/walker/stylix desktop stack, gaming, spicetify, tiled, libresprite,
  p10k — out of scope (GNOME + fish here). (Hyprland itself was moved out of
  this list and is now evaluated/deferred under item #12, not rejected.)
