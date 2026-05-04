---
applyTo: '**'
description: 'Security, secrets, auth, config, and privileged-operation rules'
---

# Security Rules

- Never create, expose, print, commit, or modify secrets.
- Do not edit `.env`, key, certificate, token, credential, or production config files without explicit approval.
- Treat auth, authorization, permissions, tenancy, billing, and data export as high-risk.
- Prefer deny-by-default behavior for permissions.
- Preserve audit logging and error handling.
- Do not bypass validation to make tests pass.
- Do not weaken access checks unless explicitly approved and documented.
