# Worked Dual-Tool Repo

This example shows one shared capability layer adapted to both OpenCode and GitHub Copilot.

## Stack

- repo type: `monorepo`
- domains: `web checkout`, `orders api`, `worker`
- tools: `OpenCode` and `GitHub Copilot`

## Main Idea

- shared policy and project context stay in durable docs
- capabilities remain the canonical workflow source
- OpenCode uses commands, skills, and agents as adapters
- Copilot uses instructions, prompt files, and agents as adapters
- risky work adds a release-audit stage and approval packet
