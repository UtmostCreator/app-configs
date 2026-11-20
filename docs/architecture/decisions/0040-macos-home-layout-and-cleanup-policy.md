---
adr: 40
title: "macOS home directory layout and report-only cleanup policy"
status: proposed
date: 2026-11-20
platforms: [macos]
areas: [home-layout, cleanup, retention, ai-agent-data, privacy, safety]
permits: [scratch-and-archive-roots, report-only-cleanup, report-only-inventory, native-cache-commands]
forbids: [automatic-delete-outside-scratch, symlink-following-cleanup, raw-inventory-in-repo, repo-run-homebrew-cleanup, automatic-agent-session-pruning, automatic-cache-cleaning, purge-without-separate-approval]
amends: []
supersedes: []
superseded_by: []
related: [28, 32, 33, 21, T-0046, T-0048]
---
# ADR-0040: macOS home directory layout and report-only cleanup policy
Status: proposed (a read-only inspection of one work Mac and outside reviews recommended it; no owner decision yet; this change adds ADR text only and nothing in the home directory is created, moved or removed) · Date: 2026-11-20 · Sources: a read-only inspection on 2026-11-20 (sizes, counts and `git status --no-optional-locks` only)

Backup and restore are ADR-0033. File managers and disk-usage tools are ADR-0028. AI CLI tools are ADR-0032. This ADR covers where files live on a macOS work host and what a cleanup may ever touch. Names are generic on purpose (see Privacy).

## Context
The inspection measured sizes and counts, not contents. It identified potential cleanup opportunities. It did not establish that anything is redundant or how much space is reclaimable.
- Home use is dominated by the system Library (about 50 GiB, of which application caches are about 7 GiB), then the development root (about 19 GiB in 38 direct children), Downloads (about 6.7 GiB, 45 items older than 30 days), a container VM store (about 4 GiB) and tool caches (about 2.5 GiB under `~/.cache`, 1.9 GiB npm, 1.2 GiB nvm, 2 GiB pnpm).
- The development root mixes active repositories with copies and tests: one `<project>-copy` repository with uncommitted changes and its own remote, one repository copy with a space in its name and uncommitted changes, one test directory with no Git history, and three linked worktrees for finished tickets (one has uncommitted changes).
- AI agent session history is the largest visible agent store: about 0.8 GiB in 316 entries, 228 of them older than 30 days. Age does not show that a session is unneeded.
- Disposable-looking output (benchmarks, logs, investigation exports, history exports) is spread across the home root: 22 loose non-standard items.
- `~/scripts` holds five symlinks that point into a second scripts directory by absolute home path. All resolve; none is broken.
- One configuration directory has a name that looks like a typo of another one that also exists.
- Six user LaunchAgents are installed.

## Decision (proposed)
- Keep the current development root, scripts directory, Documents layout and every tool's own directory where they are. Moving them risks local web servers, containers, editor workspaces, shell shortcuts and Git worktrees. Use any new layout for new work only.
- Add two top-level directories, provisioned idempotently by the configuration system after this ADR is accepted (create when missing, never move or change existing content):
  - `Scratch/` for disposable generated output, with `temp`, `logs`, `benchmarks`, `reports` and `screenshots` inside. `screenshots` is only for screenshots you know are temporary: it expires after 14 days, so do not make it the system screenshot destination, and keep screenshots you want in protected storage.
  - `Archive/` for reviewed historical material (`projects`, `snapshots`, `imports`). Archive is not a backup (ADR-0033).
- Cleanup has three classes:

| Class | Where | Rule |
|---|---|---|
| Automatic (report-only until separately approved) | regular files in the allowlisted `Scratch` subdirectories only | `temp` 7 days, `screenshots` 14 days, `logs`, `benchmarks` and `reports` 30 days, as initial defaults |
| Review first | Downloads (disk images, installers, partial downloads, saved web pages, other files after 30 days), generated project output, dependencies of archived projects | listed by a report; the owner decides |
| Protected | project sources, Git directories and worktrees, Documents, Archive, the Library application data, keychains, containers, mail, SSH and tool configuration, VM disks, database dumps, AI agent session history and checkpoints | never touched by a job |

- Automatic deletion is not approved. The first step is a read-only inventory and report.

## Cleanup safety contract
Any future cleanup implementation must meet all of these. They are rules for the implementation, not a description of one that exists.

| Concern | Rule |
|---|---|
| Default behaviour | Dry-run always. A destructive mode needs explicit configuration and owner approval. |
| Roots | Only the allowlisted `Scratch` subdirectories. A protected path can never become a target. |
| Path validation | Canonicalise each root, verify that every candidate is contained in it, and reject a candidate if any component of its path is a symlink. |
| Filesystem boundary | Never cross into another mounted filesystem. |
| Eligibility | A directory is eligible only if the owner has put it under the cleanup system explicitly (a marker created when it is provisioned), not because of its name. Within it, only ordinary files that are not symlinks, not hard-linked more than once, owned by the user, older than the retention by last-modified time (not last-access time) and not open where that can be detected reliably. Files changed in the last 24 hours and files with partial-download, temporary or lock suffixes are skipped, so active or incomplete output is never taken. Age alone is not proof that a file is unused. |
| Identity | Re-check the file's identity (path, type, size, modification time, inode) immediately before any move, so a swap between scan and action is caught. |
| Errors | Fail closed on an unreadable root, a permission error or an ambiguous path. Skip, report, and do not continue past a root-level failure. |
| Concurrency | One run per root at a time, enforced by a lock. |
| Reporting | A report that leaves the machine or goes into the repository has file count, bytes, age bucket and action only: no file names, paths, symlink targets or contents. Restoring a quarantined file needs its original location, so that lives in a separate private recovery manifest (owner-only permissions, inside the quarantine directory), which is never published, committed or sent to another host. |
| Directories | A cleanup never recursively deletes a directory. Removing an emptied directory is a separate, non-recursive step and only inside quarantine. |

### Lifecycle
Implementation is in two stages. Stage 1 is a small Bash script for the read-only inventory and report. Stage 2 (quarantine and restore) is separately approved, designed and tested, and does not start until Stage 1 has shown that real reclaimable space exists. No custom filesystem mutation engine is built to complete this ADR.

1. Discover: allowlisted roots only.
2. Validate: type, age, owner, path, hard links, exclusions.
3. Report: no change to any scanned file. A strictly read-only audit writes to standard output only, takes no lock and writes no log. This is the only step approved by this ADR.
4. Quarantine (separately authorised): move eligible files on the same filesystem into a dedicated quarantine directory (`Scratch/.quarantine`) that is outside every cleanup allowlist, so discovery can never select quarantined files. Keep their relative paths and a manifest of size, modification time and a content hash, owner-only, written so an interrupted run can be recovered. Races between scan and move matter here: a shell `find | mv` pipeline is not enough, so this stage needs file-safe operations (acting on the opened file, no path re-resolution).
5. Restore or purge (separately authorised): restore puts the original name back at the original location and refuses to overwrite anything that exists. Purge removes only files listed in a manifest, after the hold period (initial default 14 days), and is not scheduled until a restore from quarantine has been tested successfully.

### Scheduling (future requirement, nothing exists yet)
If a scheduled report is ever built, it should be a user LaunchAgent that runs the report at low priority. A scheduled run may keep a lock and a counts-only log under `Scratch/logs`; that changes `Scratch/logs` and nothing it scans. The manual, strictly read-only audit uses neither. Skipping on battery power is optional for a read-only report and required for any mutating step. The same policy file would drive Linux systemd user timers; only the scheduler differs.

### Backup requirement
Quarantine is not a backup. Before quarantine or purge is enabled, a representative file must have been restored from the independent backup (ADR-0033), and the report must say when the last successful backup was. Cleanup never runs on data that is the only copy.

## Other rules
- Developer caches are cleaned only by the tool's own command, by hand and only under real disk pressure (proposed trigger: free space below 15% of the volume; the owner sets it), never just because a cache exists. `go clean -cache` removes the build cache; the module download cache is removed by `go clean -modcache`, which forces re-downloads and is used only on purpose. `pnpm store prune` removes unreferenced packages. Run `brew cleanup -n` and read it before `brew cleanup`. No repo script, hook or test runs Homebrew maintenance (a full test run once ran `brew update` and `brew upgrade` on a real Mac; tests are now isolated).
- AI agent data: each provider owns its session store. Use the provider's housekeeping commands after reading what they do, by hand. Automatic pruning of agent sessions and checkpoints is not approved. Disposable agent-written reports go to `Scratch/reports`.
- Duplicates and worktrees: audit with read-only Git (`worktree list --porcelain`, `worktree prune --dry-run`, `status --porcelain --no-optional-locks`). Remove a finished worktree only with `git worktree remove` without `--force`; Git refuses an unclean worktree, which is the safety net. Compare a repository copy with its original first.
- Shared configuration and symlink creation use `$HOME` and named roots (`DEV_ROOT`, `SCRIPTS_ROOT`, `SCRATCH_ROOT`) or relative targets, never an absolute home path.

## Verification before any filesystem mutation
Run only against a temporary fixture directory, never real home content, and inside the existing test isolation (tests cannot reach real package managers).

| Test | Expected |
|---|---|
| Dry-run on fixtures | Filesystem state is unchanged |
| Old ordinary file | Appears in the report |
| Recent file | Skipped |
| Symlink pointing outside the root | Skipped |
| Nested symlink or manipulated path | Rejected |
| Protected root or project directory | Cannot become a target |
| Names with spaces, Unicode or newlines | Handled without truncation or command injection |
| Missing or unreadable root | Fails safely |
| Quarantine, then restore | Same content and path, no overwrite |
| Interrupted run | No corrupted file and no lost manifest |

The ADR contract test also needs a green Linux run before this ADR is accepted (macOS `sed` rejects some of its GNU-only seeded edits).

## Metrics (anonymous)
Per run: files eligible, bytes eligible, files quarantined, files restored, files skipped by reason. No names. After a few weeks the totals show whether cleanup is worth building further.

## Operation
Review: read the report. Restore: run the restore step for one run identifier. Disable: unload the agent or set the mode back to dry-run. Troubleshoot: a held lock means another run is active; the log under `Scratch/logs` has counts only.

## Privacy
The repository is public. This ADR and any later inventory, report, error message, example command or symlink target keep counts and rounded sizes only. They contain no user name, host name, project, client, ticket or incident name, and no file contents or secrets. Raw directory trees stay out of the repository.

## Why
- The inspection found places worth checking (copies, worktrees, Downloads, agent history), but it did not show that any of it is reclaimable, so the policy starts with a report.
- A small allowlisted disposable area gives any automation a safe target; everything else needs a human.
- Tests, hooks and the repo never run package-manager maintenance, which keeps one incident from repeating.

## Strong alternatives
| Option | Why it lost |
|---|---|
| A full new `Workspace` hierarchy with moved repositories | The move is risky for tools that depend on current paths, and the gain is mostly navigation. |
| Scheduled deletion of caches and logs under the Library | macOS and the applications manage them; blanket deletion can remove state. |
| Deleting agent session directories by age | Sessions hold resume points and checkpoints; age does not show they are unneeded. |
| A dedicated cleanup framework | Not needed: a small report-only script and a policy file are enough until the report shows real savings. |

## Consequences
- This ADR creates no directory, job, timer or script. The next step, if accepted, is Stage 1 only: a minimal, anonymised, read-only inventory report that measures what is really reclaimable.
- Open owner questions: accept the two new directories and the retention defaults; whether a report-only script is wanted and where its policy lives; the disk-pressure threshold; the quarantine hold period; the investigations below.
- Investigations, in order: which of the old Downloads items account for most of their size; the three finished worktrees, especially the dirty one; the two repository copies against their originals; the application-cache total by application; the agent sessions through the provider's own commands; the six LaunchAgents for obsolete paths and failures; the two similarly named configuration directories; and what is actually backed up and restorable.
- Related open work: T-0046 (first-run readiness, including the LaunchAgent paths) and T-0048 (settings inventory).
