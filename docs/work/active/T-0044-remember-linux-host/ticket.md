Source: local

# T-0044: Remember linux-desktop versus linux-cli per machine (feature)

Status: implemented on feat/remember-linux-host, not landed; human checks pending (below)
Opened: 2026-11
Follows: T-0042 (install selection), whose open question 6 asked where to persist this.

## Summary
On plain Linux nothing reliably tells `linux-desktop` from `linux-cli`, so the
answer silently fell back to `linux-desktop` (or `HOST_PROFILE_DEFAULT`) unless
the user exported `HOST_PROFILE` every time. Remember it per machine in a host
file, ask once in `ops/install.sh`, and let every consumer get the same answer
through `ops/detect-host.sh`.

## Decision
The architect's design, with all its recommendations accepted by the user, plus
one safeguard.

- **Location:** `${XDG_CONFIG_HOME:-$HOME/.config}/app-configs/host`. An
  `XDG_CONFIG_HOME` on `/mnt/<letter>` is ignored in favour of `$HOME/.config`
  (the rule of `ops/lib/selection.sh`). `APP_CONFIGS_HOST_FILE` overrides the
  path as given. It sits beside `selection/`, not inside it, because `selection/`
  is a flake input; the host file is not a flake input and not chezmoi-managed.
- **Format:** one line, exactly `linux-desktop` or `linux-cli`; trailing
  whitespace and the newline are trimmed; no comments.
- **Precedence:** `HOST_PROFILE`, then macOS or WSL2 detection (the file is never
  read there), then the host file (plain Linux only), then
  `HOST_PROFILE_DEFAULT`, then `linux-desktop`. An invalid file on plain Linux
  makes `detect-host.sh` exit 1 with nothing on stdout and an error that names
  the file, the two values and the fixes.
- **Who writes:** only `ops/install.sh`. Who reads: only `ops/detect-host.sh`
  (single-owner rule); bootstrap does not prompt.
- **Settled by the orchestrator (low-impact, reversible):** a valid
  `HOST_PROFILE_DEFAULT` (`linux-desktop` or `linux-cli`) is the host question's
  default answer, instead of the graphical-session guess; the reason line says
  "default from HOST_PROFILE_DEFAULT". The question is still asked.
- **Safeguard (the user's):** when the host comes from the file and
  `personal.yaml` (`hostProfile`, `gui`) disagrees, the warning must show the
  detected host, the configured values and the corrective action, before any
  `chezmoi apply`, in install, bootstrap and `sys-update` (report and apply). It
  only warns and never edits `personal.yaml` (seed-personal-yaml stays
  write-once).

## Owned files
- ops/detect-host.sh (reads the file; `--host-file`, `--source`)
- ops/install.sh (`--host`, the question, `host_choice_write`, the hint)
- ops/lib/preflight.sh (`preflight_host_data_drift`, `preflight_bats_path_guard`)
- ops/bootstrap.sh and ops/update-all.sh (one drift call each, nothing else)
- tests/bash/detect-host.bats, ops-script-args.bats, single-owner.bats,
  install-host.bats (new), bootstrap-safety.bats, update-all-preflight.bats
- docs/getting-started/install.md, docs/getting-started/bootstrap.md,
  docs/architecture/tool-ownership.md, docs/work/index.md

## Design
- `detect-host.sh` stays self-contained (tests copy it alone into fixtures). Under
  bats the default path is read only inside `$BATS_TEST_TMPDIR`, like
  `preflight_bats_guard`; `APP_CONFIGS_HOST_FILE` is always honoured.
  `--wsl-version` is unchanged. `--source` prints `env`, `detected`, `file` or
  `default`.
- `install.sh` flow in Preflight: `HOST_PROFILE` set means exactly as before.
  `--host` validates early (exit 2, nothing written: unknown or empty value,
  conflicting `HOST_PROFILE`, detected macOS or WSL2), then writes. Otherwise it
  asks once when the source is `default` on a TTY, or with `--reconfigure` when
  the source is `file` or `default` (default answer: the current file value, else
  `host_guess`). Without a TTY it asks nothing, writes nothing and prints a hint.
  `q` or end of input exits 1 before any mutation. `--dry-run` never writes and
  prints `dry run: would write <file> (<value>)`.
- `host_guess`: `linux-desktop` when `WAYLAND_DISPLAY` or `DISPLAY` is set or
  `XDG_SESSION_TYPE` is x11, wayland or mir (the test `sys-update` uses);
  otherwise `linux-desktop` when `systemctl get-default` prints `graphical.target`
  (one signal, not the only one); otherwise `linux-cli`.
- The drift check reads only the `^hostProfile:` and `^gui:` keys with sed. A
  missing `hostProfile` counts as `linux-desktop` (the chezmoiignore default), a
  missing `gui` as `false`; expected `gui` is true for `linux-desktop`, false for
  `linux-cli`. It runs only when `--source` says `file` (in install also after
  `--host` or the question, which make the file the source).

## Acceptance criteria
1. With no file and no env, every `detect-host.sh` result and consumer output is
   unchanged apart from install's extra hint line and its added `Source:` line
   (`Source: detected` on macOS and WSL); existing suites pass unmodified.
2. Precedence as above; WSL2 and macOS never read the file; an invalid file on
   plain Linux is exit 1 with nothing on stdout.
3. The host file directory equals the parent of `selection_dir` for unset, normal
   and `/mnt/c` `XDG_CONFIG_HOME` values.
4. Only `ops/detect-host.sh` spells the path; `install.sh` is the only writer.
5. install asks once, `--host` writes, `--reconfigure` asks the host first,
   `--dry-run` writes nothing, no TTY never blocks or writes, `q`/EOF exit 1.
6. No temp file is left behind; exit codes 0, 1 and 2 as designed.
7. The drift warning shows the detected host, the configured values and the fix,
   before any chezmoi apply, in install, bootstrap and `sys-update`; no edit.
8. Nothing changes on macOS or WSL apart from install's `Source: detected` line;
   `SELECTION_ARGS` is unchanged; the file is not
   a flake input and not chezmoi-managed; `nix/flake.lock` is untouched.

## Plan
- [x] T1: detect-host reads the host file, `--host-file`, `--source`, the single-owner rule (tests/bash/detect-host.bats, ops-script-args.bats, single-owner.bats)
- [x] T2: install asks once, `--host`, `--reconfigure`, dry run, no-TTY hint (tests/bash/install-host.bats)
- [x] T3: the drift warning in install, bootstrap and `sys-update`; consumer tests (tests/bash/bootstrap-safety.bats, update-all-preflight.bats)
- [x] T4: documentation and this ticket

## Verification
Run on the branch: the full `bash ops/run-bats.sh`, `bash ops/lint-shell.sh`,
`bash ops/validate-config.sh`, `nix flake check ./nix`, `bash ops/ci-local.sh`;
read-only `detect-host.sh`, `--source` and `--host-file` on the development host
(no file was created); `bash ops/install.sh --dry-run` without a TTY, whose output
differs only by the hint line and the `Source:` line.

Evidence (final run on this branch):
- `bash ops/run-bats.sh`: all tests ok, 0 not ok. New or extended tests:
  tests/bash/detect-host.bats (host file precedence, invalid-file matrix incl.
  leading blank line and tab, trailing blank lines, `--host-file`, `--source`,
  selection_dir parity, bats default-path rule); tests/bash/install-host.bats
  (the question and its heuristic, `--host` and its exit-2 refusals incl.
  HOST_PROFILE equal to `--host` on WSL2/macOS, a directory as host file,
  HOST_PROFILE_DEFAULT as the default, `--reconfigure`, dry run, no-TTY hint,
  drift unit tests and install drift tests); tests/bash/single-owner.bats
  (path owner, consumers); tests/bash/bootstrap-safety.bats and
  tests/bash/update-all-preflight.bats (host file as the source, drift warning
  before the chezmoi step); tests/bash/ops-script-args.bats.
- `bash ops/lint-shell.sh`, `bash ops/validate-config.sh`, `nix flake check ./nix`
  and `git diff --check`: clean.
- `bash ops/ci-local.sh` passed on the first implementation; rerun noted in the
  report of the fix round.

## Human checks
- A real headless Linux `sys-install`: it asks the host question once, writes the
  file, and a second run is silent and uses the file.
- A macOS `/bin/bash` 3.2 dry run of `bash ops/install.sh --dry-run`: no host
  question, no host file.
