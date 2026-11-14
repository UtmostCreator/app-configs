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

`log-errors` now lives in restsift: the `log-errors` command (fish function,
zsh alias) runs `res log-errors`, with the same flags (`--level`,
`--contains`, `--ignore`, `--pattern`, `--group`, `--full`, `--format`,
`--include-noise`, `--no-pager`, `--preview`). The PHP copy that lived here
was retired on 2026-11-14; differences found when retiring it are tracked in
restsift ticket T-0229.
