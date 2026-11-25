---
adr: 50
title: "NixOS and Niri home directory layout"
status: proposed
date: 2026-11-22
platforms: [nixos]
areas: [home-layout, niri, xdg, backup]
permits: [scratch-and-archive-roots, report-only-inventory, home-manager-folder-provisioning]
forbids: [automatic-home-folder-deletion, symlink-following-provisioning, raw-inventory-in-repo]
amends: []
supersedes: []
superseded_by: []
related: [33, 40, 46, 47, 49]
---
# ADR-0050: NixOS and Niri home directory layout
Status: proposed · Date: 2026-11-22

**Laptop delivery · 23 November 2026 · 50% (2/4) · P0 · medium complexity.** Home Manager base directories declared. Folder, logger and checkout examples exercised in fixtures. Seed the exact checkout and persist the log on the Kingston, then verify permissions and screenshot destination at first login. The updated integrated Home Manager activation provisions Scratch, Archive and the SSH client directory. The login report records the result. [Decision progress and evidence](0046-niri-desktop-installation-decision-register.md#laptop-delivery-by-decision)

Use the [shared work-folder convention](0040-macos-home-layout-and-cleanup-policy.md#shared-work-folder-convention) for new work and preserve existing checkout, worktree, and application paths. The convention describes desired locations. Verify on each host which directories, mappings, and backups already exist.

## Where files go

| Path | Purpose | Backup and retention |
| --- | --- | --- |
| `~/.config/`, `~/.local/share/`, `~/.local/state/` | Default XDG config, data, and persistent state locations. Follow configured XDG paths where present. | Back up essential application data selectively. |
| `~/.local/bin/`, `~/.cache/` | User commands and rebuildable caches, respectively. | Retain irreplaceable scripts. Use application-specific cache maintenance. |
| `$XDG_RUNTIME_DIR` | Session-owned runtime locations for sockets and other short-lived state. | Keep the session-provided path. |

Keep existing project metadata and reference directories, synced document trees, and Obsidian/QMD mappings where they are. Use Git's worktree commands for deliberate worktree lifecycle changes. Keep database dumps and any material that must survive out of `Scratch`. Bookmark `Projects`, `Scratch`, and `Archive` in the file manager. Scope existing QMD collections to authoritative sources and exclude disposable outputs and duplicate historical material by default. Preserve QMD indexes and model caches during routine cleanup because rebuilding them can be expensive.

## Repository ownership and provisioning

- Home Manager owns the Niri KDL and screenshot destination on `linux-niri`. Chezmoi owns the [older desktop pilot KDL](../../../home/dot_config/niri/config.kdl). Keep `Projects` capitalised for compatibility with the existing development tools.
- The [integrated Niri user](../../../nix/hosts/linux-niri/home.nix) provisions its first-login directories. It includes Scratch and Archive, and exports the three named roots. Existing XDG mappings remain application-owned. Extract a shared module when a second host adopts it. Reuse on macOS follows ADR-0040.
- On Linux, consider `xdg.userDirs` for the intended app-facing paths, with `createDirectories = false` so directory creation has one owner. The pinned module supports `xdg.userDirs.projects` as an extension. Applications may ignore `XDG_PROJECTS_DIR`, so repo scripts should use `DEV_ROOT` where they need a development root. Enabling the module manages a read-only `user-dirs.dirs` and disables the desktop updater. Null choices omit entries. Preserve existing mappings, keep `Desktop` where applications expect it, and leave optional media and sharing folders to actual use. Keep XDG application locations and `TMPDIR` independent of `Scratch`.
- Validate every destination before Home Manager's write boundary. Check each component beneath the home directory for symlinks and check that existing paths are directories. Checking `Pictures/Screenshots` alone misses a symlinked `Pictures`. Create missing directories through one activation step that honours dry-run. Give new `Scratch` and `Archive` roots mode `0700` and preserve all existing permissions and contents.

## Retention and rollout

Use the [ADR-0040](0040-macos-home-layout-and-cleanup-policy.md) reporting thresholds if an inventory is later approved. Report `temp` after 7 days, `screenshots` after 14 days, and `logs`, `benchmarks`, and `reports` after 30 days. Keep reports anonymised. Age rules in `systemd-tmpfiles` and the action-by-default `sys-cleanup` wrapper are outside this policy. Any filesystem mutation for cleanup needs a separate decision.

Before enabling provisioning, test dry-run and two successive Home Manager activations in a disposable home with existing files and custom XDG mappings. Test a regular file in place of a directory and symlinked roots, parents, and leaves separately. Verify preserved contents, permissions, and mappings, mode `0700` for new private roots even under a permissive umask, expected XDG path resolution, and zero writes outside the fixture. On first Niri login, save a screenshot and check its destination. If an inventory is built later, test that protected paths are excluded.

The [Niri installation plan](0049-niri-safest-staged-installation-order.md) owns the physical disk and encryption checks. Use [ADR-0033](0033-communication-sync-notes-and-backup.md) for Kopia backup and verify a representative restore from the independent destination before moving existing work or relying on the backup at cutover.
