# Session Re-entry And Checkpoints

Use this process to reduce lost AI work during long tasks.

## Re-entry Steps

1. Re-read `docs/ai/project-context.md` and current task scope.
2. Check branch and working tree status.
3. Review latest durable AI session entries under `docs/ai/generated/sessions/`, then local hook evidence under `.ai-logs/` if needed.
4. Restore or inspect the latest snapshot artifact if needed.
5. Continue with one bounded slice only.

## Checkpoint Rules

- Create a snapshot before risky or broad edits.
- Create a snapshot before switching task focus.
- Create a snapshot before handoff/review.

## Commands

```bash
bash scripts/ai/session-checkpoint.sh before-edit
bash scripts/ai/session-checkpoint.sh handoff
```

Snapshots are stored in `.ai-logs/snapshots/`. Local hook evidence is written to `.ai-logs/tool-usage.jsonl`; durable handoff logs are written to `docs/ai/generated/sessions/SESSION_ID/events.jsonl` with summaries in `docs/ai/generated/sessions/SESSION_ID/summary.md`.
