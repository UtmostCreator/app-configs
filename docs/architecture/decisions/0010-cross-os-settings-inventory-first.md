# ADR-0010: Cross-OS settings: inventory before alignment
Status: decided; phase 1 (Windows inventory) done, read-only · Date: 2026-11-15 · Sources: T-0048 ticket and windows.yaml (docs/work/active/T-0048-cross-os-settings)

## Decision
- One YAML inventory per system with real values, then compare, then choose a baseline, then per-host overrides, then an optional apply command.
- Nothing is applied until the WSL2 milestone (T-0047) is done. A value that cannot be read is `unknown`; never guess.
- NixOS-WSL gets no inventory: it inherits display and power from Windows.

## Why
- Alignment needs facts from each machine first; every Windows value was read by a stated command.
- Read-only probes change no setting, so phase 1 is safe now.
- Per-device settings (brightness, scaling, audio, fonts) are skipped on purpose.

## Strong alternatives
| Option | Why it lost |
|--------|-------------|
| Apply "common defaults" from outside research directly | Session decision 2026-11-15: its values were guesses and partly wrong for this PC. Example: display-off here is 5 min on AC and 3 min on battery (windows.yaml). The research values are not recorded in the repo. |

## Discarded
None recorded.

## Consequences
- Phases 2 to 5 (NixOS and macOS inventories, baseline, overrides, apply command) are not started.
- Open: where per-host override data lives (chezmoi data, nix vars or a new directory); whether the apply command may change Windows power settings (needs admin).
- Later apply steps need a restore point (`powercfg /export`) and a `--dry-run` first.
- NixOS and macOS read commands in the ticket are unverified research input.
