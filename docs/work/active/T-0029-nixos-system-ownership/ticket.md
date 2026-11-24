Source: local

# T-0029: NixOS system ownership via nixosConfigurations (feature)

Status: in progress (PC 2 pilot host linux-desktop-pilot on main 450e78e, 4c57049; PC 1 linux-desktop takeover not started, live gate needs owner)

**Niri delivery · 23 November 2026 · 50% (2/4) · P0 laptop / independent PC work · high complexity.** GNOME pilot built. Dedicated laptop output built. Review the destination module, then resolve the existing PC takeover separately. The existing PC takeover has its own live approval and recovery procedure. [T-0032](../T-0032-niri-trial-session/ticket.md) · [ADR-0012](../../../architecture/decisions/0012-desktop-compositor-gnome-niri-hyprland.md) · [ADR-0038](../../../architecture/decisions/0038-disko-nixos-anywhere-fresh-hosts.md) · [ADR-0049](../../../architecture/decisions/0049-niri-safest-staged-installation-order.md)
Niri desktop installation and component decision register: [ADR-0046](../../../architecture/decisions/0046-niri-desktop-installation-decision-register.md). Related register gaps: G01 (physical pilot layout), G13 (PC 1 backup/rollback), G14 (validation). The PC 2 flake host exists; PC 1 system takeover is still open.
Scope note (2026-11-22): the fresh `linux-niri` laptop has a separate flake output, integrated Home Manager and pinned Disko layout. Review its hardware module on the destination. Taking over the running GNOME system is independent of the blank-disk milestone. [Niri runbook](../../../platforms/nixos/niri-install.md)
Depends on: none
Blocks: T-0032
Evidence: `docs/research/desktop-migration-claim-audit.md`
Live gate: record the evidence from the existing-PC backup and rollback procedure below before the first live `/etc/nixos` takeover.

## Summary
Add `nixosConfigurations.linux-desktop` so the flake owns the running system.
Today the system comes from a hand-edited `/etc/nixos/configuration.nix` plus
aux modules written by `ops/system-setup.sh`. This ticket is desktop-neutral:
no compositor change.

- Reuse the existing `vars` / `mkHome` conventions in `nix/flake.nix`.
- Host file: T-0029 will create a new `system.nix` module under the Linux desktop host directory, importing `nix/modules/nixos`. The file does not exist yet.
- Take over, so the repo is the only writer of `/etc/nixos`:
  - `/etc/nixos/configuration.nix`;
  - `/etc/nixos/flake.nix` and its own `flake.lock` (the live system is built with `--flake /etc/nixos#nixos`, `ops/system-setup.sh:55`);
  - `app-configs-extra.nix` (written by `ops/system-setup.sh:51`) and `app-configs-docker.nix` (copied by `ops/system-setup.sh:71-72,263`);
  - `app-configs-tailscale.nix` / `-tailscale-host.nix` (written by `ops/tailscale-setup.sh:17,51`, which also edits `/etc/nixos/configuration.nix` and `flake.nix`);
  - `keyd-f1-remap.nix` (copied by hand, `docs/reference/keyboard.md:20,41`).
- Reduce `ops/system-setup.sh` to bootstrap, and bring `ops/tailscale-setup.sh` into scope; otherwise it stays a second `/etc/nixos` writer.

## Owned files
- nix/flake.nix, nix/hosts/linux-desktop/system.nix, nix/modules/nixos/**
- ops/system-setup.sh, ops/tailscale-setup.sh and their tests
- Downstream that goes stale and must be updated or re-checked: `ops/install.sh:397-428`, `ops/readiness.sh:6,92`, `docs/reference/keyboard.md:20,41`

## Findings
- VERIFIED (77564b6): flake had no `nixosConfigurations` (`nix/flake.nix:170-178`). Since 2026-11-20 it has one, the build-only niri pilot `linux-desktop-pilot` for PC 2 (`nix/hosts/linux-desktop-pilot/system.nix`); `linux-desktop` (PC 1) is still not flake-owned, which stays this ticket's scope.
- VERIFIED: only `nix/modules/nixos/default.nix` has no flake consumer. `docker.nix` is live through the `ops/system-setup.sh` copy, and `keyd-f1-remap.nix` through a manual copy.
- VERIFIED: `ops/system-setup.sh` edits `/etc/nixos/configuration.nix`, writes `app-configs-extra.nix` (:51), copies `app-configs-docker.nix` (:71-72,:263) and runs `nixos-rebuild switch` (:50, :191, :253-311, :319).
- VERIFIED: `ops/tailscale-setup.sh` writes the tailscale aux modules (:17,:51) and edits `/etc/nixos/configuration.nix` and `flake.nix`.
- VERIFIED (host read, 2026-11-14): the running system is GNOME Shell 50.1; pinned unstable has gnome-shell 51.0.

## Risks (HIGH)
- Switching to the flake moves GNOME 50.1 to 51.0. Owner decision 2026-11-20 (ADR-0012): if the daily session moves to niri, GNOME 51 parity is not a gate; the required check is only that GDM starts and the GNOME fallback session logs in. The fuller check (the Vicinae GNOME extension, 1.8.x claims 46-51 and the pinned build's metadata is UNVERIFIED, and every GNOME keybinding) applies only if GNOME stays the daily session. The owner checks keybindings by hand.
- `hardware-configuration.nix` is `/etc/nixos/hardware-configuration.nix` (VERIFIED, name-only listing); the new host must import or copy it deliberately.
- `nix/modules/nixos/default.nix` is consumed by nothing today, so it is untested as a system.
- Lock ownership: `/etc/nixos` has its own `flake.lock`. Once the repo lock also drives the system closure, define how `sys-update` and `flake.lock` ownership work (see AGENTS.md: `sys-update` owns lock bumps).

## Acceptance criteria
- `nix build ./nix#nixosConfigurations.linux-desktop.config.system.build.toplevel` builds.
- Closure diff against the current system is reviewed (for example `nvd` or `nix store diff-closures`) and shows only expected changes.
- `nixos-rebuild build` first. `test` and `switch` run only with the user's explicit approval at that time; note that `test` moves a running GNOME session from 50.1 to 51.0 components.
- `ops/tailscale-setup.sh` no longer writes `/etc/nixos`; `ops/install.sh` and `ops/readiness.sh` references updated or re-checked.
- The `flake.lock` ownership model with `sys-update` is written down.
- `nix flake check ./nix`, `bats tests/bash` and `bash ops/validate-config.sh` pass.
- The new host preserves bootloader, filesystems, initrd, encryption and GPU/kernel options from the live config; the evaluated diff is reviewed against `/etc/nixos`.
- No secret material from `/etc/nixos` enters git: gitleaks and the pre-commit hooks pass, and files containing credentials are never copied.
- Rollback is proven by booting the previous generation from the boot menu.

Note: niri could technically be trialled through `/etc/nixos`, but that would add another hand-edited writer, which this repo's ownership rule rejects; T-0032 therefore keeps this ticket as a dependency.

## Refs
`docs/plans/future-upgrades.md` section 6; `docs/plans/migration/overview.md` phase 1.

## Open checks
- Hybrid GPU behaviour after the switch: UNVERIFIED.
- GNOME 51.0 behaviour with the pinned extension: UNVERIFIED. Evidence so far: pinned `gnomeExtensions.vicinae` is EGO version 14 (`vicinaedagimg-dot.v14.shell-extension.zip`), and EGO extension-info for pk 8594 maps GNOME 46-51 to version 14; the store `metadata.json` was not read.

## Existing PC backup and rollback

Apply this procedure before a future T-0029 takeover of the existing PC. Use the [fresh-install runbook](../../../platforms/nixos/niri-install.md) for the separate laptop.

Facts read on this desktop on 2026-11-15 (user-supplied to this plan, read-only
checks by the coordinating session):

- `nixos-rebuild list-generations` shows only generation 17 (2026-09-06,
  current), so `nixos-rebuild switch --rollback` has no target right now.
- `/etc/nixos` is root-owned and hand-maintained (directory mode 0755, files
  0644 except `app-configs-extra.nix` and its `.bak`, which are 0600). It holds
  22 entries, 12 of them `.bak-*` files. Named files: `configuration.nix`,
  `configuration.nix.save`, `flake.nix` with its own `flake.lock`,
  `hardware-configuration.nix` (must never be lost), `keyd-f1-remap.nix`,
  `app-configs-extra.nix`, `app-configs-docker.nix`, `app-configs-tailscale*.nix`.
- The system is built with `--flake /etc/nixos#nixos`.

Required items (bash):

a) `/etc/nixos` snapshot. The evidence is the EMPTY-DIFF line with the path.

```bash
B=/root/etc-nixos-backup-$(date -u +%Y%m%dT%H%M%SZ); sudo cp -a /etc/nixos "$B" && sudo diff -r /etc/nixos "$B" && echo "EMPTY-DIFF $B"
```

b) Rollback target. Record `nixos-rebuild list-generations`. If only one
   generation exists, the first change must be applied with `nixos-rebuild boot`
   or `nixos-rebuild test` first, or the backup in (a) must be proven
   restorable. "Proven restorable" means the restore sequence below was done or
   rehearsed, with the RESTORED-EMPTY-DIFF line recorded. `test` leaves the boot
   default alone, so a reboot returns to the old generation, but it activates the
   new system at once: it is a live change under this gate, not a dry run. Do not restore with
   `cp -a "$B"/. /etc/nixos/`: it only overlays (newer files stay), and GNU cp
   writes through destination symlinks, which can overwrite repo files after the
   T-0029 takeover. Restore by replacing the directory:

   ```bash
   B=<path recorded in the gate evidence (e)>
   sudo test -d "$B" && { [ ! -e /etc/nixos ] && [ ! -L /etc/nixos ] || sudo mv /etc/nixos /etc/nixos.failed-$(date -u +%Y%m%dT%H%M%SZ); } && sudo cp -a "$B" /etc/nixos && sudo diff -r "$B" /etc/nixos && echo RESTORED-EMPTY-DIFF
   ```

   The `test -d` guard stops the sequence when `$B` is empty or wrong, so
   `/etc/nixos` is never removed without a verified copy to put back; it also
   covers the case where `/etc/nixos` is missing. `/etc/nixos.failed-*` is kept
   for inspection. Then choose ONE of these, never both in sequence:

   - EITHER, after the restore above: `sudo nixos-rebuild switch --flake /etc/nixos#nixos`
   - OR, when two or more generations exist and `/etc/nixos` is not needed:
     `sudo nixos-rebuild switch --rollback` (or pick the previous generation in
     the boot menu).

   Do not garbage-collect (`nix-collect-garbage`, `nix-env --delete-generations`)
   until the rollback check passes: generation 17 is the only rollback target.
   `nix-gc.timer` runs weekly with `nix-collect-garbage --delete-older-than 14d`,
   which ages generations by creation time: generation 17 (2026-09-06) is kept
   only while it is current, so the first GC run after a new generation becomes
   current deletes it. Stop the timer and set `nix.gc.automatic = false` before
   the first `boot` or `switch`, and re-enable it after the rollback check
   and the boot-tested generation has an explicit retention policy.

   GNOME stays the selectable fallback session.

c) User-level state the migration can touch. Keep these OUTSIDE the repo, in a
   private, user-only location; never commit them, they may contain private
   data. Create it with `P=<private dir>; install -d -m 0700 "$P"`. Refresh this
   item before each shell trial (Dux, then Noctalia).
   - `dconf dump / > <private dir>/dconf-<stamp>.ini` (GNOME settings,
     keybindings, extensions).
   - The Home Manager generation id: `home-manager generations | head -3`.
   - `chezmoi status` must be clean, or the managed state committed first.
   - A copy of `~/.config/niri`, `~/.config/noctalia` and
     `~/.config/DankMaterialShell`, and the Dux config directory (path to be
     confirmed when the module is chosen), for each that exists.

d) Data backup. NixOS generations are not data backups (see T-0032).
   - [ ] User confirms a home-data backup of `$HOME`, especially `~/Projects`
     and the KeePassXC database, before changing that PC. Verify a Kopia restore to independent storage.

e) Gate record: an evidence file at
   `docs/work/active/<ticket>/evidence/backup-<UTC>.md` holding the commands
   run, the paths, the EMPTY-DIFF line and the generation list. No secrets and
   no file contents.
