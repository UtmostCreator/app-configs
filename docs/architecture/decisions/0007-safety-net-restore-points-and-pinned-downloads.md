---
adr: 7
title: "Safety net: restore points, exports, pinned downloads, state reports"
status: decided
date: 2026-11-15
platforms: [windows, wsl]
areas: [safety, recovery]
permits: [restore-point, wsl-export, pinned-image]
forbids: [scripted-wsl-unregister, unpinned-download]
amends: []
supersedes: []
superseded_by: []
related: [T-0047]
---
# ADR-0007: Safety net: restore points, exports, pinned downloads, state reports
Status: decided (restore-point step observed on a real install 2026-11-15 with a pre-commit build of bootstrap.ps1; see [evidence](../../work/active/T-0047-nixos-wsl/evidence/h1-elevated-run-2026-11-15.md) and [expected results](../../platforms/wsl/expected-results.md) row 1) · Date: 2026-11-15 · Sources: T-0047 ticket (Recovery) and plan, docs/platforms/wsl/windows-and-wsl.md (Restore points)

## Decision
- A Windows restore point before installing WSL.
- `wsl --export` of NixOS before setup and before Docker; text before/after reports to compare state.
- On the desktop: back up /etc/nixos and prove it restorable before any apply.
- Three distinct recoveries: restore the /etc/nixos files, `nixos-rebuild switch --rollback`, `wsl --import` from an export.
- The NixOS-WSL image is pinned by SHA256. `wsl --unregister` is never scripted.

## Why
- Each failure class needs its own undo; none of them covers the others.
- The change touches the system layer (risk HIGH in the plan), so recovery is prepared first.
- A pinned hash makes a re-run reuse a verified download instead of trusting a new one.
- Re-runs never overwrite a backup: exports and reports are once per label.

## Strong alternatives
| Option | Why it lost |
|--------|-------------|
| Exports after install and after Docker, for comparison | Size, and the tars can hold keys and tokens. Text reports compare instead. |
| NixOS generations alone | Do not cover /etc/nixos file edits or Windows-side changes. |

## Discarded
Scripted `wsl --unregister` (a manual decision).

## Consequences
- Export tars are private and deleted by hand; keep them out of synced folders.
- A restore point needs admin and System Protection on C:, one per 24 hours by default.
- Revisit if exports prove too large or the before-report misses a state that matters.
