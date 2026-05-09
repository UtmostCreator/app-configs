---
applyTo: "scripts/ai/**,tools/ai/**,docs/ai/tools/**"
---

# AI Tooling Instructions

Prefer existing repository scripts over ad-hoc shell commands.

Before adding a new AI tool, compare with existing tools and avoid duplicates when overlap is >=75%.

## Preview-file rule

Use `scripts/ai/preview-file.sh` instead of raw `cat` when inspecting files.

Required safe pattern:

```bash
AI_OUTPUT=json bash scripts/ai/preview-file.sh <path> --around <line> --context 30
```

Do not expand to whole-file reads unless the file is small and relevant.
