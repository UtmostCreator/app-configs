---
adr: 36
title: "Screenshots, media, images and PDF: Flameshot, Preview, Edge PDF, IINA, Paint.NET"
status: partly-decided
date: 2026-11-16
platforms: [cross, windows]
areas: [screenshots, media, images, pdf, tool-selection]
permits: [flameshot-windows-personal, preview-macos-pdf, edge-pdf-exception, iina-exception, paintnet-exception]
forbids: []
amends: [11]
supersedes: []
superseded_by: []
related: [13, 14, 19, 20, 21, 45, 46, 47, T-0032, T-0042]
---
# ADR-0036: Screenshots, media, images and PDF: Flameshot, Preview, Edge PDF, IINA, Paint.NET
Status: partly-decided (Windows personal screenshots, macOS PDF and four exceptions are decided-unverified, owner 2026-11-16; the other rows are proposed; nothing here is built) · Date: 2026-11-16 · Amends: ADR-0011 (the ShareX rejection reason, "Flameshot runs everywhere", is no longer true: no macOS cask) · Sources: tool-selection design round 3

Notation, parity and profiles: [ADR-0021](0021-cross-platform-parity-and-profiles.md). Windows additions are bounded by [ADR-0019](0019-platform-scope-linux-macos-wsl2-first.md). Windows built-ins (Media Player on both profiles) are ADR-0020's.

## Owner decisions (2026-11-16, quoted)
- Screenshots on Windows personal: Flameshot.
- PDF on macOS: Preview.
- O2: all native exceptions approved (here: Edge PDF on Windows, IINA on macOS, Paint.NET on Windows personal).

## Decision
One status per row.

| Job | L / M / Win | Alternatives | P/W | Status | Now |
|---|---|---|---|---|---|
| Screenshot, Linux | Flameshot | none | P+W | Pr | Record |
| Screenshot, macOS (CM) | built-in Cmd+Shift+5 (cask removed: `docs/reference/app-catalog.md:28`, commit fb1d74e; nixpkgs has darwin builds; the real reason is ADR-0014 ruling out Nix GUI apps on macOS plus the removed cask) | CleanShot X | P+W | Pr | Record |
| Screenshot, Windows P | Flameshot | ShareX | P | DU | Manual |
| Screenshot, Windows W (OS, built in) | Snipping Tool (ADR-0021 R3 keeps W installs to a minimum) | none | W | Pr | Manual |
| PDF, Linux | Brave (`nix/modules/home/default-apps.nix`) | Okular | P+W | Pr | Record |
| PDF, macOS | Preview | Acrobat (discard) | P+W | DU | Deferred (follow-up I-02, ADR-0022) |
| PDF, Windows (Ex) | Edge | Okular; SumatraPDF; Acrobat (discard; W only if an employer workflow needs it) | P+W | DU | Manual |
| Media player, Linux | GNOME built-in | VLC; mpv | P+W | Pr | Record |
| Media player, macOS (Ex) | IINA, needing a T-0042 group; built-in player meanwhile | mpv | P | DU | Deferred |
| Media player, Windows | Media Player (ADR-0020, both profiles) | none | none | see ADR-0020 (DU) | ADR-0020 |
| Images | built-in viewers (discard JPEGView). Quick edits: Pinta (Linux, deferred), Preview markup (macOS) | Krita; GIMP | P | Pr | Record; Deferred |
| Images, Windows P (Ex) | Paint.NET | Pinta | P | DU | Manual |
| Media and office apps | OBS, Audacity, GIMP, LibreOffice, calibre, PureRef: Windows P by hand. Linux and macOS deferred until a T-0042 group exists (candidate mediaApps, next to the approved CLI group media, `nix/modules/home/cli.nix:49`) | none | P | Pr | Manual; Deferred |

## R1 tests for the Ex rows
| Part | Edge PDF (Windows) | IINA (macOS) | Paint.NET (Windows, personal) |
|---|---|---|---|
| (a) licence for that profile | free; built in | free (GPL) | free (freeware); P only in this ADR |
| (b) native or built in | built in | native macOS app | native Windows app |
| (c) named gap against the parity pick | forms and ink, against Brave | native macOS UI, picture-in-picture, system media keys | plugins, maturity |
| (d) dated row | 2026-11-16; replaced pick Brave (the Linux PDF viewer, parity pick); revisit if Brave covers forms and ink | 2026-11-16; replaced pick mpv; revisit if mpv gains a native UI | 2026-11-16; replaced pick Pinta; revisit when Pinta is mature on Windows |
| (e) owner approval | 2026-11-16 | 2026-11-16 | 2026-11-16 |

## Consequences
- Nothing is installed by this ADR. The orphaned Flameshot config removal is follow-up I-10 (the chezmoi source `home/dot_config/flameshot/flameshot.ini`, its `home/.chezmoiignore` lines and the `docs/architecture/tool-ownership.md` exception).


## Niri capture comparison: separate screenshots from ScreenCast (2026-11-22)

The existing **Flameshot** application is not automatically the best Niri screenshot solution, but **do not remove its annotation, pin or last-region workflow without a verified replacement**. The GNOME **ScreenCast portal** is a separate capability from local screenshot utilities.

| Candidate | Pros | Cons / selection trigger |
|---|---|---|
| **Niri native actions** | Zero extra screenshot daemon; compositor-native region/window capture and clipboard | Annotation/pin workflow less rich than Flameshot; confirm actual actions on the pinned Niri |
| **Flameshot** (existing) | Mature annotations, pin, last region, resident workflow already installed | Wayland portal/focus and mixed-monitor screenshot risk; service starts for graphical-session target and needs an explicit GNOME/Niri scope |
| **grim + slurp + Satty** | Flexible Wayland area capture + powerful annotation editor | Several components, hotkey glue, output selection; check actual Niri wlr-screencopy support |
| **grim + slurp + swappy** | Lean scriptable editing pipeline | More scripts and separate editor process, may not match pin/last-region |
| **niri-shot** | Niri-specific workflow, fewer generic adapters | Smaller ecosystem/version risk; compare actual features and Nix availability |

**Separate P0 gates:** ScreenCast portal with PipeWire must work for Brave/Vesktop window and monitor sharing; file chooser/Secret/GlobalShortcuts also have independent portal routes. Upstream Niri currently documents `xdg-desktop-portal-gnome` for ScreenCast, which **does not require retaining GNOME Shell**. Test sensitive-window exclusion and multi-monitor privacy with an actual receiver; if no robust exclusion exists, do not claim a security guarantee. [ADR-0047](0047-gnome-dependency-retirement-and-wayland-components.md), [ADR-0046](0046-niri-desktop-installation-decision-register.md) G11/G18/G26, [T-0032](../../work/active/T-0032-niri-trial-session/ticket.md).
