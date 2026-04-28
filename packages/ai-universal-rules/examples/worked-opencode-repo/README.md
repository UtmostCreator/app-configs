# Worked OpenCode Repo

This example shows a realistic OpenCode-first repository install for a fictional `Acme Orders` service.

## What This Example Demonstrates

- stable repo policy in `AGENTS.md`
- durable facts in `docs/ai/project-context.md`
- shared guardrails in `docs/ai/AI-GUARDRAILS.md`
- staged OpenCode agents for research, implementation, and review
- commands as task entry points for planning and bug-fix work
- capabilities and skills as the deeper workflow layer

## Typical Flow

1. run `plan-slice` for multi-step work
2. use `bug-regression` when the task is a bounded bug fix
3. let `researcher` ground unfamiliar areas
4. let `implementer` make the bounded change
5. let `reviewer` audit in a fresh context
6. add `release-auditor` when risk is `medium` or `high`
