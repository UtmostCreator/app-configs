<!-- glyphbrace: kit document. Replaced by `glyphbrace update` unless you edit it; an edited copy is kept and reported. -->
---
documentation:
  schema_version: 1
  id: TPL-0003
  kind: template
  status: template
  summary: Context Economy
  review:
    approval_ref: unknown
    summary_by: agent
---
# Context Economy

Use the smallest context that proves the work. This file keeps token and context usage bounded.

## Core Rule

Before adding context, prove the model needs it. Prefer a bounded read over a broad one, and a scoped command over an unscoped one.

## Search And Read Discipline

- Search for the narrowest scope that answers the question: the changed files first, then the tracked tree.
- Read ranges around the line that matters instead of whole large, generated, or vendored files.
- Do not dump entire files when a range proves the point.

## Command Output Discipline

Shell output enters context verbatim, so cap or scope it before running:

- Prefer `git log --oneline -20` over unbounded `git log`.
- Scope searches to relevant paths and exclude `vendor/`, `node_modules/`, and generated bundles.
- Keep a bounded excerpt of a failed test or build, plus where the full output was saved. Do not rely on an arbitrary `tail` as the only failure evidence.
- Never inject full logs unless analyzing the full log is the task.

## Session Discipline

- Keep one task per session where practical; start a fresh session for unrelated work rather than growing one long mixed-topic session.
- Before switching tasks or compacting, write down exact paths, versions, decisions, and the next step (see [`session-reentry.md`](session-reentry.md)).
- Load a given skill once per session where possible; repeated loads re-inject the full skill content.
