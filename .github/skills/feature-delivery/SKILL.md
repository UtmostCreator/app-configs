---
name: feature-delivery
description: Plan and deliver a scoped feature with minimal diffs, focused verification, and PR-ready summary
---

# Feature Delivery Skill

Use this skill when a request is to implement or extend a feature.

## Steps

1. Restate the requested behavior in one paragraph.
2. Create a minimal implementation plan (3-7 steps).
3. List files likely to change before editing.
4. Implement smallest complete slice.
5. Run focused checks first (unit/feature tests, lint/format only where touched).
6. Produce a compact summary with exact verification commands.

## Guardrails

- Do not widen scope unless the user asks.
- Prefer existing repo conventions over introducing new architecture.
- Include rollback-safe notes when change risk is non-trivial.
