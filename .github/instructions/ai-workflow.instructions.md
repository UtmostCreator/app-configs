---
applyTo: "AGENTS.md,CLAUDE.md,README.md,docs/ai/**,.github/copilot-instructions.md,.github/agents/**,.github/instructions/**"
description: "Rules for AI workflow docs and runtime adapters"
---

# AI Workflow Rules

- Keep canonical workflow guidance in `docs/ai/` and adapter-specific guidance in runtime files.
- Do not let `.github/` disagree with `AGENTS.md`, `CLAUDE.md`, or `docs/ai/project-context.md`.
- Prefer portable concepts first: policy, project context, capabilities, verification, approval boundaries.
- Mention runtime limitations explicitly instead of implying feature parity.
- Keep always-on instruction files short and durable.
- Keep live agent behavior documented in `docs/ai/agents.md`.
- Keep command failure logging, retry policy, and corrected usage guidance documented in `docs/ai/failure-handling.md`.
- State explicitly that safe repo-local read-only commands are approval-free by default.
- Route broad edits through `scripts/copilot/ai-edit.sh` instead of raw shell replacement commands when the Copilot tool layer can handle the change.
- Keep the Copilot hook policy aligned with `scripts/copilot/policy.yaml`, `scripts/copilot/pre-tool-use.sh`, and `scripts/copilot/post-tool-use.sh`.
