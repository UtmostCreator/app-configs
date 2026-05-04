---
applyTo: '**'
description: 'Approval boundaries for destructive, risky, privileged, or broad changes'
---

# Approval Boundaries

Ask for explicit approval before:

- deleting files
- overwriting existing instructions
- changing installer or rollback behavior
- changing CI or release workflows
- changing authentication or authorization
- changing secrets, environment files, keys, tokens, or credentials
- changing database schema destructively
- modifying generated artifacts directly
- touching more than 6 files or more than 300-500 LOC
- running destructive commands
- changing adapter policy in `.github/**`, `.opencode/**`, `AGENTS.md`, or `CLAUDE.md`

## Safe Default

When approval is missing:

- research
- plan
- produce a patch proposal
- run read-only commands
- avoid writes
