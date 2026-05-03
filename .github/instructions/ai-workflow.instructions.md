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
- For mutating or high-risk tool use, route through `docs/ai/capabilities/authorization-and-tool-governance/CAPABILITY.md` before execution.
- For medium or high-risk agentic work, route through `docs/ai/capabilities/agent-observability-and-evidence/CAPABILITY.md` so outputs include traceable evidence fields when supported.
- For behavior-changing agentic work, route through `docs/ai/capabilities/evaluation-and-regression/CAPABILITY.md` and include regression evidence in task output.
- For medium/high-risk changes requiring temporary environment validation, route through `docs/ai/capabilities/preview-environments/CAPABILITY.md` and include lifecycle/cleanup evidence in task output.
- Route broad edits through `scripts/ai/ai-edit.sh` instead of raw shell replacement commands when the Copilot tool layer can handle the change.
- Keep the Copilot hook policy aligned with `policies/copilot/policy.yaml`, `scripts/ai/pre-tool-use.sh`, and `scripts/ai/post-tool-use.sh`.
