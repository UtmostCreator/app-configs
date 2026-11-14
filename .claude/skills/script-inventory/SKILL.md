---
name: script-inventory
description: Use when auditing repository scripts, their risk class, required tools, or drift between what is documented and what actually exists on disk.
---

# Script inventory

Inventory the repository's own automation: what exists, what it mutates, what it
needs, and where the docs disagree with the filesystem.

## Choose This Skill When

- Auditing which scripts a repository ships and what each one is able to change.
- Checking whether documented scripts still exist (and whether existing scripts are
  documented at all).
- Classifying automation by risk before deciding which scripts an agent may run unattended.

## Choose Another Skill When

- Use `select-repo-commands` when you are choosing which command to run for one task rather than auditing them all.
- Use `workflow-drift-audit` when the drift you are chasing is in instruction or adapter files rather than scripts.

## Workflow

1. Run `git status --short` so uncommitted automation is visible.
2. Enumerate executables and script directories from the filesystem — the filesystem
   is the source of truth, not a doc that may be stale.
3. For each script, record: purpose, whether it mutates state, required external
   tools, and its approval posture (read-only / approval-gated / never-auto).
4. Reconcile against whatever script list or docs the repository keeps. Report BOTH
   directions of drift: documented-but-missing, and present-but-undocumented.
5. Mark anything you cannot prove `unknown` rather than assuming it is safe.

## Output

- one row per script: path, purpose, mutates-state, required tools, risk class
- documented-but-missing entries
- present-but-undocumented entries
- scripts whose risk class could not be determined (`unknown`)

## Gotchas

- Absence from the documented list does not make a script safe — it makes it unreviewed.
- Never infer risk from a script's name or convenience; read its body and what it writes before classifying it.
<!-- glyphbrace:user:begin id=user -->
<!-- glyphbrace:user:end id=user -->
