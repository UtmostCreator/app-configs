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
- `docs/ai/agent-ops.md`: agentic architecture, risk, IAM, and evaluation defaults.
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

Use this AI-native workflow stack when the task needs packaging, looped verification, or deterministic runtime setup:

### 1) LLM Context Packaging

1. `scripts/copilot/pack-context.sh auto .` to auto-select the best installed packer.
2. `scripts/copilot/pack-context.sh repomix ...` for full-repo context packaging.
3. `scripts/copilot/pack-context.sh files-to-prompt ...` for focused file-list packaging.
4. `scripts/copilot/pack-context.sh code2prompt ...` for template-driven provider-specific context files.
5. `tokei` before packaging when you need language/scope metrics in the prompt preface.
6. `scripts/copilot/repomix-scc-router.sh` when you need ranked per-folder bundle planning before packing.

Use `docs/ai/context-packing.md` for the per-folder `scc` + `repomix` workflow and output files.

### 2) File-Watch Feedback Loop

1. `scripts/copilot/watch-loop.sh "<verify-command>" "<ext-list>"` for edit -> run -> observe loops.
2. Prefer `watchexec` backend when available.
3. Use `entr` fallback when `watchexec` is missing.
4. Keep watch commands non-destructive and repo-local by default.

### 3) Runtime + Environment Handshake

1. Pin versions with `mise` (`mise.toml`).
2. Load per-project environment with `direnv` (`.envrc`).
3. Before multi-step verification, run `mise exec -- <command>` or `direnv exec . <command>` when available.
4. Treat missing runtime managers as an explicit limitation in your summary instead of silently continuing.

## Guardrail Notes

- Keep hooks deterministic and lightweight.
- Do not encode complete workflow logic inside hooks.
- Treat hooks as enforcement and telemetry only.
- For agentic workflows, require traces and bounded privileges before adding more autonomy.
- Keep destructive commands denied by default unless explicitly requested.
