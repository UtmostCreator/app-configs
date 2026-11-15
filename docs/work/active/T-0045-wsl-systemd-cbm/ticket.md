Source: local

# T-0045: WSL: systemd requirement and codebase-memory-mcp units (bug)

Status: open
Wave: 2
Depends on: none to start. T-0035 (exit 3) is useful for the readiness verdict.
Blocks: T-0039 (docs), T-0040 step 10
Order: sixth. Recommended implementation order for the WSL2 work: T-0035, T-0038, T-0037, T-0036, T-0034, T-0045 (Wave 2, not Wave 1), T-0039 (its wsl.conf fix may land first), T-0040 last. T-0045 must land before T-0040 step 10 (post-install checks). Full test order: T-0040.

Written 2026-11-15 against main ed39171 from a read-only research pass. Findings marked inferred or unknown are unproven.

## Summary
The `wsl` and `linux-cli` profiles enable systemd user units (the codebase-memory-mcp (CBM) UI, health check and updaters, the AI CLI updater and the weekly audit). They only run when systemd is PID 1, which on WSL2 is opt-in. Nothing before or after install detects systemd being off in a way that fails or reads as red, and sys-update's failed-unit check reports a false green. Add the guards and decide whether the CBM units stay on headless hosts.

## Owned files (write boundary)
- ops/update-all.sh (the failed-units check only)
- ops/readiness.sh (a CBM unit check and a WSL systemd TODO)
- ops/install.sh or ops/lib/preflight.sh (the systemd preflight, once the open question is decided)
- tests/bash for the above (extend the existing readiness, preflight and update-all suites; new cases only)
- docs/platforms/wsl/setup.md is owned by T-0039, not this ticket

## Findings
- VERIFIED: the CBM UI service, health service and timer (every 2 minutes), and the update service and weekly timer are all `lib.mkIf pkgs.stdenv.hostPlatform.isLinux` in `nix/modules/home/dev.nix` (around lines 206-290), so they are enabled on wsl and linux-cli. The UI is a loopback server on port 9749.
- VERIFIED: `nix/modules/home/ai-cli-updates.nix` (hourly) and `nix/modules/home/audit.nix` (weekly) are also enabled on wsl.
- VERIFIED: the CBM package supports x86_64-linux and aarch64-darwin only, so ARM WSL is out of scope.
- INFERRED: with systemd off, Home Manager activation probably prints "User systemd daemon not running. Skipping reload." and continues. Nothing in `ops/install.sh` or `ops/lib/preflight.sh` checks systemd. The only signal is the wsl-check TODO (around `ops/wsl-check.sh:24-30`), which sys-readiness shows only after install.
- VERIFIED: `ops/update-all.sh` (around lines 1497-1501) runs `systemctl --user list-units --state=failed ... 2>/dev/null`. With systemd off this prints "no failed units": a false green.
- VERIFIED: the CBM updater works on WSL only with systemd. It shares sys-update's lock, commits the release.json file (a dirty tracked file blocks sys-update), needs api.github.com, and its UI is the loopback server on 9749. `CBM_ALLOWED_ROOT` is `$HOME/Projects` (set in `nix/modules/home/dev.nix`), which may not exist on a fresh WSL home.
- VERIFIED: qmd and openclaw are not evaluated for wsl. They are linux-desktop only through `profileOverlays` in `nix/flake.nix` (around line 115). A nix-openclaw or qmd bump therefore changes only the lock for wsl (it still needs fetching when the lock resolves). A breakage surfaces in `nix flake check --all-systems` on the linux-desktop sentinel, not on wsl. The bumps that do affect wsl are nixpkgs, home-manager and nixpkgs-last-good (the semgrep overlay).
- UNKNOWN: whether the Determinate Nix installer on Linux works without systemd (it likely needs it).
- UNKNOWN: whether WSL tolerates trailing comments in /etc/wsl.conf (tracked in T-0039; verify on a real host).

## Decision / Options
- (a) sys-update's failed-units check first tests `systemctl --user is-system-running` and reports "systemd user manager not running" instead of printing a false green. Recommended; small and local.
- (b) sys-readiness flags an inactive or failed CBM UI unit on hosts where systemd is PID 1, and prints a TODO on WSL when systemd is off (the wsl-check TODO exists; confirm it reaches the verdict via T-0035).
- (c) An install preflight on wsl warns, or fails, before the Nix install when systemd is not PID 1. OPEN: warn or fail (see Open questions). Recommendation: fail on wsl with the fix text, because the Nix installer and every timer depend on it; unverified.
- (d) Whether the CBM UI, health and updater units stay on wsl and linux-cli or are gated off. OPEN. Recommendation: keep them and document them (T-0039); gating needs a separate Nix change and baseline re-record.
- (e) Docs: the systemd requirement and CBM guidance go into setup.md under T-0039.

## Acceptance criteria
- AC1 (failing test first): with systemd off (stubbed `systemctl is-system-running` failing or `/proc/1/comm` not systemd), the sys-update failed-units check reports "systemd user manager not running" and does not report "no failed units". With systemd on and no failed units, behaviour is unchanged.
- AC2: sys-readiness reports a CBM UI unit that is inactive or failed when systemd is PID 1, and a TODO on WSL when systemd is off.
- AC3: the install preflight on wsl reacts when systemd is not PID 1 (warn or fail, per the decision), before any Nix install step; non-wsl hosts are unaffected; the dry run prints the same warning without changing anything.
- AC4: the keep-or-gate decision for the CBM units is recorded here, with the docs follow-up handed to T-0039.
- AC5: new tests extend the existing suites; the relevant suites pass. A change to `ops/update-all.sh` or `ops/lib/*` runs the full `bats tests/bash` suite (AGENTS.md).
- Independent review PASS; one conventional commit per logical change; no AI attribution trailers.

## Plan
1. Reproduce the false green with a stubbed `systemctl` (test first).
2. Fix (a) in the update-all failed-units check.
3. Add (b) to readiness (after T-0035 so a TODO yields exit 3).
4. Decide (c) with the user, then add the preflight with its test.
5. Record (d); hand (e) to T-0039.

## Verification
- `bats tests/bash/readiness.bats tests/bash/ops-script-args.bats` plus the preflight and update-all suites.
- `bats tests/bash` (required for `ops/update-all.sh` and `ops/lib/*` changes).
- `bash ops/lint-shell.sh`; `bash ops/validate-config.sh`.
- Real host (T-0040 step 10): `systemctl --user list-timers`, `systemctl --user status codebase-memory-mcp-ui`, `curl 127.0.0.1:9749`.

## Open questions
- Warn or fail for the systemd preflight on wsl?
- Keep or gate the CBM units on headless hosts (wsl, linux-cli)?
- Does WSL tolerate trailing comments in /etc/wsl.conf? (verify on a real host)
- What does the Determinate Nix installer do without systemd?

## Out of scope / notes
- ARM WSL; qmd or openclaw on wsl; changing the CBM updater itself.
- Build-affecting changes (ops scripts) follow AGENTS.md: validate, then commit when safe.
- Only the files listed above. Unrelated findings are reported, not fixed.
