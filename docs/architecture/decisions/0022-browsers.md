---
adr: 22
title: "Browsers: Brave stable everywhere, Firefox secondary"
status: partly-decided
date: 2026-11-16
platforms: [cross, windows]
areas: [browsers, tool-selection]
permits: [brave-stable-default, firefox-secondary]
forbids: []
amends: []
supersedes: []
superseded_by: []
related: [11, 19, 20, 21, T-0041, T-0042]
---
# ADR-0022: Browsers: Brave stable everywhere, Firefox secondary
Status: partly-decided (Brave stable and the Beta discard are decided-unverified, owner 2026-11-16; the other rows are proposed; nothing here is built) · Date: 2026-11-16 · Sources: tool-selection design round 3

**Laptop delivery · 24 November 2026 · 75% (3/4) · P1 · medium complexity.** Brave in base profile. Firefox in optional bundle. The shared home activation preserves independent MIME associations in fixture tests. Check browser, PDF and link handlers in the restored graphical session. The config and legacy data locations can each hold independent preferences. [Decision progress and evidence](0046-niri-desktop-installation-decision-register.md#laptop-delivery-by-decision)

Notation (D, DU, Pr, O<n>; P, W; Ex, CM, OS, Exempt), parity and profiles: [ADR-0021](0021-cross-platform-parity-and-profiles.md). Windows additions are bounded by [ADR-0019](0019-platform-scope-linux-macos-wsl2-first.md). L / M / Win = Linux / macOS / Windows.

## Owner decision (2026-11-16, quoted)
- "Brave stable everywhere".

## Decision
One status per row.

| Job | L / M / Win | Alternatives | P/W | Status | Now |
|---|---|---|---|---|---|
| Default browser: Brave stable | repo-packaged stable / cask brave-browser (unverified), replacing the beta cask / Brave.Brave (unverified) | Brave Beta; Firefox; Vivaldi | P+W | DU | Deferred (follow-up I-02) |
| Brave Beta | discard after migrating the browser profile by hand (Beta and stable keep data in different directories), then uninstall by hand, because the cask cleanup is "none" | none | P+W | DU (follows the row above) | Deferred (I-02) |
| Firefox (secondary) | Nix / cask / Mozilla.Firefox | LibreWolf; Chromium | P+W | Pr | Record |
| Edge | built in, never the default browser. Autolaunch is ADR-0020's. Its PDF role is in ADR-0036 only | none | P+W | Pr | Record |
| Safari | built in, not the default | none | P+W | Pr | Record |
| Epiphany (GNOME Web) | GNOME base on Linux, exempt from parity (tag OS, not Exempt); removal via environment.gnome.excludePackages is a T-0029 option. Not installed on the GNOME-free niri install (ADR-0012) | none | P+W | Pr | Record |
| duti (brew) | used by `nix/modules/home/scripts/set-default-browser-macos.sh` | SwiftDefaultApps; set by hand | P+W | Pr | Record |
| Mozilla Maintenance Service | optional; removing it means Firefox updates ask for UAC | none | P+W | Pr | Manual |

## Follow-up I-02 (separate authorised change, not part of this ADR)
Brave stable and the macOS Preview PDF handler (ADR-0036) land in one change. Files:
- `nix/modules/darwin/homebrew.nix:40` (cask).
- `nix/modules/home/scripts/set-default-browser-macos.sh`: lines 2, 4-5 (bundle id and app path), 7, 12 (drop com.adobe.pdf from the Brave list; set Preview explicitly with duti) and 16. Preview mechanism: `duti -s com.apple.Preview com.adobe.pdf all`, then check with `duti -d com.adobe.pdf`.
- `nix/modules/home/default-apps.nix:102`; `nix/modules/home/default-browser-macos.nix:4`.
- `docs/platforms/macos/setup.md:221`; `docs/reference/default-apps.md:72-85`; `docs/work/active/T-0042-install-selection/ticket.md:344`; `repo-docs/software-and-cli-tools.md:247`; `docs/reference/app-catalog.md` (Brave row); the comment at `nix/modules/home/gui.nix:20`; T-0041:39.
- Then migrate the browser profile and uninstall Beta by hand (the profile move is manual and not reversible by a generation rollback).
- Validate per AGENTS.md (flake check, host build, bats, chezmoi diff, report-mode update).

## Consequences
- Today the repo still installs Brave Beta on macOS and the packaged stable build on Linux; this ADR changes no file.
- Unknown: the cask token and the winget id (unverified until `brew info --cask` and `winget show` are run).
