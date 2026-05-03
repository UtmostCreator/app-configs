# Workflow

## Default Task Flow

1. route through `project-context` when ownership is unclear
2. use `plan-slice` or a planning agent for multi-step work
3. implement the bounded slice
4. review the diff in a fresh context
5. use `release-safety` when risk is `medium` or `high`

## Entry Point Examples

- bounded bug fix -> `bug-regression`
- existing diff review -> `review-diff`, then `release-safety` when risk justifies it
- behavior-following docs update -> `docs-sync`
