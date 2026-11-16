---
adr: 32
title: "AI CLIs, context tools and desktop apps: packers removed after audit"
status: partly-decided
date: 2026-11-16
platforms: [linux, nixos, macos, wsl, windows]
areas: [ai-cli, context-packers, ai-desktop-apps, tool-selection]
permits: []
forbids: []
amends: [6]
supersedes: []
superseded_by: []
related: [11, 16, 19, 20, 21, T-0042, T-0047, T-0056]
---
# ADR-0032: AI CLIs, context tools and desktop apps: packers removed after audit
Status: partly-decided (the packer-removal and dsh-removal decisions are decided-unverified, owner 2026-11-16; the other rows are proposed; nothing here is built) · Date: 2026-11-16 · Amends: ADR-0006 (adds macOS and packer rows; Claude and Codex rows unchanged) · Sources: tool-selection design round 3

Notation, parity and profiles: [ADR-0021](0021-cross-platform-parity-and-profiles.md). Windows additions are bounded by [ADR-0019](0019-platform-scope-linux-macos-wsl2-first.md). The Windows status line is ADR-0016's; Windows built-ins (M365 Copilot) are ADR-0020's.

## Owner decision (2026-11-16, quoted)
- O3, packers: "Remove after audit".
- "remove deepseek harness for now": the DSH removal (decided-unverified). The repo part is done: removed in 4b15279 (T-0056); the live cleanup on the host is pending.

## Decision
One status per row.

| Job | Pick | Alternatives | P/W | Status | Now |
|---|---|---|---|---|---|
| Claude Code, Codex | ADR-0006 on Linux and WSL. macOS: vendor installers into `~/.local/bin` | brew casks; nixpkgs | P; W: employer | Pr | Deferred (installer not built: T-0047 S3-5) |
| opencode; openclaw | Nix everywhere; openclaw only on linux-desktop | none | P (W: employer) | Pr | Record |
| copilot | Nix on Linux and WSL. macOS uses a cask today; moving it to Nix is possible: github-copilot-cli 1.0.108 has an aarch64-darwin build (verified) | cask | P; W: employer | Pr | Deferred |
| Packers: remove code2prompt and files-to-prompt | keep repomix. The removal waits for the T-0042:311 gate, then updates to `ops/generate-package-matrix.sh:102` and `docs/reference/app-catalog.md:88` | none | P+W | DU | Deferred |
| dsh (DeepSeek Harness) removal | removed from the repo in 4b15279 (T-0056); owner live cleanup pending. It was the dsh install task in mise.toml at 63d206a (lines 393-398 there; at 7a6dc97 those lines are another task) | none | P+W | DU | Record; live cleanup pending |
| promptfoo; stray tools | Nix only (remove the npm copy); inventory qmd, harbor, inspect-ai, phoenix and graphify | none | none | Pr | Deferred |
| AI desktop apps | web or PWA everywhere. ChatGPT and Claude desktop installed by hand on macOS and Windows (P). Linux: CM (no official apps, unverified) | none | P; W only if the employer allows (suspect) | Pr | Manual |
| M365 Copilot (Windows built-in) | owned by ADR-0020 (work only); not restated | none | none | see ADR-0020 (DU) | ADR-0020 |

## Consequences
- Nothing is removed by this ADR; the packers stay installed until the audit gate passes. openclaw comes from the nix-openclaw overlay.
