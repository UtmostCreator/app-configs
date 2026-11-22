---
adr: 41
title: "Login greeter: GDM during the niri trial, greetd with tuigreet proposed after cutover"
status: proposed
date: 2026-11-20
platforms: [linux, nixos]
areas: [desktop, greeter, login, session]
permits: [gdm-during-trial, greetd-tuigreet-after-cutover, greeter-vm-test-first]
forbids: [two-display-managers, greeter-change-on-live-desktop-without-approval, greeter-change-during-trial]
amends: []
supersedes: []
superseded_by: []
related: [12, 13, 23, 38, T-0029, T-0032, 46]
---
# ADR-0041: Login greeter: GDM during the niri trial, greetd with tuigreet proposed after cutover
Status: proposed (owner asked on 2026-11-20 for greetd + tuigreet compared with the two strongest alternatives; nothing is built and the live desktop keeps GDM) · Date: 2026-11-20 · Sources: ADR-0012 (GDM stays; "Ly and greetd/tuigreet (deferred)"), `docs/research/desktop-migration-claim-audit.md` ("GDM stays during the trial"), `docs/research/niri-vs-hyprland.md` (greetd PATH note), evaluation of the pilot host on the pinned nixpkgs

**Niri migration installation inventory and unresolved gaps:** [ADR-0046](0046-niri-desktop-installation-decision-register.md). This cross-reference does not change this ADR's decision or status.

The compositor is ADR-0012 and the shell is ADR-0013. This ADR covers only what shows the login prompt and starts the session. If accepted, it replaces ADR-0012's "greetd/tuigreet (deferred)" with a dated plan; ADR-0012 is not changed by this proposal.

## Options compared
Versions are the pinned nixpkgs (26.11, 5d2b81a). All three have NixOS modules there.

| | GDM 51.0 (today) | greetd 0.10.3 + tuigreet 0.11.1 | greetd 0.10.3 + ReGreet 0.5.0 |
|---|---|---|---|
| What it is | GNOME's display manager; the greeter is a gnome-shell session | A small login daemon plus a text greeter on the console | The same daemon plus a GTK4 greeter inside the cage kiosk compositor |
| Needs a working GPU session to log in | Yes (Wayland gnome-shell) | No (text on a VT) | Yes (cage) |
| GNOME fallback session | Full, including the lock screen | Starts, but GNOME's own lock screen needs GDM, so locking in the fallback session is lost (upstream behaviour, not tested here) | Same limit as tuigreet |
| niri session | Listed next to GNOME (a niri login through GDM worked in a VM run of the pilot on 2026-11-20) | Listed with `--sessions`; evaluates on the pilot with GDM off, GNOME and niri both offered | Lists the same session files |
| Remembers user and last session | Yes, per user in AccountsService; this overrides the configured default | Yes (`--remember`, `--remember-session`), in its own cache | Yes |
| Keyring unlock at login | Wired by the GNOME module | Off by default: needs `security.pam.services.greetd.enableGnomeKeyring = true` (evaluated: false without it) | Same as tuigreet |
| Config surface | Several modules, dconf for the greeter | One command line in `services.greetd.settings` | The greetd command plus a TOML and CSS for the greeter |
| Weight | Pulls GNOME Shell for the greeter | Smallest | GTK4 plus cage |
| Maturity | Long established | Established; tuigreet is simple | Youngest of the three (0.5.0) |
| Look and accessibility | Graphical, on-screen keyboard, screen reader | Text only; boot messages can overwrite it unless the console is kept quiet | Graphical and themable; fewer accessibility features than GDM |

## Scores (opinion, 0-100; not measured)
| Phase | GDM | greetd + tuigreet | greetd + ReGreet |
|---|---|---|---|
| niri trial, GNOME kept as the fallback session | 88 | 72 | 64 |
| After cutover, niri is the only daily session | 62 | 90 | 76 |

The order flips because GDM's main advantage is the GNOME fallback (its lock screen and keyring wiring), and its main cost is carrying GNOME Shell just to log in once GNOME is no longer used.

## Fit for this machine
Read on the daily machine on 2026-11-20 (read-only): a laptop with a 2560x1600 internal panel and an external display at times, an AMD integrated GPU that drives the screens plus an NVIDIA GPU on nouveau, one user, US and Russian layouts in the session with a US console keymap, no fingerprint login in use, and KeePassXC as the password manager (ADR-0023).

| Property of the machine | GDM | greetd + tuigreet | greetd + ReGreet |
|---|---|---|---|
| Hybrid AMD and nouveau graphics; nouveau has logged timeouts (`docs/platforms/nixos/desktop-stability.md`) | The greeter is a Wayland gnome-shell, so a graphics fault can block login | Best fit: text on the console needs no compositor, so login and session choice survive a graphics fault | cage is a compositor too; same exposure as GDM, with a smaller stack |
| 2560x1600 panel | Scales itself | The default console font is tiny at this density; needs a larger console font set in the system config (a one-line setting, to be tested in the VM and on the panel) | Scales through GTK; needs its scale set once |
| External display sometimes attached | Follows GNOME's monitor logic | The console is cloned to the connected outputs (INFERRED, not tested) | Shown per cage's output handling (not tested) |
| US and Russian layouts | Layout switcher on the login screen | Console keymap is US only, which suits a Latin password; no layout indicator | Follows the configured XKB layout; no switcher by default |
| One user, no fingerprint | More than needed (user list, accessibility, enterprise login) | Enough: remembered user, password prompt, session menu, power menu | Enough |
| KeePassXC, not the GNOME keyring, holds passwords | Keyring unlock wired anyway | Keyring unlock is optional here; turn the PAM line on only if an app still needs the Secret Service at login | Same as tuigreet |
| Laptop suspend and lid | The session's locker handles resume; GDM only matters for the GNOME fallback's lock | No role after login; the niri shell's locker (ADR-0013) handles resume | Same as tuigreet |
| Rebuild and rollback from the repo | Many moving parts move with every GNOME release (50.1 to 51.0 now) | One short declaration that rarely changes between releases | A daemon plus a GTK greeter and a kiosk compositor to keep working together |

Why these three and not others for this machine: GDM is the option that keeps the GNOME fallback whole, tuigreet is the option that cannot be taken down by the graphics stack, and ReGreet is the closest graphical alternative that still shares tuigreet's daemon, so moving between the last two is cheap.

## Decision (proposed)
- During the niri trial, and for as long as GNOME stays a usable fallback session, keep GDM. No greeter change on PC 1 or the pilot in that phase.
- After cutover (niri the daily session, the shell from ADR-0013 providing lock and idle), move to greetd with tuigreet. The text greeter does not depend on the graphics stack, which matters on a hybrid AMD and nouveau machine: a broken compositor or driver still leaves a way to log in or pick another session.
- greetd with ReGreet is the runner-up, for the case where a graphical greeter is wanted. It keeps greetd, so switching between tuigreet and ReGreet later is one module change.
- One display manager at a time. A change is tried in the pilot VM first (the greetd unit starts, tuigreet lists GNOME and niri, a niri login works), then on PC 2, and reaches PC 1 only with the owner's approval at that time.
- When greetd is used: enable the keyring PAM line above, start niri through `niri-session`, keep the console quiet so boot messages do not draw over the greeter, and apply the PATH note in `docs/research/niri-vs-hyprland.md` if the niri user service does not see the user profile.

## Why
- The trial needs the least change. GDM already works, lists both sessions and keeps GNOME's lock screen, and the audit's recommendation was to defer the greeter out of the trial.
- After cutover the same properties stop mattering, and the smallest greeter with the least to break is the better fit for a single-user desktop.

## Discarded
- Ly 1.5.0: a text greeter with its own display-manager logic; the Hyprland plan already rated it "works, not recommended". tuigreet on greetd covers the same need with a simpler split.
- SDDM 0.21.0: brings the Qt and KDE stack for no gain here.
- cosmic-greeter 1.11.0: also greetd-based, but part of COSMIC, which ADR-0012 discarded.
- No greeter (console login that starts niri): no session choice and no remembered session; kept only as a rescue path.

## Open questions (owner)
- Accept tuigreet as the target after cutover, or prefer ReGreet for a graphical login.
- Whether the GNOME fallback is kept after cutover. If it is, either accept that its lock screen does not work without GDM, or stay on GDM.
- Fingerprint or other PAM methods at login, if wanted; none is configured today.
- The console font and size for tuigreet on the 2560x1600 panel.

## Consequences
- Nothing changes now. The pilot keeps GDM (`nix/hosts/linux-desktop-pilot/system.nix`), and `tests/bash/nixos-pilot.bats` keeps asserting it.
- If accepted, the greeter move is its own change after cutover, with a VM test first, and ADR-0012's "deferred" line is updated then.
