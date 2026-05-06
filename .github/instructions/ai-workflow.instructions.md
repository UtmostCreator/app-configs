---
applyTo: 'AGENTS.md,README.md,docs/ai/**,.github/copilot-instructions.md,.github/agents/**,.github/instructions/**,.github/prompts/**,.github/skills/**'
description: 'Rules for AI workflow docs, Copilot adapter files, and stronger VS Code enforcement'
---

# AI Workflow Rules

- Keep canonical workflow policy in `docs/ai/` and keep runtime adapters thin.
- For non-trivial work, route through `docs/ai/execution-protocol.md`.
- Keep security, approval, testing, generated-artifact, and tooling rules in their dedicated instruction files.
- Keep hook and script policy aligned with `policies/copilot/policy.yaml`, `scripts/ai/pre-tool-use.sh`, `scripts/ai/post-tool-use.sh`, and `docs/ai/script-registry.{md,json}`.
