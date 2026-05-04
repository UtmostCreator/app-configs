# Post Install

- Profile: `full-governance`
- Packs: `capabilities-extended-full, hooks-pack, ci-pack, scripts-pack, policy-pack, evidence-pack, adapter-copilot, adapter-opencode, capabilities-extended-lite, base, setup-docs, capabilities-core`

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

## See Also

- `install-order.md` — full install command flow and selective pack recipes
- `external-repo-install.md` — external repository install examples
- `packages/ai-universal-rules/docs/ONBOARDING.md` — what to customize and in what order
- `packages/ai-universal-rules/PLACEHOLDERS.md` — placeholder reference for all copied templates
- `packages/ai-universal-rules/docs/INSTALL-GITHUB-COPILOT.md` — GitHub Copilot install guide
- `packages/ai-universal-rules/docs/INSTALL-OPENCODE.md` — OpenCode install guide
