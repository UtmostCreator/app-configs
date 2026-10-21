# Machine profiles (`myConfig.profile`)

A Home Manager option selects an opt-in app set per host.

- Option: `myConfig.profile`
- Type: enum `"work" | "personal"`
- Default: `"work"` (ships nothing personal)
- Declared in: `nix/modules/home/profile.nix` (imported by every host via
  `nix/modules/home`)
- Consumed in: `nix/modules/home/gui.nix`

## What `personal` adds

When a host sets `myConfig.profile = "personal";` **and** the host is Linux,
`gui.nix` additionally installs:

| App | Package | Notes |
| --- | --- | --- |
| Vesktop | `vesktop` | Discord with **Vencord** built-in (https://github.com/Vendicated/Vencord). The supported way to ship Vencord; the bare `vencord` attr is only a client-mod bundle, not a launchable app. |
| Telegram | `telegram-desktop` | Telegram desktop client. |

`work` (the default) installs none of these.

## Enable it on a host

Edit the host's `home.nix` (e.g. `nix/hosts/linux-desktop/home.nix`):

```nix
{
  imports = [
    ../../modules/common
    ../../modules/home
    ../../modules/home/gui.nix
    ../../modules/home/default-apps.nix
    ../../modules/home/gnome-files.nix
  ];
  myConfig.profile = "personal";
}
```

Then apply:

```bash
home-manager switch -b backup --flake ./nix#linux-desktop
```

## Verify

```bash
command -v vesktop telegram-desktop   # present only under the personal profile
```

> macOS note: `vesktop` and `telegram-desktop` also build on macOS, but this
> repo installs GUI apps on macOS via Homebrew casks. The `personal` gate here
> is wired in `gui.nix`, which is Linux-guarded; extend the darwin Homebrew
> module if a personal macOS set is wanted later.
