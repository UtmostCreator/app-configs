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
