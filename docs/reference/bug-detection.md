# Bug detection

Every way this repo finds bugs, what each one catches, and where it runs. The
bug types are the twelve found on 2026-11-14 (about 40 fixes in 70 commits);
the table at the end maps each type to the checks that now guard it.

Run it all: `mise run audit` (CI gate, restsift, live machine). The parts:
`mise run audit:ci`, `audit:deep`, `audit:live`. Every line is PASS, WARN or
FAIL; the exit status is 1 on any FAIL. WARN is advisory and never fails.

## Bug types

| # | Type |
|---|------|
| 1 | Gate passes without checking (skipped work counted as success) |
| 2 | Arguments silently ignored (`--help` or a typo ran the real job) |
| 3 | Tests touching or depending on real state (HOME, host tools) |
| 4 | Writes to chezmoi-managed files, double ownership |
| 5 | Platform assumption leaks (macOS paths on Linux, WSL1) |
| 6 | Wrong or missing input, silent default |
| 7 | Stale references (docs, config, comments naming removed things) |
| 8 | Unsafe defaults, missing confirmation |
| 9 | Missing tool, or a crash after success |
| 10 | Orchestration ordering, irreversibility, twin drift between scripts |
| 11 | Nondeterminism (hash seed, ordering) |
| 12 | Output-channel mixing (stderr merged into parsed stdout) |

## Methods

Where: **CI** = `mise run ci` / `ci:local` and GitHub CI on every push to
`main`; **deep** = `mise run audit:deep`; **live** = `mise run audit:live`;
**weekly** = the `repo-audit` user timer (`audit:live`, notifies on FAIL);
**manual** = by hand, when you suspect the type.

### Automated, deterministic

| Method | Catches | Types | Where |
|--------|---------|-------|-------|
| Bats behaviour tests (`tests/bash/*.bats`, run by `ops/run-bats.sh`) with real-shaped input, PATH stubs and `--separate-stderr` | Wrong behaviour of a script; silent defaults; unsafe confirmations; crashes after success; mixed output channels | 2, 5, 6, 8, 9, 10, 12 | CI |
| Test-hygiene scanner (`tests/lib/find-dead-bang-asserts.py`, `tests/bash/test-hygiene.bats`) | `! cmd` and `[ ] && ...` assertions in the middle of a test, which can never fail | 1 | CI |
| Scratch HOME and leak check (`ops/run-bats.sh`) | A test that writes to the real `~/.config`, `~/.local/state`, tmux server | 3 | CI |
| Bats apply guards (`preflight_bats_guard` in `ops/lib/preflight.sh`, `tests/bash/mutation-guards.bats`) | An apply run from a test that reaches the real HOME or repo | 3, 10 | CI |
| `mise run lint:shell` (`ops/lint-shell.sh`): `bash -n` per file, rendered chezmoi shell templates, ShellCheck on the curated list; fails when a tool is missing | Syntax errors, `bash -n a b` parsing only `a`, a lint that skips | 1, 9 | CI |
| CI-identical clean environment (`ops/ci-local.sh`) and GitHub CI (`.github/workflows/ci.yml`) | Tests that silently use `~/.nix-profile`, `/run/current-system`, your HOME or login shell | 3, 5, 12 | CI |
| Doc contracts (`tests/bash/doc-contracts.bats`) | Docs or workflows naming a `mise run` task that does not exist; private data files not gitignored | 7 | CI |
| `arg-contract.bats` | Every script reachable from mise, `~/.local/bin`, fish functions and zsh aliases: `--help` exits 0 with usage, an unknown flag exits non-zero, neither calls a mutating tool (sandbox of recording stubs) | 2 | CI |
| `path-contract.bats` | A repo path named by shell, nix, `mise.toml` or markdown that does not exist | 7 | CI |
| `managed-writers.bats` | A script writing to a chezmoi-managed path without a `chezmoi_managed` check; Home Manager `xdg.configFile` / `home.file` on a chezmoi path | 4 | CI |
| `single-owner.bats` | `home-manager switch` outside `ops/lib/hm-switch.sh`; WSL1, username and bats guards copied out of `ops/lib/preflight.sh`; an apply mode without the bats guard; fish and zsh `ws-*` twins running different scripts | 10 | CI |
| `audit.bats`, `repo-audit-timer.bats` | The audit and its timer themselves | all | CI |

Each contract test carries a commented allowlist (the exceptions that are
justified, and findings not yet fixed), proves it catches a bug seeded into a
copy of the repo, and fails when an allowlist entry stops being needed.

### Automated, local (restsift `res`, `mise run audit:deep`)

| Method | Catches | Types | Where |
|--------|---------|-------|-------|
| `res arch check` (policy `.directory-size.env`), also `mise run arch:check` | Directory sprawl: file counts, depth, fragmentation; gated at error | structure | deep |
| `res refactor scan` | Files and functions with high complexity, size and nesting; FAIL at priority 90 or more | change risk | deep |
| `res refactor-scan dupes` | Copy-pasted blocks, the usual source of twin drift; WARN above 3% | 10 | deep |
| `res refactor-scan comments` | Comment inventory with history, to find comments that name removed files or flags | 7 | manual (`res refactor-scan comments`) |
| `res verify shell` over all tracked shell scripts | Syntax and ShellCheck errors (FAIL), warnings (advisory). SC2148 in `nix/modules/home/scripts/*.sh` is expected: Nix wraps them | 1, 9 | deep |
| `res git history missing-companions` | A file that nearly always changes with the files on this branch, but did not (a twin or its test left behind) | 10 | deep |
| `res git history rework` | Files changed again within 1, 7 and 30 days: unfinished fixes | all | deep |
| `res git history hotspots` | Live files whose fix ratio is 50% or more: where bugs cluster | all | deep |

### Automated, this machine (read-only, `mise run audit:live`)

| Method | Catches | Types | Where |
|--------|---------|-------|-------|
| `chezmoi status` | Pending changes (WARN); managed files edited by hand that are not `modify_` targets (FAIL, `sys-update` refuses to run) | 4 | live, weekly |
| `systemctl --user --failed` | A user unit that failed, such as an updater that crashed on a missing tool | 9 | live, weekly |
| nix-profile vs Home Manager collision check (`profile_hm_conflicts`) | A hand-installed package that would make `home-manager switch` fail after removing `home-manager-path` | 10 | live, weekly |
| Last `sys-update` run (`$SYS_UPDATE_STATE_DIR/last-run`) | A failed, unfinished or very old update | 10 | live, weekly |
| Main checkout dirty | Uncommitted files that block the next `sys-update` | 10 | live, weekly |
| codebase-memory index | Projects indexed from `/tmp` or from a deleted directory; prints the `delete_project` command | none (hygiene) | live, weekly |

### Manual

| Method | Catches | Types | How |
|--------|---------|-------|-----|
| Golden byte-for-byte equivalence under several hash seeds | Output that depends on Python's per-process hash seed (`min()` over a set) | 11 | Run the tool with `PYTHONHASHSEED=0 1 2 3 ...` and `diff` the outputs before and after a change |
| Behavioural parity suites | Platform leaks and fish/zsh drift: `tests/bash/shell-os-parity.bats`, `ws-shell-parity.bats`, `cli-abbr.bats` | 5, 10 | Run them after touching a template or alias |
| Stub and shim reproductions | A bug that needs an environment you do not have: a fake tmux server, a `nix` shim that writes a notice to stderr, a `getent` that is missing | 9, 12 | Put the shim first on `PATH`, reproduce, then turn it into a bats test |
| Shell-history analysis, `mise run history:report` | Workflows that fail or repeat often, risky one-word aliases, defaults nobody uses | 6, 8 | Read `~/.local/state/history-report/report.md`; aggregates only |

## Type to check

| # | Type | Caught by |
|---|------|-----------|
| 1 | Gate passes without checking | test-hygiene, `lint:shell`, `res verify shell`, fail-closed tasks |
| 2 | Arguments silently ignored | `arg-contract.bats`, bats behaviour tests |
| 3 | Real state | scratch HOME and leak check, bats apply guards, `ci:local`, GitHub CI |
| 4 | Managed-file writes | `managed-writers.bats`, `audit:live` chezmoi check, `modify_` merge scripts |
| 5 | Platform leaks | parity suites, `ci:local`, per-OS template guards |
| 6 | Silent defaults | bats tests with real-shaped input; manual history analysis |
| 7 | Stale references | `path-contract.bats`, doc contracts; comments by hand |
| 8 | Unsafe defaults | bats behaviour tests (`git-shortcuts.bats`); manual history analysis |
| 9 | Missing tool, crash after success | bats stubs, `res verify shell`, `audit:live` failed units |
| 10 | Ordering and twin drift | `single-owner.bats`, `res refactor-scan dupes`, `res git history missing-companions`, `audit:live` nix-profile and sys-update checks |
| 11 | Nondeterminism | manual hash-seed equivalence only |
| 12 | Output-channel mixing | bats `--separate-stderr`, `ci:local`, GitHub CI |

Known gaps: type 11 has no automated check; stale comments (type 7) are found
only by reading the `comments` inventory; type 6 depends on writing tests with
input shaped like the real thing.
