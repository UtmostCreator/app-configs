---
applyTo: "**"
description: "Approval boundaries for destructive, privileged, broad, or policy-sensitive changes"
---

# Approval Boundaries

Ask for explicit approval before destructive, privileged, broad, or hard-to-reverse actions.

Approval-required examples:

- destructive commands and history-rewrite git operations
- dependency/lockfile changes outside explicit scope
- migrations or data rewrites
- auth/security policy changes
- CI/CD or deployment changes
- generated-artifact rewrites without source change

File operations rule:

- Ask before deleting, moving, renaming, or overwriting existing user/repository files unless explicitly requested, scoped, and reversible.

Git operations rule:

- Approval is required for commands that discard user work, rewrite history, or alter branches.
- Targeted restore of the agent's own uncommitted edits is allowed when clearly scoped and reported.
