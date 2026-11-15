# T-0042 T6-T8 results: docs, macInput and chezmoi gating, WSL2 check

Base 972422f, Nix 2.34.7, host linux-desktop (NixOS), chezmoi v2.70.3. Branch feat/install-selection.

## Step 0

evidence/t5-results.md said install-selection.bats has 77 tests. `bats --count tests/bash/install-selection.bats` gave 71 before this slice (73 now, after two new macOS/Linux prompt tests). The text now says 71, and the "62 tests pass" row says that was before review round 1.

## Design choices

1. macInput on non-macOS hosts. The option `myConfig.groups.macInput` exists on every host, so a selection file may set it anywhere and it is validated like any group (profile TOMLs list it, true in both). The preview code hides it where it has no effect: the state and members Nix expressions in ops/lib/selection.sh take a `mac` flag (false for Home Manager hosts, true for the darwin system) and drop `macInput` from the group names when it is false. So on Linux and WSL2 the present-state table, the prompts and the outcome list never show it; on macOS they do. A file with `macInput = false` on Linux is accepted and has no effect.
2. Darwin gating. nix/modules/darwin/homebrew.nix reads `config.home-manager.users.${vars.username}.myConfig.groups.macInput` and splices karabiner-elements and linearmouse with `lib.optionals` between betterdisplay and the next block, in the original order. No new input or option.
3. chezmoi file reading. Proved read-only: `include` accepts an absolute path outside the source dir, `stat` returns nil for a missing file, `env` reads variables, `fromToml` parses, `.chezmoi.sourceDir` is `<repo>/home` (honours .chezmoiroot), so the profile file is `<sourceDir>/../nix/profiles/<p>.toml`. Resolution (home/.chezmoiignore): local file `[groups] macInput` (boolean) else the profile file for the local file's `profile` (only `work` or `personal`, else the host default) else true. Host default: linux-desktop = personal, others = work. Directory: `APP_CONFIGS_SELECTION_DIR`, else `${XDG_CONFIG_HOME:-$HOME/.config}/app-configs/selection`. The rendered list carries a comment `# host default profile: X` which the parity test reads.
4. Missing or invalid local file. Missing, empty, missing key, non-boolean value, unknown profile name, missing profile file: all fall through and the render succeeds. The selection is read only on darwin, so a broken file can never affect a Linux or WSL2 `chezmoi apply`. A syntactically invalid TOML file on darwin DOES fail the render (chezmoi templates cannot catch a `fromToml` error). I chose a loud failure over silently deploying or skipping the wrong configs: install.sh and every Nix build already reject such a file earlier. This is a deviation from "must not break apply" for that one case; the alternative (a regex line scan) can misread tables.
5. WSL directory rule. `selection_dir` ignores an `XDG_CONFIG_HOME` that is `/mnt/<letter>` or below it, prints a note on stderr, and uses `$HOME/.config`. `/mnt/wsl/...` is not a drive and is honoured. `APP_CONFIGS_SELECTION_DIR` is taken as given (test and preview override). Not covered: `$HOME` itself under /mnt/c, and the chezmoi template does not apply the /mnt rule (WSL is non-darwin, so the template never reads the file there). The ticket states only "resolves under the Linux $HOME, not /mnt/c".
6. Linux LinearMouse. `.config/linearmouse` is now ignored on every non-darwin host (the user's decision). Existing os, gui and hostProfile rules are unchanged; `.config/karabiner` stays ignored on non-darwin and when gui is false.
7. Not done: the chezmoi section of the preview does not show selection-driven changes on macOS (it needs a second chezmoi run against a proposed selection; not cheap). It still shows the pending state via `chezmoi status`.

## Acceptance criteria and tests

| AC | tests |
| --- | --- |
| AC10 | docs only: install.md ("Choose what to install"), tool-ownership.md ("Install selection"); path-contract.bats and doc-contracts.bats pass |
| AC11 | selection.bats: "AC11: the macos Home Manager output is the same for no selection, an empty file and all groups on"; "AC11: darwinConfigurations.macos.system is the same for no selection, an empty file and all groups on"; "linux-desktop with an empty selection file is the same as no selection"; "AC11: macInput is on by default and gates exactly karabiner-elements and linearmouse, in place"; "macInput=false changes no Linux package set"; "the Home Manager macos output also reads macInput from the selection". The darwin system drvPath equals the T1 baseline (see below). |
| AC12 | chezmoiignore-selection.bats (18 tests): darwin on/off from the profile file and from the local file, local overrides profile both ways, profile-only local file, host default, non-darwin always ignored, Linux no longer deploys LinearMouse, missing/empty/wrong-shape/unknown-profile/missing-profile-file fall through, invalid TOML fails on darwin only, APP_CONFIGS_SELECTION_DIR and the XDG/HOME default, "AC-N3: the existing os, gui and host profile rules are unchanged", "AC12 parity: the template's host default profile equals myConfig.profile for every host" (nix eval, 4 hosts) |
| AC13 | install-selection.bats: "AC13: on macOS the prompt offers macInput, and n lists both input casks as staying installed" (exact hint text, stub brew), "AC13: on Linux the prompt never offers macInput" (weak with stubs; the real-Nix test below is the proof), existing AC7d tests; selection.bats "the preview's state, members and check expressions evaluate against the real flake" now expects 3 groups on linux-cli and 4 (with macInput) on macos and no macInput text on linux-cli. Docs say removed casks stay installed. |
| AC14 | human, not attempted (see Human checks) |
| AC15 | selection.bats: "AC15: the wsl profile evaluates with a non-default selection"; "AC15: selection_dir resolves under the Linux HOME"; "AC15: an XDG_CONFIG_HOME inside the Linux HOME is honoured"; "AC15: an XDG_CONFIG_HOME under /mnt/c is ignored, with a note on stderr"; "AC15: any drive letter and the bare mount point are treated as Windows paths"; "AC15: APP_CONFIGS_SELECTION_DIR stays an explicit override"; wsl/setup.md has a 2-line section pointing to install.md |

Tests were written first and failed against the tree before the implementation (selection.bats AC15 /mnt tests, macInput group tests; chezmoiignore-selection.bats 14 of 18 failed).

Suite sizes (`bats --count`): selection.bats 34, install-selection.bats 73, chezmoiignore-selection.bats 18, portable-bash.bats 6.

## Checks run

| command | scope | result |
| --- | --- | --- |
| bats chezmoiignore-selection.bats chezmoiignore-vscode.bats | 2 suites | 21 pass |
| bats tests/bash/selection.bats | new and changed | 34 pass (after the WSL change) |
| bats -f "AC13\|F2\|AC7d" install-selection.bats | changed tests | 8 pass |
| bats path-contract, doc-contracts, test-hygiene, portable-bash | 4 suites | pass |
| bash ops/run-bats.sh | full suite | 1296 tests, 0 failures, rc 0 |
| bash ops/lint-shell.sh | 113 files bash -n, 7 templates, 25 shellcheck | no findings |
| bash ops/validate-config.sh and --eval | text and evaluated, 4 hosts | all invariants pass |
| nix flake check ./nix | this system (includes treefmt-check) | rc 0 |
| nix flake check ./nix --all-systems --no-build | all systems | all checks passed |
| bash ops/ci-local.sh | validate-config, lint:shell, bats, flake check, all-systems check, linux activation build | all PASS, rc 0 |
| 5 drvPaths vs t1-baseline.md | linux-desktop, linux-cli, wsl, macos home, darwin system | all identical |
| nix/flake.lock sha256 | worktree | 44847d34cfeb9d8e119e22934bcf8a12d97bc3b3187cd4c09088c4c15a61ceee, unchanged |
| `install.sh --dry-run --profile work </dev/null` with a scratch APP_CONFIGS_SELECTION_DIR | real host | rc 0, preview printed, no macInput shown on Linux, nothing written, no result link, ~/.config/app-configs holds only ssh-agent.sh |
| chezmoi execute-template on the real worktree source (linux and darwin override data) | read-only | linux ignores both macOS input trees, darwin ignores neither, `# host default profile: work` |

Not run: any real switch, `chezmoi apply`, `sys-update --apply`; a real macOS, bash 3.2 or WSL2 host; real brew.

## Review round 1 follow-ups (final review: PASS WITH NOTES)

- S1: members data on darwin now carries `X<TAB>group<TAB>cask` lines (casks with the group on minus casks with it off, from the darwin system). The present-state row counts those casks against `brew list --cask -1` (one brew call per run), the prompt label lists them, the outcome row says `keep N`, `add ...` or `stays installed N: names` (a deselected cask stays installed). Without brew the row says `casks <names> (cask state unknown)`. Tests (install-selection.bats, "S1: ..." x5, written first and failing before) and a real-Nix check in selection.bats that macos has 2 X lines for macInput and linux-cli none.
- S2: profile.nix adds a module assertion `builtins.deepSeq config.myConfig.groups true`, so a wrong-typed group fails every host build. selection.bats "S2: ..." x2 (linux-cli, macos home and darwin system: message names `myConfig.groups.macInput`). All 5 default drvPaths, the empty and the all-on fixtures are unchanged (see checks).
- S3, S4: human checks below rewritten.
- S5, S7, D1-D4: install.md, tool-ownership.md and wsl/setup.md corrected (invalid files and the macOS chezmoi error text, macInput on Linux, wrong-type wording, personal apps on linux-desktop only, the PATH annotation only on a first install, the actual /mnt rule).
- S6: `selection_dir` is silent; `selection_args` prints the /mnt note once per process (a `$(selection_dir)` subshell cannot keep a flag). Tests "S6: ..." x2.
- S8: the template prints `# known profiles: ...`; two new parity tests (darwin Home Manager user's profile, and the list equals the files in nix/profiles).
- D5: the ticket Status line (only that line) and the index row list the four pending human checks.

Checks after these follow-ups: selection.bats and chezmoiignore-selection.bats 58 tests pass; the S1 and S6 tests failed before their fixes and S2 was confirmed failing on the previous tree (the wrong-type macInput build succeeded there); full `bash ops/run-bats.sh` 1307 ok, 0 failures; lint:shell, validate-config (text and --eval), both flake checks and `bash ops/ci-local.sh` (6 stages) pass; the 5 default drvPaths equal t1-baseline.md; lock sha256 44847d34cfeb9d8e119e22934bcf8a12d97bc3b3187cd4c09088c4c15a61ceee; a real `install.sh --dry-run --profile work </dev/null` with a scratch APP_CONFIGS_SELECTION_DIR passes (rc 0, no macInput on Linux, nothing written).

## Human checks

1. AC14, real Mac with Determinate Nix. THIS SWITCHES THE LIVE MAC. Rollback: re-run the switch without `--override-input`, or run `sudo darwin-rebuild --rollback`. In a clean checkout of feat/install-selection:
   ```
   git status --short                 # expect no output
   sha256sum nix/flake.lock           # expect 44847d34cfeb9d8e119e22934bcf8a12d97bc3b3187cd4c09088c4c15a61ceee
   mkdir -p /tmp/sel-check && printf 'profile = "work"\n\n[groups]\nmacInput = false\n' > /tmp/sel-check/selection.toml
   nix eval --json "./nix#darwinConfigurations.macos.config.homebrew.casks" --override-input selection path:/tmp/sel-check --apply 'cs: map (c: c.name) cs'
   sudo darwin-rebuild switch --flake "$PWD/nix#macos" --override-input selection path:/tmp/sel-check
   git status --short                 # expect no output
   sha256sum nix/flake.lock           # expect the same hash as above
   brew list --cask
   ```
   Expect: the `nix eval` list lacks karabiner-elements and linearmouse; the switch succeeds; `git status --short` is empty and the lock hash is unchanged; both casks are still installed (Homebrew cleanup is none). A second run with the `path:$PWD/nix#macos` flake form is optional. Then re-run the switch without `--override-input`: it succeeds and `nix eval` of the same attribute without the override lists both casks.
2. Real /bin/bash 3.2 on a Mac. `/bin/bash --version` shows 3.2.x. Run `APP_CONFIGS_SELECTION_DIR=$(mktemp -d) /bin/bash ops/install.sh --dry-run --profile work </dev/null`, then, in a terminal with a scratch `APP_CONFIGS_SELECTION_DIR` that holds no file, `/bin/bash ops/install.sh --dry-run`. Expect: no `unbound variable`, `mapfile`, `readarray` or `bad substitution` errors; both runs end with `dry run: would write ...`; nothing is written.
3. macOS present-state and cask preview with real brew. Install karabiner-elements and linearmouse first (or confirm they are installed). Run `APP_CONFIGS_SELECTION_DIR=$(mktemp -d) bash ops/install.sh --dry-run` in a terminal and answer, in the real prompt order: profile `Enter`, go `Enter`, macInput `n`, media `Enter`, security `Enter`, then `a`. Expect: the present-state table has a row `macInput installed 2/2 karabiner-elements linearmouse` and the prompt reads `Install group macInput (karabiner-elements linearmouse)?`; the outcome row reads `macInput stays installed 2: karabiner-elements linearmouse`; the "macOS casks" section reads, for each, `<name>: stays installed (Homebrew cleanup = none); remove by hand: brew uninstall --cask <name>`; "unmanaged installed casks: N" is a count only; the run ends with `dry run: would write ...` and the scratch directory stays empty. With brew off `PATH`, the macInput rows show the names and `cask state unknown`.
4. WSL2 host. Run `bash ops/install.sh --dry-run </dev/null` and `mise run sync:dry-run`. Expect: the line `Selection: no local selection; using the committed default (nothing written)`, no macInput in the table or the outcome, no prompt, and no prompt in sync:dry-run. To see the selection path, run `env -u APP_CONFIGS_SELECTION_DIR bash ops/install.sh --dry-run --profile work </dev/null`: it prints `dry run: would write /home/<user>/.config/app-configs/selection/selection.toml` (the path comes from `--profile work`, not from a plain dry run). With `XDG_CONFIG_HOME=/mnt/c/Users/<you>/AppData` set, expect the note `selection: ignoring XDG_CONFIG_HOME=... using /home/<user>/.config` once and the same Linux path.
