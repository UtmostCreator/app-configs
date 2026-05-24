# nix-config — borrow analysis

Read-only research against `~/projects/nix-config` (a personal NixOS
flake) to identify patterns and modules worth borrowing into this repo.

**No code adopted yet.** This is a proposal document. Each recommended
item lists: the upstream file, why it improves this repo's setup, the
target path inside `nix/modules/home/` (or `nix/modules/darwin/`), and
the cost/risk of bringing it in.

## Where nix-config excels relative to this repo

| Strength | Upstream evidence | How it helps here |
|----------|-------------------|-------------------|
| Browser-as-a-module with declared extensions | `modules/home/applications/brave.nix` uses `programs.brave.enable + extensions = [{id=…}]` — Home Manager installs Brave and pins extensions by Chrome Web Store ID. | We currently leave Brave/Chrome out of scope; managing both the binary and per-host extensions declaratively is a big quality-of-life win for any desktop host. |
| System-wide browser policy JSON | `modules/nixos/browser-policies.nix` writes `/etc/brave/policies/managed/*.json` and `/etc/chromium/policies/managed/*.json` (shared + brave-specific blocks), gated by `modules.nixos.browser-policies.enable`. | Enforces Brave Search default, disables Rewards/Wallet/VPN/AIChat/Talk/News, kills metrics + autofill + spell-check + notifications + geolocation, sign-in off. Replaces "click through 20 toggles on every new machine" with a one-line enable. |
| `feature-flag` module style (`config.modules.<area>.enable`) | All `nixos/*.nix` modules use `lib.mkEnableOption` + `lib.mkIf cfg.enable` (see `browser-policies.nix`, `niri.nix`, `gaming.nix`, `k3s.nix`, `obs.nix`). | This repo's `nix/modules/home/*.nix` are flat imports with no enable gate. Adopting the `lib.mkEnableOption` pattern would let each host opt into modules without duplicating module files. |
| `mksystem.nix` helper centralising `nixosSystem { … }` per host | `lib/mksystem.nix` takes a host name + meta, returns `nixosSystem`. Hosts become 1-line entries in `flake.nix` (`nixosConfigurations.phoenix = mkSystem "phoenix" {}`). | This repo already has `nix/lib/mkhome.nix` with the same shape for Home Manager. The upstream pattern is the obvious sibling for `darwinSystem` and any future NixOS host. Minimal change — same idiom. |
| `treefmt-nix` integrated as a flake check | `treefmt.nix` enables `nixfmt` + `shfmt`; `flake.nix` wires it into `checks.formatting`. Running `nix flake check` enforces formatting. | Our `nix flake check` only validates module evaluation. Adding treefmt-nix gives us "PR-blocking format" essentially for free, no separate Action needed. |
| SSH-signed git commits with key materialised by `signingPubkey` per host | `modules/home/git.nix` puts `signingPubkey` in `vars.hosts.<name>` and writes `~/.config/git/allowed_signers` from it. | We currently only template `name`/`email`/`signingKey`. Adding the `allowed_signers` materialisation gives `git verify-commit` parity locally and on hosted CI. |
| Per-host signing key file convention `~/.ssh/id_ed25519_<hostname>` | Same `git.nix` derives the SSH key path from `osConfig.networking.hostName`. | Means one chezmoi-managed `~/.gitconfig` can serve multiple machines without per-host overrides. Same trick works for our `dot_gitconfig.tmpl` via `{{ .chezmoi.hostname }}`. |
| `sops-nix` as the secrets layer | `modules/common/sops.nix` declares `defaultSopsFile`, `defaultSopsFormat`, `age.sshKeyPaths`. Real secrets live encrypted in `secrets/<host>/secrets.yaml`. | Our followups doc currently says "choose chezmoi age / 1Password / Bitwarden later." sops-nix is mature, integrates cleanly with our existing Nix flake, and the upstream module is ~10 lines. |
| `nix.gc` automation in common settings | `modules/common/nix-settings.nix`: `gc.automatic = true; dates = "weekly"; options = "--delete-older-than 7d";` | Our `nix/modules/common/nix-settings.nix` only sets experimental features + `auto-optimise-store`. Adding scheduled GC prevents the long-tail "Nix store is 40 GB" problem. |
| Custom origin-build of Brave (`brave-origin`) as an overlay package | `pkgs/brave-origin/{package.nix,make-brave.nix,update.sh}` + `overlays/default.nix`. Builds Brave from upstream archives per system (x86_64/aarch64 × linux/darwin). | Demonstrates a clean overlay pattern we could reuse to pin any GUI app per system without waiting for nixpkgs. Not urgent for us, but a good template if we ever need a divergent package. |
| `stable` overlay exposing `pkgs.stable.*` | `overlays/default.nix` adds `final.stable = import nixpkgs-stable { … }`. Modules then say `pkgs.stable.ssm-session-manager-plugin`. | Lets unstable be the default while still pinning specific tools to stable. Our flake currently follows `nixpkgs-unstable` only. Adding this gives us a per-package escape hatch with zero behavioural change. |

## Where nix-config does NOT match our scope (do not borrow)

- NixOS-only things: `disko-config.nix`, `lanzaboote`, `niri`, `k3s`, `gaming.nix`, `noctalia.nix`, OBS module. We are macOS + Linux desktop + WSL + Linux CLI; we are not standing up a NixOS box.
- `programs.fish` / `programs.zen-browser`: we are zsh-first and don't ship a browser fork. Keep as reference only.
- `services.syncthing.enable = true;`: out of scope for a dotfiles repo.
- `inputs.llm-agents` / `inputs.agent-skills`: AI-tooling concerns; explicitly excluded per project rule.

## Concrete proposal: quick wins (no architecture change)

Three slices, smallest first. Each is a separate PR-sized commit.

### Slice 1 — Add Brave + Chromium policy module (Linux desktop, macOS via cask)

**Borrow:** `modules/nixos/browser-policies.nix` patterns.

**Target:**
- `nix/modules/home/brave.nix` (new) — Home Manager module enabling Brave + extension IDs.
- `nix/modules/common/browser-policies.nix` (new) — writes managed-policy JSON to `~/.config/BraveSoftware/Brave-Browser/policies/managed/` (Linux) and `~/Library/Application Support/BraveSoftware/Brave-Browser/Managed Preferences/com.brave.Browser.plist` (macOS). System-wide `/etc/brave/policies/managed/` only on NixOS (we don't have one yet).
- `nix/modules/home/gui.nix` — import `./brave.nix` (only on linux-desktop and macos hosts via the existing gating).
- `nix/modules/darwin/homebrew.nix` — add `brave-browser` cask alongside ghostty/bbedit etc.

**Extension IDs to seed:** copy the 8 entries from upstream `brave.nix`. Document each in a comment so the reader knows what's being installed (currently the upstream file has no comments — that's a small improvement we should make).

**Cost:** ~120 lines of Nix + a doc paragraph in `docs/architecture/tool-ownership.md`. No changes to chezmoi or bootstrap.

**Risk:** low. Brave package on macOS via Nix is patchy; we'd default to cask and only use `pkgs.brave` on Linux. The policy JSON is additive — uninstalling reverts cleanly.

### Slice 2 — Adopt the `lib.mkEnableOption` gate pattern for Home Manager modules

**Borrow:** the `options.modules.home.<name>.enable = lib.mkEnableOption …` + `config = lib.mkIf cfg.enable { … }` pattern from upstream's `nixos/*.nix`.

**Target:** all five `nix/modules/home/*.nix` files in this repo:
- `cli.nix`, `dev.nix`, `gui.nix`, `shell-packages.nix`, common.

**Result:** each host file (`nix/hosts/<profile>/home.nix`) opts in by setting `modules.home.cli.enable = true;` instead of importing the module unconditionally. Linux-cli stays opt-out of GUI by simply leaving the flag false instead of leaving `gui.nix` unimported (which our `hosts/linux-cli/home.nix` does today).

**Cost:** ~30 lines per module × 5 = 150 lines total. Pure refactor; no package list changes.

**Risk:** low. We have only 4 host profiles, so reviewing the resulting `nix flake check` output on each is mechanical.

### Slice 3 — Add `treefmt-nix` to `nix flake check`

**Borrow:** `treefmt.nix` (6 lines) + the `treefmtEval` + `checks.formatting` plumbing in upstream `flake.nix`.

**Target:**
- `treefmt.nix` at repo root (new).
- `nix/flake.nix` — add `treefmt-nix` input, build the eval, and expose `checks.<system>.formatting = treefmtEval.${system}.config.build.check self;`.

**Result:** `nix flake check ./nix` enforces nix + shell formatting in CI and locally without an Action.

**Cost:** ~25 lines.

**Risk:** low. `treefmt-nix` is widely used; failure mode is a formatting error, not a build break.

## Stretch proposal: medium wins

### Slice 4 — Adopt `sops-nix` for per-host secrets templating

**Borrow:** `modules/common/sops.nix`.

**When:** as soon as we have a real "the laptop needs this token" use case. Today we explicitly defer secrets handling in `docs/architecture/tool-ownership.md`.

**Cost:** sops-nix flake input + a `secrets/` directory per host + a `.sops.yaml` at repo root + `age` key on each machine. Materially bigger than slices 1–3; consider only after one of slices 1–3 ships.

**Risk:** medium. Secrets policy needs review before merge.

### Slice 5 — Per-host signing key materialisation

**Borrow:** the `git.nix` pattern that derives `signingKeyPath` and `allowed_signers` from `vars.hosts.<host>.signingPubkey`.

**Target:** `home/dot_gitconfig.tmpl` + a new chezmoi script (NOT orchestration — just a file render) that writes `~/.config/git/allowed_signers` from a list in `personal.yaml`.

**Cost:** ~40 lines of templating. Per-host fingerprint goes into `personal.yaml` (already gitignored).

**Risk:** low. Only affects users who set `signingKey` in personal.yaml.

### Slice 6 — Add scheduled `nix.gc` to common settings

**Borrow:** the `gc.automatic = true;` block in `nix-settings.nix`.

**Target:** `nix/modules/common/nix-settings.nix` (this repo). One-liner.

**Cost:** trivial.

**Risk:** low; deletable per host.

## Architectural patterns NOT recommended right now

| Pattern | Why not borrow yet |
|---------|-------------------|
| `mksystem.nix` for NixOS hosts | We don't run NixOS as host OS. Our analogue is already `mkhome.nix`. Worth revisiting if someone adopts NixOS on a workstation. |
| `inputs.zen-browser` + `inputs.niri` + `inputs.noctalia` | Personal taste / NixOS-only window manager bits. Adding them would bloat our `flake.lock` for no host benefit. |
| `inputs.disko` + `inputs.lanzaboote` | Installer-time concerns; we are dotfiles, not provisioning a NixOS box. |
| Custom `brave-origin` build | Only matters if you want the *origin* build (privacy-tweaked, not the standard `brave`). Using `pkgs.brave` (Linux) + `brave-browser` cask (macOS) is simpler. |

## Recommended execution order

1. **Slice 1 (Brave + policies)** — direct user value (matches your stated interest in Brave + extensions).
2. **Slice 3 (treefmt-nix)** — small, raises formatting baseline.
3. **Slice 2 (mkEnableOption pattern)** — refactor; less urgent than user-visible wins.
4. **Slice 6 (nix.gc)** — one-liner alongside any of the above.
5. **Slice 5 (signing-key materialisation)** — when you actually adopt signed commits.
6. **Slice 4 (sops-nix)** — when secrets handling becomes a real need.

## Brave extension list (locked for Slice 1)

User-supplied annotated list. **This replaces the 8 IDs in upstream
`brave.nix`** — the placeholder entry `bnjjngeaknajbdcgpfkgnonkmififhfo`
("fake filler") was dropped. Use this exact list in
`nix/modules/home/brave.nix` when Slice 1 ships:

| Chrome Web Store ID | Name | Notes |
|---------------------|------|-------|
| `fdpohaocaechififmbbbbbknoalclacl` | GoFullPage — Full Page Screen Capture | |
| `bkhaagjahfmjljalopjnoealnfndnagc` | Octotree — GitHub code tree | |
| `abjcfabbhafbcdfjoecdgepllmpfceif` | Magic Actions for YouTube™ | **Disabled by default** — install but ship `installation_mode = "normal_installed"` (not `force_installed`) so the user can toggle off. |
| `dhdgffkkebhmkfjojejmpbldmpobfkfo` | Tampermonkey | |
| `cjpalhdlnbpafiamejdnhcphjbkeiagm` | uBlock Origin | |
| `eadndfjplgieldjbigjakmdgkmoaaaoc` | Xdebug helper | |
| `chphlpgkkbolifaimnlloiipkdnihall` | OneTab | |

Implementation hint for Slice 1: Brave (Chromium-derived) honours the
Chromium `ExtensionInstallForcelist` policy in
`/etc/brave/policies/managed/00-shared.json` (or
`~/.config/BraveSoftware/Brave-Browser/policies/managed/` for per-user).
The format is `<ID>;<update_url>` and the canonical update URL is
`https://clients2.google.com/service/update2/crx`. Magic Actions stays
out of `ExtensionInstallForcelist` and instead uses
`ExtensionSettings.<id>.installation_mode = "normal_installed"` so it
can be disabled.

## Failure ledger for this research slice

| Item | Reason | Resolution |
|------|--------|------------|
| (none) | All reads on `~/projects/nix-config` succeeded | — |

No new failures.
