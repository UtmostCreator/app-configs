# NixOS system rebuild (`nixos-rebuild`)

This repo's `nix/` flake manages your **user environment** via standalone
**Home Manager** (`home-manager switch`). It does **not** manage the NixOS
**system** (kernel, login shell, services, users, garbage-collection timer,
trusted users). Those live in `/etc/nixos/` and are applied with
`sudo nixos-rebuild …`.

Two layers, two commands:

| Layer | Owns | Apply with | In this repo? |
| --- | --- | --- | --- |
| User environment | CLI/GUI packages, dotfiles, fish/atuin/starship config | `home-manager switch --flake ./nix#linux-desktop` (automated by `scripts/install.sh`) | **Yes** (`nix/`) |
| NixOS system | login shell, services, users, `nix.gc`, `trusted-users`, kernel, bootloader | `sudo nixos-rebuild switch` | **No** (`/etc/nixos/`) — you own it |

> Why the split: a standalone Home Manager install (used here so the repo
> works on macOS/WSL/non-NixOS too) cannot set system-level options. On a pure
> NixOS box you *could* import Home Manager as a NixOS module, but that would
> make the flake NixOS-only. We keep them separate on purpose.

## What `nixos-rebuild` does

From the official manual: it builds the system described by
`/etc/nixos/{configuration.nix,flake.nix}` into `/nix/store`, runs the
activation script, and stops/(re)starts system services as needed. **Every
time you change the system config you must run `nixos-rebuild`** for it to take
effect.

### Subcommands (when to use which)

| Command | Effect | Use when |
| --- | --- | --- |
| `sudo nixos-rebuild switch` | Build + activate now + set as **boot default** | Normal apply. Persists across reboot. |
| `sudo nixos-rebuild test` | Build + activate now, **not** added to boot menu | Risky change you want to try; reverts on reboot. |
| `sudo nixos-rebuild boot` | Build + set boot default, **don't activate now** | Kernel/driver change to take effect on next boot. |
| `sudo nixos-rebuild dry-activate` | Build + show what activation *would* do | Preview service restarts before committing. |
| `sudo nixos-rebuild build` | Build only, no activation | Just check it compiles. |
| `sudo nixos-rebuild switch --rollback` | Activate the **previous** generation | Undo a bad system change. |
| `nixos-rebuild list-generations` | List system generations | See history / pick a rollback target. |

Flake-based systems (this machine is one — `/etc/nixos/flake.nix` exists) take
`--flake`:

```bash
sudo nixos-rebuild switch --flake /etc/nixos#nixos
```

`nh` (installed by this repo) is a friendlier wrapper:

```bash
nh os switch /etc/nixos      # = nixos-rebuild switch, nicer output + diff
nh os boot   /etc/nixos
```

## When is a system rebuild REQUIRED?

Run `sudo nixos-rebuild switch` after editing `/etc/nixos/*` for any of these.
The repo install (`scripts/install.sh`) does **not** do these automatically
because they are system-level and need `sudo`:

1. **Make fish the login shell** (recommended after install — see below).
2. **Silence the `auto-optimise-store` warning** by adding yourself to
   `nix.settings.trusted-users`.
3. **System-level garbage collection / store optimise timer**
   (`nix.gc.automatic`, `nix.optimise.automatic`).
4. **Kernel, drivers, bootloader, file systems** → use `boot`, then reboot.
5. **System services / daemons** (docker daemon, ssh, networking).
6. **New users or user shell changes.**

You do **not** need a system rebuild for: installing/removing the CLI/GUI apps
this repo manages, or changing dotfiles — those are `home-manager switch` +
`chezmoi apply`, both automated.

## Recommended system snippet for this setup

Add to `/etc/nixos/configuration.nix` (inside the top-level attrset), then
rebuild. This wires the three things this repo recommends at the system level:

```nix
{
  # 1. fish as a registered shell + the login shell for your user.
  programs.fish.enable = true;
  users.users.utmostcreator.shell = pkgs.fish;

  # 2. Trust your user so client Nix settings (auto-optimise-store) apply
  #    without the warning seen during home-manager switch.
  nix.settings.trusted-users = [ "root" "utmostcreator" ];

  # 3. Declarative, scheduled, NON-destructive store maintenance.
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";   # keeps recent rollbacks
  };
  nix.optimise.automatic = true;
}
```

Apply it:

```bash
sudo nixos-rebuild switch --flake /etc/nixos#nixos    # flake system
# or, non-flake systems:
sudo nixos-rebuild switch
```

## Do I need to reboot?

- **Usually no.** `switch` activates immediately; most changes (packages,
  shells, most services) take effect without a reboot. Open a **new terminal**
  to pick up a login-shell change.
- **Reboot required** for: kernel updates, bootloader/initrd changes, some
  GPU/driver and firmware changes, or anything applied with `boot` instead of
  `switch`.
- After a kernel/driver change: `sudo nixos-rebuild boot && sudo reboot`.

## Confirm system readiness after a rebuild

```bash
nixos-rebuild list-generations | head        # new generation is "Current"
systemctl --failed                            # no failed system units
systemctl --user --failed                     # no failed user units
echo $SHELL                                    # fish, after login-shell change + new login
nix-collect-garbage --dry-run 2>/dev/null | tail -1   # GC sanity (optional)
```

If something is wrong, roll back instantly:

```bash
sudo nixos-rebuild switch --rollback
```

## Dual-boot with Windows (optional)

This repo ships an **opt-in** NixOS module and a **read-only** detector for a
safe Windows + Linux boot menu via systemd-boot (the bootloader this machine
already uses). Nothing here runs automatically — it is config you apply to
`/etc/nixos` yourself.

- Module: `nix/modules/nixos/dual-boot.nix` (options under `myConfig.dualBoot`).
  Inert unless `enable = true`, so single-OS users can ignore it.
- Detector: `scripts/detect-os-disks.sh` — scans disks live (read-only) and
  prints a suggested `myConfig.dualBoot` snippet. It never writes config and
  never touches the bootloader.

### 1. Detect what you have

```bash
bash scripts/detect-os-disks.sh            # human report + suggested snippet
AI_OUTPUT=json bash scripts/detect-os-disks.sh   # machine-readable
```

It reports, per physical disk, whether it holds Windows or Linux, marks the
disk the current OS booted from, and tells you whether Windows is on the **same**
disk/ESP as NixOS or a **separate** one.

### 2. Enable the module in `/etc/nixos`

Import it and set the options the detector suggested. Two cases:

**Same disk/ESP** (systemd-boot auto-detects Windows — fully reproducible):

```nix
myConfig.dualBoot.enable = true;
```

**Separate disk** (Windows on its own ESP — needs a one-time device handle):

```nix
myConfig.dualBoot = {
  enable = true;
  windowsOnSeparateDisk = true;
  # windowsDeviceHandle = "HD0c1";  # discover it once (step 3)
};
```

> systemd-boot cannot load an EFI binary from another disk's ESP directly, so
> the separate-disk path chainloads Windows **read-only** via the EDK2 UEFI
> Shell. Neither OS can overwrite the other's ESP: systemd-boot only ever writes
> to its own ESP (`/boot` here), and Windows lives on its own disk.

### 3. Discover `windowsDeviceHandle` (separate disk only)

1. Set `windowsOnSeparateDisk = true` (this adds the EDK2 UEFI Shell entry),
   then `sudo nixos-rebuild boot --flake /etc/nixos#nixos`.
2. Reboot, choose **"EDK2 UEFI Shell"** from the systemd-boot menu.
3. Run `map -c` to list consistent device handles (e.g. `HD0c1`).
4. For each handle, run `ls HD0c1:\EFI`; the Windows ESP has a `Microsoft` dir.
5. Confirm with `HD0c1:\EFI\Microsoft\Boot\Bootmgfw.efi` (Windows should boot).
6. Put that handle in `windowsDeviceHandle`, then
   `sudo nixos-rebuild switch --flake /etc/nixos#nixos`.

### 4. Make NixOS the default and set menu order

The module sets `boot.loader.efi.canTouchEfiVariables = true`, so after a
rebuild **`efibootmgr` is available** on the system and the NixOS UEFI entry is
registered. To make NixOS the firmware default (instead of Windows):

```bash
efibootmgr                       # list entries; note the NixOS + Windows IDs
sudo efibootmgr -o 0001,0000     # boot order: NixOS first, then Windows (use YOUR ids)
```

Within the systemd-boot menu itself, NixOS sorts ahead of the Windows entry by
default; `myConfig.dualBoot.timeout` (default 5s) controls the menu wait.

> Rollback: every `nixos-rebuild switch` creates a generation; pick an older one
> from the boot menu or run `sudo nixos-rebuild switch --rollback`. The boot
> order change is reversible with another `efibootmgr -o`.

## Where this fits in the install flow

1. `bash scripts/install.sh` — user env (packages + dotfiles + fish config).
   *Fully automated, no sudo.*
2. **(optional, recommended)** edit `/etc/nixos/configuration.nix` with the
   snippet above and run `sudo nixos-rebuild switch` — makes fish the login
   shell and enables system GC.
3. Open a new terminal (or reboot if a kernel/driver changed). Run the
   readiness checks above.

See `docs/INSTALL.md` for the end-to-end timeline and
`docs/install-nixos.md` for NixOS failure modes.
