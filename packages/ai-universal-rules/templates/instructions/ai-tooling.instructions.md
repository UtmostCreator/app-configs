---
applyTo: "tools/ai/**,scripts/ai/**,docs/ai/script-registry.md,docs/ai/script-registry.json,policies/copilot/policy.yaml,.github/hooks/tool-policy.json"
description: "AI tooling contract, registry alignment, and hook-policy consistency"
---

# AI Tooling Rules

- Keep script/tool behavior deterministic.
- Preserve machine-readable output keys and exit semantics unless contract changes are approved.
- Keep script registry aligned across PHP source and docs JSON/MD.
- Keep hook policy aligned across policy, scripts, and hook config.
- Use `scripts/ai/preview-file.sh` instead of raw `cat` for bounded file inspection, especially after search returns a file and line.
