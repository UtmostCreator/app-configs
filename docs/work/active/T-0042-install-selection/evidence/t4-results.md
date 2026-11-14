# T-0042 T4 results: the selection reaches every host build, switch and eval

Base 972422f, Nix 2.34.7. Source of the arguments: ops/lib/selection.sh (the only file under ops that contains the override flag).

## Rules

- The directory is APP_CONFIGS_SELECTION_DIR (test override), else XDG_CONFIG_HOME or HOME/.config, then app-configs/selection.
- SELECTION_ARGS is `--override-input selection path:<absolute, symlink-resolved dir>` only when selection.toml exists in it; otherwise empty, and every command line is byte-identical to before (asserted by the "without a local file" tests).
- The path is made absolute inside selection_args, which runs as the user before any sudo.
- Expansion is `${SELECTION_ARGS[@]+"${SELECTION_ARGS[@]}"}`, safe under set -u on bash older than 4.4 (a test runs it under bash -u). The scripts already need bash 4 (mapfile), so macOS system bash 3.2 is not a supported interpreter for them.
- Validators, CI and flake check are not given the arguments: validate-config.sh, ci.sh, ci-local.sh, and the `nix flake check` in update-all.sh evaluate the committed default.
- Captured values keep `2>/dev/null`. The stderr lines "Updated input 'selection'" and "not writing modified lock file" are not matched by classify_warning (returns 1, so they are ignored); a test in update-facts.bats pins that. No classify entry was added.

## Call sites (line numbers at the T4 commit)

| site | handling |
| --- | --- |
| ops/lib/hm-switch.sh, pre-check nix build (hm_check_conflicts) | passes SELECTION_ARGS; the fix hint prints the override via selection_args_text |
| ops/lib/hm-switch.sh, hm_switch_raw switch | passes SELECTION_ARGS |
| ops/lib/hm-switch.sh, hm_switch_describe | prints the override, so dry-run output matches the real command |
| ops/install.sh, darwin-rebuild branch | passes SELECTION_ARGS after the switch arguments |
| ops/install.sh, nix run darwin-rebuild fallback | SELECTION_ARGS after the `--`, so darwin-rebuild receives it |
| ops/install.sh, Linux switch | through hm_switch and hm_switch_describe |
| ops/bootstrap.sh, SWITCH_CMD (darwin-rebuild, nix run fallback, home-manager), DRY_CMD (darwin nix build; Linux dry run reuses SWITCH_CMD) | all four carry SELECTION_ARGS; selection_args runs once before the branch, before sudo |
| ops/bootstrap.sh, real Linux switch | through hm_switch |
| ops/update-all.sh, host build and the print-out-paths build | both pass SELECTION_ARGS; selection_args runs in the host build step |
| ops/update-all.sh, darwin-rebuild switch | passes SELECTION_ARGS |
| ops/update-all.sh, Linux switch | through hm_switch_raw (calls selection_args itself) |
| ops/update-all.sh, nix flake check | deliberately without: committed default |
| ops/audit.sh, activationPackage outPath eval | passes SELECTION_ARGS; the not-built hint prints it |
| ops/update-codebase-memory-mcp.sh | through hm_switch (covered); reached by the weekly timer via nix/modules/home/scripts/codebase-memory-mcp-update.sh with --apply |
| ops/ci.sh, ops/validate-config.sh --eval, ops/ci-local.sh | deliberately without |

## Sites left outside the write boundary (reported, not edited)

These switch Home Manager or nix-darwin without the override. After a selection exists, running them applies the committed default and so reverts the selection until the next sys-update or install run.

| site | effect | covered by hm-switch.sh? |
| --- | --- | --- |
| mise.toml line 179, sync:apply on macOS: `darwin-rebuild switch --flake ./nix#macos` | switches without the selection | no |
| mise.toml line 185, sync:apply on Linux: `hm_switch ./nix "$HOST"` | carries the selection | yes |
| mise.toml line 112, sync:dry-run macOS: `darwin-rebuild check` | read-only preview of the default, not the selection | no (no mutation) |
| mise.toml line 119, sync:dry-run Linux: `home-manager switch --dry-run` | read-only preview of the default | no (no mutation) |
| home/dot_config/fish/conf.d/cli.fish line 92, function hms: `home-manager switch -b hm-bak --flake ...` | switches without the selection | no (interactive wrapper, listed in the single-owner allowlist) |
| ops/tailscale-setup.sh and ops/system-setup.sh nixos-rebuild | NixOS system layer, not Home Manager; the selection does not apply | not applicable |

Suggested follow-up (not done): hms and the macOS sync:apply line need the same arguments, or to call hm_switch_raw.

## Evidence

- AC5: tests/bash/selection.bats checks nix/flake.lock sha256 is identical across override evaluations; the worktree lock sha stayed 44847d34cfeb9d8e119e22934bcf8a12d97bc3b3187cd4c09088c4c15a61ceee through the full suite, ci-local and update-all report runs. The stubbed call-site tests never write the lock.
- AC8: tests/bash/single-owner.bats scans ops for host build, switch and eval lines (home-manager switch or build, darwin-rebuild, the pinned darwin-rebuild flake output, nix build or eval of a host output) and fails any that lacks SELECTION_ARGS. Seeded tests prove an added switch, build, eval and darwin-rebuild line is caught, that dropping the arguments from update-all.sh is caught, and that adding them is accepted. Another test requires each consumer to source selection.sh and that selection.sh is the only file with the override flag. During development the first version of the pattern could not see `nix#$BUILD_TARGET`; the seeded "dropping the arguments" test caught that and the pattern was corrected before commit.
- AC-N1: no prompt. hm-switch.sh and selection.sh contain no read; update-all.sh, hm-switch.sh and ci.sh contain no selection prompt, preview or write function; update-all ran to success with stdin closed and a selection present; install and bootstrap dry runs ran with stdin closed. T5 will add the prompt, only in install.
- Invalid selection: a real `nix build --dry-run` with the unknown-group fixture exits 1 with "selection.toml: unknown group 'bogus'". hm_switch stops before the switch when the pre-check build fails (stubbed test).
- Call-site tests (each with and without a local file): hm-switch.bats, install-preflight.bats (macOS both forms, Linux), bootstrap-safety.bats (Linux, macOS dry run), audit.bats, update-all-apply.bats. They were first run against the tree from before T4: the 11 "with a local selection" tests failed there and the 8 "unchanged" tests passed, so they do test the change. (The implementation was written before these tests in this task; the tests were then checked against the old tree.)

## Checks run

| command | result |
| --- | --- |
| bash ops/run-bats.sh (full suite) | 1180 tests, rc 0 |
| bash ops/lint-shell.sh | bash -n 113 files, shellcheck 25 files, no findings |
| bash ops/ci-local.sh | PASS: validate-config, lint:shell, bats, nix flake check, all-systems check, linux activation build |
| bash ops/update-all.sh (report mode, scratch worktree) | rc 0, nothing changed; with a selection directory the plan shows the host build with the override |
| nix flake lock sha, git status | unchanged and clean |

Not run: a real sys-update --apply, home-manager switch or darwin-rebuild (forbidden here); darwin-rebuild with the override on a Mac is still the AC14 human check. A selection directory whose path contains `?`, `#`, `%` or a space was not tested: path: URLs treat some of those specially. Behaviour is unknown.
