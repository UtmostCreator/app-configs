# ADR-0009: Two machines, one history: push/pull, desktop first, file ownership
Status: decided · Date: 2026-11-15 · Sources: T-0047 ticket (Transfer, Coordination) and plan (Decisions), `AGENTS.md`

## Decision
- Changes that affect the NixOS desktop are made and verified there first, then reach WSL and Windows.
- Sync by commit and push to origin, `git pull --ff-only` before work and before each commit. No force-push, rebase or stash.
- Each session confirms its own push authorisation for its task.
- Files are split between the Windows session and the NixOS session (owned-files lists in the T-0047 ticket).

## Why
- The desktop is the real system layer; untested desktop-affecting changes would first meet it in production.
- Fast-forward-only keeps one linear history with no silent overwrites between concurrent sessions.
- `AGENTS.md`: authorisation does not carry over; the stash is shared across worktrees.
- Disjoint file ownership avoids collisions (Windows files stay untracked until their commit).

## Strong alternatives
| Option | Why it lost |
|--------|-------------|
| git bundle by hand | The first choice; replaced once pushing was authorised (2026-11-15): more manual steps. |
| WSL first, desktop later | Desktop-affecting changes would be untested on the real desktop. |

## Discarded
Force-push, rebase and stash as sync tools.

## Consequences
- Slower for WSL: it waits for the desktop checks (D0) and the pushes.
- Collision risk remains for untracked Windows files; they are moved aside by the user before a pull that adds them.
- Revisit if the desktop ceases to be the reference machine.
