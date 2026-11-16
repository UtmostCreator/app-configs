Source: local

# T-0057: Enable Tailscale by default only on the personal desktop (feature)

Status: open (implemented on a branch; not landed)
Relates to: ADR-0029, ADR-0004, ADR-0021, T-0029
Note: T-0054 is reserved by another session. T-0029 owns the NixOS system layer; coordinate before landing.

Written 2026-11-16 against main 1115175.

## Why
ADR-0029 records an owner decision (decided-unverified, 2026-11-16): work hosts get no Tailscale. Before this change `ops/system-setup.sh` defaulted `ENABLE_TAILSCALE` to 1 on every non-WSL host, so a NixOS linux-cli work host got Tailscale, and `ops/readiness.sh` reported a pending rebuild when tailscaled was inactive on any non-WSL host.

## Scope
- `ops/system-setup.sh`: `ENABLE_TAILSCALE` defaults to 1 only when `HOST_PROFILE=linux-desktop` (the pattern of `ENABLE_DESKTOP_STABILITY`). An explicit `ENABLE_TAILSCALE=1` still enables it anywhere; `=0` still disables it.
- `ops/readiness.sh`: the "tailscaled inactive" pending-rebuild check applies only on linux-desktop.
- `ops/tailscale-setup.sh` and the `tailscale:setup` mise task: manual opt-in, no behaviour change. Nothing runs it automatically (it appears only in `mise.toml` and the `ops/lint-shell.sh` file list).
- `docs/guides/tailscale-local-services.md`: personal-only, desktop default, how to opt in.

## Also fixed in this change
- Under `sudo`, HOME is root's, so `detect-host.sh` found no host file and defaulted to linux-desktop. `ops/system-setup.sh` now runs it with the invoking user's home (`SUDO_USER`, via `getent`). A host file under a custom XDG_CONFIG_HOME is not found under sudo and takes the rule below.
- Design decision (orchestrator, reversible): when the profile source is `default` (no host file, root or not), sys-setup PRESERVES Tailscale and desktop stability: neither added nor dropped, whatever the managed module has stays, in report and apply alike, with a note to run `sys-install --host <profile>`. An explicit `ENABLE_TAILSCALE` / `ENABLE_DESKTOP_STABILITY` still wins. `sys-readiness` prints a TODO to record the host instead of the tailscaled rebuild TODO.
- `ENABLE_TAILSCALE=0` now drops `services.tailscale.enable` from the managed module on the next run (it was reported "already present").
- Lingering (`users.users.<user>.linger`) was emitted only with Tailscale. It is now separate and emitted on every non-WSL host (an explicit `ENABLE_TAILSCALE=0` on a non-WSL host now emits it too), so linux-cli keeps its update timers and codebase-memory user units after logout (orchestrator decision, low impact, reversible).

## Acceptance criteria
1. `HOST_PROFILE=linux-desktop` report output is unchanged (golden `tests/bash/fixtures/system-setup-desktop-snippet.golden` untouched).
2. `HOST_PROFILE=linux-cli` report has no `services.tailscale.enable` by default, and has it with `ENABLE_TAILSCALE=1`.
3. `ENABLE_TAILSCALE=0` still skips it on linux-desktop.
4. readiness on linux-cli and wsl prints no Tailscale line; on linux-desktop it still asks for the daemon.
5. The guide states personal-only, the desktop default and the opt-in.

## Verification
- `bats tests/bash/readiness.bats tests/bash/system-setup.bats`, plus the suites that reference Tailscale, `doc-contracts`, `path-contract` and `adr-contract`.
- `shellcheck -x` on the touched scripts, `ops/validate-config.sh`, `git diff --check`.

## Owner steps
0. Personal desktop (it has no host file today): run `sys-install --host linux-desktop`, or confirm `bash ops/detect-host.sh --source` prints `file`, before the next `sudo sys-setup --apply`.

On an existing work host:
1. Run `sudo sys-setup --apply`: it drops the managed `services.tailscale.enable` entry and keeps linger.
2. A module written by `ops/tailscale-setup.sh` (`/etc/nixos/app-configs-tailscale*.nix` and its import) is not touched; remove both by hand, then rebuild.
3. Run `tailscale logout` and remove the device from the tailnet.

## Out of scope
- ADR-0029 status changes (owner or ADR author). Live removal of Tailscale from an existing work host.
