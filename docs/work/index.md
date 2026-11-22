<!-- glyphbrace: seeded once and yours to edit. Glyphbrace never rewrites or removes it. -->
---
documentation:
  schema_version: 1
  id: TPL-0039
  kind: template
  status: template
  summary: Work
  review:
    approval_ref: unknown
    summary_by: agent
---
# Work

**Niri migration cross-ticket status and installation choices:** [ADR-0046](../architecture/decisions/0046-niri-desktop-installation-decision-register.md) links T-0029–T-0033, existing shell/greeter decisions and the P0–P2 gaps. The ticket rows below retain their individual implementation status.

Read [project interaction](../shared/overview/project-interaction.md) before working on a ticket that crosses repositories.

Time-boxed: tickets, plans, investigations. Nothing here is a source of truth about
how the system works - that is [`../shared/`](../shared/index.md). When a ticket
closes, move its directory from [`active/`](active/README.md) to
[`archive/<YYYY>/`](archive/README.md); never delete it.

| Ticket | Status | Opened |
|---|---|---|
| [T-0001: Audit remediation program (umbrella)](active/T-0001-audit-remediation/ticket.md) | open (umbrella; open children T-0009, T-0010, T-0020, T-0025, T-0026; T-0011 archived 2026-11-21) | 2026-11 |
| [T-0009: install.sh safety and preflight](active/T-0009-install-safety/ticket.md) | in progress (most findings fixed on main; remaining: #7 hm-bak message naming the file, trusted-users audit, review) | 2026-11 |
| [T-0010: update-all lifecycle, locking and rollback](active/T-0010-update-lifecycle/ticket.md) | done, pending human (pre-deploy audit PASS 8cd1c92; owner: supervised live --apply + rollback on Linux; notes R4-02/03/05, R5-01..03 open) | 2026-11 |
| [T-0020: mise.toml task safety](active/T-0020-mise-tasks/ticket.md) | in progress (4 findings fixed 2026-11-21, 1 false positive; 8 open, see Progress) | 2026-11 |
| [T-0025: failure-prevention registry (feature)](active/T-0025-failure-prevention-registry/ticket.md) | not started (no registry, validator or skill on main) | 2026-11 |
| [T-0026: repo-guardian agent draft (inactive)](active/T-0026-repo-guardian-agent-draft/ticket.md) | blocked on T-0025 (draft only; never activated without owner approval) | 2026-11 |
| [T-0029: NixOS system ownership via nixosConfigurations (feature)](active/T-0029-nixos-system-ownership/ticket.md) | in progress (PC 2 pilot host linux-desktop-pilot on main 450e78e, 4c57049; PC 1 linux-desktop takeover not started, live gate needs owner) | 2026-11 |
| [T-0030: Validator allows NixOS programs.* and a niri config owner (feature)](active/T-0030-validator-nixos-programs-and-niri/ticket.md) | open, partly superseded (niri config owned by chezmoi 6fb82ee, rule 11 change unneeded; rule 6 scope change still needed) | 2026-11 |
| [T-0031: Compositor-neutral window actions (refactor)](active/T-0031-compositor-neutral-window-actions/ticket.md) | in progress (backend interface and GNOME backend on main dea74d4, 25d7ca8; remaining: niri backend, live checks) | 2026-11 |
| [T-0032: niri trial session, without the GNOME desktop (feature)](active/T-0032-niri-trial-session/ticket.md) | in progress (pilot session config and VM test on main 450e78e, 4c57049, 6fb82ee, 57b66fe; all real-session checks remain, PC 2 install needs owner) | 2026-11 |
| [T-0033: Refresh stale migration docs (docs)](active/T-0033-refresh-stale-migration-docs/ticket.md) | not started (stale statements still present in owned docs) | 2026-11 |
| [T-0035: sys-readiness must not print ALL SET while TODO items remain (bug)](active/T-0035-readiness-todo-verdict/ticket.md) | done (verdict exit 3 for remaining TODOs, 2026-11-21); archive after the next WSL run confirms it | 2026-11 |
| [T-0036: WSL open/BROWSER in zsh and the bash fallback (bug)](active/T-0036-wsl-open-zsh-bash/ticket.md) | not started (zsh and bash still lack the WSL BROWSER=wsl-open block) | 2026-11 |
| [T-0037: VS Code on WSL2: report a missing `code`, skip the extension installer (bug)](active/T-0037-vscode-on-wsl/ticket.md) | partly superseded by T-0047 (code check dropped); extension-installer skip on WSL still open | 2026-11 |
| [T-0038: Colima darwin-only; confirm the Docker Compose plugin (bug)](active/T-0038-colima-darwin-only/ticket.md) | done (colima macOS-only, ~/.colima ignored on Linux/WSL, compose ships with docker; 2026-11-21); archive | 2026-11 |
| [T-0040: Real WSL2 host acceptance pass (human verification)](active/T-0040-wsl-real-host-pass/ticket.md) | NixOS-WSL pass done via T-0047 Slice 4 (2026-11-16); Ubuntu real-distro pass still needs a person on Windows | 2026-11 |
| [T-0041: Windows-side copy-only app list (docs)](active/T-0041-windows-app-list/ticket.md) | not started (approved 2026-11-14, documentation only; apps.md not written, PowerToys/launcher question open) | 2026-11 |
| [T-0042: Install selection: committed profiles, a local per-host selection, first-run choice (feature)](active/T-0042-install-selection/ticket.md) | done, pending human (T1-T8 on main; real-Mac checks via T-0046; extension questions Q1-Q11 await owner, Q6 answered by T-0044) | 2026-11-14 |
| [T-0043: sys-update --selection-diff: a read-only diff of the selection, and the applied-state record (feature)](active/T-0043-selection-diff/ticket.md) | done, pending human (landed on main 572be3f..2639d0c; pending a macOS run, a real bash 3.2 install run, a real apply that writes the record) | 2026-11 |
| [T-0044: Remember linux-desktop versus linux-cli per machine (feature)](active/T-0044-remember-linux-host/ticket.md) | done, pending human (landed on main 17156d7..6ceea7b; pending a real headless Linux sys-install and a macOS bash 3.2 dry run) | 2026-11 |
| [T-0045: WSL: systemd requirement and codebase-memory-mcp units (bug)](active/T-0045-wsl-systemd-cbm/ticket.md) | in progress ((a) update-all systemd check fixed 2026-11-21; open: (c) preflight warn-or-fail and (d) keep-or-gate, both owner decisions) | 2026-11 |
| [T-0046: macOS first-run readiness: blockers, fixes and a real-Mac verification order (bug)](active/T-0046-macos-first-run-readiness/ticket.md) | in progress (fix 3 aerospace tap e9bc4fd landed; fixes 1, 2, 4, 5, 6 and AC-B/C open; no real-Mac run yet) | 2026-11 |
| [T-0047: WSL2 on NixOS-WSL, desktop-first (feature)](active/T-0047-nixos-wsl/ticket.md) | done, pending human (WSL verified at 531c4d8; owner: personal.yaml (b), Claude/Codex login, tailscale up, SKIP_HOOKS (d); (e) open). SHAs remapped to main after the 2026-11-18 rewrite; originals in backup-18-11-2026 | 2026-11-15 |
| [T-0048: Cross-OS settings inventory, baseline and per-host overrides (feature)](active/T-0048-cross-os-settings/ticket.md) | in progress (Windows and macOS inventories done; NixOS desktop capture, baseline, overrides and apply open) | 2026-11-15 |
| [T-0050: Always show user feedback during waits (bug + rule)](active/T-0050-user-feedback-during-waits/ticket.md) | in progress (rule, bootstrap heartbeat and install.sh waits done 4a3dd20, 0654c1e; bash audit table AC-4/9 open) | 2026-11-15 |
| [T-0051: Git hooks must work on Windows end to end (bug)](active/T-0051-windows-git-hooks/ticket.md) | done, pending human (F1/F3/F4 fixed on main e9549bf, db6caaf, 7c9a002, 3dada49; Windows checks AC-1,3,4,5 open; AC-3 now applies at push) | 2026-11-15 |
| [T-0052: Claude Code status line on native Windows (feature)](active/T-0052-windows-claude-statusline/ticket.md) | done, pending human (on main 5533fdc, 846f7dc; owner: T6 real run and H1 visual check in Windows Terminal; T3-T5 review open) | 2026-11-15 |
| [T-0055: Windows safe settings: snapshot first, profiles, telemetry, NVIDIA (feature)](active/T-0055-windows-safe-settings/ticket.md) | in progress (T1-T3 landed: ADRs 86ff52e, boundary checker 98d200d, catalogue ace86dd; T4 -WindowsSnapshot next; T5+ need Windows) | 2026-11-16 |
| [T-0056: Remove the DeepSeek harness and its remote access, for now (chore)](active/T-0056-remove-deepseek-harness/ticket.md) | done, pending human (removed on main e889726; live leftovers on the desktop: dsh-remote*, its unit, mise conf.d). SHAs remapped to main after the 2026-11-18 rewrite; originals in backup-18-11-2026 | 2026-11-16 |
| [T-0057: Enable Tailscale by default only on the personal desktop (feature)](active/T-0057-tailscale-desktop-only/ticket.md) | done, pending human (landed on main b1699c0; owner: sys-install --host linux-desktop (step 0) and work-host cleanup) | 2026-11-16 |
| [T-0058: Secret scan and workflow lint must not depend on local hooks alone (bug)](active/T-0058-push-secret-scan-and-workflow-lint-in-ci/ticket.md) | open (verified 2026-11-21 from an external audit; not started) | 2026-11-21 |
| [T-0059: OpenCode OTel plugin: verify against a live session, redact at the source (bug)](active/T-0059-opencode-otel-plugin-verification/ticket.md) | open (verified 2026-11-21 from an external audit; owner to decide keep or remove) | 2026-11-21 |
| [T-0060: GitHub date userscript blocks modifier and middle clicks on timestamps (bug)](active/T-0060-github-date-userscript-modifier-clicks/ticket.md) | open (verified 2026-11-21 from an external audit) | 2026-11-21 |
| [T-0061: Karabiner docs say Right Cmd, the config uses Left Cmd (docs)](active/T-0061-karabiner-left-cmd-docs/ticket.md) | open (verified 2026-11-21 from an external audit) | 2026-11-21 |
| [T-0062: Canonical project context pages are still unfilled templates (docs)](active/T-0062-fill-canonical-project-context/ticket.md) | open (verified 2026-11-21 with qmd and grep; not started) | 2026-11-21 |
| [T-0063: Install and bootstrap docs disagree on the first-run command (docs)](active/T-0063-unify-first-run-install-docs/ticket.md) | open (verified 2026-11-21; not started) | 2026-11-21 |

Archived tickets: see [archive/](archive/README.md).
