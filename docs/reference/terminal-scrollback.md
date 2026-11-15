# Terminal scrollback

How much output each terminal keeps so you can scroll back to it. This is
screen history, not shell command history.

| Terminal | Setting | Value | Managed here |
| --- | --- | --- | --- |
| Ghostty | `scrollback-limit-lines` and `scrollback-limit-bytes` | 100000 lines, 400 MB cap per terminal | yes (`home/.chezmoitemplates/ghostty/config.body.tmpl`) |
| tmux | `history-limit` | 100000 lines | yes (`home/dot_tmux.conf`) |
| VS Code | `terminal.integrated.scrollback` | 100000 lines | yes (`home/.chezmoitemplates/vscode/settings.full.json`) |
| Windows Terminal | `historySize` | lines, maximum 32767, default 9001 | no, set on the Windows side |

## tmux

`history-limit` also counts screen rows, so long wrapped lines reduce the
logical line count (about 50k lines of 300 characters at 200 columns). On
tmux 3.8 an existing pane picks up a new limit after `prefix r` or
`tmux set`; lines already trimmed are gone.

## Ghostty

Needs **Ghostty 1.4 or later**. Since 1.4 the line limit is its own option
(`scrollback-limit-lines`, default unlimited) and the byte limit was renamed
`scrollback-limit-bytes` (default 50 MB). The first limit reached wins, so the
400 MB cap is a memory safety net for very wide or styled output. Older
Ghostty rejects `scrollback-limit-lines`, so update it first; on macOS that
means keeping the cask up to date. Scrollback compression stays at its
default.

- The line limit counts screen rows, so a soft-wrapped line counts as several.
- The 400 MB cap is per terminal, meaning each tab or split.
- New limits apply only to new tabs or windows opened after `chezmoi apply`.
- The byte value must be a plain integer; a unit suffix such as `400MB` is
  rejected.

## VS Code

VS Code pre-allocates memory from this value, so a large number costs memory
in every terminal. The setting schema declares no maximum. Rough cost when a
terminal is full: about 240-300 MB per terminal at 200-250 columns (an
estimate, not measured here).

## Windows Terminal and WSL2

Windows Terminal is not managed by this repo. Set `historySize` under
`profiles.defaults` in its `settings.json` on the Windows side (lines, maximum
32767, default 9001).

WSL2 has no terminal of its own: it uses the scrollback of the host terminal.
Inside it, tmux and the shell settings apply as usual.

## Not covered: shell command history

Atuin owns searchable command history (Ctrl-R). None of the settings above
change it, and it does not affect how much screen output a terminal keeps.
