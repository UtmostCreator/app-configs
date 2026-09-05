# Installing this repo on NixOS

NixOS is **not** one of the four officially supported host profiles
(`macos`, `linux-desktop`, `linux-cli`, `wsl` — see `repo-docs/bootstrap.md`).
This document records the **NixOS-safe install order** and the failure
modes encountered when installing the chezmoi + mise + Nix/Home-Manager +
Lefthook stack onto a NixOS host, so the next person does not re-hit them.

Verified host: **NixOS 26.11 (Zokor)**, `x86_64-linux`, host profile
`linux-desktop`, standalone Home Manager (not nixos-rebuild integration).

## TL;DR — why you cannot just run `bootstrap.sh --yes`

`ops/bootstrap.sh` step 1 runs the **Determinate Systems Nix
installer**. On NixOS, Nix is owned by the OS (`/run/current-system/sw/bin/nix`),
so that step is wrong and must be **skipped**. Run the remaining steps
manually in the order below. Everything after step 1 works on NixOS with
two adaptations (node and `vars/default.nix`, both noted below).

## Prerequisites already true on NixOS

- `nix` is provided by the system. Do **not** run the Determinate installer.
- Install the base tools into your user profile (once):

  ```bash
  nix profile install nixpkgs#chezmoi nixpkgs#mise nixpkgs#home-manager nixpkgs#lefthook
  ```

- Fill in `nix/vars/default.nix`: replace every `REPLACE_ME` with your real
  username and home directory (`/home/<you>`). Home Manager cannot build
  with the placeholder values.

## NixOS-safe install order

Run from the repo root. This is `bootstrap.sh` steps 2–9 **minus** the Nix
installer.

```bash
# 0. identity file (gitignored) — only if not already present
cp home/personal.yaml.example home/.chezmoidata/personal.yaml
$EDITOR home/.chezmoidata/personal.yaml

# 1. validate the flake (should print "all checks passed!")
nix flake check ./nix

# 2. chezmoi: init + preview + snapshot + apply
chezmoi init --source="$PWD"
chezmoi diff
bash ops/snapshot-home.sh            # backs up $HOME files chezmoi manages
chezmoi apply                            # see "chezmoi TTY conflict" below if it aborts

# 3. Home Manager (standalone) — installs ~40 CLI packages + node
home-manager switch --flake ./nix#linux-desktop

# 4. mise runtimes (should be a near-instant no-op; see "mise compiles node")
mise trust "$PWD"
mise install

# 5. git hooks
lefthook install

# 6. ssh-agent helper (optional; installs a shell snippet)
bash ops/unix/ssh-agent-setup.sh

# 7. health checks (must pass; php/code/repomix WARNs are expected and non-fatal)
bash ops/doctor.sh
bash ops/validate-config.sh
```

## Failure modes on NixOS (and how each was resolved)

### 1. Determinate Systems Nix installer (bootstrap step 1)

- **Symptom:** `bootstrap.sh --yes` would try to install Nix over the
  OS-owned Nix.
- **Cause:** the repo targets non-NixOS hosts; NixOS already ships Nix.
- **Fix:** skip step 1. Use the manual order above. (Do not run
  `bootstrap.sh --yes` unmodified on NixOS.)

### 2. mise compiles node 22 from source ("infinite loop")

- **Symptom:** `mise install` appears to hang, emitting thousands of
  `cc ... openssl ...` compile lines for 30–60 minutes and leaving
  ~700 MB in `/tmp/mise/node-v22.*`.
- **Cause:** mise's `core:node` backend downloads the **prebuilt** node
  from nodejs.org. NixOS's dynamic loader `/lib64/ld-linux-x86-64.so.2`
  is a deliberate **stub** that rejects prebuilt Linux binaries, so mise
  silently falls back to building node from source. It is **not** a loop.
- **Fix (current):** node is provided by **Nix**, not mise:
  - `nix/modules/home/dev.nix` includes `nodejs_22` (binary-cached from
    `cache.nixos.org`, same `22.22.3`).
  - The mise template `home/dot_config/mise/config.toml.tmpl` **no longer
    pins** `node`, so `mise install` reports `all tools are installed`.
  - Verify: `node --version` → `v22.22.3`; `npm --version` → `10.9.8`.
- **If you hit a stuck build:** Ctrl-C, then `rm -rf /tmp/mise/node-v*`.

### 3. chezmoi apply aborts: "could not open a new TTY"

- **Symptom:**
  `<file> has changed since chezmoi last wrote it?` followed by
  `could not open a new TTY: open /dev/tty: no such device or address`,
  exit 1.
- **Cause:** chezmoi found a managed file modified **outside** chezmoi and
  wants interactive confirmation before overwriting. In a non-interactive
  shell (CI, automation, no TTY) it cannot prompt, so it aborts.
- **Fix:** decide per file. To let the **repo source win** (overwrite the
  local edit), run `chezmoi apply --force`. The pre-apply snapshot
  (`ops/snapshot-home.sh`, written to
  `~/.local/state/dotfiles-snapshots/<UTC>/`) preserves the old content for
  rollback. To **keep** a local edit, exclude that path or re-add it to the
  chezmoi source first.

### 4. `auto-optimise-store` warning on every nix command

- **Symptom (harmless):**
  `warning: ignoring the client-specified setting 'auto-optimise-store',
  because it is a restricted setting and you are not a trusted user`.
- **Cause:** `nix/modules/common/nix-settings.nix` sets
  `auto-optimise-store = true`, but standalone Home Manager applies it as a
  client setting and your user is not in the **system** NixOS
  `nix.settings.trusted-users`. Nix ignores the client setting and warns.
- **Fix:** none required — it is a warning, not an error. To silence it,
  add your user to `nix.settings.trusted-users` in your **system**
  `/etc/nixos/configuration.nix` (system-side change, out of scope for this
  repo).

### 5. `nix.package = pkgs.nix` in nix-settings.nix

- **Context:** standalone Home Manager managing `nix.*` on NixOS may need an
  explicit Nix package to avoid conflicting with the system Nix.
- **Status:** the current module does not set `nix.package`; add it only if a
  supported NixOS host reproduces that conflict.

## Can NixOS use mise at all? (yes, with one rule)

**Yes — mise works on NixOS, but it must not manage compiled runtimes.**

- **Use mise for:** repo tasks (`mise run …`, defined in `mise.toml`),
  per-project environment, and tools mise can fetch as static prebuilt
  binaries that already run on NixOS.
- **Do NOT use mise for:** language runtimes whose mise backend ships a
  glibc-dynamic prebuilt binary that NixOS's stub loader rejects — most
  notably **node** (`core:node`). mise will silently fall back to a
  30–60 min source compile (see failure mode 2 above).

**The NixOS rule for runtimes:**

> If the system is NixOS, provide the runtime via **Nix** (add it to
> `nix/modules/home/dev.nix`) and **re-switch**:
>
> ```bash
> home-manager switch --flake ./nix#linux-desktop
> ```
>
> Then remove that tool's pin from the mise config so `mise install`
> reports `all tools are installed` instead of compiling.

This is exactly what was done for node: `nodejs_22` lives in
`nix/modules/home/dev.nix`, and `home/dot_config/mise/config.toml.tmpl`
carries **no** `[tools]` runtime pins. On a non-NixOS host you could pin
node in mise instead; on NixOS, Nix owns it.

Practical checklist when adding a runtime on NixOS:

1. `nix eval --raw nixpkgs#<pkg>.name` to confirm the package/version.
2. Add `<pkg>` to `nix/modules/home/dev.nix` `home.packages`.
3. `home-manager switch --flake ./nix#linux-desktop`.
4. Ensure it is **not** also pinned in
   `home/dot_config/mise/config.toml.tmpl` (avoid a double-managed source).

## Shell: fish

This repo ships a fish config at
`home/dot_config/fish/config.fish.tmpl` (chezmoi → `~/.config/fish/config.fish`)
ported from the zsh config. fish provides **autosuggestions and syntax
highlighting natively**, so no extra plugins/packages are added for those.
Starship, Atuin, fzf, zoxide, yazi (`yy`), and mise all initialise for fish.

- fish is installed via Nix (`nix/modules/home/cli.nix`).
- macOS-only bits (Herd PHP, Homebrew mysql-client, 1Password NPM token)
  are gated behind `{{ "{{" }} if eq .chezmoi.os "darwin" {{ "}}" }}` in the template.

**Switching into fish — two layers:**

1. **Immediate (repo-owned, already wired):** `~/.bashrc` (chezmoi template
   `home/dot_bashrc.tmpl`) `exec`s into fish for **interactive** shells when
   fish is on PATH and you are not already in fish. So a new terminal lands
   in fish without any system change. Escape hatch: run `NO_FISH=1 bash` to
   stay in bash (useful for ops/tooling that expect bash).

2. **Persistent login shell (system-level, you apply once):** the real login
   shell on NixOS is set in `/etc/nixos/configuration.nix`, not via `chsh`
   (fish from the Nix profile is not in `/etc/shells`). Add:

   ```nix
   # /etc/nixos/configuration.nix
   programs.fish.enable = true;                       # registers fish + /etc/shells
   users.users.utmostcreator.shell = pkgs.fish;       # login shell = fish
   ```

   then:

   ```bash
   sudo nixos-rebuild switch
   ```

   After that, fish is the actual login shell and the `.bashrc` exec becomes a
   no-op (bash is no longer the login shell). Until you run the rebuild, layer
   1 already gives you fish in every interactive terminal.

   Do **not** `chsh` to the Nix-profile fish path on NixOS — it is
   non-persistent and points outside `/etc/shells`.

## Expected non-fatal `doctor.sh` warnings on NixOS

These are **optional** tools, not failures (`doctor.sh` still exits 0):

- `php` — not pinned anywhere by design; only the AI-workflow validators
  need it. Install a system php or skip the validators.
- `repomix` — not in the Nix modules; optional.
- `justfile` / `Justfile` / `.github/copilot-instructions.md` — optional
  files this repo does not ship.

## Rollback

- chezmoi: `cp -a ~/.local/state/dotfiles-snapshots/<UTC>/. ~/`
- Home Manager: `home-manager generations`, then
  `/nix/store/<hash>-home-manager-generation/activate` for the prior id.
