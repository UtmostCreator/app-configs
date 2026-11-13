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
| macOS validation | The full system evaluates on Linux (`nix eval ./nix#darwinConfigurations.macos.config.system.build.toplevel.drvPath`, 2026-11-13). Not built or switched: `darwin-rebuild check/switch` needs a Mac. Untested there: the moved default-browser activation script, the new casks (`grandperspective` needs macOS 14+, `nimble-commander`, `localsend`), and the GitHub SSH rewrite against real Keychain/Homebrew Git. | On the Mac: `darwin-rebuild check --flake ./nix#macos`, then `switch`, then `sys-readiness`; confirm `git config --get-all credential.helper` prints only an empty value. |
| WSL validation | `nix build ./nix#homeConfigurations.wsl.activationPackage` builds (checked 2026-11-13 on x86_64-linux), and the first-install dry run, host detection and seeding are covered by `tests/bash/bootstrap-safety.bats`. Not verified on a real WSL host: activation, systemd user timers, `ops/wsl-check.sh` against a real `/proc` and Windows PATH, and `clipcopy` through a real `clip.exe` (UTF-16LE conversion is tested with stubs only). | On the next WSL host, follow `docs/platforms/wsl/setup.md`, run `sys-readiness`, and copy non-ASCII text in tmux. |
| GitHub SSH rewrite on first run | `url."git@github.com:".insteadOf https://github.com/` (dot_gitconfig.tmpl) sends every GitHub Git operation over SSH. Background timers only download over HTTP and are unaffected; mise installs nothing by Git. lazy.nvim's first plugin install and `sys-update`'s `git pull` on an HTTPS clone need a GitHub-registered SSH key. | Add the SSH key to GitHub before the first `nvim` launch or `sys-update` on a new host (`docs/platforms/wsl/setup.md`). |
| macOS/WSL CLI parity | Not measurable yet: readiness checks presence, not versions or behaviour across hosts. | Build `sys-parity` (shared inventory, version comparison, functional smoke tests) as a separate change. |

## Refactor audit

| Item | Current evidence | Next action |
| --- | --- | --- |
| OpenCode OTEL event handler | RestSift ranked `home/dot_config/opencode/plugins/otel-tracing.ts` at priority 69 because `event@178-260` combines session-idle and completed-message handling. Duplication remained 0%. | Extract the two event paths into focused helpers in a separate behavior-preserving change with plugin tests or captured event fixtures. |
