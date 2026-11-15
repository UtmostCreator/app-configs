# T-0050 findings: additions to the ticket
Date: 2026-11-15 · The ticket file itself is frozen; this file adds to it.

## Scope widened (user, 2026-11-15)
- Every CLI command we run for installation must make clear what happened and the success status.
- The user always sees feedback and, where helpful or critical, the next step.

## Output contract (proposed)
| Rule | Detail |
|------|--------|
| Per step | Print start, then result. |
| PASS | Done now. |
| SKIP | Already done; say what was found. |
| REBOOT_REQUIRED | A reboot is needed before continuing. |
| BLOCKED | A prerequisite elsewhere (e.g. the D0 gate); say what and where. |
| DEGRADED | Continued without an optional part. |
| FAIL | What failed, plus the command to retry. |
| Summary | Final block, one line per step with its result, then exactly one "Next:" line. |
| Long waits | Start line with the expected duration; heartbeat or progress at least every 30 s. |
| No false completion | Never an intermediate message that reads like completion ("imported NixOS" was mistaken for "installation complete" by outside reviewers). |

## Observed in the real runs (2026-11-15)
- About 3 min of silence before step 0 (wsl.exe probes and the restore point).
- Steps 0 and 1 printed nothing on run 2.
- No progress on the ~550 MB download.
- The step-6 message mentions git bundle.
- `The operation completed successfully.` (from wsl --import) appears without context.
- No final summary and no next action.

## New acceptance checks
- AC-6: final summary and a single Next line on every exit path.
- AC-7: the result vocabulary is used consistently; tests assert each step emits exactly one result.
- AC-8: a third run with everything installed prints only SKIP/PASS lines and changes nothing (idempotency test).
- AC-9: the same contract is documented for the bash installers (`ops/install.sh`, `ops/update-all.sh`, `ops/system-setup.sh`), with gaps listed.

## Not adopted (outside reviews)
- Persisted checkpoint or state machine: we re-probe real state on every run, no state file, by design.
- Generic checkpoint engine or a second bootstrap.
- Pester: plain PowerShell tests chosen; no extra modules on a fresh Windows.
- Explicit --system/--user/--resume modes: the elevation rule already separates them; revisit if confusing.
