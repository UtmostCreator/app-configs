---
description: Architecture rules for the Acme Web product paths
applyTo: "apps/web/**,packages/api-client/**"
---

- Keep API contract translation in `packages/api-client`.
- Keep presentation state in feature owners instead of pushing business rules into shared UI primitives.
- Avoid editing `legacy-web/` unless the task explicitly requires it.
