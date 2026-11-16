# ADR-0016: Native Windows Claude status line: the repo script through Git Bash, installed by the bootstrap
Status: proposed (design reviewed; not implemented) · Date: 2026-11-15 · Amends: ADR-0002, ADR-0006 · Sources: T-0052, code.claude.com/docs/en/statusline (Windows configuration)

Amends ADR-0002 and ADR-0006. Their consequence lines are added with this record. Plan: `docs/work/active/T-0052-windows-claude-statusline/plan.md`.

## Decision
- Add one opt-in step to ops/windows/bootstrap.ps1, run by `-ClaudeStatusLine`. The default full run does not include it.
- It installs the unchanged repo script home/dot_claude/executable_statusline.sh as `%USERPROFILE%\.claude\statusline.sh`.
- It installs jq through winget when jq is missing.
- It sets exactly one key in `%USERPROFILE%\.claude\settings.json`: `statusLine`, equal to `.statusLine` read at run time from home/.chezmoitemplates/claude/settings.json.
- Claude Code on Windows runs the documented command `~/.claude/statusline.sh` through Git Bash.
- Backups go to `%LOCALAPPDATA%\app-configs\claude\<UTC>-<PID>\` before any replacement. A re-run with nothing to change changes nothing and keeps no backup.

## Boundary
- Step S owns only the `statusLine` key in `%USERPROFILE%\.claude\settings.json`, the file `statusline.sh`, and the winget id `jqlang.jq`.
- Any other key, file, hook or winget id needs a new ADR.
- This is one opt-in step with a fixed surface and a single source, guarded by tests. It is not the open-ended "repo-run Windows layer" that T-0041 discards. That resolves the tension with ADR-0002's "keep it to WSL and commit tooling".
- Windows gets no hooks, model, theme or env from the repo. ADR-0006 still limits Windows Claude to Windows-side work.

## Why
- The user asked for it explicitly (T-0052 request), which pulls it forward from Milestone 2.
- The script ran unchanged under Git Bash 5.3 with jq 1.8.2: 12 cases exit 0, about 0.6 s per run against a 5 s refresh.
- One source: the template and the script are the same repo files WSL and Linux use, read at run time.

## Removal trigger
Delete step S if native Windows Claude use ends, or if a later ADR adopts chezmoi on Windows.

## Strong alternatives
| Option | Why it lost |
|--------|-------------|
| A: chezmoi on Windows, limited to the Claude files | No Windows rules exist, so a plain apply deploys about a dozen Unix dotfiles. Limiting it needs an ignore-everything-else list that every new home/ file must be checked against, an unbounded burden. Whether a bash `modify_` script runs without `interpreters` is unknown. The template would push hooks, model and theme, and the Linux `modify_` overwrites invalid JSON. Its capability (a single source) is kept: step S reads the same repo files. |
| C: a native PowerShell status line | A second implementation of a 592-line script with no parity tests (bats does not run on Windows) and no speed gain. |
| E: point statusLine.command at the repo checkout file | No drift, but it ties Claude to whatever branch is checked out and to the clone path, and needs a Windows-only command value, which is a second source. |
| Include step S in the default full run | It couples a cosmetic step to the WSL exit codes and widens what the default run writes. Deferred (T-0052 D2). |
| ConvertTo-Json merge | PS 5.1 reformats, escapes `<>'&` and limits depth. jq is needed anyway. |
| Recursive merge `. * {statusLine:...}` (Linux parity) | Keys inside an old statusLine would survive. Windows replaces the value exactly. |

## Discarded
Windows hooks, model, theme, subagentStatusLine and env from the repo; installing Claude Code; chezmoi on Windows; a Nerd Font or Windows Terminal profile changes.

## Consequences
- Updates reach Windows only when `-ClaudeStatusLine` is re-run after `git pull`. `-ClaudeStatusLine -DryRun` shows drift.
- The step edits a user-owned file. Safeguards: refusals before any write, a backup per change, a temp file verified before the replace, a hash check, read-only and reparse-point refusals.
- Residual risk R4 (T-0052): Claude-side disagreements. Claude Code may pick another bash (`CLAUDE_CODE_GIT_BASH_PATH`, PATH order) or start in a different environment (old PATH without jq, other HOME or LANG). Which home it resolves is unknown (inferred: `USERPROFILE`). The step reports `CLAUDE_CODE_GIT_BASH_PATH`; the human check H1 detects the rest.
- Residual risk R6 (T-0052): an edit to the statusline script that breaks Git Bash is caught only when tests/windows runs on Windows (bats does not run there).
- Status moves to "decided, not yet verified" in T5 and to verified after the human check H1 on a real run.
