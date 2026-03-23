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
- Read existing code before proposing structural changes.
- Follow established repository patterns before inventing new abstractions.
- Ask for approval before making: `<APPROVAL_REQUIRED_CHANGES>`
- Distinguish current implementation from planned or hypothetical systems.

## Quality Bar

- Keep logic close to its existing owner.
- Add focused tests when behavior changes.
- Prioritize review around: `<REVIEW_PRIORITIES>`
- Use `<PRIMARY_VERIFY_COMMAND>` as the main verification command unless the task needs a narrower command first.

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
