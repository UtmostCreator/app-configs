Source: local

# T-0052: Claude Code status line on native Windows (feature)

Status: done, pending human (on main 5533fdc, 846f7dc; owner: T6 real run and H1 visual check in Windows Terminal; T3-T5 review open)
Relates to: T-0047 (Milestone 2 item pulled forward), ADR-0016
Amends: ADR-0002, ADR-0006
Plan: [plan.md](plan.md)
Note: T-0049 is reserved by another session.

Written 2026-11-15 against main 400a30b.

## Summary
- Add an opt-in step to `ops/windows/bootstrap.ps1`, run by `-ClaudeStatusLine`.
- It installs the repo status line for Claude Code running natively on Windows, in Windows Terminal.
- It sets one key (`statusLine`) in `%USERPROFILE%\.claude\settings.json`, installs `statusline.sh` next to it, and installs jq through winget when missing.
- The default full run does not include it and its output stays byte-identical.

## Request (verbatim)
"check - claude statusline and ensure we can also automate its installation into normal windows terminal too."

Interpretation: "normal windows terminal" means Claude Code installed natively on Windows (`%USERPROFILE%\.local\bin\claude.exe`) and run in Windows Terminal.
Claude inside WSL already gets the status line through chezmoi.

## Why a ticket
- The step writes a user-owned file (`settings.json`): data-loss risk, so it needs backups and tests.
- It amends two decided scopes:
  - ADR-0006 lists "native Windows Claude automation now (Milestone 2)" as discarded.
  - ADR-0002 limits automatic winget installs to commit tooling ("keep it to WSL and commit tooling").
- [ADR-0016](../../../architecture/decisions/0016-native-windows-claude-status-line.md) records the amendment.

## Acceptance criteria
Unless stated otherwise, the check is `powershell -NoProfile -ExecutionPolicy Bypass -File tests\windows\bootstrap.tests.ps1`, the named CS case passing, and the whole suite passing.
Names: `$T` is the repo template `home/.chezmoitemplates/claude/settings.json`. `$P` is `%USERPROFILE%\.claude\statusline.sh`. `$S` is `%USERPROFILE%\.claude\settings.json`. `$B` is the backup folder `%LOCALAPPDATA%\app-configs\claude\<UTC>-<PID>`.

| ID | Criterion | Check |
|---|---|---|
| AC1 (explicit) | `bootstrap.ps1 -ClaudeStatusLine` installs the status line end to end without manual steps. | CS-flow happy path (stubs) and T6 real run, exit 0 |
| AC2 | `$P` is byte-identical to the repo script: same sha256, LF, no CR. | CS-file and T6 `Get-FileHash` on both files |
| AC3 | After a run, `jq -e --slurpfile t $T '.statusLine == $t[0].statusLine' $S` returns 0. | CS-merge (real jq) and T6 |
| AC4 | Other keys are preserved by value, not bytes: `del(.statusLine)` is equal before and after. The temp file is verified with the S9 `-s` program before the replace. jq may rewrite `1e2` to `1E+2` and `1.5E-3` to `0.0015`, and unescape `\/`; it keeps `1.0`, `-0` and big integers exactly. | CS-merge number case (pins the list) and T6 `jq -e --slurpfile o <B>\settings.json --slurpfile t $T 'del(.statusLine) == ($o[0] \| del(.statusLine))' $S` |
| AC5 | A missing `$S` is created. Empty, garbage or non-object content exits 3 and leaves the file unchanged. A UTF-8 BOM is accepted and the file is rewritten without one. | CS-merge |
| AC6 | Old files are backed up in `$B` before replacement. Writes are temp file then replace. A hash change before the replace exits 1 with the temp file deleted. | CS-file, CS-merge |
| AC7 | A second run changes nothing, keeps no backup and says "current". The tests assert unchanged targets and no backup folder left behind. The dry run writes nothing and returns the real code. Waits are announced. The script is ASCII-only. | CS-idempotent, dry-run test, static S2, T6 second run |
| AC8 | A missing jq triggers `Invoke-Winget -Id jqlang.jq` with the `Get-WingetInstallArgs` arguments. Source agreements exit 3. Still missing exits 1. | CS-flow |
| AC9 | Only Git for Windows bash is used. If it is missing, exit 3. | CS-flow |
| AC10 | The render check uses the exact S11 argument array and needs exit 0 with at least one line. Otherwise exit 1. | CS-render unit (asserts the `-c` string and `'_'`) |
| AC11 (explicit) | The status line shows in Windows Terminal. | H1 (person) |
| AC12 | An elevated run exits 3. Combining the switch with another mode exits 2. | CS-flow |
| AC13 | ADR-0016, the consequence lines, index row, setup.md 4b with Mermaid, the windows-and-wsl.md bullet and the T-0047 line all exist as specified. | Inspection in T1 and T5 review |
| AC14 | An existing statusLine with extra keys (`"hideX":true`) is not current and is replaced exactly. | CS-merge |
| AC15 | A multi-document file `{"a":1}{"b":2}` exits 3 and is left unchanged. | CS-merge |
| AC16 | An unreadable `$S` exits 3 ("cannot read"). This is distinct from an absent `$S`, which is created. | CS-merge |
| AC17 | Invalid UTF-8 exits 3 and nothing is written. Bytes starting `FF FE` give "not UTF-8 (UTF-16?)". | CS-merge |
| AC18 | A read-only `$P` or `$S` that is current gives exit 0 in both modes. A read-only target that needs writing gives exit 3 in both modes; `$P` and `$S` are unchanged, `$B` is absent, and no temp file remains. The dry run lists only targets that would be written. A reparse point at `$ClaudeDir`, `$S` or `$P` exits 3. | CS-file, CS-merge |
| AC19 | A `Get-GitBashHome` mismatch exits 3. Trailing `\`, different case, and a non-ASCII profile path (for example `C:\Users\Jörg`) pass. A failing probe exits 1. `CLAUDE_CONFIG_DIR` in any scope exits 3. `CLAUDE_CODE_GIT_BASH_PATH` in any scope is reported without stopping. | CS-flow (stubs) |
| AC20 | The real template has no `{{` and parses. A planted template with `{{ }}` inside a string value exits 1. | CS-contract |
| AC21 | A stubbed `jq-1.6` exits 3 and the message names the jq path. | CS-flow |
| AC22 | The isolation rules in the plan (Test isolation) hold, and the suite guard passes. | Harness and guard |
| AC23 | A planted `$S.app-configs-tmp-1` is reported and still exists afterwards. A planted temp with the current PID makes the write exit 1 without overwriting it. | CS-file |
| AC24 | The repo script under real Git Bash, with three payload files (complete with cwd `$RepoRoot`, minimal with model and workspace only, Windows backslash paths) and `STATUSLINE_GIT_TTL=0`, exits 0 with empty stderr and at least one line each. | CS-render-real |
| AC25 | Install into the redirected profile, then the real `Invoke-StatusLineRender` exits 0 with at least one line and empty stderr. Delete the redirected `$P` and render again: exit is non-zero. The guard confirms the real `~/.claude` is untouched. | CS-render-real |
| AC26 | An absent `$S` is created as `{statusLine: tpl}`. If a stubbed `Invoke-Jq` creates `$S` during the temp verification, the run exits 1, the planted `$S` is unchanged and the temp file is deleted. A static check confirms that Move-Item has no `-Force`. | CS-merge |
| AC27 | Script differs and settings are current: `$B` keeps `statusline.sh` and has no `settings.json`. Every settings exit 3 leaves no `$B`. An empty `$StateRoot\claude` is removed. | CS-file |
| AC28 | `Get-BytesSha256` equals `Get-Sha256` for the same bytes, as lowercase hex. | CS-helper |
| AC29 | With `Get-UtcStamp` stubbed and `$StateRoot\claude\<stamp>-<$PID>` pre-created, the run exits 1 and leaves that folder untouched. | CS-file |
| N1 | The full run without the switch is unchanged. All existing tests pass with no assertion edited, and step C messages are byte-identical. | Full suite; review of the T2 diff |
| N2 | Nothing under `home/`, `nix/` or `ops/*.sh` changes. | `git diff --stat main -- home nix ops/*.sh` is empty |
| N3 | Windows gets no hooks, model, theme, subagentStatusLine or env from the repo. | CS-merge asserts that only `statusLine` differs |
| N4 | No other file in `~/.claude` is touched. | Dry-run and real tree comparison in the redirected profile |

## Decisions in force
D1 is set by the user's explicit request.
D2 to D8 are defaults. They stand unless the user overrides them.

| ID | Decision | Set by |
|---|---|---|
| D1 | Pull the feature forward from Milestone 2 and amend ADR-0002 and ADR-0006. Yes. | user request (explicit) |
| D2 | An opt-in switch, not part of the full run. The full run's closing NOTICE does not mention it. | default, user can override |
| D3 | An existing different statusLine is replaced exactly. The old value is reported and backed up. | default, user can override |
| D4 | A locally modified statusline.sh is replaced, with a backup. | default, user can override |
| D5 | No LANG in v1, so separators are ASCII when Claude's environment has no UTF-8 locale. Decide after H1 between settings `env.LANG=C.UTF-8` and a script default for MSYS. | default, user can override |
| D6 | Create `~/.claude` when it is absent. | default, user can override |
| D7 | Keep every backup (one per actual change) and delete them by hand. | default, user can override |
| D8 | Install jq automatically through winget. | default, user can override |

## Residual risks
- R1: Claude Code can rewrite settings.json in the milliseconds between the S9 hash check and the replace. The S7 notice covers this.
- R2: the S5 open-probe cannot detect a handle held without Delete sharing. The replace then fails, the run exits 1, the temp file is deleted, and a re-run converges.
- R3: an ACL or disk failure after S5 can stop the run between S8 and S9 (half-applied). It exits 1, keeps the script backup, and a re-run converges.
- R4: Claude-side disagreements.
  - Claude Code may pick another bash (`CLAUDE_CODE_GIT_BASH_PATH`, PATH order).
  - It may start in a different environment (an old PATH without jq, other HOME or LANG).
  - Which home it resolves for its config dir is unknown (inferred: `USERPROFILE`).
  - If it falls back to PowerShell, the `.sh` file association may open a window.
  - S3 reports `CLAUDE_CODE_GIT_BASH_PATH`; H1 detects the rest.
- R5: jq is visible only to processes started after the install.
- R6: an edit to the statusline script that breaks it under Git Bash is caught only by the real Git Bash render case (SL17) when tests/windows runs on Windows; skipped without Git for Windows.
- R7: leftover temp files and backups accumulate (manual cleanup).
- R8: unknown whether Claude passes COLUMNS on Windows (layout switching); some glyphs may show as tofu. Separators are ASCII under D5.
- R9: the dry-run S5 probe opens existing targets for write without writing to them.

## Out of scope
- Installing Claude Code, chezmoi on Windows, changing the status line script or the Linux template.
- A Nerd Font, Windows Terminal profile settings, automatic updates.
- Windows hooks, model, theme, env (see the plan, Scope).

## Status
- Design reviewed (PASS WITH NOTES, round 3). Implemented 2026-11-16 in ops/windows/bootstrap.ps1 (uncommitted); tests/windows suite 193 passed, 0 skipped, 0 failed. Not run on the real settings.json yet (T6).
- T1 (these records): written and reviewed (PASS WITH NOTES); pre-commit and commit pending. T2 to T6 are listed in [plan.md](plan.md).
- Prerequisite P0: the step C work in `ops/windows/bootstrap.ps1` is committed by its owner first.
