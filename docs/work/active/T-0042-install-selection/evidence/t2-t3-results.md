# T-0042 T2 and T3 results

Evidence for AC1 (drvPaths), AC2, AC3, AC4, AC5 and AC9 after T2 (selection input, profiles, groups option) and T3 (media, security and go gated in place). Nix 2.34.7, base 972422f.

## drvPaths

Command per cell (A is the activation package for the four Home Manager outputs, or the darwin system):

```
nix eval --raw "path:$PWD/nix#homeConfigurations.<host>.activationPackage.drvPath" [--override-input selection path:<fixture dir>]
nix eval --raw "path:$PWD/nix#darwinConfigurations.macos.system.drvPath" [--override-input selection path:<fixture dir>]
```

T1 baseline (no local file) is in t1-baseline.md. 'equal' means the full drvPath string equals that baseline.

| output | T1 baseline | no file (after T3) | all-on fixture | media+go off | all groups off |
| --- | --- | --- | --- | --- | --- |
| linux-desktop | 9vz288c6.. | equal | equal | differs (r1ky3skj) | differs (1jb7scdc) |
| linux-cli | mbpxd5hm.. | equal | equal | differs (cphymnf6) | differs (dvin9qwc) |
| wsl | mbpxd5hm.. | equal | equal | differs (cphymnf6) | differs (dvin9qwc) |
| macos | 97njhnqb.. | equal | equal | differs (dbqpybbn) | differs (63xk5xss) |
| darwin | 9lacxzqb.. | equal | equal | differs (a16j54c1) | differs (2xggvsm3) |

The 'no file' column equals the T1 baseline table on every row (full strings compared against t1-baseline.md). The same results held after T2 alone (before any package was gated).

All-on fixtures: all-on-work (profile work, all groups true) for linux-cli, wsl, macos and darwin; all-on-personal for linux-desktop, because linux-desktop's host profile is personal and a selection profile overrides the host profile. A single all-on fixture cannot equal the baseline on every host.

The media+go off and all-false fixtures name profile work, so on linux-desktop they also switch the host from personal to work. Their drvPaths therefore differ from the baseline for that reason as well as for the gated packages; the package-level checks below use linux-cli, where the profile does not matter.

## Package-level checks (linux-cli, home.packages pnames)

- Default has 115 entries. all-on and default are drvPath-identical.
- media=false and go=false: ffmpeg and go are absent; fish, ripgrep, fd, jq, git, trivy and osv-scanner remain; the removed set is exactly {ffmpeg, imagemagick, viu, yt-dlp} plus the 12 Go block names (AC2).
- all groups off: removed set is exactly the gated names (media 4, security 2, go 12); 31 required or sampled tools from update-all, readiness and doctor (home-manager, git, jq, yq-go, gitleaks, fish, neovim, ripgrep, fd, bat, eza, fzf, zoxide, starship, atuin, tmux, lazygit, delta, gh, nodejs, php-with-extensions, docker, stripe-cli, repomix, scc, bats, actionlint, ShellCheck, shfmt, lychee, curl) are all present (AC3). No script in the ops directory requires any gated tool (grep over ops, tests, mise.toml, lefthook and CI files found none).
- These are asserted in tests/bash/selection.bats (tests 12 to 15).

## Lock (AC5)

- `git diff 972422f -- nix/flake.lock`: 13 insertions, 0 deletions, the selection node plus the root input. sha256 44847d34cfeb9d8e119e22934bcf8a12d97bc3b3187cd4c09088c4c15a61ceee, equal to the T1 spike lock.
- Written by `nix flake lock ./nix` (only 'Added input selection'); no flake update was run.
- `nix flake check ./nix`, the all-systems check, every override eval and the host build left the lock sha unchanged.

## Failure messages (AC4)

Asserted in tests/bash/selection.bats tests 9 to 11. The messages: unknown profile 'nope' (known profiles listed); unknown group 'bogus' (known groups listed); [groups] is set but 'profile' is missing. They are throws, so they fire for any option that reads the selection, including config.myConfig.groups, not only for the activation package (an assertion would not).

## Checks run

| command | scope | result |
| --- | --- | --- |
| `bats tests/bash/selection.bats` | new suite, 15 tests | 15 ok |
| `bash ops/run-bats.sh` | full suite incl. ops/projects/logging/test | 1154 tests, rc 0 |
| `bats nix-ownership, generate-package-matrix, test-hygiene, validate-config` | named files | no failures |
| `bash ops/validate-config.sh` | text invariants | all invariants pass |
| `bash ops/validate-config.sh --eval` | evaluated policy, 4 profiles | all invariants pass |
| `nix flake check ./nix` | git ref, x86_64-linux | all checks passed |
| `nix flake check ./nix --all-systems --no-build` | git ref, all systems | all checks passed |
| `nix build --no-link path:$PWD/nix#homeConfigurations.linux-desktop.activationPackage` | host build | rc 0 |
| `seeded: forbidden tool (direnv) inserted before ffmpeg, trivy and gopls in a scratch copy` | static scanner in validate-config.sh | flagged in all three gated blocks (AC9) |

The package matrix generator (ops/generate-package-matrix.sh) does not read Nix package lists; the static scanner is the validate-config.sh one above. Gated names stay literal in cli.nix and dev.nix.
