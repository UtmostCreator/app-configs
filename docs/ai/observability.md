# AI Observability

Use two files for every non-trivial AI session:

- `docs/ai/generated/sessions/SESSION_ID/events.jsonl` for append-only machine events.
- `docs/ai/generated/sessions/SESSION_ID/summary.md` for human handoff and re-entry context.

The `.ai-logs/` directory remains local runtime evidence. Durable session handoff belongs under `docs/ai/generated/sessions/` so a later agent can load it deterministically.

## Required Events

Record material actions as JSONL records:

- `session.start`
- `user.query` with a summary or hash, not the full private prompt by default
- `context.loaded`
- `file.read`
- `file.edit`
- `command.pre`
- `command.post`
- `decision`
- `verification`
- `approval` or `denial`
- `error`
- `session.end`

Each event should follow `.schemas/ai-session-event.schema.json` and include stable `trace_id`, `session_id`, `task_id`, timestamp, actor, tool, authorization, and execution fields.

## Repository Tools

Prefer these tools over ad hoc files:

```bash
php tools/ai/session-start.php --session-id <id> --task "short task" --agent <agent>
php tools/ai/agent-log.php --session-id <id> --type decision --summary "why this approach"
php tools/ai/session-end.php --session-id <id> --status partial --next-step "run focused verification"
php tools/ai/validate-session-log.php <id>
```

Runtime hooks may also mirror events from `.ai-logs/tool-usage.jsonl` into `docs/ai/generated/sessions/SESSION_ID/events.jsonl` when `SESSION_ID` is available.

## Redaction Rules

Never log secrets, `.env` contents, tokens, credentials, raw private prompts, large command output, vendor dumps, or full sensitive stack traces. Use summaries, hashes, paths, exit codes, and redacted previews instead.

## Generated Artifact Posture

Session files under `docs/ai/generated/sessions/` are runtime-generated handoff artifacts. They may be created locally during AI work and validated with `php tools/ai/validate-session-log.php`.
