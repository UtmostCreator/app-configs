# Niri two-PC pilot: trial on PC 2, then migrate PC 1 in place (2026-11-20)

**Current installation choices and open decisions:** [ADR-0046](../architecture/decisions/0046-niri-desktop-installation-decision-register.md). The *implemented* pilot uses a **chezmoi-owned** `home/dot_config/niri/config.kdl`; the older hypothetical `/etc/niri/config.kdl` alternative below was **not selected**. PC 2's declared disk layout remains a placeholder; nothing here authorises a physical install.

Proposed variant of the phases in `docs/plans/niri-migration.md` (section 6).
Nothing here is authorised: every live activation, install, commit and push
still needs its own approval, and the mandatory backup gate in that plan still
applies to PC 1.

Evidence labels as in the main plan: VERIFIED (checked in the repo at 77564b6),
WEB (cited, not re-fetched), INFERRED, ESTIMATE, unverified.

## Terms

- **PC 1**: the daily desktop. NixOS generation 17 only, built today from
  `/etc/nixos#nixos`, GNOME 50.1, AMD iGPU drives the screens, NVIDIA dGPU on
  nouveau (main plan, sections 4a and 6).
- **PC 2**: the pilot machine. NixOS goes on its spare SSD with its own ESP.
  Its hardware (GPU, outputs) is unverified and is not PC 1's.

## Recommendation

Install a repo-built NixOS pilot on PC 2. Keep PC 1 on GNOME for daily work.
After the pilot passes, bring PC 1 under the repo with GNOME first, then add
Niri as a selectable GDM session in a separate change. This separates a system
migration regression from a Niri regression.

What changes against the main plan: the shell comparison (P4) can start on
PC 2 before PC 1's activation gate (P4a). A pass on PC 2 does not clear PC 1's
GPU, outputs, or `/etc/nixos` takeover.

## Corrections to the draft this file came from

| Draft claim | Correction |
|---|---|
| Use a separate pilot account on PC 2. | VERIFIED: `nix/vars/default.nix` is single-user (`username = "utmostcreator"`, checked by `tests/bash/nix-identity.bats`), and every `homeConfigurations` output uses it. Use the same username on PC 2 with a fresh home and representative data. A second account would need a vars override that does not exist. |
| Activate with `nixos-rebuild test`, then prove generation 17 bootable and retain it. | Generation 17 is running, so it is bootable today. The real risk is losing it: `nix-gc.timer` runs `--delete-older-than 14d`, which ages a generation by its creation time. Generation 17 (2026-09-06) is protected only because it is current; once `boot` or `switch` makes generation 18 current, the next weekly GC deletes it. The main plan's "within 14 days of the first new generation" is wrong for the same reason. Stop the timer and keep `nix.gc.automatic = false` in the repo config until the rollback check passes. `test` creates no generation and changes no boot entry, so it is safe, but it also proves nothing about the kernel, initrd or filesystems. |
| `nixos-rebuild test` exercises the GNOME baseline. | INFERRED from the NixOS display-manager module (`restartIfChanged = false`): `test` does not restart GDM, so the running session keeps the old GNOME. Testing GNOME 51 and GDM under `test` means switching to a TTY and restarting `display-manager`, or rebooting after `boot`. |
| Put the trial KDL at `/etc/niri/config.kdl` under NixOS. | Fits the user guidance (NixOS owns compositor and session config), but contradicts T-0032 ("niri config is HM-owned") and leaves open decision 6 in the main plan unresolved. Choosing `/etc` closes decision 6 differently, so T-0032 and the T-0030 validator scope (rule 11 targets an xdg path) must be updated in the same change. Niri reads the user path first and falls back to `/etc/niri/config.kdl` (WEB), so the check that no `~/.config/niri/config.kdl` exists stays. |
| A basic pilot in 4–10 hours. | No repo source. A first Niri login in hours is plausible; a pilot that passes T-0032's P0 gates is days. The repo estimates T-0029 at 2–3 days and the minimal session at 3–6 (ESTIMATE). |
| Roughly 10–18 engineering days for the core scope. | The main plan says 9.5–18 (midpoint 13.75), excluding the Dux row, the second-shell comparison, hide emulation and selection plumbing (13.5–26 with those). |
| Configure a remote builder only if uncached builds are the bottleneck. | Agreed, but the first remote step is deployment, not distributed builds: build and push from PC 1 with `--target-host` (below). Both machines are x86_64, so no builder is needed for architecture. |
| Pinned Niri module at nixpkgs `5d2b81a7`. | VERIFIED current: the root input is lock node `nixpkgs_2`, rev `5d2b81a7`. The main plan's `e126e9e7` pin is stale (left for T-0033). |

Confirmed as written at the time (2026-11-20): no `nixosConfigurations` output
yet. Since 2026-11-21 the flake has `nixosConfigurations.linux-desktop-pilot`
(450e78e, 4c57049) and the niri config is chezmoi-owned (6fb82ee); PC 1's
`linux-desktop` host is still to do. The pinned module defaults `defaultSession` to
Niri, so GNOME must be set explicitly; Dux first, Noctalia second (ADR-0013);
Vicinae stays the launcher and clipboard owner (main plan decisions 1 and 11);
`sys-update` owns `nix/flake.lock`.

## Steps

### 1. GNOME baseline in the flake (build only)

- Add `nixosConfigurations.linux-desktop` (PC 1) and
  `nixosConfigurations.linux-desktop-pilot` (PC 2). Share `nix/modules/nixos`
  and a common desktop module; keep `hardware-configuration.nix`, disks, boot
  and GPU per host under `nix/hosts/`.
- PC 1 keeps its `system.stateVersion`. PC 2 gets the stateVersion of the
  release it is installed from.
- Set `system.configurationRevision = self.rev or self.dirtyRev or "dirty"`, so
  `nixos-version --configuration-revision` shows which commit is running.
- Both hosts keep standalone Home Manager and chezmoi. `ops/detect-host.sh`
  still returns `linux-desktop` on both, so the HM output is the same.
- Do not run `ops/system-setup.sh` or `ops/tailscale-setup.sh` on PC 2: both
  write `/etc/nixos` (T-0029). Making them refuse on repo-managed hosts is part
  of T-0029.
- `git add` new `*.nix` files before evaluating.

### 2. Install PC 2

- Back up or physically disconnect PC 2's original disk during the install, so
  partitioning and the bootloader can only touch the spare SSD.
- Give the pilot its own ESP; `boot.loader.efi.efiSysMountPoint` is the only
  ESP systemd-boot writes (`nix/modules/nixos/dual-boot.nix`). Pick the OS in
  the firmware boot menu. Reconnect the original disk and confirm both boot.
- From the installer: `nixos-generate-config --root /mnt`, copy the generated
  hardware file into `nix/hosts/<pilot>/`, then
  `nixos-install --flake <checkout>/nix#linux-desktop-pilot`.
- Leave Syncthing, Tailscale and account-bound services off at first.
- GNOME and GDM first. Then enable `programs.niri`, set
  `services.displayManager.defaultSession` to GNOME's evaluated session name,
  and check that Niri is in `sessionNames`.
- Bind Dux's and Noctalia's user units to the Niri session: both default to
  `graphical-session.target` and would also start under GNOME (main plan, 4b).

### 3. Remote workflow between the PCs

PC 1 stays the workstation and builder; PC 2 only runs candidates.

- PC 2 needs, in the pilot config only: `services.openssh` with key-only auth,
  no root login, and the user in `nix.settings.trusted-users` so closures copied
  from PC 1 are accepted. PC 1 gets no new listener.
- Deploy a system candidate from a clean checkout on PC 1:

  ```bash
  git status --porcelain   # must be empty: the revision is the test id
  nixos-rebuild test --flake "git+file://$PWD/nix#linux-desktop-pilot" \
    --target-host utmostcreator@pc2 --sudo
  ```

  Use `boot` or `switch` instead of `test` once a candidate should persist.
  `--sudo` is the nixos-rebuild-ng flag in the pinned nixpkgs; older tools call
  it `--use-remote-sudo` (unverified on PC 1's current tool).
- Deploy the HM side by building
  `homeConfigurations.linux-desktop.activationPackage` on PC 1, `nix copy --to
  ssh://utmostcreator@pc2` the result, then run its `activate` on PC 2.
- Record per candidate: the commit, `nixos-version --configuration-revision` on
  PC 2, the checks that ran, and the result.
- Two agents: one owns the flake, system modules and validator (T-0029, T-0030),
  the other the shortcut inventory, window actions and pilot results (T-0031,
  T-0032). Separate worktrees if both edit.
- Add `nix.buildMachines` only if repeated uncached builds become the
  bottleneck.

### 4. Move PC 1 in two approved changes

Before the first change: the main plan's backup gate (items a–e), console or
rescue-media access confirmed, and `nix-gc.timer` stopped with
`nix.gc.automatic = false` in the repo config.

1. **GNOME baseline.** `nixos-rebuild build`, review the closure diff
   (`nix store diff-closures /run/current-system ./result`), then `test` from a
   TTY with a `display-manager` restart, then `boot` and reboot. Confirm
   generation 17 is still in the boot menu, boot it once, then return to the new
   generation.
2. **Niri as an optional session**, a separate change. GNOME stays the GDM
   default through the 2–4 week daily-use trial. Making Niri the default is a
   separate cutover decision (P6).

Re-enable GC only after the rollback check is recorded.

## Acceptance

- Build: both NixOS closures and the `linux-desktop` HM activation package;
  `nix flake check ./nix`; `bats tests/bash`; `bash ops/validate-config.sh` and
  `--eval`; `chezmoi diff`; `bash ops/update-all.sh` in report mode.
- Desktop, on PC 2 then on PC 1: T-0032's acceptance list and shell trial gates
  G1–G11. Use Niri's built-in screenshot action for the pilot and test
  Flameshot separately.
- PC 1 still needs its own AMD + nouveau and external-display (DP-3) tests.

## Open

- PC 2's hardware and original OS (if Windows, nothing here writes to it;
  anything that would needs an ADR citing ADR-0019).
- Main plan decision 6 if `/etc/niri/config.kdl` is chosen (see corrections).
- Whether starting P4 on PC 2 before P4a is accepted as a phase change.
