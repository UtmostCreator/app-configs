# backend log workspace

`log-workspace` opens a persistent tmux investigation workspace on the default
`dashboard` window, with side-by-side views for Integration, combined backend PHP/npm,
and Frontend. The `all` window remains available for a single merged timeline across
all four log sources. Set `LOG_WORKSPACE_DEFAULT_VIEW=all` to open that view
first.

Each lnav pane opens at its newest loaded entry. Press `g` to navigate to the
start of its history when older messages are needed.

```bash
log-workspace
log-workspace --detached
log-workspace --rebuild
log-workspace --help
```

The tested full viewer is `lnav` 0.14.0 or newer.  When it is unavailable the
workspace uses a clearly marked `less` fallback.  Application log files and
directories are never created by the viewer; missing sources remain in a
`WAITING` state and are picked up when they appear.

## Investigation controls

| Action | Key |
|---|---|
| Search | `/` |
| Next/previous match | `n` / `N` |
| Next/previous error | `e` / `E` |
| Pause/resume | `=` |
| Toggle wrapping | `Ctrl-W` |
| Mark line/range | `m` / `Shift-M` |
| Copy marked content | `c` |
| Toggle lnav mouse handling | `F2` |
| Show help | `F1` or `?` |
| Zoom tmux pane | `Prefix`, then `z` |
| Cycle tmux layout | `Prefix`, then `Space` |

lnav mouse handling is disabled by default, so drag to select text in any pane
and use your terminal's usual copy shortcut. Press F2 only when lnav mouse
actions are needed. For lnav-native copying, press `m` on the first line, move
to the last line, press `Shift-M` to mark the range, then `c` to copy it to the
macOS clipboard. The scripts do not modify global tmux key bindings or
clipboard settings.

`Ctrl-R` is handled by lnav, not this workspace. The reported crash occurred
while lnav was rebuilding its index of historical log files; avoid `Ctrl-R` in
this view until lnav is updated, and use `lnav -m crash upload` to submit the
existing crash report.

## Optional environment overrides

Routine use needs no configuration.  Tests and non-standard installations can
override `LOG_WORKSPACE_SINCE` (default `24h`),
`LOG_WORKSPACE_DEFAULT_VIEW`, `LOG_WORKSPACE_SESSION_NAME`, the Herd/log roots,
or any individual source pattern defined in `watch/config.sh`.

Persisted npm output is capture-timestamped in UTC and labelled `BACKEND-NPM` or
`FRONTEND-NPM`.  Capture time records when this tooling received a line and is not
necessarily an application event timestamp.  Legacy unprefixed content remains
available, but should not be treated as precisely ordered across services.

Repository-local formats contain safe baseline samples.  They should be refined
against sanitized real excerpts containing normal lines, warnings, errors,
multiline exceptions, JSON/context values, ANSI output, and startup/build output.

## Error reports

`log-errors` uses the dependency-free PHP 8.2+ event parser to scan any number
of explicit files or directories. Directory scans recursively include `.log`,
rotated `.log.*`, and `.jsonl` files while skipping compressed logs and
directory symlinks. Explicit files are accepted regardless of their extension.

```bash
log-errors storage/logs frontend.log
log-errors --level WARNING --level ERROR --contains checkout storage/logs
log-errors --pattern 'GraphQL|currency' --ignore 'known probe' app.log
log-errors --group exact --full app.log
log-errors --preview app.log
log-errors --format json app.log > error-report.json
log-errors --format jsonl app.log > error-groups.jsonl
```

The default selected levels are `ERROR`, `CRITICAL`, `ALERT`, and `EMERGENCY`.
Selection is `(selected level OR --pattern)`, followed by every literal
`--contains`, then CLI and repository noise exclusions. `--include-noise`
disables only the repository rules. Matching and grouping always operate on the
complete multiline event, so exception stacks are not discarded. JSON always
contains the complete representative raw event; `--full` affects only human
output. Very long one-line messages are shortened in the human summary so
payloads do not overwhelm the screen; `--full` still prints the newest complete
raw event without truncation.

When human output is attached to a terminal, `log-errors` always opens an
interactive, color-preserving `less` investigation view. Use arrow keys or
Page Up/Page Down to scroll, `/` to search case-insensitively, `n`/`N` for the
next/previous match, `&` to show only matching lines, and `m` followed by a
letter to mark a position. Drag normally to select text and use the terminal's
usual copy shortcut (`Cmd-C` on macOS or typically `Ctrl-Shift-C` on Linux).
For a keyboard-selected range, press `ma` to mark one end, move to the other
end, then press `|a` and enter `pbcopy` on macOS or `wl-copy` on Wayland Linux.
Press `q` to close the report. `--no-pager` prints directly; redirection and
JSON/JSONL output never invoke the pager. `--preview` also skips paging and
forces ANSI styling so preview panes (for example `fzf --ansi`) keep severity
colors and header emphasis. If `less` is unavailable, the report prints
directly with a warning.

Smart grouping conservatively replaces volatile identifiers while retaining
application paths and ordinary numbers. Exact grouping ignores capture/event
timestamps only. `--group none` emits each occurrence separately. Machine
output schemas use version 1; JSONL contains only independent `error_group`
records and produces empty stdout when there are no matches.

Exit codes are `0` for a reliable scan (including no matches), `1` for an
unexpected output or pager failure, `2` for invalid invocation, `3` when a
recoverable read or declared-format failure made results partial, `4` for a
missing/incompatible PHP runtime or required core resource, and `130` for an
interrupt. Diagnostics and warnings are written to stderr.

Run the dependency-free checks with:

```bash
php test/log-errors-unit.php
bats test/log-errors.bats
```
