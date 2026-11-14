Source: local

# T-0037: VS Code on WSL2: report a missing `code`, skip the extension installer (bug)

Status: open
Wave: 1
Depends on: none

## Summary
On WSL2, git's editor and the extension installer both depend on the Windows
VS Code `code` shim. Make a missing `code` visible in `sys-readiness`, and skip
the curated extension install on WSL2 because which side it installs into is
unknown.

## Owned files (write boundary)
- ops/wsl-check.sh
- tests/bash/wsl-check.bats
- ops/vscode-extensions.sh
- tests/bash/vscode-extensions-wsl.bats (new; do not edit install-vscode-extensions.bats)

## Findings (review claims, unverified until reproduced: reproduce first; reject false positives with evidence)
- VERIFIED: `home/dot_gitconfig.tmpl:306` sets `editor = code --wait` on every
  host; nothing under home/ or nix/ sets `EDITOR` or `VISUAL`. On WSL, `code`
  exists only when Windows VS Code is installed and `appendWindowsPath=true`;
  otherwise `git commit` without `-m` cannot start an editor.
- VERIFIED: `ops/vscode-extensions.sh:21-37` uses any `code` on PATH (on WSL,
  the Windows shim under /mnt/c). `ops/install.sh` calls it and degrades on failure.
- UNKNOWN: whether `code --install-extension` run from WSL targets the Windows
  client or the WSL server. `docs/platforms/wsl/setup.md:103` says Windows-side
  settings sync through Settings Sync.

## Design
- `wsl-check.sh`: one new check. `code` resolves: `OK VS Code CLI (code) on PATH (git core.editor)`;
  otherwise `TODO VS Code CLI 'code' not on PATH: install VS Code on Windows (git uses 'code --wait') or set GIT_EDITOR=nvim`.
- `vscode-extensions.sh`: on host profile `wsl` (`HOST_PROFILE`, else
  `bash ops/detect-host.sh`, as in `ops/readiness.sh`), log a skip message naming
  WSL2 and Settings Sync and exit 0, in apply and `--dry-run` mode, before any
  `code` call.
- Rejected: a per-host `core.editor` (changes the WSL workflow and needs a
  fallback wrapper); installing into the WSL server (target unknown; revisit
  after the T-0040 observation).

## Acceptance criteria
- AC1: With no `code`, wsl-check prints a TODO naming `code` and `GIT_EDITOR`;
  with a stub `code`, the OK line. The "healthy host reports only OK lines" test
  adds a `code` stub.
- AC2: With `HOST_PROFILE=wsl` and a recording stub `code`, the extension
  installer exits 0, makes no `--list-extensions` or `--install-extension` call,
  and names WSL2. Same with `--dry-run`.
- AC3: With `HOST_PROFILE=linux-desktop` and the stub, the installer behaves as
  before (lists, then installs missing).
- AC4: existing `wsl-check.bats` and `install-vscode-extensions.bats` pass.
- Regression tests fail on the old code and pass on the new; independent review
  PASS; one conventional commit per logical change; no AI attribution trailers.

## Verification
- `bats tests/bash/wsl-check.bats tests/bash/vscode-extensions-wsl.bats tests/bash/install-vscode-extensions.bats tests/bash/ops-script-args.bats`
- `bash ops/lint-shell.sh`

## Out of scope / notes
- `home/dot_gitconfig.tmpl`, `ops/install.sh`.
- linux-cli has the same `core.editor` gap (no `code`): follow-up.
- Once T-0035 lands, a missing `code` makes readiness exit 3 (intended).
- Only the files listed above. Unrelated findings are reported, not fixed.
