# NixOS desktop stability

Audit of a `linux-desktop` host after a session loss. It covers one long-running boot.

## What happened

- At night, RAM and swap filled up completely. The kernel OOM killer fired.
- It killed Xwayland, so GNOME Shell shut down. There was no reboot, only a new login.
- The memory hog: nine parallel `shellcheck` processes from a repo verify tool.
- The OOM victim (a small editor process) was not the hog. Read the kernel's task dump, not only `Killed process`.
- After relogin, Ghostty crashed on every start (an input-method bug, unrelated to the OOM).

## Issues

| Issue | Cause | Fix | Status |
| --- | --- | --- | --- |
| Session lost to OOM (repeated OOM kills in one boot) | One terminal's workload filled RAM and swap; nothing bounded it | Per-tab and shared terminal memory limits | Mitigated |
| Runaway lint/test tooling | Unbounded parallel `shellcheck -x`; jq/mawk crashes in tests | Parallelism and memory caps in that tool | Fixed (separate repo) |
| Ghostty segfault at start | ibus GTK4 module recursion (stack overflow) | Ghostty-only wrapper with GTK's simple IM | Fixed |
| Restart storms (thousands of restarts per service) | `Restart=always` with no back-off on a persistent error | Exponential back-off to 10 min | Fixed |
| openclaw down after upgrade | New build needs a DB migration; Nix mode blocks `doctor` repairs | Rehearsed migration (see below) | Open, gateway stopped |
| Launcher apps share one cgroup | Apps opened from Vicinae run inside `vicinae.service` | Needs a scope-per-app launcher | Open |
| dGPU (nouveau) RPC timeouts, hung tasks | Driver/firmware; seen after the OOM, not before | Driver decision (see below) | Open |
| GNOME "Settings stopped" notice | Upstream crash in the global-shortcuts dialog | None; upstream | Documented |
| "Device nearly full" notice | Unknown; no filesystem was near full when checked | Detect scratch growth first | Monitoring |
| Fish `Unsupported use of '='` at login | Managed fish file older than the repo fix | Applied the managed file | Fixed |

## Fixed in this repo

- Per-tab soft limit, 12 GiB: `home/.chezmoitemplates/ghostty/config.body.tmpl` (`linux-cgroup-memory-limit`).
- All tabs in one budget, `app-terminals.slice` (High 18G, Max 22G, Swap 8G), plus 4G swap per tab: `nix/modules/home/gui.nix`.
- GNOME Console tabs join the same budget (High 12G, swap 4G per tab): `nix/modules/home/gui.nix`.
- AI remote-control services are capped (High 12G, Max 16G, swap 4G each) on every Linux host: `nix/modules/home/ai-cli-updates.nix`. They join `app-terminals.slice` through a desktop-only drop-in: `nix/modules/home/gui.nix`. They had peaked at 18-19 GiB outside every budget. The caps and the slice move take effect at the next restart of each service (restarting is the owner's call).
- Ghostty ibus workaround (version-guarded): `nix/overlays/default.nix`. It sets `GTK_IM_MODULE=gtk-im-context-simple`, which everything started from a Ghostty shell inherits: GTK apps launched from a tab lose ibus input. GNOME Shell layout switching is unaffected.
- Restart back-off: `nix/modules/home/openclaw.nix`, `nix/modules/home/dev.nix`, `nix/modules/home/ai-cli-updates.nix`.
- System baseline (fwupd discovery, smartd; zram opt-in): `nix/modules/nixos/desktop-stability.nix`, wired by `ops/system-setup.sh`. smartd runs with `-q nodev0`, so a host with no SMART device does not fail activation.

What the memory limits do and don't do:

- At the slice's `MemoryMax`, the kernel picks a victim inside the slice by OOM score, and `OOMPolicy=stop` then stops that one tab scope or service per kill. It is not necessarily the largest process.
- `MemoryMax=16G` on the remote-control services can stop a session that peaks above it (18-19 GiB was seen). The restart back-off then applies. That is the intended trade-off.
- Where the Ghostty main process runs depends on how it was launched: from the GNOME launcher it is `app-com.mitchellh.ghostty.service`, outside the slice; from Vicinae it runs in `vicinae.service`, unbounded.
- GNOME is outside the slice, which lowers the risk. It is not a guarantee: tabs opened before the change and apps launched from Vicinae are still unbounded.

## Baseline audit

| Area | State | Action |
| --- | --- | --- |
| UEFI, systemd-boot, current BIOS | OK | None |
| CPU microcode | Loaded | None |
| LTS kernel | OK | None |
| SSD TRIM (`fstrim.timer`) | On | None |
| Nix GC timer | On | None |
| Persistent journal | On | None |
| Core dump storage | Capped by systemd default (10%, max 4 GiB) | None |
| Firmware updates (`services.fwupd`) | Missing | Module: discovery only, flashing stays manual |
| Drive health (`services.smartd`) | Missing | Module: autodetect, journal + wall + desktop notifications; `-q nodev0` keeps activation green with no SMART device |
| zram swap | Missing | Module option, off by default (`DESKTOP_STABILITY_ZRAM=1`) |

## Needs sudo

`--apply` does more than this baseline. It also (re)manages docker, tailscale, the time zone (`mkForce`), trusted-users and Nix GC, then runs `nixos-rebuild switch`. Read the report first.

```bash
sudo bash ops/system-setup.sh       # 1. report only; sudo lets it read the current module
sudo sys-setup --apply              # 2. writes files, dry-builds, then switches
                                    #    (or: sudo bash ops/system-setup.sh --apply)
sudo nixos-rebuild switch --rollback   # if the new generation misbehaves
```

- A dry-build failure restores every file. A switch that activates but has failed units keeps the files and prints the rollback command.
- The script has no non-persistent mode. `sudo nixos-rebuild test --flake /etc/nixos#nixos` only checks the config already in `/etc/nixos`, not the new module.
- `ENABLE_DESKTOP_STABILITY=0` skips the module. `DESKTOP_STABILITY_ZRAM=1` adds zram.
- Every value is `lib.mkDefault`, so `configuration.nix` wins (the report names any option you already set).
- Firmware: `fwupdmgr get-updates`, read the notes, then flash explicitly with `fwupdmgr update`.

openclaw (the gateway is stopped; a state backup was taken while it was stopped):

- Do not run `openclaw doctor --fix` here. It is a general repair (plugins, config, services), not only the database, and `--non-interactive` still applies automatic repairs.
- Safe path: wait for a supported database-only migration. Or rehearse on a disposable copy of the state directory (`OPENCLAW_STATE_DIR` pointing at the copy, network isolated, Nix config untouched). Verify integrity, copy back only the migrated database files, keep the backup, and restart in Nix mode.

## Deliberately not changed

- Core dump caps: the systemd default already caps them.
- `vm.swappiness`: low values suit disk-only swap; with zram they work against compression.
- `systemd.oomd.enableUserSlices` / `ManagedOOMSwap`: oomd kills whole cgroups, and launcher apps still share one. Fix isolation first, then test with `sudo nixos-rebuild test`.
- journald size: the default cap kept the history this audit needed.
- GPU driver: needs a choice. Options: `nouveau.config=NvGspRm=0`, the iGPU only (blacklist nouveau), or the proprietary driver with PRIME offload. Test with a fallback boot entry.
- Disk encryption: changing it means reinstalling. Not a stability fix.
- Secure Boot: not needed for stability.
- XMP/ECC: not applicable to soldered laptop memory.
- Swap size: more swap only delays an unbounded workload.
- Scratch cleanup: agent scratch under `/tmp` grows large. Detect growth first, and clean up only by owner. Keep cleanup separate from detection.

## Check again

```bash
last -x | head                                     # reboot vs session loss
journalctl -k -b | grep -E 'Out of memory|oom-killer|blocked for more than'
coredumpctl list --since -7d                        # crashes
journalctl -b -o cat | grep -aoP '\S+\.service(?=: Scheduled restart job)' | sort | uniq -c | sort -rn
oomctl                                              # what systemd-oomd watches
systemctl --user show app-terminals.slice -p MemoryPeak -p MemoryMax
df -h / ; df -i /                                   # disk and inodes
```
