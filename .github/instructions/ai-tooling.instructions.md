---
applyTo: "tools/ai/**,scripts/ai/**,docs/ai/script-registry.md,docs/ai/script-registry.json,policies/copilot/policy.yaml,.github/hooks/tool-policy.json"
description: "AI tooling contract, registry alignment, and hook-policy consistency"
---

# AI Tooling Rules

- Keep script/tool behavior deterministic.
- Preserve machine-readable output keys and exit semantics unless contract changes are explicitly approved.
- Keep script registry aligned across `tools/ai/install/script-registry.php`, `docs/ai/script-registry.json`, and `docs/ai/script-registry.md`.
- Keep hook policy aligned across policy, scripts, and `.github/hooks/tool-policy.json`.
- Prefer focused checks before broad verification.
