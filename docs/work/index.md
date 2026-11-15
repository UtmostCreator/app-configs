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

Read [project interaction](../shared/overview/project-interaction.md) before working on a ticket that crosses repositories.

Time-boxed: tickets, plans, investigations. Nothing here is a source of truth about
how the system works - that is [`../shared/`](../shared/index.md). When a ticket
closes, move its directory from [`active/`](active/README.md) to
[`archive/<YYYY>/`](archive/README.md); never delete it.

| Ticket | Status | Opened |
|---|---|---|
| [T-0001: Audit remediation program (umbrella)](active/T-0001-audit-remediation/ticket.md) | open | 2026-11 |
| [T-0009: install.sh safety and preflight](active/T-0009-install-safety/ticket.md) | open | 2026-11 |
| [T-0010: update-all lifecycle, locking and rollback](active/T-0010-update-lifecycle/ticket.md) | open | 2026-11 |
| [T-0011: update-* helper libraries (P1)](active/T-0011-update-libs/ticket.md) | open | 2026-11 |
| [T-0020: mise.toml task safety](active/T-0020-mise-tasks/ticket.md) | open | 2026-11 |
| [T-0025: failure-prevention registry (feature)](active/T-0025-failure-prevention-registry/ticket.md) | open | 2026-11 |
| [T-0026: repo-guardian agent draft (inactive)](active/T-0026-repo-guardian-agent-draft/ticket.md) | open | 2026-11 |
| [T-0034: WSL2 before/after state snapshot and backup runbook (feature)](active/T-0034-wsl-before-after-snapshot/ticket.md) | open (superseded by T-0047: before/after reports in bootstrap.ps1 -Report) | 2026-11 |
| [T-0035: sys-readiness must not print ALL SET while TODO items remain (bug)](active/T-0035-readiness-todo-verdict/ticket.md) | open | 2026-11 |
| [T-0036: WSL open/BROWSER in zsh and the bash fallback (bug)](active/T-0036-wsl-open-zsh-bash/ticket.md) | open | 2026-11 |
| [T-0037: VS Code on WSL2: report a missing `code`, skip the extension installer (bug)](active/T-0037-vscode-on-wsl/ticket.md) | open | 2026-11 |
| [T-0038: Colima darwin-only; confirm the Docker Compose plugin (bug)](active/T-0038-colima-darwin-only/ticket.md) | open | 2026-11 |
| [T-0039: Refresh the WSL2 docs (docs)](active/T-0039-wsl-docs-refresh/ticket.md) | open (folded into T-0047) | 2026-11 |
| [T-0040: Real WSL2 host acceptance pass (human verification)](active/T-0040-wsl-real-host-pass/ticket.md) | open (acceptance = T-0047 Slice 4) | 2026-11 |
| [T-0041: Windows-side copy-only app list (docs)](active/T-0041-windows-app-list/ticket.md) | open (approved 2026-11-14: documentation only) | 2026-11 |
| [T-0042: Install selection: committed profiles, a local per-host selection, first-run choice (feature)](active/T-0042-install-selection/ticket.md) | open (T1–T8 on main; four human checks pending) | 2026-11-14 |
| [T-0043: sys-update --selection-diff: a read-only diff of the selection, and the applied-state record (feature)](active/T-0043-selection-diff/ticket.md) | open (T1-T7 implemented on feat/selection-diff; macOS and a real apply unverified) | 2026-11 |
| [T-0044: Remember linux-desktop versus linux-cli per machine (feature)](active/T-0044-remember-linux-host/ticket.md) | open (T1-T4 implemented on feat/remember-linux-host, not landed; pending human checks: real headless Linux sys-install, macOS bash 3.2 dry run) | 2026-11 |
| [T-0045: WSL: systemd requirement and codebase-memory-mcp units (bug)](active/T-0045-wsl-systemd-cbm/ticket.md) | open | 2026-11 |
| [T-0046: macOS first-run readiness: blockers, fixes and a real-Mac verification order (bug)](active/T-0046-macos-first-run-readiness/ticket.md) | open | 2026-11 |
| [T-0047: WSL2 on NixOS-WSL, desktop-first (feature)](active/T-0047-nixos-wsl/ticket.md) | open | 2026-11-15 |
| [T-0048: Cross-OS settings inventory, baseline and per-host overrides (feature)](active/T-0048-cross-os-settings/ticket.md) | open (phase 1: Windows inventory) | 2026-11-15 |
| [T-0050: Always show user feedback during waits (bug + rule)](active/T-0050-user-feedback-during-waits/ticket.md) | open | 2026-11-15 |

Archived tickets: see [archive/](archive/README.md).
