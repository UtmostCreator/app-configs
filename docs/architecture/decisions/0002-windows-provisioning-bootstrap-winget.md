# ADR-0002: Windows provisioning is one PowerShell bootstrap; winget is the only package manager
Status: decided (script built, not yet committed) · Date: 2026-11-15 · Sources: T-0047 ticket and plan, docs/platforms/base.md, `docs/work/active/T-0041-windows-app-list/ticket.md`, `docs/work/active/T-0042-install-selection/ticket.md` (lines 407, 530), `docs/plans/migration/implementation.md` (Appendix A)

## Decision
- One re-runnable script, ops/windows/bootstrap.ps1 (dry-run, stops for human steps; only the WSL install step is elevated).
- winget is the only Windows package manager. The script uses it automatically only for commit tooling (chezmoi, gitleaks, lefthook); app installs stay a manual list (T-0041).
- Reverses "Windows provisioning stays manual" (2026-05; Appendix A excludes PowerShell automation and Windows package managers).

## Why
- winget comes with Windows 11 (App Installer): no extra installer, install by exact id (T-0042).
- T-0042 judges it capable enough; the limits are UAC, scope and missing manifests, not a missing feature.
- Largest catalogue and installer hashes in manifests: session decision 2026-11-15, not stated in a repo file.
- The WSL install was re-derived by hand each time; fully manual lost on reproducibility.

## Strong alternatives
| Option | Why it lost |
|--------|-------------|
| Scoop | T-0042: "weak on proprietary apps", no gain over winget (marked unverified in the source). Also a second manager to bootstrap. |
| Chocolatey | T-0042: "needs admin and offers little over winget" (marked unverified in the source). |
| Fully manual (the 2026-05 decision) | Not reproducible; superseded by this ADR. |

## Discarded
Homebrew on Linux/WSL (a second manager next to Nix), a new app-selection menu on gum/fzf (the T-0042 install selection exists), running the whole bootstrap elevated.

## Consequences
- Contradiction to know: T-0041 discards "a repo-run windows/ layer (setup.ps1, doctor.ps1, DSC)" as an open-ended maintenance burden; the bootstrap partly reverses that. Keep it to WSL and commit tooling.
- Amended by ADR-0019: app-list automation and `winget configure` are not planned.
- Was open: automate the app list (`winget import` of a committed JSON) or keep it manual; `winget configure` (DSC) deferred "if the plain list proves insufficient". See ADR-0011.
- Commit-tooling step (T-0047 task T2) is not yet verified on the real PC.
- ADR-0016 amends "only for commit tooling" / "Keep it to WSL and commit tooling" with one opt-in step (Claude status line; jq via winget).
