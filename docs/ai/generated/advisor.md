# Advisor

- Status: `ok`
- Generated at: `2026-05-10T10:32:57+00:00`
- Commit: `06dde0c`
- Branch: `codex/integrate-ai-search-scripts-into-project`
- Recommended next action: `Run advisor --check to enforce deterministic advisor outputs.`

```json
{
    "schema_version": 1,
    "artifact": "advisor.json",
    "generated_at": "2026-05-10T10:32:57+00:00",
    "command": "php tools/ai/ai.php advisor",
    "based_on_commit": "06dde0c",
    "based_on_branch": "codex/integrate-ai-search-scripts-into-project",
    "input_hashes": {},
    "status": "ok",
    "score": null,
    "stale": false,
    "recommended_next_action": "Run advisor --check to enforce deterministic advisor outputs.",
    "data": {
        "status": "ok",
        "events": [],
        "outputs": {
            "project_signals": "docs/ai/generated/project-signals.json",
            "project_scorecard": "docs/ai/generated/project-scorecard.json",
            "secret_findings": "docs/ai/generated/advisor-secret-findings.json",
            "token_budget": "docs/ai/generated/advisor-token-budget.json",
            "context": "docs/ai/generated/advisor-context.md",
            "prompt": "docs/ai/generated/advisor-prompt.md",
            "baseline": "docs/ai/generated/advisor-baseline.json",
            "drift": "docs/ai/generated/advisor-drift.md",
            "submit_dry_run": "docs/ai/generated/advisor-submit-dry-run.json"
        }
    }
}
```
