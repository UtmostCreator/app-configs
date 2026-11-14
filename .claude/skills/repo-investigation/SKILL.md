---
name: repo-investigation
description: Use when diagnosing a bug, regression, suspicious behavior, or historical change; gather read-only evidence before proposing edits.
---

## What I Do

I run a read-first investigation workflow, gathering exact evidence before proposing any change.

## Choose This Skill When

- You are diagnosing a bug, regression, or unexpected behavior whose cause is still unknown.
- You are tracing change history for a specific file, function, or behavior.
- You need to narrow down the owner or origin of a problem.

## Choose Another Skill When

- Use `repo-search` when you need to locate files or trace references without diagnosis.
- Use `project-context` when you need to understand ownership and boundaries before work.
- Use `bug-reproduction-and-fix` when the cause is known and you are implementing the fix, or when a reproduction needs writes (a test or instrumentation).

## When Investigating

1. Establish the observed behavior, target, and smallest relevant path boundary.
   List the plausible hypotheses and, for each, the smallest read-only observation
   that would disprove it; check the most distinguishing one first, and drop a
   hypothesis only when evidence contradicts it. A failing test is evidence only
   when its failure matches the reported symptom, not a setup or unrelated failure.
2. Start with one bounded native search using the host's read and search tools.
3. Preview candidate files with a bounded ranged read rather than dumping whole files.
4. Use one history command (`git log`, `git blame`, or pickaxe search with `git log -S`) only when provenance would distinguish the remaining hypotheses.
5. Request pull-request or issue context only when the task depends on it, through a read-only tool you already have; if none is available, record the gap instead of reaching for one.
6. Keep diagnostics adaptive: one command per tool call, with the next command chosen from the previous result.
7. Prefer read-only work until root cause is identified.
8. Summarize exact commands used, file paths, line ranges, commits, and confidence.
9. Do not use destructive commands.

## Expected Output

- likely root cause or narrowed hypotheses, with the evidence for and against each
- exact evidence gathered (file paths, line ranges, commit hashes)
- commands run
- remaining uncertainty or next check

## Gotchas

- Do not treat grep hits as root cause without tracing usage.
- Do not propose a fix during the investigation phase; report findings first.
<!-- glyphbrace:user:begin id=user -->
<!-- glyphbrace:user:end id=user -->
