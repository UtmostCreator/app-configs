# Post Install

- Profile: `full-governance`
- Packs: `base, setup-docs, capabilities-core, capabilities-extended-lite, capabilities-extended-full, adapter-copilot, adapter-opencode, scripts-pack, policy-pack, hooks-pack, ci-pack, evidence-pack, docs-reference-pack, delivery-pack, optional-agents-pack, optional-prompts-pack, preview-environments-pack, evaluation-pack, service-boundary-pack, mcp-boundaries-pack, advisor-pack`

## How To Use Installed Assets

- Copilot assets: `.github/copilot-instructions.md`, `.github/instructions/`, `.github/agents/`, `.github/prompts/`.
- OpenCode assets: `.opencode/agents/`, `.opencode/commands/`, `.opencode/skills/`.
- Scripts installed under `scripts/ai/` for search, context packing, verify, rollback, and investigation flows.
- Required tools: `bash`, `git`, `jq`, `rg`, `repomix`, `scc`.
- Optional tools: `fd`, `gh`, `fzf`, `bat`, `delta`, `yq`, `shellcheck`, `semgrep`, `ast-grep`.

## Commands

- Verify: `php tools/ai/ai.php verify`
- Strict verify: `php tools/ai/ai.php verify --strict`
- Placeholders: `php tools/ai/ai.php placeholders --fail`
- Upgrade preview: `php tools/ai/ai.php upgrade --dry-run`
- Rollback: `php tools/ai/ai.php rollback --backup <backup-id> --apply`

## Hook Wiring

- Hook scripts are installed when `hooks-pack` is selected; wiring remains explicit.
- Wire hooks with: `php tools/ai/ai.php hooks install --driver husky|lefthook|native`.

## Project Configuration Checklist

- Fill project facts and commands in `docs/ai/project-context.md`.
- Confirm risk areas and approval-required changes.
- Confirm active/inactive paths and runtime targets.

## OpenCode Agent Visibility Troubleshooting

- If OpenCode does not list agents, confirm files exist in `.opencode/agents/`.
- Ensure each agent frontmatter uses `mode: subagent` and `hidden: false`.
- Re-run installer apply if needed, then restart OpenCode CLI session.
