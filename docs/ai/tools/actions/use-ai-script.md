# Use AI Script

Use this action when you need a repository script and want deterministic, policy-aligned execution.

## Preconditions

1. Confirm the script exists in `docs/ai/script-registry.json`.
2. Confirm the same script appears in `docs/ai/script-registry.md` and `docs/ai/scripts-reference.md`.
3. Respect risk level from the registry:
   - `read-only`: run directly within existing approval boundaries.
   - `mutating`: request explicit approval before execution.

## Command Pattern

```bash
bash scripts/ai/SCRIPT_NAME.sh [args]
```

Prefer JSON output mode where supported:

```bash
AI_OUTPUT=json bash scripts/ai/SCRIPT_NAME.sh [args]
```

## Escalation Rules

- Start with narrow read-only wrappers (`ai-search`, `preview-file`, `query-usage`, `ai-diff-context`).
- Escalate to broader or mutating wrappers (`ai-verify`, `pack-context`, `ai-edit`, `ai-rollback`, installer scripts) only when required by scope and approvals.
- If `bash` is unavailable, report `unknown` for command evidence rather than claiming execution.

## Evidence Format

- command
- result (success/failure/unknown)
- files or lines impacted
- gaps and safest next step
