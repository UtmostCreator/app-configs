# Install For GitHub Copilot

Use this guide for the smallest useful Copilot setup.

For the full operating model, read:

- `docs/workflows/SYSTEM-WORKFLOW.md`
- `docs/workflows/TASK-ENTRYPOINTS.md`
- `docs/foundations/COMPATIBILITY.md`

## Recommended Base Install

Start with the most stable primitives first:

- `templates/core/copilot-instructions.template.md` -> `.github/copilot-instructions.md`
- `templates/core/project-context.template.md` -> `docs/ai/project-context.md`
- `templates/shared/guardrails/AI-GUARDRAILS.md` -> `docs/ai/AI-GUARDRAILS.md`
- `templates/capabilities/project-context/` -> `docs/ai/capabilities/project-context/`
- `templates/capabilities/verify-change/` -> `docs/ai/capabilities/verify-change/`
- `templates/capabilities/review-diff/` -> `docs/ai/capabilities/review-diff/`
- `templates/github-copilot/instructions/architecture.instructions.md`
- `templates/github-copilot/instructions/testing.instructions.md`

Add other path instructions only when the repo truly needs them.

## Core Agent Set

If your Copilot surface supports custom agents reliably, start with only these four:

- `templates/github-copilot/agents/researcher.agent.md`
- `templates/github-copilot/agents/architect.agent.md`
- `templates/github-copilot/agents/implementer.agent.md`
- `templates/github-copilot/agents/reviewer.agent.md`

Recommended optional agents:

- `templates/github-copilot/agents/release-auditor.agent.md` for `medium` or `high` risk work
- `templates/github-copilot/agents/refactorer.agent.md` when behavior is already correct and only structure should change

Do not start with more agents than this.

## Core Prompt Set

If your surface supports prompt files, start with only:

- `templates/github-copilot/prompts/regression-test.prompt.md`
- `templates/github-copilot/prompts/release-readiness.prompt.md`

Recommended optional prompt:

- `templates/github-copilot/prompts/docs-sync.prompt.md`

Do not make prompt files the required base install.

## Setup Steps

1. Copy repo-wide instructions, project context, guardrails, and base capabilities first.
2. Add only the path-specific instructions you can justify.
3. Add the core four agents only if your target Copilot surface supports them well.
4. Add at most two prompts to start.
5. Replace placeholders across all copied files.
6. Search for unresolved `<PLACEHOLDER_NAME>` tokens and project-specific leaks.

## Clear Choice Model

- unclear area -> `researcher`
- multi-step or risky task -> `architect`
- bounded implementation -> `implementer`
- diff audit or correctness check -> `reviewer`
- rollout-sensitive change -> optional `release-auditor`
- structure-only cleanup -> optional `refactorer`
- narrow one-off proving task -> `regression-test`
- release posture question -> `release-readiness`

## Surface Guidance

### VS Code Or CLI

- safest base: repo instructions + path instructions + capabilities
- agents: add only the compact core set
- prompt files: optional and surface-dependent

### GitHub.com

- safest base: repo instructions + `AGENTS.md` + capability folders
- agents may behave differently than in local IDEs
- prompt-file workflows should not be your default assumption

## Anti-Pattern To Avoid

Do not solve every workflow problem by adding more prompt files or more agents.
