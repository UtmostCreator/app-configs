# Repository Instructions For app-configs

Use these instructions as the repository-wide baseline for GitHub Copilot.

## Project Context

- Project: `app-configs`
- Type: `configuration repo + AI workflow kit`
- Summary: `Opinionated local development configuration plus a live benchmark for durable cross-tool AI workflow setup.`
- Active paths: `AI-universal-rules/, docs/, vscode/, shell/, tools/, php/, .github/`
- Avoid by default: `treat copied examples as references unless the task explicitly targets them`
- Primary entrypoints: `README.md, AGENTS.md, docs/ai/project-context.md, AI-universal-rules/README.md, vscode/user/settings.json`
- Project context file: `docs/ai/project-context.md`
- Capability folders available: `docs/ai/capabilities/project-context, docs/ai/capabilities/verify-change, docs/ai/capabilities/review-diff, docs/ai/capabilities/bug-regression, docs/ai/capabilities/docs-sync, docs/ai/capabilities/config-change-safety`

## Working Style

- Prefer the smallest safe change.
- Read current repo files before proposing new structure.
- Keep this file policy-focused and use `docs/ai/` for canonical workflow detail.
- Ask for approval before changing secrets, credentials, or broad compatibility posture.
- Fix adapter drift instead of teaching conflicting workflows.
- Say `unknown` instead of guessing when the repo does not prove a fact.

## Quality Bar

- Keep logic close to its existing owner.
- Sync docs when commands, paths, or setup behavior change.
- Prioritize review around: `repo truth, path accuracy, runtime-adapter alignment, portability, and simple adoption`
- Start verification with the narrowest non-destructive check available for the changed tool.
- Treat broad builds as optional smoke checks, not automatic proof.

## Common Gotchas

- This repo is not a Laravel or product application codebase.
- `AI-universal-rules/examples/` contains references, not root-repo facts.
- Shared docs must call out machine-specific paths explicitly.
- Runtime surfaces differ; do not imply parity when support varies.

## Limits

- Copilot surface: `repository-scoped instructions plus optional narrower instructions and agents`
- Stable supported features: `repo instructions, path-scoped instructions, custom agents`
- Optional or preview features: `prompt files, advanced agent behavior, hooks, MCP depending on surface`
- Instruction precedence notes: `narrower path-scoped instructions should refine this file, not contradict it`
- Conflict avoidance notes: `keep canonical process in docs/ai and use Copilot files as adapters`
- Global or shared rule sources: `AGENTS.md, CLAUDE.md, docs/ai/project-context.md, docs/ai/workflow.md, docs/ai/AI-GUARDRAILS.md`
