# Active follow-ups

This file contains only unresolved repository work. Completed migration history is
available in Git and is intentionally not duplicated here.

## Repository cleanup

| Item | Current evidence | Next action |
| --- | --- | --- |
| Legacy package audit helper | `repo-docs/install-dev-tools.sh` is used only by `ops/generate-package-matrix.sh` and still describes a zsh/Homebrew-era install flow. | Retire the helper and its validator dependencies in one focused change, or update it as a supported macOS fallback. |

## Product decisions

| Item | Current evidence | Next action |
| --- | --- | --- |
| Linux compositor | Both `docs/plans/migration/overview.md` (Niri) and `docs/plans/hyprland-migration.md` remain active alternatives. | Choose Niri or Hyprland before changing the desktop architecture; then retire the rejected plan and comparison doc. |
| macOS validation | `darwin-rebuild check --flake ./nix#macos` requires a macOS host. | Run before production macOS use. |
| WSL validation | `nix build ./nix#homeConfigurations.wsl.activationPackage` builds (checked 2026-11-13 on x86_64-linux). Activation on a real WSL host is still unverified. | On the next WSL host, follow `docs/platforms/wsl/setup.md` and run `sys-readiness` (includes `ops/wsl-check.sh`). |

## Refactor audit

| Item | Current evidence | Next action |
| --- | --- | --- |
| OpenCode OTEL event handler | RestSift ranked `home/dot_config/opencode/plugins/otel-tracing.ts` at priority 69 because `event@178-260` combines session-idle and completed-message handling. Duplication remained 0%. | Extract the two event paths into focused helpers in a separate behavior-preserving change with plugin tests or captured event fixtures. |
