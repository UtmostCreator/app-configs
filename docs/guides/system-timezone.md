# System time zone (Europe/London)

This repo ships a reproducible system time-zone default of **Europe/London**.

- Module: `nix/modules/nixos/timezone.nix`
- Imported by: `nix/modules/nixos/default.nix`
- Option: `myConfig.timezone.name` (default `"Europe/London"`, `enable` default `true`)

Time zone is a **NixOS system setting** (`time.timeZone`). It is *not* something
Home Manager or nix-darwin applies. The live system config is in `/etc/nixos`,
so the module only takes effect once `/etc/nixos` imports it and you run a
system rebuild.

## Apply to the live host (automated)

`/etc/nixos` is root-owned, so these steps need `sudo` (run them yourself; the
AI tooling cannot supply a sudo password non-interactively).

Run the existing NixOS system-layer helper:

```bash
sudo sys-setup --apply
```

or from the repository checkout:

```bash
sudo bash ops/system-setup.sh --apply
```

That helper writes `/etc/nixos/app-configs-extra.nix`, wires it into the system
flake when needed, sets:

```nix
time.timeZone = lib.mkForce "Europe/London";
```

and runs:

```bash
sudo nixos-rebuild switch --flake /etc/nixos#nixos
```

`lib.mkForce` is intentional: the stock installer line in
`/etc/nixos/configuration.nix` may still say `America/New_York`, but the shipped
app-configs system module wins so the live system becomes Europe/London without
hand-editing that file.

Override for a one-off host:

```bash
SYSTEM_TIMEZONE=Europe/London sudo bash ops/system-setup.sh --apply
```

## Manual module wiring (advanced)

Import the module from `/etc/nixos`. Add this to `/etc/nixos/app-configs-extra.nix`
(the file already imported by `/etc/nixos/flake.nix`):

   ```nix
   imports = [ /home/utmostcreator/Projects/app-configs/nix/modules/nixos ];
   ```

The module defaults `myConfig.timezone.name = "Europe/London"`, so no extra
option is needed. To override per host:

   ```nix
   myConfig.timezone.name = "Europe/London";
   ```

Rebuild:

   ```bash
   sudo nixos-rebuild switch --flake /etc/nixos#nixos
   ```

## Quick alternative (no module, direct edit)

If you prefer not to import the module, edit `/etc/nixos/configuration.nix`
directly (line currently reads `America/New_York`):

```bash
sudo sed -i 's#time.timeZone = "America/New_York";#time.timeZone = "Europe/London";#' /etc/nixos/configuration.nix
sudo nixos-rebuild switch --flake /etc/nixos#nixos
```

> If both `/etc/nixos/configuration.nix` and this module set `time.timeZone`,
> NixOS will report a conflicting-definition error. Pick ONE owner: either the
> direct line in `configuration.nix` OR the module. Remove the other.

## Verify it is applied (the "ensure it is gone" check)

```bash
timedatectl | grep "Time zone"
# expected: Time zone: Europe/London (BST, +0100)  — America/New_York gone
```

`BST` (+0100) in summer, `GMT` (+0000) in winter.
