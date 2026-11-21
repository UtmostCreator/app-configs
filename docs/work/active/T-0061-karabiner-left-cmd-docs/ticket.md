Source: local

# T-0061: Karabiner docs say Right Cmd, the config uses Left Cmd (docs)

Status: open (verified 2026-11-21 from an external audit)

Written 2026-11-21 against main 0b09964.

## Finding
The Karabiner config in `home/` has 17 `left_command` and 1 `left_gui` and no right-side modifier, while `keyboard.md:167,168,255` and the `karabiner.json` description at line 86 say "Right Cmd". `docs/reference/hotkeys.yaml:6-11` already records the mismatch.

## Acceptance criteria
- AC1: the owner confirms the intended side on the Mac (no binding changes without that confirmation).
- AC2: `keyboard.md`, the karabiner.json descriptions and `hotkeys.yaml` agree with the config.
- AC3: a bats check compares the modifier side in karabiner.json with the documented side.
