# Event Schema

Use this schema model for durable agent evidence events when the runtime surface supports structured logs.

Canonical schema file: `.schemas/evidence-event.schema.json`

## Required Fields

- `event_version`
- `event_type`
- `trace_id`
- `session_id`
- `task_id`
- `timestamp`
- `actor.type`
- `actor.id`
- `tool.name`
- `tool.mutates_state`
- `authorization.decision`
- `execution.status`

## Optional But Recommended Fields

- `actor.delegated_by`
- `tool.args_hash`
- `authorization.approval_required`
- `authorization.approved_by`
- `authorization.reason`
- `execution.latency_ms`
- `execution.retry_count`
- `execution.exit_code`
- `execution.output_truncated`
- `cost.model`
- `cost.input_tokens`
- `cost.output_tokens`
- `cost.estimated_cost_usd`
- `failure.category`
- `failure.message`
- `failure.resolution`
- `repository.root`
- `repository.git_branch`
- `repository.git_commit`
- `output.preview`
- `details`

## Minimal Example

```json
{
  "event_version": "1.0",
  "event_type": "tool.result",
  "trace_id": "trc_example_001",
  "session_id": "ses_example_001",
  "task_id": "tsk_example_001",
  "timestamp": "2026-04-25T00:00:00Z",
  "actor": {
    "type": "agent",
    "id": "coding_agent",
    "delegated_by": "user_local"
  },
  "tool": {
    "name": "ai-edit.sh",
    "category": "repo_mutation",
    "args_hash": "sha256:example",
    "mutates_state": true
  },
  "authorization": {
    "policy_version": "1",
    "decision": "allowed",
    "approval_required": false,
    "approved_by": null,
    "reason": null
  },
  "execution": {
    "status": "success",
    "latency_ms": 320,
    "retry_count": 0,
    "exit_code": 0,
    "output_truncated": false
  },
  "cost": {
    "model": null,
    "input_tokens": null,
    "output_tokens": null,
    "estimated_cost_usd": null
  },
  "failure": {
    "category": null,
    "message": null,
    "resolution": null
  },
  "repository": {
    "root": "/workspace/app-configs",
    "git_branch": "main",
    "git_commit": "abc123"
  },
  "output": {
    "preview": "ok"
  },
  "details": {
    "tool_args": {
      "command": "bash scripts/ai/ai-search.sh hooks"
    }
  }
}
```
