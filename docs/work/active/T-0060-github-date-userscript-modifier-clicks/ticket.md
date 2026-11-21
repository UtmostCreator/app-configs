Source: local

# T-0060: GitHub date userscript blocks modifier and middle clicks on timestamps (bug)

Status: open (verified 2026-11-21 from an external audit)

Written 2026-11-21 against main 0b09964.

## Finding
`home/dot_config/browser/tampermonkey/github-switchable-date-formats.user.js:505-536` blocks click, mousedown and auxclick on managed dates, including Ctrl/Cmd-click and middle-click, so timestamp permalinks cannot be opened in a new tab.

## Acceptance criteria
- AC1: a plain click still switches the date format.
- AC2: Ctrl/Cmd/Shift-click and middle-click pass through to the link unchanged.
- AC3: a test or a recorded manual check covers plain, modifier and middle clicks.
