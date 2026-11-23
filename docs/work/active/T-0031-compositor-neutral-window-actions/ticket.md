Source: local

# T-0031: Compositor-neutral window actions (refactor)

Status: in progress (backend interface and GNOME backend on main dea74d4, 25d7ca8; remaining: niri backend, live checks)

**Niri delivery · 23 November 2026 · 50% (2/4) · P1 daily use · high complexity.** Backend contract recorded. GNOME backend landed. Implement the Niri backend, then verify focus and keyboard parity on hardware. The Niri session provides a test platform before the daily-use decision. [T-0032](../T-0032-niri-trial-session/ticket.md) · [ADR-0027](../../../architecture/decisions/0027-launcher-clipboard-windows-input-macos-ux.md) · [ADR-0045](../../../architecture/decisions/0045-niri-windows-like-desktop-shell-ux.md) · [ADR-0048](../../../architecture/decisions/0048-niri-launcher-vscode-project-workflows.md)
Niri desktop installation and component decision register: [ADR-0046](../../../architecture/decisions/0046-niri-desktop-installation-decision-register.md). Related register gap: G05 (Niri window/MRU/hide/restore and bilingual parity).
Scope note (2026-11-22): the niri install carries no GNOME desktop (ADR-0012), so on it the GNOME backend cannot serve as a fallback. The niri backend is required before that install can be the daily system ([ADR-0049](../../../architecture/decisions/0049-niri-safest-staged-installation-order.md), cutover sign-off for G05). The GNOME backend stays, unchanged, for the existing GNOME system.
Depends on: none for the spec and GNOME refactor; the niri backend needs the T-0032 session.
Evidence: `docs/research/desktop-migration-claim-audit.md`

## Summary
Confirmed portability defect: `vicinae-toggle-app`, `vicinae-focus-tracker`,
`vicinae-resize` and the window focus in `vscode-recent-projects` are GNOME-only.
Define a desktop-neutral action spec with per-compositor backends and keep the
GNOME backend working unchanged.

Actions: toggle-app, clipboard-history, launcher, screenshot-area,
screenshot-last-region, screenshot-pin, resize-current, recent-projects.

## Owned files
- nix/modules/home/gui.nix (helpers: flameshot-area :89, vicinae-resize :136, vicinae-toggle-app :181, vicinae-focus-tracker :201, vscode-recent-projects :228)
- nix/modules/home/scripts/{vicinae-resize,vicinae-toggle-app,vicinae-focus-tracker}.sh
- nix/modules/home/gnome-keybindings.nix (only if bindings move behind the spec)

## Findings
- VERIFIED: helpers call `org.gnome.Shell` `/org/gnome/Shell/Extensions/Windows` (List, Activate, Minimize, GetFocusedWindowSync, MoveResize) and `org.gnome.Mutter.DisplayConfig`.
- VERIFIED: the focus tracker polls every 0.25 s (`nix/modules/home/scripts/vicinae-focus-tracker.sh:9,24`) as a user service (`gui.nix:452-465`).
- VERIFIED (niri docs): `WindowFocusTimestampChanged` exists since niri v25.11 (not 26.04), so on niri the poller can be replaced by the event stream.
- PARTLY: niri releases up to v26.04 have no minimise or scratchpad. Scratchpad PR #2807 was closed on 16 Nov 2025 over contribution policy, not design; PR #4363 (minimize requests) and draft #2997 (hidden workspaces) are still open. No maintainer refusal is claimed.

## Required semantics
Mandatory portable contract: launch-or-focus-MRU.
- Not running: launch.
- Running: focus the most recently used window.

Backend capability (not portable): hide-if-focused, the same key restores. GNOME keeps minimise exactly as today. Whether niri gets hide (for example a stash workspace) is an open design decision, not a requirement; opinion estimate: emulating it robustly adds 2-4 days.
- Bilingual: the same physical key works under us and ru. GNOME needs Cyrillic twins (`<key>-cyr`), but they exist only for bindings that declare `cyrillic`; Super+E Nautilus (`gnome-keybindings.nix:107-113`) has none, so decide whether the spec covers it. niri binding semantics for this: UNVERIFIED.

## Acceptance criteria
- GNOME behaviour unchanged: existing tests pass, plus a manual check of every binding listed in R5 of the audit.
- Two VS Code windows keep MRU order.
- All application toggles launch or focus the most-recent window. Hide and restore are required only for backends that explicitly implement those capabilities. GNOME must retain its existing behaviour.
- niri backend passes the same checklist under that criterion (needs the T-0032 session; T-0032 in turn needs this niri backend only for parity sign-off, so there is no hard cycle: spec and GNOME refactor first, niri backend after the T-0032 session exists).

## Open checks
- Whether niri gets a hide emulation, and Cyrillic binding behaviour: UNVERIFIED.
