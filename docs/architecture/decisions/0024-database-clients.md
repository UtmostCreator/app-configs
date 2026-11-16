---
adr: 24
title: "Database clients: Beekeeper Studio everywhere, DBeaver on macOS, HeidiSQL on Windows"
status: partly-decided
date: 2026-11-16
platforms: [cross, windows]
areas: [database-clients, tool-selection]
permits: [beekeeper-studio, dbeaver-macos, heidisql-windows-exception]
forbids: []
amends: [11]
supersedes: []
superseded_by: []
related: [19, 21, T-0042]
---
# ADR-0024: Database clients: Beekeeper Studio everywhere, DBeaver on macOS, HeidiSQL on Windows
Status: partly-decided (Beekeeper, DBeaver on macOS and HeidiSQL are decided-unverified and Sequel Ace is decided, owner 2026-11-16; the mysql CLI row is proposed; nothing here is built) · Date: 2026-11-16 · Amends: ADR-0011 (HeidiSQL changes from discarded to a permanent exception) · Sources: tool-selection design round 3

Notation, parity and profiles: [ADR-0021](0021-cross-platform-parity-and-profiles.md). Windows additions are bounded by [ADR-0019](0019-platform-scope-linux-macos-wsl2-first.md).

## Owner decisions (2026-11-16, quoted)
- "both Beekeeper Studio and hidesql" (Beekeeper on every OS; HeidiSQL on Windows, which is the owner exception already referenced in ADR-0011).
- "macos also add beaverdb" (DBeaver Community on macOS).
- Sequel Ace stays on macOS: inferred from "also add", because the owner did not ask to remove it (an inference, not a quote).

## Decision
One status per row. HeidiSQL is Exempt (an owner-decision exemption; no R1 test applies).

| Job | L / M / Win | Alternatives | P/W | Status | Now |
|---|---|---|---|---|---|
| Beekeeper Studio Community | `nix/modules/home/gui.nix`, ungrouped (nixpkgs beekeeper-studio 6.2.1 builds on Linux and darwin, verified) / cask (unverified) / manual | DBeaver CE; DataGrip | P+W | DU | Deferred (follow-up I-06) |
| DBeaver Community | none / cask dbeaver-community (unverified; nixpkgs dbeaver-bin 26.2.4 also builds on darwin, verified) / none | none | P+W | DU | Deferred (I-06) |
| HeidiSQL (Exempt) | none / none / manual, permanent | none | P+W (GPL) | DU | Manual |
| Sequel Ace | none / cask, kept as is / none | none | P+W | D (inferred from the DBeaver answer) | Record |
| mysql CLI | Nix `mariadb` (`nix/modules/home/dev.nix:181`, Linux only) / brew mysql-client (keg-only, reason stated) / none | mycli; usql | P+W | Pr | Record |

## Follow-up I-06 (separate authorised change)
Beekeeper in `nix/modules/home/gui.nix` and a cask; DBeaver as a cask; Windows manual rows for Beekeeper and HeidiSQL; update `docs/reference/app-options.yaml` and `docs/reference/app-catalog.md` (this ADR only cites them).

## Consequences
- Nothing is installed by this ADR. Cask tokens and nixpkgs availability are unverified.
