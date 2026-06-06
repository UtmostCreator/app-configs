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
2. Add `.sops.yaml` with age recipients (admin recovery key + per-host keys).
3. Add a NixOS module under `nix/modules/nixos/` (system layer, wired via
   `sys-setup` into `/etc/nixos`) — NOT Home Manager, since secret
   materialization to `/run/secrets` is a system concern.
4. Document the age-key bootstrap (`ssh-to-age`) in a repo-doc.

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
system layer reproducibly (timezone, substituters, gnupg, sops all become
first-class instead of `sys-setup` patches). Biggest architectural step; do as a
dedicated slice. Optional companions seen in pavlo: `disko` (declarative
partitioning) and `lanzaboote` (secure boot) — only if wanted.

---

## 7. SSH-based git commit signing — NEEDS-DECISION

**Benefit 40 · Difficulty 20.**

nix-config-pavlo `modules/home/git.nix` signs commits with an SSH key
(`gpg.format = "ssh"`, `signByDefault = true`, `allowed_signers` file). Cleaner
than GPG signing. Worth considering alongside item 2.

---

## Already shipped (near-zero, done)

- **Binary caches**: `nix/modules/nixos/substituters.nix` (nix-community +
  garnix). System layer, applied via `sys-setup`/`nixos-rebuild`.
- **Build diffs**: `nvd` + `nix-output-monitor` (`nom`) in `dev.nix`.
- **CLI tools**: `onefetch`, `ffmpeg`, `yt-dlp`, `imagemagick`, `viu`, `entr`,
  `dust` (du replacement, chosen over ncdu) in `cli.nix`/`dev.nix`.

## Explicitly rejected (do not add)

- `gen-commit` — low trust (tiny project). Use built-in/other tooling.
- `ncdu` — replaced by `dust`.
- All Hyprland/waybar/walker/stylix desktop stack, gaming, spicetify, tiled,
  libresprite, p10k — out of scope (GNOME + fish here).
