# T-0042 T5 results: sys-install --profile, --reconfigure, prompt, preview and write

Base 972422f, Nix 2.34.7, host linux-desktop (NixOS). Code: ops/lib/selection.sh (write, prompts, preview), ops/install.sh (flags and the "Selection" step), tests/bash/install-selection.bats (new, 71 tests after review round 1, counted with `bats --count`), stubs and TSV states under tests/bash/fixtures/selection/{stubs,state}.

## Step 0: follow-ups from the T4 review

- R1: `shell = "bash -c -o errexit"` on `sync:dry-run` and `sync:apply` in mise.toml. `MISE_TRUSTED_CONFIG_PATHS=$PWD mise tasks ls --json` reports that shell for both tasks (never `mise trust`). tests/bash/single-owner.bats asserts both declare a bash shell (it failed before the edit).
- R2: `pct='%'; p="${p//"$pct"/%25}"` in selection_url_path; the directory-with-`?#%` tests still pass (selection.bats and hm-switch.bats).
- C1: the comment now says only space, `?`, `#` and `%` are encoded and the printed form is not guaranteed safe to paste.

## Behaviour (what the code does)

| situation | result |
| --- | --- |
| `--reconfigure`, no TTY | exit 1 before the first step, nothing run or written |
| `--profile NAME` | NAME checked against nix/profiles/*.toml first (unknown: exit 2, nothing run); then evaluate, preview, write `profile = "NAME"` only, continue; never asks, also on a TTY; a failing preview stops the install; an invalid current file is reported and compared with the committed default, so `--profile` repairs it |
| local file, no flags | one line `Selection: <path> (profile X)`, no prompt, no preview; `selection_validate` evaluates it (unknown key, group or profile fails with the Nix error) before chezmoi or the switch |
| no file, TTY | present-state table, profile prompt (default = the host profile), group prompts from the profile defaults, preview, `[a]pply [c]hange selection [q]uit`; `a` writes deltas through selection_write, `c` re-prompts pre-filled, empty answer asks again |
| quit or EOF at any selection prompt | exit 1; message says no selection saved, no dotfiles applied, no switch run, and that Nix and the base tools from earlier steps remain (a dry run says nothing was changed) |
| no file, no TTY | writes nothing, committed default; a dry run prints the present-state and pending blocks, and a failed evaluation there is a note, not an error |
| `--dry-run` | prompts and previews as above; `a` prints `dry run: would write <path>`; nothing written or applied; no nix: `preview unavailable: nix not installed` |
| `--reconfigure`, TTY | prompts pre-selected from the current effective values; an invalid file is shown and the host default is used |

Prompts go to stderr, the preview to stdout. selection.sh never reads the terminal: install.sh defines `selection_read` (the hm-switch.bats guard "no prompt can run in hm-switch.sh or selection.sh" matches any `read ` word, so selection.sh also parses with mapfile and awk).

## The preview is evaluation only

- Commands run: `nix eval --option allow-import-from-derivation false --raw <flake>#<attr> [--override-input ...] --apply <expr>`; `nix-store -q --references` (through the existing nix_toplevel_packages); `chezmoi --source=<repo> status --no-tty </dev/null`; `brew list --cask -1` (macOS). No build, no result link, no download.
- States: I = installed generation (selection_hm_profile mirrors update-all.sh:133-141; packages by nix_toplevel_packages, files from `<gen>/home-files` symlinks); C = the checkout with the current selection; P = the same eval with `--override-input selection path:<temp dir>` built by the same selection_override_args as the real one. Membership is one extendModules eval with groups and profile forced (committed default, never the local file).
- Package rows reuse nix_packages_from_paths, package_delta and render_package_delta; the noise list is `dummy-xdg-mime-dirs`.
- All evaluations finish into temp files before the first line is printed; a failure prints the Nix error and exits 1 with no section printed.
- update-version-report.sh (and update-facts.sh) are sourced inside selection_facts, so hm-switch.sh, bootstrap.sh and audit.sh never load the preview code (tested).
- Temp dirs: one `mktemp -d` registered in install.sh's CLEANUP trap.

## Real read-only runs on this host (T5.4)

`install.sh --dry-run` was read-only here: every mutating step goes through `run`, which prints "would run" in a dry run, and the selection step only reads. Run from this worktree with `APP_CONFIGS_SELECTION_DIR` in a scratch dir, stdin closed or a pty from script(1), real HOME.

- `bash ops/install.sh --dry-run --profile work </dev/null`: rc 0, about 50 s. Installed generation 148 packages; outcome `personal apps remove 7: openclaw sync-open sync-start sync-stop syncthing telegram-desktop vesktop`, go/media/security keep; packages from your selection `- 7 removed (141 unchanged)`; pending repo changes `no package changes (148 unchanged)`; files removed: syncthing and openclaw-gateway units (user unit) and .openclaw/openclaw.json; pending files added: repo-audit.service/.timer (user unit); chezmoi `unavailable (chezmoi: template: .chezmoiignore:25:44 ... map has no entry for key "hostProfile")` because this worktree has no personal.yaml, and the preview still succeeded; `dry run: would write <scratch>/sel/selection.toml`.
- TTY flow under script(1) with `--dry-run` and answers `personal`, default, `n`, default, `q`: present-state table printed first (go 12/12, media 4/4, security 2/2, personal apps 7/7), prompts, preview (`media remove 4: ffmpeg imagemagick viu yt-dlp`, versions 9.0.2, 7.1.2-35, 1.6.1, 2026.10.26), then `cancelled at the selection step (dry run): nothing was changed`, rc 1.
- `--dry-run` with an existing file (`work`, `media = false`): one `Selection:` line, then the no-change view. I to C shows 11 removed packages: the file is not applied yet, so its effect appears under "pending", which is what I to C means.
- macOS expressions evaluated from this Linux host (no builder): state eval (`darwinConfigurations.macos.config`: 24 casks, 105 packages, 3 groups), members eval and the validation eval all rc 0.
- Afterwards: nix/flake.lock sha256 44847d34cfeb9d8e119e22934bcf8a12d97bc3b3187cd4c09088c4c15a61ceee (unchanged), no `result` link, `git status` clean, no selection file under ~/.config/app-configs (it holds only ssh-agent.sh), scratch TMPDIR holds no leftover temp dirs.

## Acceptance criteria and tests (tests/bash/install-selection.bats)

| AC | tests |
| --- | --- |
| AC6 | "AC6: --reconfigure without a TTY exits 1 before any mutation and writes nothing"; "AC6: --reconfigure --dry-run without a TTY also exits 1"; "AC6: --dry-run without a TTY and without a local file prompts for nothing, writes nothing, uses the default"; "AC6: --dry-run with a local file: SELECTION_ARGS carries the override and nothing is asked"; "a plain apply without a local file or a TTY writes nothing, never blocks and uses the committed default" |
| AC7 | "AC7: --profile writes only profile, previews and continues without asking"; "AC7: --profile drops the group overrides and the preview says they are replaced"; "AC7: --profile on a TTY asks nothing either"; "AC7: the preview lists additions and removals with versions"; "AC7: a second run with the file present asks nothing"; the AC7f writes-only-deltas tests |
| AC7a | "AC7a: package rows compare installed with proposed, split into your selection and pending repo changes" |
| AC7b | three tests "AC7b: Home Manager files and units ..." (removed and changed with unit annotation, added, pending separate) |
| AC7c | "AC7c: the chezmoi section shows counts and at most 20 paths, no diff"; "AC7c: a failing chezmoi status prints unavailable and the preview still succeeds" |
| AC7d | "AC7d: macOS casks ..." (exact stays-installed text, add marked, unmanaged only counted); "AC7d: macOS without brew says cask state unknown"; "AC7d: Linux prints no cask section and never calls brew" |
| AC7e | "AC7e: the present-state table prints before the first prompt ..."; "AC7e: on a first install the table shows 0/m and annotates what is on PATH ..." |
| AC7f | "AC7f: a on a TTY writes only the deltas ..."; "all defaults ..."; "c returns to the prompts with the current answers pre-filled"; "an empty answer at the a/c/q prompt asks again"; "q writes nothing, runs no chezmoi and no switch, and says what was not done"; "q at the profile prompt"; "EOF at a prompt"; "EOF at the a/c/q prompt"; dry-run a and q |
| AC7g | "--dry-run and --profile without a TTY never prompt" (AC6 and AC7 tests); "AC7g: nothing but install.sh and selection.sh calls the preview, prompt or write functions"; "AC7g: seeded: a call from update-all.sh, bootstrap.sh or hm-switch.sh is caught"; "AC7g: sourcing selection.sh does not load the preview code" |
| AC7h | "AC7h: the preview runs only nix eval with IFD off, nix-store -q, chezmoi status and brew list" (allowlist over the call log, flake.lock sha, macOS and Linux); "AC7h: no result link, no selection file and no temp dir is left behind"; "AC7h: a real apply leaves no temp dir either" |
| AC7i | "AC7i: an invalid selection exits 1, names the key, prints no preview section and writes nothing"; "AC7i: a proposed selection that cannot be evaluated prints no section and writes nothing" |
| AC7j | "AC7j: with no Home Manager profile the first-install header shows ..."; "AC7j: an unreadable installed generation prints unknown and the selection comparison still prints" |
| AC7k | "AC7k: a version change of a kept package shows as upgraded under pending repo changes" |
| AC7l | "AC7l: comparing an identical configuration shows no package changes, the noise list applied" |
| existing file | "a plain apply with a local file prints one line, asks nothing and prints no preview"; "... validates it before chezmoi and the switch"; "a plain apply with an invalid local file fails before chezmoi and the switch, naming the key" |
| space in dir | "a selection directory with a space works end to end: write, then the switch arguments" |
| other | selection_write (deltas, refusals), selection_hm_profile, `--profile` unknown/invalid-file/failing preview, a dry run that survives an unevaluable default, nix missing |

New tests against the tree before T5 (the test commit 534e520, ops files as at T4, run from a `git archive` copy): 62 tests, 59 fail and 3 pass. The 3 that pass hold before the feature: "AC6: --dry-run with a local file" (T4 behaviour), "AC7g: seeded ..." and "AC7g: sourcing selection.sh does not load the preview code" (guards for a property T5 must keep).

## Review round 1 (FAIL on three major findings), fixes

- F1 (the key was never shown): `_sel_show_err` kept the first 30 lines of a Nix error; it now drops `warning:` lines and keeps the last 25. The stub's errors are realistic now (warnings, 45 trace frames, the message last), so "the Nix error shown for an invalid selection is the end of a long error" and the earlier "naming the key" tests fail on the old code. Against the real flake, selection.bats "selection_validate rejects each invalid fixture and shows the line that names the key" covers unknown-group, unknown-profile, groups-without-profile, typo-profile-key and bare-group-key; that test passes on the old code too, because here Nix's trace is shorter than in the review, so the stub test is the one that pins the tail. The earlier claim "exit 1 with the key named" rested on one-line stub errors and is replaced by these.
- F2 (bash 3.2 on a fresh Mac): `_sel_split` (parameter expansion, no mapfile, no read) replaces every mapfile; empty arrays use `${a[@]+"${a[@]}"}`; `$'..'` is no longer used inside `${..}` (`_SEL_TAB`, `_SEL_NL`). portable-bash.bats bans the bash 4 features in install.sh and selection.sh and runs the library with `enable -n mapfile readarray`; install-selection.bats runs --profile, the macOS prompt path and a plain run with mapfile and readarray disabled through BASH_ENV. The hm-switch.bats guard (no `read ` word in selection.sh) is unchanged and still passes: the line splitter does not use read. Not possible here: a real bash 3.2 (the empty-array rule is audited by hand and by the static ban, not run).
- F3 (wrong-type group passed validation): the check expressions are `m: builtins.deepSeq m.groups m.profile` (and the darwin form). New fixture wrong-type-group (`media = "no"`); selection.bats "selection_validate rejects a group of the wrong type and names the option" (real Nix, names `myConfig.groups.media`); "the preview's state, members and check expressions evaluate against the real flake (linux-cli and macos)" catches drift in the expression strings. The earlier claim "validates before chezmoi" held only for the stub; the real-Nix tests above now back the validation itself, and the stubbed order test still pins that the validation runs before chezmoi.
- N1 empty `--profile` value: exit 2 (test). N2: dry-run `a` prints that the real run passes `--override-input selection path:<dir>`. N3: the labels are "pending changes (repo, or a selection not yet applied)" for packages and files; chezmoi keeps "pending repo changes". N4: on a first install "Packages, from your selection" says nothing is installed yet instead of listing removals. N5: the cancel message says what earlier steps did (Nix, base tools, preflight seeding of personal.yaml) remains. N6: `selection_profile_of` reads single quotes and prints `default` for an empty file.
- Real runs after the fixes: `install.sh --dry-run` with the unknown-group file and with the `media = "no"` file both exit 1 and show `unknown group 'bogus'` and ``option `myConfig.groups.media' is not of type `boolean'``; `--dry-run --profile work` and the macOS prompt path (HOST_PROFILE=macos, a pty) pass with mapfile and readarray disabled.

## Checks run

| command | scope | result |
| --- | --- | --- |
| bats tests/bash/install-selection.bats | new suite | 62 tests pass (before review round 1; 71 after it, from `bats --count`) |
| bash ops/run-bats.sh | full suite | 1250 tests, rc 0 (first full run: 5 failures, see below) |
| bash ops/lint-shell.sh | bash -n 113 files, shellcheck 25 files | no findings |
| bash ops/validate-config.sh, and --eval | text and evaluated policy, 4 hosts | all invariants pass |
| nix flake check ./nix | this system | rc 0 (aarch64-darwin omitted) |
| bash ops/ci-local.sh | validate-config, lint:shell, bats, flake check, all-systems check, linux activation build | all PASS |
| drvPaths of the 5 outputs vs evidence/t1-baseline.md | linux-desktop, linux-cli, wsl, macos home, darwin system | identical |
| nix/flake.lock sha256 | worktree | 44847d34cfeb9d8e119e22934bcf8a12d97bc3b3187cd4c09088c4c15a61ceee, unchanged |

The first full run (before commit eff1ed6) found five cross-suite failures, none visible from the new suite: bootstrap-safety "first install on macos/wsl" (a stub nix whose every eval fails turned an informational dry-run preview into exit 1; a dry run without a local file now treats a failed preview as a note), hm-switch.bats "no prompt can run in hm-switch.sh or selection.sh" (any `read ` word in selection.sh; reads moved to install.sh, parsing uses mapfile and awk), single-owner.bats rule 5 (the nix eval line must carry SELECTION_ARGS; `_sel_eval` now reads SELECTION_ARGS and `_sel_eval_for` swaps it for the committed or proposed selection), and test-hygiene (a mid-test `[ ] && [ ]` chain in the new suite).

Not run: any real switch, `sys-install` without --dry-run, `chezmoi apply`, `sys-update --apply`; a macOS or WSL host (the macOS expressions were evaluated from Linux and the cask logic is tested only against stubs); a real `brew list`.
