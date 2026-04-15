# Copilot Tooling Integration

This file defines how the repository wires Copilot tooling without moving canonical workflow logic out of `docs/ai/capabilities/`.

## Installation Order

1. Read `AGENTS.md`, `docs/ai/project-context.md`, and `docs/ai/workflow.md`.
2. Apply repository defaults from `.github/copilot-instructions.md`.
3. Add path-level refinements from `.github/instructions/*.instructions.md`.
4. Install wrapper scripts in `scripts/copilot/` and keep them executable.
5. Enable hooks with `.github/hooks/tool-policy.json` for guardrails and audit logging.
6. Add task workflows through `.github/skills/` and `.github/prompts/`.
7. Use GitHub MCP or `gh` for PR, issue, and workflow context.

## Responsibility Split

- Repository instructions: default tool order and execution posture.
- Path instructions: language or surface-specific refinements.
- Hooks: allow/deny guardrails and post-tool usage logs.
- Wrapper scripts: deterministic command entrypoints.
- Skills: reusable multi-step investigation workflow.
- Prompt files: explicit one-shot workflow starters.
- GitHub MCP: GitHub-native context when available.

## Tool Routing Baseline

Use these tools in this preferred order for read-first investigation:

1. `scripts/copilot/rg-code.sh` (`rg`) for broad search.
2. `scripts/copilot/fd-files.sh` (`fd`) for file discovery.
3. `fzf` for interactive narrowing.
4. `scripts/copilot/preview-file.sh` (`bat`) for previews.
5. `git grep` for tracked-tree only search.
6. `scripts/copilot/git-forensics.sh` for `git log -S/-G/-L` and `git blame -L`.
7. `scripts/copilot/gh-pr-context.sh` plus `jq` or GitHub MCP for remote context.
8. `ast-grep` for syntax-aware discovery.
9. `semgrep` for rule-based bug or security sweeps.
10. `delta` for diff rendering.

## Guardrail Notes

- Keep hooks deterministic and lightweight.
- Do not encode complete workflow logic inside hooks.
- Treat hooks as enforcement and telemetry only.
- Keep destructive commands denied by default unless explicitly requested.
