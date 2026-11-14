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

## Review round 1 fixes: the two sites outside the Owned files

The user's recorded decision is that every build and switch entry point gets the same selection, so the write boundary was widened for exactly: mise.toml (the sync:apply and sync:dry-run lines), the hms function in cli.fish, tests/bash/cli-abbr.bats (additive) and tests/bash/single-owner.bats.

| site | handling now |
| --- | --- |
| mise.toml sync:apply, macOS: darwin-rebuild switch | sources ops/lib/selection.sh, calls selection_args, appends the safe expansion |
| mise.toml sync:apply, Linux | through hm_switch (unchanged, covered) |
| mise.toml sync:dry-run, macOS darwin-rebuild check and Linux home-manager switch --dry-run | same args, so the preview matches what would apply |
| cli.fish hms | bash -c sources selection.sh when the file exists, adds the args before the caller's own arguments (for example --show-trace); without a selection the command line is identical to before; a checkout without selection.sh behaves as before |
| ops/tailscale-setup.sh, ops/system-setup.sh nixos-rebuild | NixOS system layer, selection does not apply |

mise runs task bodies with `sh -c` (mise setting unix_default_inline_shell_args). selection.sh was run under `bash --posix` and the system sh here (bash 5.3 in posix mode, which is also how macOS runs bash 3.2 as sh): selection_args and the safe expansion work, also under `set -eu` with an empty array. Plain dash is not supported by hm-switch.sh either (arrays, mapfile), so sync:apply already needed a bash-compatible sh.

Other review fixes:
- G1: the single-owner selection rule now scans the same file set as rule 1 (ops, scripts, home, nix, mise.toml), has no hms exemption, removes a message call and its quoted string before matching (so `cmd || fail "..."` is judged on cmd), and has seeded cases for the || fail form, home-manager -b x switch and nix build "$FLAKE#$TARGET". The real tree reports exactly the four sites above before the fix and none after.
- F2: selection_url_path percent-encodes % first, then space, ?, # in the path: URL. A real nix eval with --override-input on a directory named like `my sel?x#y%z` works (it failed with "invalid URI parameter" before). The printed form from selection_args_text is encoded too, so it has no raw space and can be pasted.
- H1: the five exact-command-line suites (hm-switch, install-preflight, bootstrap-safety, audit, update-all-apply) pin APP_CONFIGS_SELECTION_DIR to a nonexistent path in setup. Chosen over exporting it in ops/run-bats.sh and ci-local.sh because a plain `bats tests/bash/<file>` must be safe too, and run-bats.sh only isolates HOME. With a real selection file under an exported XDG_CONFIG_HOME, the old hm-switch and bootstrap-safety files fail (2 failures) and the pinned ones pass. audit.bats runs the script under env -i, which already drops the variable and XDG_CONFIG_HOME, so its pin is belt and braces.
- N2: the update-all-apply host-build failure stub now fails only when --override-input is present, and the test asserts the override was passed.
- N1 (report-mode switch line via hm_switch_describe): not done. ui_run prints the command words; showing the override there needs a label change in update-all.sh and was optional. The host build line in the plan does show the override.

## Evidence

- AC5: tests/bash/selection.bats checks nix/flake.lock sha256 is identical across override evaluations; the worktree lock sha stayed 44847d34cfeb9d8e119e22934bcf8a12d97bc3b3187cd4c09088c4c15a61ceee through the full suite, ci-local and update-all report runs. The stubbed call-site tests never write the lock.
- AC8: tests/bash/single-owner.bats scans ops for host build, switch and eval lines (home-manager switch or build, darwin-rebuild, the pinned darwin-rebuild flake output, nix build or eval of a host output) and fails any that lacks SELECTION_ARGS. Seeded tests prove an added switch, build, eval and darwin-rebuild line is caught, that dropping the arguments from update-all.sh is caught, and that adding them is accepted. Another test requires each consumer to source selection.sh and that selection.sh is the only file with the override flag. During development the first version of the pattern could not see `nix#$BUILD_TARGET`; the seeded "dropping the arguments" test caught that and the pattern was corrected before commit.
- AC-N1: no prompt. hm-switch.sh and selection.sh contain no read; update-all.sh, hm-switch.sh and ci.sh contain no selection prompt, preview or write function; update-all ran to success with stdin closed and a selection present; install and bootstrap dry runs ran with stdin closed. T5 will add the prompt, only in install.
- Invalid selection: a real `nix build --dry-run` with the unknown-group fixture exits 1 with "selection.toml: unknown group 'bogus'". hm_switch stops before the switch when the pre-check build fails (stubbed test).
- Call-site tests (each with and without a local file): hm-switch.bats, install-preflight.bats (macOS both forms, Linux), bootstrap-safety.bats (Linux, macOS dry run), audit.bats, update-all-apply.bats. They were first run against the tree from before T4: the 11 "with a local selection" tests failed there and the 8 "unchanged" tests passed, so they do test the change. (The implementation was written before these tests in this task; the tests were then checked against the old tree.)

## Checks run

| command | result |
| --- | --- |
| bash ops/run-bats.sh (full suite) | 1186 tests, rc 0 (round 1 fixes); 1180 before |
| bash ops/lint-shell.sh | bash -n 113 files, shellcheck 25 files, no findings |
| bash ops/ci-local.sh | PASS: validate-config, lint:shell, bats, nix flake check, all-systems check, linux activation build |
| bash ops/update-all.sh (report mode, scratch worktree) | rc 0, nothing changed; with a selection directory the plan shows the host build with the override |
| nix flake lock sha, git status | unchanged and clean |

Also after round 1: fish -n on cli.fish ok, mise tasks ls parses (MISE_TRUSTED_CONFIG_PATHS, no trust), ci-local PASS, default drvPaths identical to the T1 baseline, lock sha 44847d34... unchanged.

Not run: a real sys-update --apply, home-manager switch or darwin-rebuild (forbidden here); darwin-rebuild with the override on a Mac is still the AC14 human check.
