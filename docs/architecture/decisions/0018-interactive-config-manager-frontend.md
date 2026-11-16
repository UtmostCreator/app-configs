---
adr: 18
title: "Interactive configuration manager: a frontend over the existing selection"
status: proposed
date: 2026-11-16
platforms: [linux, macos]
areas: [installer, selection]
permits: [optional-frontend]
forbids: [own-installer, eval-user-input, windows-frontend]
amends: []
supersedes: []
superseded_by: []
related: [T-0042]
---
# ADR-0018: Interactive configuration manager: a frontend over the existing selection, not a new installer
Status: proposed (nothing implemented; `sys-config` and its flags are a proposed API, not existing) · Date: 2026-11-16 · Reopens: T-0042 "TUI ... ruled out" and ADR-0002 "no gum/fzf menu" · Sources: owner request 2026-11-16 with an outside AI-written recommendation (unverified where noted), T-0042, T-0043, ops/install.sh, nix/modules/home/profile.nix, a read-only look at the local KitPact checkout

Amended by ADR-0019: a Windows frontend is out of scope.

Does not amend an accepted record. If accepted, ADR-0002, ADR-0011 and the T-0042 "Discarded or deferred" list get a consequence line.

## Decision
- Add one optional frontend, proposed name `sys-config` (proposed flags: `--reconfigure`, `--plan`, `--list`, `--apply`). It asks questions and writes a proposed selection file. It owns no installation.
- Execution stays with the current owners: ops/install.sh, ops/lib/selection-preview.sh and selection-diff.sh, Nix/Home Manager, chezmoi, and ops/windows/bootstrap.ps1. The frontend never evals or executes user input.
- Interface: it writes a candidate selection to a private temp directory; the existing preview evaluates it; only a confirmed candidate replaces `~/.config/app-configs/selection/selection.toml` (tmp + mv, as selection_write does).
- UI: reuse the KitPact `wizard` module (Charm Huh, Bubble Tea, Lip Gloss), compiled in CI into per-OS binaries. No Go, Node or Python on user machines.
- Download: a pinned version, sha256 and build provenance (GitHub artifact attestation), checked before it runs. No silent "latest". No `go install` fallback.
- Fallback: the native Bash prompts of ops/install.sh (and a PowerShell equivalent only if a Windows entry point is ever approved) stay, so a failed or missing binary never blocks an install.
- Later extension (needs Nix validation to change; see Consequences): an allowlisted `[apps]` table, only if T-0042 Q2 = a (the architect leans b, single-app groups), with three states per app (inherit, enable, disable; only differences saved), fed by a JSON catalog of stable app ids that points at real Nix, Homebrew or WinGet declarations.

## Order change this ADR also proposes
Selection should come before dependency installation. Verified in ops/install.sh: step 2 "Nix" (line 405), step 3 "Base tools" (line 439, `nix profile install` at line 450) and step 4 "Validate flake" (line 456) all run before step 4b "Selection" (line 463). The script itself says a cancel at selection leaves "Nix, base tools, preflight seeding of personal.yaml" in place (line 477). Moving the selection earlier is not free: the preview evaluates the flake with Nix, so a Nix-less machine can only ask, not preview. `unknown`: how much of the current preview can run before Nix exists; step 3 of the implementation order settles it.

## Safeguards (P0 and P1)
P0:
- Selection is separate from execution; the frontend only proposes.
- Preview and dry-run are read-only (already true of selection-preview.sh: it evaluates, builds nothing, and leaves flake.lock alone).
- One installation owner per app and per host (T-0042 extension, section 2).

P1:
- A summary that groups add, remove, keep and manual.
- Explicit disables survive updates. Today they survive only when the answer differs from the profile default (only deltas are saved), so a disable that later matches a changed default is lost; the three-state model fixes that.
- A non-interactive path and an accessible mode (Huh's accessible, line-based mode exists per the wizard README).

## What exists today (verified at origin/main 4cfbae0)
- Local file: `${XDG_CONFIG_HOME:-$HOME/.config}/app-configs/selection/selection.toml` (T-0042 ticket; install.sh header, lines 53-54).
- Schema: only two top-level keys, `profile` (`work` or `personal`) and `[groups]` (nix/modules/home/profile.nix lines 22-36). Groups: `media`, `security`, `go`, `macInput` (profile.nix, groupDescriptions).
- Nix rejects unknown keys, unknown profiles, unknown groups, and groups without `profile`, by `throw` (profile.nix lines 41-48). So an `[apps]` table is rejected today; accepting it is a Nix change, not a frontend change.
- `sys-install --reconfigure` asks again and exits 1 without a terminal (install.sh lines 37, 99, 205). `--profile NAME` and `--dry-run` also exist (T-0042 design; --dry-run never persists a selection).
- Read-only comparison: `sys-update --selection-diff` (T-0043, ops/lib/selection-diff.sh).
- Prompts live only in install.sh, through `selection_read`; the libraries never read the terminal (install.sh lines 186-191).

## Why
- The selection model, validation, preview and diff already exist and are tested. A frontend adds ergonomics without a second source of truth.
- The owner asked for a friendlier choice than line prompts (owner request 2026-11-16). T-0042 Q2 is cited only for the growing app list.
- A compiled binary keeps user machines free of language runtimes; pinning plus provenance follows ADR-0007's pinned-image precedent.
- The wizard module already supplies a preview pane, accessible mode and "ask only on a terminal" guidance (kitpact/wizard/README.md), and is generic (it "imports nothing from KitPact").

## Strong alternatives
Scores are external AI-assisted estimates from the owner's pasted recommendation. They were not reproduced here and are not repo evidence.

| Option | Estimate | Why it lost or is kept |
|--------|----------|------------------------|
| KitPact wizard, compiled Go (chosen) | 93 | Best fit for the stated criteria, with the caveats below. |
| Huh directly | 87 | Same stack without the wizard layer. Fallback if the private, untagged wizard cannot be pinned reviewably. |
| Gum | 82 | A shell-out per question; ADR-0002 already discarded a gum/fzf menu while the T-0042 prompts were enough. |
| fzf | 76 | Selection list only; no confirm or preview flow. |
| Pure Bash/PowerShell | 63 | Kept as the fallback, not the main UI. |
| @clack/prompts | 57 | Needs Node on user machines. |
| Python | 49 | Needs Python on user machines. |

## Discarded
- A second package manager or installer inside the TUI.
- Installing Nix or base tools from the frontend.
- Any `go install` or build-on-user-machine path.
- A Nix-packaged frontend pinned by flake.lock: it gives hash pinning but cannot run before Nix exists, which conflicts with selection-before-Nix.

## Non-goals
- No package installation from the TUI.
- No Go, Node or Python required on user machines.
- No silent "latest" downloads.
- No Windows installs from WSL (ADR-0011, T-0042 extension section 1; no winget.exe from WSL).
- No new sources of truth for what a package is: the catalog points at Nix, Homebrew and WinGet declarations.
- Windows apps stay a manual list (ADR-0011) until a separate decision; this ADR does not decide T-0042 Q2, Q3 or Q8.

## Windows and WSL
- Today ops/windows/bootstrap.ps1 uses winget only for commit tooling (ADR-0002); ADR-0016 proposes adding jq. Apps are manual (ADR-0011). A Windows-native app list and a WSL app list would need separate owners and are T-0042's extension (section 3, proposed, awaiting Q1-Q11). This ADR does not duplicate it.
- The proposed frontend therefore targets the Linux/macOS selection first. Windows support is `unknown` and not planned here.

## Consequences
- Reopens two earlier choices: T-0042 "TUI, DSL or plugin system: ruled out; plain prompts only" (Discarded or deferred list) and ADR-0002's discard of a gum/fzf menu. Both were made when the selection had four groups; accepting this ADR needs an explicit owner decision to supersede them.
- New supply-chain surface: a private repository, a CI build, release assets, attestation checks, and per-OS binaries to keep working. A failed verification must fall back to the Bash prompts and never run an unverified binary.
- KitPact caveats from a read-only look at ~/Projects/kitpact (HEAD ba34bc0):
  - verified: `wizard` is a separate module (`github.com/utmostcreator/kitpact/wizard`) using huh/v2 2.0.3, bubbletea/v2 2.0.2, lipgloss/v2 2.0.1;
  - verified: `go 1.27` with `toolchain go1.27.3` in wizard/go.mod (build-time only);
  - stated: private (`gh repo view`, needs network, run 2026-11-16). Verified: no tags in the local clone (last fetch 2026-11-14), so a reviewed commit SHA is the only pin;
  - verified: the only workflow, .github/workflows/ci.yml, builds `GOOS=linux` and `GOOS=darwin`; it has no Windows build;
  - verified: the wizard asks questions; it is not a package installer. KitPact's lifecycle engine (a package in KitPact's root module) is for project files and is not used here.
  - unknown (not checked): the wizard module's behaviour on Windows terminals, and whether a release workflow with attestations exists (none seen in ci.yml).
- The wizard is a library (no `package main`). app-configs would own a small Go `main`, its tests and a Go toolchain in CI. Which repo builds and hosts releases is undecided, and release files on a private repo cannot be downloaded by user machines without credentials. A private module also cannot be consumed by this repo's CI without a token or a vendored copy (the README allows copying the directory, but then the pin is this repo's commit). Step 3 below depends on these decisions.
- `[apps]` and the catalog depend on T-0042's open questions (Q2: allowlisted app overrides) and need a Nix validation change; this ADR does not accept that change.
- Not verified here: the claim that a selection step before dependencies is safe on every host (see above); the performance of a compiled TUI on WSL; accessibility of the compiled TUI beyond the wizard README's statement.

## Implementation order (when accepted)
1. Move the selection step before dependency installation in ops/install.sh (or, if the preview needs Nix, ask first and preview after Nix); test that a cancel changes nothing.
2. Add the read-only plan (`--plan`) over the existing preview and selection-diff, with JSON output as the frontend contract.
3. Only after the Go `main`, the build and release host and the private-repo download question are decided: add the compiled wizard behind a verified download (pinned version, sha256, attestation) with the Bash prompts as fallback.
4. Add `[apps]` (Nix validation and tests) and the catalog, only after T-0042 Q2 is answered.

## Removal trigger
Remove the frontend and the download path if the pinned binary cannot be kept verifiable, or if the Bash prompts prove enough for the number of groups and apps.
