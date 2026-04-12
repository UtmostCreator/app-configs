---
description: Testing guidance for Acme Commerce product paths
applyTo: "apps/web/**,services/orders-api/**,packages/contracts/**"
---

- Prefer package-local tests before root-level commands.
- If a change touches `packages/contracts`, verify both producer and consumer paths.
- Do not use build-only evidence for contract changes.
