# Active follow-ups

This file contains only unresolved repository work. Completed migration history is
available in Git and is intentionally not duplicated here.

## Repository cleanup

| Item | Current evidence | Next action |
| --- | --- | --- |
| RestSift structural graph | `.vscode/mcp.json` is installed, but `res refactor audit . --refresh-graph` cannot run because `codebase-memory-mcp` is absent from `PATH`. The optional generated `.github` skill was intentionally not retained. | Install `codebase-memory-mcp`, allow this repository root, then rerun the graph-backed audit. |
| Legacy package audit helper | `repo-docs/install-dev-tools.sh` is used only by `ops/generate-package-matrix.sh` and still describes a zsh/Homebrew-era install flow. | Retire the helper and its validator dependencies in one focused change, or update it as a supported macOS fallback. |

## Product decisions

| Item | Current evidence | Next action |
| --- | --- | --- |
| Linux compositor | Both `migration-plan.md` (Niri) and `repo-docs/hyprland-migration-plan.md` remain active alternatives. | Choose Niri or Hyprland before changing the desktop architecture; then retire the rejected plan and comparison doc. |
| macOS validation | `darwin-rebuild check --flake ./nix#macos` requires a macOS host. | Run before production macOS use. |
| WSL validation | `home-manager switch --flake ./nix#wsl --dry-run` has not been rerun on a WSL host. | Run on the next supported WSL host. |

## Refactor audit

| Item | Current evidence | Next action |
| --- | --- | --- |
| OpenCode OTEL event handler | RestSift ranked `home/dot_config/opencode/plugins/otel-tracing.ts` at priority 69 because `event@178-260` combines session-idle and completed-message handling. Duplication remained 0%. | Extract the two event paths into focused helpers in a separate behavior-preserving change with plugin tests or captured event fixtures. |
