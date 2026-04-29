# Approval Boundaries

Ask for human approval before:

- destructive/irreversible operations
- credentials, secrets, token, or key changes
- auth, permissions, session, or guard logic changes
- billing/pricing/quota/subscription logic
- schema or migration changes
- dependency additions/upgrades with compatibility risk
- CI/CD, deployment, or release pipeline changes
- public API/GraphQL/event contract changes
- major file moves/deletions
- privileged/elevated commands or remote write operations

Read-only local inspection is approval-free by default unless sensitive data is exposed.
