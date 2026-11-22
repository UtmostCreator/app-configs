# niri shell: Dux Modular Shell vs Noctalia v5

**Installation/selection status:** [ADR-0046](../architecture/decisions/0046-niri-desktop-installation-decision-register.md) is the current registry. This issue assessment is evidence for the Dux → Noctalia trial, **not** a permanent shell selection or proof that a reported issue remains open in the pinned release.

## 1. Status and provenance

Two assessments supplied by the user on 2026-11-15, compiled from upstream
GitHub issues and docs. The issue numbers, dates and fix states below have NOT
been independently verified in this repo. Treat all of them as **user-supplied,
unverified (not fetched here)**. Evidence labels VERIFIED, INFERRED and WEB
follow `docs/plans/niri-migration.md` (lines 12-13); WEB there means fetched on
2026-11-15, which does not apply to the user-supplied items, so none of them is
labelled WEB. Only section 6 contains local facts, and each names its command.

Nothing in this note changes a decision.

## 2. Decision context (unchanged)

- Trial order: Dux first, Noctalia second (`docs/plans/niri-migration.md`,
  "Trial order (DECIDED)"). No permanent shell is selected.
- Vicinae stays the launcher.
- Exactly one owner each for notifications, clipboard history, lock/idle and
  polkit authentication.

## 3. Feature and architecture comparison (assessment 1, condensed; user-supplied, unverified)

| Aspect | Dux Modular Shell | Noctalia v5 |
|---|---|---|
| Runtime | QML and Go | Native C++ runtime |
| Extensibility | `dms` CLI and IPC; plugin lockfile | Luau-sandboxed plugins |
| Nix integration | Upstream HM module; the pinned nixpkgs ships only a NixOS module (repo fact, plan :141) | Not covered by the assessment |
| Config | Not covered by the assessment | Layered TOML, with separate GUI state overrides |
| Notifications | Not covered by the assessment | Encrypted notification history |
| Polkit | Not covered by the assessment | Opt-in native agent (`polkit_agent`, default false) |
| Other | Not covered by the assessment | Night light |

Provisional weighted scores (judgements, not measurements): Dux 87, Noctalia 88.
Within 5 points counts as a tie. The permanent-selection bar is 90 or more on
the runtime acceptance matrix, with no failed critical check. Assessment 1 also
had an earlier, differently weighted matrix (Dux 76, Noctalia 83); this is also
a judgement. Neither pair is evidence for or against a shell.

Recommendations from the assessment (not decisions):

- Keybindings: both shells' stock niri binds clash with the user's keys
  (Mod+Space, Mod+D, Mod+Shift+E). Use the repo's KDL binds only.
- Clipboard history goes to Vicinae: set Dux's `clsettings.json`
  `disabled = true`, and Noctalia's `clipboard_enabled = false`. The owner is
  still open plan decision 11 (recommended there: Vicinae).
- Screenshots go to Flameshot first. Still open plan decision 7 (reproduce
  Flameshot first).
- Disable Noctalia's git plugin auto-update (keeps plugins in the Nix closure).

## 4. Issue audit (assessment 2; user-supplied, unverified)

| Shell | Issue | State | Severity class | Trigger | Test that detects it (this note) |
|---|---|---|---|---|---|
| Dux | #4259 | OPEN, unfixed in 2.1.2 | Session crash or data loss | Lock screen leaks about 100 MiB per monitor reconnect while locked; ends in an OOM that kills niri | Lock, reconnect an external monitor N times, record shell RSS (T-0032 shell trial gates) |
| Dux | #2789 | Fixed in 1.5.1; U2F unlock reported still failing | Unusable session (if a security key is used) | U2F unlock | U2F unlock, only if a security key is used |
| Dux | #359, #2945/#2725, #1753, #4074, #778 | Fixed | Not rated | Not stated | None needed beyond the general matrix |
| Dux | #1153 (IPC on NixOS/niri) | Fixed | Unusable session if it regressed | Shell IPC | IPC check on NixOS/niri |
| Noctalia | #5349 | OPEN (seen on 5.4.1) | Unusable session | Fatal wl_registry error on resume after unplugging an output; session stays locked, re-login needed | Lock, suspend, unplug an output, resume |
| Noctalia | #4714 | OPEN | Unusable session (hybrid NVIDIA only) | Invisible UI with egl-wayland 1.1.23 on NVIDIA PRIME hybrid systems | Render check on this GPU setup |
| Noctalia | #4565 | OPEN enhancement | Unusable auth flow | No warning when no polkit agent runs; `polkit_agent` defaults to false | Exactly one polkit agent runs and a prompt appears |
| Noctalia | #3540 | OPEN | Cosmetic | Keyboard backlight lost after suspend | Optional: suspend, check backlight |
| Noctalia | #2836 | Fixed | Intermittent crash | Notification flood while locked | Notification flood while locked, then unlock |
| Noctalia | #3062, #3598, #3123, #3296, #4668 | Fixed | Not rated | Not stated | None needed beyond the general matrix |
| Noctalia | #1325 (Flameshot) | Fixed | Unusable workflow if it regressed | Flameshot capture and pin | Flameshot capture and pin |
| Noctalia | #1768 | Likely a compositor fault, not the shell | Not rated | Not stated | None |

Severity order used by the audit: session crash or data loss > unusable session
> intermittent crash > cosmetic. The "severity class" column is the audit's
ordering applied by the person compiling this note; individual ratings for
fixed issues are not stated in the assessment.

## 5. The audit's verdict (attributed to assessment 2)

Noctalia currently carries more "session unusable" risk on hybrid GPU and on
resume with output changes. Dux's main open risk is the lock-screen leak under
repeated monitor reconnects. This is the assessment's conclusion, not a result
of this repo.

## 6. Relevance to this machine (local, read-only, 2026-11-15)

- `lspci` is not installed here (`lspci -nn | grep -Ei 'vga|3d|display'`
  returns "command not found"). The same fact was read from sysfs instead:
  `for d in /sys/class/drm/card[0-9]; do echo $d $(cat $d/device/vendor) $(cat $d/device/device) $(basename $(readlink $d/device/driver)); done`.
- VERIFIED result: card1 is vendor 0x10de (NVIDIA), device 0x2860, bound to the
  `nouveau` driver; card2 is vendor 0x1002 (AMD), device 0x15bf, bound to
  `amdgpu`. So the machine is a hybrid AMD iGPU + NVIDIA dGPU, which matches the
  plan's "Hybrid GPU" note.
- VERIFIED connectors (`cat /sys/class/drm/card*-*/status`): only `eDP-2`
  (on the AMD card) is connected at the time of reading; no external monitor was
  attached. Monitor count at read time: 1.
- Relevance of Noctalia #4714: INFERRED (from the unverified issue description) not applicable now, because the report
  concerns egl-wayland with the proprietary NVIDIA driver and this machine
  runs nouveau on the dGPU. It becomes relevant if the proprietary NVIDIA driver
  is ever enabled. Still run the render check, since the machine is hybrid.
- Relevance of Dux #4259 and Noctalia #5349 depends on external monitors, so
  the trial needs an external display attached (the plan mentions external DP-3).
