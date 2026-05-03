# Repository Instructions For <PROJECT_NAME>

Use these instructions as the repository-wide baseline for GitHub Copilot.

They should remain valid even if advanced agent features or prompt files are unavailable on the active surface.

## Project Context

- Project: `<PROJECT_NAME>`
- Type: `<PROJECT_TYPE>`
- Summary: `<PROJECT_SUMMARY>`
- Active paths: `<ACTIVE_PATHS>`
- Avoid by default: `<INACTIVE_PATHS>`
- Primary entrypoints: `<PRIMARY_ENTRYPOINTS>`
- Project context file: `<PROJECT_CONTEXT_PATH>`
- Capability folders available: `<AVAILABLE_CAPABILITIES>`

## Working Style

- Prefer the smallest safe change.
- For non-trivial work, classify risk as `low`, `medium`, or `high` to set review and verification depth.
- Read existing code before proposing structural changes.
- When the repository includes a tool map or command wrappers, load that routing first and prefer `rg`, `fd`, `ast-grep`/`sg`, and structured queries over raw `grep`, `find`, or broad file dumps.
- Follow established repository patterns before inventing new abstractions.
- Keep this file policy-focused and use prompt files, skills, or agents for deeper procedures.
- Ask for approval before making: `<APPROVAL_REQUIRED_CHANGES>`
- A human approver must be able to explain each changed section well enough to own the merge.
- Distinguish current implementation from planned or hypothetical systems.
- Say `unknown` instead of guessing when repository evidence is missing.
- If a slice grows beyond roughly 6 files or 300-500 changed lines, pause and confirm it is still one bounded outcome.
- Prefer reusable capability folders for workflow-specific guidance when the repository provides them.

## Quality Bar

- Keep logic close to its existing owner.
- Add focused tests when behavior changes.
- Prioritize review around: `<REVIEW_PRIORITIES>`
- Use `<PRIMARY_VERIFY_COMMAND>` as the main verification command unless the task needs a narrower command first.
- Start with the smallest relevant verification and escalate only when needed.
- Use the verification ladder: focused proof first -> affected layer tests second -> broader repository verification third -> build as a smoke check when relevant -> release-safety review only when risk warrants it.
- For `medium` and `high` risk changes, define rollback or disable path and post-deploy confirmation signal.
- For migrations that drop, rename, or restructure existing data, use expand-contract.
- Treat prototype paths as exploratory only; promoted prototype code must pass the normal workflow before merge.

## Common Gotchas

- `<KNOWN_GOTCHA_THEMES>`
- When a workflow asset has its own `gotchas` section, follow the narrower guidance there.

## Limits

- Copilot surface: `<COPILOT_SURFACE>`
- Stable supported features: `<SUPPORTED_FEATURES>`
- Optional or preview features: `<OPTIONAL_FEATURES>`
- Instruction precedence notes: `<INSTRUCTION_PRECEDENCE_NOTES>`
- Conflict avoidance notes: `<CONFLICT_AVOIDANCE_NOTES>`
- Global or shared rule sources: `<GLOBAL_OR_SHARED_RULE_SOURCES>`
- Do not assume prompt file support on every Copilot surface.
- Do not assume custom-agent properties, handoffs, or advanced workflows behave the same on every Copilot surface.
- Do not imply tool features that are not clearly supported in the current environment.
- Treat hooks, skills, and MCP as surface-aware features with explicit fallbacks.
