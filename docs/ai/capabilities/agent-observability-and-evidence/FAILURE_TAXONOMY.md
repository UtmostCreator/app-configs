# Failure Taxonomy

Use these normalized categories for agent evidence events.

## Categories

- `authorization_denied`
- `approval_missing`
- `tool_unavailable`
- `tool_timeout`
- `invalid_tool_input`
- `unsafe_mutation_blocked`
- `test_failure`
- `lint_failure`
- `schema_validation_failure`
- `context_missing`
- `model_hallucination`
- `non_reproducible_result`
- `cost_budget_exceeded`
- `external_dependency_failure`
- `human_review_required`
- `unknown`

## Mapping Notes

- Map command-level `policy-blocked` to `authorization_denied` or `unsafe_mutation_blocked` based on evidence.
- Map command-level `approval-blocked` to `approval_missing`.
- Map command-level `environment-missing` to `tool_unavailable`.
- Map command-level `transient-runtime` timeout evidence to `tool_timeout`.
- Map command-level `usage-error` to `invalid_tool_input` when the issue is tool invocation.

Command-level taxonomy in `docs/ai/failure-handling.md` remains the canonical retry policy for operator actions.
