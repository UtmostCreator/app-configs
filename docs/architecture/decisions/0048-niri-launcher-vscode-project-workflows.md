---
adr: 48
title: "Niri launcher: feature-first Vicinae comparison and VS Code project-opening parity"
status: partly-decided
date: 2026-11-22
platforms: [linux, nixos]
areas: [desktop, launcher, vscode, clipboard, automation, window-management]
permits: [conditional-vicinae-trial, launcher-comparison, project-opening-evaluation]
forbids: [assumed-vicinae-superiority, duplicate-launcher-bindings, project-history-data-loss, unapproved-live-launcher-replacement]
amends: []
supersedes: []
superseded_by: []
related: [12, 13, 21, 26, 27, 45, 46, 47, T-0031, T-0032]
---
# ADR-0048: Niri launcher: feature-first Vicinae comparison and VS Code project-opening parity
Status: partly-decided (the existing Vicinae launcher stays for the current pilot to preserve workflows; permanent Niri launcher and clipboard-history provider are **not selected**) · Date: 2026-11-22 · Sources: ADR-0013/0027/0046/0047; `nix/modules/home/vicinae.nix`, `nix/modules/home/gui.nix`, [Vicinae features](https://github.com/vicinaehq/vicinae).

## Requirement, not an endorsement

The preferred launcher is the **strongest feature-rich, reliable, keyboard-driven tool for this Niri + development setup**, not necessarily the incumbent. **Vicinae is provisionally retained only to avoid losing existing commands while alternatives are assessed.** Permanent choice requires concrete advantages over competitors for window/project search, app launch, commands, extensions and clipboard. If another launcher is better overall, replace it **without losing VS Code recent project opening**.

**Non-negotiable workflow:** open or focus a **specific recent VS Code folder, saved `.code-workspace` or project** from a global keyboard shortcut; preserve the actual editor target, path and recent order; support a project already open in one of several Code windows; work from Niri and GNOME fallback while both are still installed. The project chooser can be a separate repo-owned script/plugin launched through *any* compliant frontend—it is not evidence that Vicinae is the only capable solution.

The repo already has **two different implementation surfaces**:
- `nix/modules/home/vicinae.nix` installs `programs.vicinae` via Home Manager, the `vscode-recents` extension, and a user service.
- `nix/modules/home/gui.nix` already defines a **`vscode-recent-projects`** command using VS Code's recent history and Vicinae `dmenu` as a frontend. The current Niri window backend remains unfinished ([T-0031](../../work/active/T-0031-compositor-neutral-window-actions/ticket.md)).
- Opening **recent VS Code projects** and **focusing an existing VS Code window** are separate actions. Test both; avoid a naïve launcher that opens a duplicate `code` instance for every click.

## Candidate comparison (paper research; all runtime scores unverified)

| Launcher | Strengths / why it might be better | Limitations / what must be added | VS Code project path |
|---|---|---|---|
| **[Vicinae](https://github.com/vicinaehq/vicinae)** | Rich unified launcher: app/file/window/workspace search, snippets, calculator, clipboard history, emoji, script commands, React/TypeScript and Raycast-compatible extensions; already pinned in repo, `vscode-recents` installed | Additional long-running service and extension state, possible GUI config drift; verify Niri window and clipboard protocols, history persistence and launcher responsiveness; risks duplicating shell's launcher | **Existing extension** and repo `vscode-recent-projects` dmenu script; prove exact window/project behaviour |
| **[Walker](https://github.com/abenz1267/walker) + [Elephant](https://github.com/abenz1267/elephant)** | **Strongest direct challenger** on documented scope: Elephant providers for apps, files, clipboard text/images, Niri windows/sessions, commands and other results; Walker provides the configurable UI | **Two components**, provider packages, user service and clipboard owner must be pinned/configured; reported clipboard/provider regressions require pinned-version test; VS Code *actual recent history* and exact project focus are not proven built-in | Reuse a launcher-neutral recent-project reader with Elephant custom menu/provider; test Niri window selection and already-open VS Code project focus |
| **[Albert](https://github.com/albertlauncher/albert)** | Mature extensible Qt launcher, native and Python plugins, well-developed search modes; possible custom project provider | Different extension API, no automatic Vicinae extension reuse; clipboard/window management/Wayland workflow needs testing; could add Qt stack | Project plugin calling the same shared history reader; not assumed built-in |
| **[Ulauncher](https://github.com/Ulauncher/Ulauncher)** | Established app search, keywords, Python extension ecosystem, file-browser mode; easy-to-write provider | Feature breadth in window switching/clipboard and advanced launch workflows may trail Vicinae; v6 plugin API currently subject to change | Python extension/keyword provider or script using shared project history |
| **[Rofi 2.x](https://github.com/davatorium/rofi)** / **[Fuzzel](https://codeberg.org/dnkl/fuzzel)** | Script-driven menu, small frontend; Rofi supports Wayland and dmenu/script modes; easy explicit ownership and recovery if main launcher fails | Not a like-for-like clipboard/snippets/window/extension suite; script integration is **custom work**; Rofi Wayland window capabilities depend on compositor | `vscode-recent-projects` adapted to emit dmenu rows and call `code` safely, separate Niri window-focus logic |
| **Selected shell launcher** (Dux/Noctalia/iNiR) | May eliminate a separate launcher UI/daemon, native window actions and integrated appearance | Constrained to chosen shell and its provider/plugin API; rich project search, clipboard, Raycast-style automation may be missing; coupling increases upgrade blast radius | Command/menu/script plugin reading shared VS Code history; **not assumed present** |

**Comparison confidence:** project descriptions and source APIs show **candidate capabilities**, not verified head-to-head performance or feature dominance. Do not award high scores merely for a long feature list or number of extensions. Plugin counts must be filtered for maintained/secure/needed functionality. Refer to the [shell criteria](0045-niri-windows-like-desktop-shell-ux.md) separately so the launcher does not re-evaluate the compositor.

## Non-negotiable VS Code/opening test matrix — P0

- [ ] Read VS Code's actual *Open Recent* files/folders/workspaces, with spaces, UTF-8/non-ASCII, symlinks and missing/stale paths handled. Test against known golden recent records; never invent a VS Code history JSON schema.
- [ ] Show the correct type (folder vs `.code-workspace`), full path, useful label and recency; optionally show Git branch and remote if available **without blocking** the picker.
- [ ] **Open target:** call an appropriately quoted `code` CLI with an explicit target; handle workspace files rather than treating them as directories, and preserve remote/URI entries where actually supported. Do **not** swallow launch failures.
- [ ] **Focus existing:** for three VS Code windows, choose the requested project and focus the matching window via **Niri native IPC**; if no matching window exists, open project once. Distinguish `code --reuse-window`, `--new-window` and Niri MRU requirements through tests; no guessed flags on existing windows.
- [ ] Keyboard invocation works in both English US and Russian layouts, including after shell restart, cold login and with several monitors/workspaces.
- [ ] No duplicate current-window launch, dead menu, arbitrary application execution from untrusted recent-project titles, or corrupted recent history. The repo-owned project-history adapter is read-only.
- [ ] The main launcher must meet required app search, file/command search, calculator, search latency, clipboard text/image history (if it owns it), Niri window search and extension/automation parity. Explicitly document intentional missing functionality rather than silently dropping features.
- [ ] No launch/control shortcut clashes with the desktop shell, no uncontrolled user service in GNOME/Niri, and no duplicate clipboard-history provider.

## Weighted decision rubric (100; verify before scoring)

| Category | Weight | Criterion |
|---|---:|---|
| VS Code and developer-project workflow | 25 | Recent folder/workspace/remote handling, preview, focus, MRU, zero duplicate windows |
| Feature completeness | 20 | Apps, files, snippets, calculator, search, clipboard, window switching, bookmarks/commands |
| Niri and multi-window integration | 15 | Native focus, Wayland clipboard protocols, correct session scope, keyboard layouts |
| Extension and automation ecosystem | 12 | Maintained plugins, TypeScript/Python scripts, extensibility and testability |
| Reliability and recovery | 10 | No hangs after logout/restart; stable clipboard/usage history; clean failure handling |
| Nix/chezmoi ownership, security | 10 | Pinned releases/plugins, predictable updates, minimal permissions, rollback |
| Resource cost and responsiveness | 5 | Measured memory/CPU and cold/warm launch latency |
| Community and documentation | 3 | Niri issues, relevant contributors, migration documentation |
| **Total** | **100** | No candidate has been scored yet |

**Decision rule:** all P0 tests must pass; score verified dimensions 0–100 with supporting source/trace, unverified = **unknown**, not 0. If a lean frontend requires a small **shared, repo-owned VS Code project picker** and preserves full parity, it is eligible to win; do not give Vicinae monopoly credit for its UI. Tie within 5 points: favour fewer overlapping services, better reproducibility and less workflow-specific custom code.

## Integration decision

- During the current Dux→Noctalia trial, **keep Vicinae running**, its extension available and its bindings functional **for continuity only**. This is not a future endorsement.
- **First** check if `vscode-recents` or the existing script can open exact recent projects under Niri. If it works, record its dependencies and do not rewrite it without reason.
- Then evaluate **Walker + Elephant, Albert, Ulauncher, Rofi** and the selected shell's launcher using the same test fixture and compare total retained functionality. Fuzzel is a low-overhead rescue frontend, not full-featured competitor.
- **Exactly one global shortcut owner for the active launcher**. A graphical shell Start menu may coexist if it does not own conflicting bindings; ensure one clipboard-history service, separate from the `wl-clipboard` CLI.
- If the strongest alternative wins, move the VS Code recent-project reader/focus logic into a **launcher-neutral adapter** and keep a thin UI-specific frontend. This work belongs in [T-0031](../../work/active/T-0031-compositor-neutral-window-actions/ticket.md) or a new scoped implementation ticket **after** selection.
- Do not automatically install a new launcher just to conduct a paper comparison, and do not remove Vicinae from GNOME fallback until its replacements have passed on that session if GNOME remains in use.

## Walker + Elephant evidence and comparative test plan (2026-11-22)

The current [Walker provider documentation](https://walkerlauncher.com/docs/providers) and [Elephant repository](https://github.com/abenz1267/elephant) document a **provider backend**, not just a single-process app launcher. Clipboard, files, commands, windows, Niri sessions and application search are meaningful competition for Vicinae. **This does not prove equivalence for VS Code project history**, extension ecosystem or reliability. The main experiment is **Vicinae vs Walker+Elephant**, with Ulauncher for project-specific plugins, Albert and Rofi as separate comparisons. Rofi/Fuzzel remain recovery options if a rich launcher fails.

| Required feature | Vicinae baseline | Walker + Elephant acceptance |
|---|---|---|
| VS Code recent folders / `.code-workspace` | Existing declarative `vscode-recents` extension and repo `vscode-recent-projects` | Implement **only a thin provider** over the same history reader, not a second parser; verify stale paths, remote URI, labels and order |
| Focus correct existing VS Code window | Test native Niri IPC and repo window-backend integration | Test Elephant Niri window provider IDs, exact project-to-window matching and MRU focus; no guessed project title as unique identifier |
| Clipboard text, images, pin/history | Vicinae history; record retention/privacy | Elephant Clipboard provider; separate session service and persistent history must work and not start beside Vicinae history |
| Files, actions, commands, calculator | Built-in/features/extensions | Provider set on **pinned version**, fail gracefully when providers are unavailable |
| Session lifecycle, service ownership | Vicinae HM user service | Walker UI + Elephant backend service; no second daemon without feature value; Niri-only scope |
| Developer extensions and search | Raycast-compatible ecosystem / installed project extension | Niri-aware provider and maintained scripts; validate actual plugins rather than counting them |
| Updates and security | Declarative Vicinae extension installation | Pin Elephant provider modules, assess command execution, access to clipboard/history, source downloads and controlled state |

**Failure/recovery gate:** Walker and Elephant must restart independently without losing results, locking clipboard queries or creating duplicate instances. Upstream has documented clipboard/provider issues (e.g. [Walker clipboard deadlock #748](https://github.com/abenz1267/walker/issues/748)); **recheck current status and reproduction against the pinned revision**, do not claim it persists or was fixed without evidence. Compare warm/cold latency and idle memory *for both processes together* versus the full Vicinae service and extensions.

**Project workflow test:** open a selected recent VS Code project, return to a different app and invoke the launcher again; focusing the same project must activate **the correct existing** Niri window, not merely any Code instance. For workspaces on different monitors, record focus destination and whether moving the window is intentional.

## Relationship to the main register

[ADR-0046](0046-niri-desktop-installation-decision-register.md) records launcher **G23** and clipboard **G06** as unresolved for the permanent Niri session. [ADR-0027](0027-launcher-clipboard-windows-input-macos-ux.md) retains separate Windows/macOS profile decisions; this ADR changes only the **Niri** launcher-selection policy, not Windows Raycast or macOS policies. [ADR-0047](0047-gnome-dependency-retirement-and-wayland-components.md) owns the GNOME component retirement rule.

**No launcher is newly selected or installed by this record.**
