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

## Working Style

- Prefer the smallest safe change.
- For non-trivial work, classify risk as `low`, `medium`, or `high` to set review and verification depth.
- Read existing code before proposing structural changes.
- Follow established repository patterns before inventing new abstractions.
- Ask for approval before making: `<APPROVAL_REQUIRED_CHANGES>`
- A human approver must be able to explain each changed section well enough to own the merge.
- Distinguish current implementation from planned or hypothetical systems.
- If a slice grows beyond roughly 6 files or 300-500 changed lines, pause and confirm it is still one bounded outcome.

## Quality Bar

- Keep logic close to its existing owner.
- Add focused tests when behavior changes.
- Prioritize review around: `<REVIEW_PRIORITIES>`
- Use `<PRIMARY_VERIFY_COMMAND>` as the main verification command unless the task needs a narrower command first.
- For `medium` and `high` risk changes, define rollback or disable path and post-deploy confirmation signal.
- For migrations that drop, rename, or restructure existing data, use expand-contract.
- Treat prototype paths as exploratory only; promoted prototype code must pass the normal workflow before merge.

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
