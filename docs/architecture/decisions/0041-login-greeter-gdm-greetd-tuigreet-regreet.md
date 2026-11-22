---
adr: 41
title: "Login greeter: GDM as safe fallback; evaluate greetd with tuigreet or gtkgreet"
status: proposed
date: 2026-11-22
platforms: [linux, nixos]
areas: [desktop, greeter, login, session]
permits: [gdm-during-trial, greetd-tuigreet-evaluation, greetd-gtkgreet-evaluation, greeter-vm-test-first]
forbids: [two-display-managers, greeter-change-on-live-desktop-without-approval, greeter-change-during-gnome-safety-trial]
amends: []
supersedes: []
superseded_by: []
related: [12, 13, 23, 38, 46, 47, T-0029, T-0032]
---
# ADR-0041: Login greeter: GDM as safe fallback; evaluate greetd with tuigreet or gtkgreet
Status: proposed (**tuigreet** preferred for reliability; **ReGreet** as graphical feature benchmark, **gtkgreet** as lean graphical alternative; current GDM remains untouched pending approval and live fallback gates) · Date: 2026-11-22 · Sources: [greetd upstream](https://github.com/kennylevinsen/greetd), [tuigreet](https://github.com/tuigreet/tuigreet), [gtkgreet](https://github.com/kennylevinsen/gtkgreet), [ReGreet](https://github.com/rharish101/ReGreet), [NixOS greetd guidance](https://wiki.nixos.org/wiki/Greetd), ADR-0012 and T-0032.

**Installation choices and dependent gaps:** [ADR-0046](0046-niri-desktop-installation-decision-register.md). **GNOME dependency policy:** [ADR-0047](0047-gnome-dependency-retirement-and-wayland-components.md).

## Decision

1. **Future target:** prefer **greetd + tuigreet** because the login prompt works in a text console and need not start another graphical compositor. This is a **research preference, not a permanent greeter selection**.
2. **Graphical alternatives:** compare **greetd + ReGreet** as the better-documented feature-rich GTK4/NixOS option against **greetd + gtkgreet** as the user-requested lean graphical alternative. Both require a greeter-only compositor such as Cage or Sway. Neither is selected; choose by real login, session-selection, accessibility, startup and recovery tests.
3. **GDM remains active for the existing physical desktop and current PC 2 baseline**: it preserves a working GNOME fallback and known login, keyring, accessibility and session integration. GDM is **not** the preferred permanent Niri-only greeter when the fallback can be safely retired.
4. Do not switch greeters, remove GNOME or set Niri default until a separate owner-approved, recoverable VM → PC 2 → PC 1 migration has passed actual login/TTY/PAM tests. A functioning Niri session is not evidence that the greeter works after reboot.
5. If GNOME is kept as a usable fallback after cutover, **test the GNOME screen-lock functionality under greetd**. Existing research indicates it may depend on GDM; preserve GDM if that fallback requirement cannot be met. Login, Secret portal unlock and session lock are **separate** systems.

## Comparative matrix (target hardware and pinned nixpkgs not yet tested)

| Candidate | Pros / differentiators | Cons / risks | Preferred role |
|---|---|---|---|
| **greetd + [tuigreet](https://github.com/tuigreet/tuigreet)** | Runs on TTY, no graphical greeter compositor; minimal failure surface under AMD/NVIDIA graphics problems; remembers user and session; session chooser, theming and power controls | TTY fonts/console appearance on 2560×1600; accessibility/alternative layouts and user menu limitations; no graphical keyboard; check `--remember`/menu regressions in pinned version | **First target to trial**, particularly recovery |
| **greetd + [gtkgreet](https://github.com/kennylevinsen/gtkgreet)** | Lightweight GTK graphical login, clear username/password/session selection, minimal traditional login design | Requires Cage/Sway or other greeter compositor; graphical driver issues can block greeter; explicit environments/session setup; GTK/DBus startup delays reported | **Lean graphical comparator**, not selected |
| **greetd + [ReGreet](https://github.com/rharish101/ReGreet)** | GTK4/Relm4, declarative NixOS `programs.regreet`, background/font/theme/CSS, user/session memory and selectable sessions, supported Cage/Niri greeter examples | Requires compositor, additional graphical/GTK dependencies and styling state; fewer benefits if a terminal greeter is sufficient; graphical login inherits GPU risk | **Feature-rich graphical benchmark**, not selected |
| **GDM** (current) | Existing working GNOME fallback, GDM login/lock/keyboard/accessibility and PAM/keyring wiring | Pulls GNOME Shell for greeter and retains full GNOME-fallback coupling; more desktop dependencies than desired | **Current safety baseline only**, not default future preference |
| **greetd + agreety** | Rescue-oriented very small TTY prompt, useful when customised greeter fails | Limited UI, session-selection UX and history | Emergency fallback, not daily choice |

**Feature reach over appearance**: favour session selection, reliable PAM/keyring, last-user/session behaviour, power/reboot actions, keyboard accessibility, prompt startup and TTY rescue over themes. Upstream feature descriptions are **not machine-tested scores**. Versions in the old 2026-11-20 comparison were pinned then but must be re-evaluated against the actual new `flake.lock`.

## Comparison and acceptance rubric

| Criterion | Weight | Gate |
|---|---:|---|
| Login reliability and recovery under graphical driver failure | 25 | P0 |
| PAM, session lock, keyring / Secret service lifecycle | 20 | P0 |
| GDM/GNOME fallback requirements during migration | 15 | P0 |
| Niri session registration, default selection, persistence | 15 | P0 |
| Keyboard layouts, TTY usability, accessibility | 10 | P1; P0 where user needs login method |
| Nix declarativity, easy rollback, independently scoped greeter | 10 | P0 |
| Community, docs, optional graphical theming | 5 | P2 |
| **Total** | **100** | P0 failure disqualifies regardless of score |

**Selection rule:** Never choose from paper scores. Record real GPU, TTY and keyboard measurements. A visually superior greeter cannot win if a crashed compositor prevents login or there is no reliable rescue path. Check `greetd` session wrappers, environment/PATH injection and start `niri-session` rather than a bare unsupervised Niri process.

## Required trial checks

- [ ] VM: greetd lists exactly the configured GNOME/Niri sessions; correct login, bad-password retry, logout/relogin, poweroff/reboot, no two display managers active.
- [ ] PC 2: graphical greeter on actual GPU; text greeter on 2560×1600 console; correct switching of US/RU layouts if needed; recovery via TTY when GTK/Cage, Niri or shell fails; last session preservation/restart.
- [ ] PC 2: login keyring/PAM vs KeePassXC correctly separated; Secret portal access after unlock; correct user services and `XDG_CURRENT_DESKTOP`.
- [ ] If keeping GNOME fallback, confirm GDM-free GNOME **locking**, not merely the ability to log in. If unsupported, stop replacement and retain GDM.
- [ ] Evaluate `gtkgreet` with an explicitly declared greeter-only Cage/Sway config; do not mix it with user Niri shell and KDL or add a second display manager.
- [ ] `tuigreet` remembering user/session and greeter cache are validated on the pinned build. Check combination of `--user-menu` and remember flags; known version-specific upstream regressions must not be assumed fixed.
- [ ] No GDM changes or destructive boot edits before the mandatory backup and rollback evidence in [T-0029](../../work/active/T-0029-nixos-system-ownership/ticket.md) / [T-0032](../../work/active/T-0032-niri-trial-session/ticket.md).
- [ ] Retire GDM and GNOME packages **only** as a later implementation ticket with documented minimal GNOME portal compatibility exceptions in ADR-0047.

## Graphical greeter evidence refinement (2026-11-22)

- [Official NixOS greetd guidance](https://wiki.nixos.org/wiki/Greetd) has a declarative **`programs.regreet`** module, whereas `gtkgreet` typically requires a custom Cage/Sway wrapper and session list. This is a **configuration/feature advantage**, not proof of better security.
- [ReGreet upstream](https://github.com/rharish101/ReGreet) documents session remembering, user/session choices, power actions, styling, NixOS support, greeter-only Cage/Sway and demo mode. GTK/DBus startup delays can also affect it; compare actual boot/login latency with `gtkgreet` rather than asserting that only gtkgreet is affected.
- **`tuigreet` remains first** because console access under a broken graphics stack has greater value than a themed graphical interface for this migration.
- A **greetd + oo7** Secret Service combination adds a *separate* PAM unlock gate. [ADR-0047](0047-gnome-dependency-retirement-and-wayland-components.md) and [ADR-0023](0023-password-managers-and-secrets-cli.md) now track oo7 independently of the greeter choice. Do not combine both migrations into one live cutover.
- Use a greeter-specific, minimal compositor configuration with a working VT escape; do not inherit the user's full `home/dot_config/niri/config.kdl` or desktop-shell startup into the greeter session.

## Consequences and open choices

- **No immediate change** to `nix/hosts/linux-desktop-pilot/system.nix`: GDM is still deliberately enabled and GNOME default. Existing pilot tests remain valid.
- Open: compare `tuigreet` vs `ReGreet` vs `gtkgreet` on the actual host; choose graphical accessibility requirements and session-memory expectations; decide GNOME fallback retirement timing.
- A later selection should amend this ADR and refresh [ADR-0046](0046-niri-desktop-installation-decision-register.md) **before** installation. The current preference is not a permanent selection.
