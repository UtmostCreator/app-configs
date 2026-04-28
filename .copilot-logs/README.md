# Copilot Logs

This directory is the repo-local runtime log surface for the stronger `scripts/copilot/` tool layer.

Committed file:

- `README.md` - documents the purpose of this directory

Runtime-generated files are ignored by git and may include:

- `tool-usage.jsonl` for post-tool telemetry
- `watch-loop.jsonl` for watch-session events
- `sessions/` for per-session JSONL traces
- `snapshots/` for rollback patches and refs created by guarded edit flows

When runtime support allows, evidence events should align with:

- `docs/ai/capabilities/agent-observability-and-evidence/CAPABILITY.md`
- `docs/ai/capabilities/agent-observability-and-evidence/EVENT_SCHEMA.md`
- `.schemas/evidence-event.schema.json`

Treat the contents as local runtime artifacts, not canonical policy or durable repository truth.
