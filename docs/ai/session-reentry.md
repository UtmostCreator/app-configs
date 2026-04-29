# Session Re-entry And Checkpoints

Use this process to reduce lost AI work during long tasks.

## Re-entry Steps

1. Re-read `docs/ai/project-context.md` and current task scope.
2. Check branch and working tree status.
3. Review latest AI session log entries under `.copilot-logs/`.
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

Snapshots are stored in `.copilot-logs/snapshots/` and session logs in `.copilot-logs/tool-usage.jsonl`.
