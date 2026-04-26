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
- `scripts/copilot/common.sh`: shared dependency, logging, token-budget, and secrets-scan helpers for the stronger wrapper layer.
- Skills: reusable multi-step investigation workflow.
- Prompt files: explicit one-shot workflow starters.
- GitHub MCP: GitHub-native context when available.

## Tool Routing Baseline

Use these tools in this preferred order for read-first investigation:

1. `scripts/copilot/ai-search.sh` as the unified search entrypoint for `text`, `files`, `struct`, `tracked`, and `all` modes.
2. `scripts/copilot/rg-code.sh` (`rg`) for broad search.
3. `scripts/copilot/fd-files.sh` (`fd`) for file discovery.
4. `fzf` for interactive narrowing.
5. `scripts/copilot/preview-file.sh` (`bat`) for previews.
6. `git grep` for tracked-tree only search.
7. `scripts/copilot/git-forensics.sh` for `git log -S/-G/-L` and `git blame -L`.
8. `scripts/copilot/gh-pr-context.sh` plus `jq` or GitHub MCP for remote context, optional diff/check/review capture, and PR-scoped context packing.
9. `ast-grep` for syntax-aware discovery and the approved structural rewrite path through `scripts/copilot/ai-edit.sh`.
10. `semgrep` for rule-based bug or security sweeps.
11. `delta` for diff rendering.

Use this AI-native workflow stack when the task needs packaging, looped verification, or deterministic runtime setup:

### 1) LLM Context Packaging

1. `scripts/copilot/pack-context.sh auto .` to auto-select the best installed packer.
2. `scripts/copilot/pack-context.sh repomix ...` for full-repo context packaging.
3. `scripts/copilot/pack-context.sh files-to-prompt ...` for focused file-list packaging.
4. `scripts/copilot/pack-context.sh code2prompt ...` for template-driven provider-specific context files.
5. `tokei` before packaging when you need language/scope metrics in the prompt preface.
6. `scripts/copilot/repomix-scc-router.sh` when you need ranked per-folder bundle planning before packing.
7. `scripts/copilot/ai-diff-context.sh` when you need PR-local, unstaged, recent, or touched-file context instead of a broad repo pack.

Use `docs/ai/context-packing.md` for the per-folder `scc` + `repomix` workflow and output files.

Router outputs now include:

- `bundle-plan.tsv` for shell-friendly review
- `bundle-plan.json` for agent-friendly plan consumption
- optional changed-since filtering and churn-aware scoring when the repository has git history available

Recommended `just` entrypoints for the router layer:

- `just context-plan`
- `just context-plan-since BRANCH_OR_REF`
- `just context-pack-all`
- `just context-pack-all-since BRANCH_OR_REF`
- `just context-plan-json`
- `just context-clean`
- `just context-purge`
- `just context-tree-analyze path='.' opts='--compress'` for Repomix-aware recursive fit analysis using packed output size
- `just context-tree-plan path='.' opts='--compress'` to write a recursive plan and manifest
- `just context-tree-pack path='.' opts='--compress'` to generate leaf bundles plus parent reference indexes
- `just query-usage path='.' multiplier='1' label='1x'` for read-only raw-token and weighted-usage closeout reporting

Recommended prompt starters in `.github/prompts/`:

- `investigate-bug`
- `trace-regression`
- `docs-sync`
- `new-feature`
- `review-code`

### 2) File-Watch Feedback Loop

1. `scripts/copilot/watch-loop.sh "<verify-command>" "<ext-list>"` for edit -> run -> observe loops.
2. Prefer `watchexec` backend when available.
3. Use `entr` fallback when `watchexec` is missing.
4. Keep watch commands non-destructive and repo-local by default.
5. Watch sessions append start metadata to the repo-local watch loop log file and support debounce via `WATCH_DEBOUNCE_MS`.

### 3) Runtime + Environment Handshake

1. Pin versions with `mise` (`mise.toml`).
2. Load per-project environment with `direnv` (`.envrc`).
3. Before multi-step verification, run `mise exec -- <command>` or `direnv exec . <command>` when available.
4. Treat missing runtime managers as an explicit limitation in your summary instead of silently continuing.

### 4) Guarded Modification Path

Wrapper scripts in `scripts/copilot/` are classified by the three-tier command risk taxonomy in `docs/ai/command-risk-taxonomy.md`. Tier is determined by invocation shape, not script name.

| Wrapper                                                                                            | Invocation                       | Tier | Approval                     |
| -------------------------------------------------------------------------------------------------- | -------------------------------- | ---- | ---------------------------- |
| `ai-search.sh`, `ai-verify.sh`, `git-forensics.sh`, `fd-files.sh`, `rg-code.sh`, `preview-file.sh` | any                              | 1    | auto                         |
| `repo-stats.sh`, `query-usage.sh`                                                                  | any                              | 1    | auto                         |
| `ai-diff-context.sh`, `pack-context.sh`, `gh-pr-context.sh`, `repomix-context-tree.sh`             | any                              | 1†   | auto (generated-output only) |
| `ai-edit.sh`                                                                                       | dry-run (no `APPLY=1`)           | 1    | auto                         |
| `ai-edit.sh`                                                                                       | `APPLY=1` or `VERIFY=1`          | 2    | confirm                      |
| `ai-rollback.sh`                                                                                   | `list`, `show`                   | 1    | auto                         |
| `ai-rollback.sh`                                                                                   | `apply`                          | 3    | explicit approval            |
| `repomix-scc-router.sh`                                                                            | `stats`, `plan`, `run`, `bundle` | 1    | auto                         |
| `repomix-scc-router.sh`                                                                            | `clean`, `purge`                 | 3    | explicit approval            |

1. Use `scripts/copilot/ai-edit.sh` for broad repository edits.
2. Keep `APPLY=0` for the first pass so the script shows a dry-run candidate set.
3. Re-run with `APPLY=1` only after the candidate set looks correct.
4. Use `VERIFY=1`, `scripts/copilot/ai-verify.sh`, or `just verify` after applying changes.
5. Use `scripts/copilot/ai-rollback.sh` only for explicit recovery work because it modifies the working tree.
6. Review the per-session manifest in `.copilot-logs/sessions/` when you need a compact record of a guarded edit run.

## Guardrail Notes

- Keep hooks deterministic and lightweight.
- Do not encode complete workflow logic inside hooks.
- Treat hooks as enforcement and telemetry only.
- For agentic workflows, require traces and bounded privileges before adding more autonomy.
- Keep destructive commands denied by default unless explicitly requested.
- Prefer the stronger wrapper scripts over ad hoc shell pipelines when the wrapper already captures search modes, token budgets, or structured output.
- For broad modifications, do not use raw `sed`, `perl`, or shell replacement loops when `scripts/copilot/ai-edit.sh` can perform the operation with a snapshot, dry-run, diff, and verification path.
- Post-tool telemetry now records a best-effort `failureCategory` so logs align more closely with `docs/ai/failure-handling.md`.
