# T-0043 verification

Run on the linux-desktop host from the feat/selection-diff worktree, with a
short private TMPDIR that was removed afterwards. Nothing was applied or
switched; the real runs below are read-only.

| Check | Scope | Result |
| --- | --- | --- |
| `bash ops/run-bats.sh` | the whole suite (1388 tests, run twice: once before and once after the record and docs work) | passed |
| `bash ops/lint-shell.sh` | the curated list, 30 files | passed |
| `bash ops/validate-config.sh` | the repo | passed |
| `nix flake check ./nix` | this host's systems (aarch64-darwin omitted by Nix) | passed |
| `bash ops/ci-local.sh` | validate-config, lint, bats, flake check, all-systems eval, linux activation build, clean-runner environment | all six PASS |
| `bash ops/update-all.sh --selection-diff` and `--apply --selection-diff --json` | this host, from the worktree | exit 11 (chezmoi unknown, see below); JSON parses |

Real read-only runs: wall time 42 s (text) and 29 s (JSON) with other work
running on the host. Before and after, byte-identical: chezmoistate.boltdb
(sha256 and mtime), nix/flake.lock (main checkout and worktree), every file under
the sys-update state directory, and the Home Manager profile link (generation 110).
No installed.meta was created.

The chezmoi source is reported unknown there because a git worktree has no
gitignored per-host chezmoi data (`chezmoi status` fails on `.hostProfile`). That
is the intended honest answer, and it is why the exit code is 11 and not 0.

Not verified: macOS (casks, the darwin-system record kind, `brew list --cask`)
beyond stubs; a real bash 3.2 run of the install path; a real apply or install
that writes the record.

## Round 2 (HEAD 2e5e73f, after the review fixes)

Run from the worktree with a short private TMPDIR.

| Check | Result |
| --- | --- |
| `bash ops/run-bats.sh` (full suite) | 1395 of 1395 passed |
| `bash ops/lint-shell.sh` | passed (30 files) |
| `bash ops/validate-config.sh` | passed |
| `nix flake check ./nix` | passed |
| `bash ops/ci-local.sh` | all six steps PASS |
| `bash ops/update-all.sh --selection-diff` and `--selection-diff --json` | 26.3 s and 25.6 s, both exit 11 (chezmoi unknown in a worktree), JSON parses |

The before and after snapshots of the state the diff must not touch (chezmoi
state, flake.lock, the sys-update state, the Home Manager profile) were
byte-identical; nix/flake.lock is unchanged.
