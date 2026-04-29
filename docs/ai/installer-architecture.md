# AI Installer Architecture

This document explains the full installer model, what gets installed, and how to verify it.

## Entrypoints

- `php tools/ai/install-ai-kit.php` is the canonical installer implementation.
- `bash tools/ai/install-ai-kit.sh` is a thin shell wrapper that forwards all args to PHP.
- `bash tools/ai/install-copilot-kit.sh` is a compatibility wrapper for legacy Copilot-only workflows.

## Install Profiles

- `minimal`: base policy + project context + guardrails + 3 core capabilities.
- `copilot`: `minimal` + GitHub Copilot runtime assets.
- `opencode`: `minimal` + OpenCode runtime assets.
- `dual`: `minimal` + both runtime adapters.
- `guarded`: same files as `dual`; adds explicit operator reminder for guard/hook policy layering.

Flags:

- `--force`: overwrite existing files/dirs.
- `--no-base`: install runtime adapters only (do not copy `AGENTS.md`/`docs/ai/capabilities/*`).
- `--allow-core-overwrite`: required with `--force` to replace existing base policy files and base capabilities.

## Runtime Asset Map

Base layer:

- `AGENTS.md`
- `docs/ai/project-context.md`
- `docs/ai/AI-GUARDRAILS.md`
- `docs/ai/capabilities/project-context/`
- `docs/ai/capabilities/verify-change/`
- `docs/ai/capabilities/review-diff/`

GitHub Copilot runtime:

- `.github/copilot-instructions.md`
- `.github/instructions/`
- `.github/agents/`
- `.github/prompts/`

OpenCode runtime:

- `.opencode/agents/`
- `.opencode/commands/`
- `.opencode/skills/`

## Placeholder Adaptation

After copying files, installer replaces placeholders in markdown files under:

- `AGENTS.md`
- `docs/ai/`
- `.github/`
- `.opencode/`

Values are inferred from target repo signals when possible:

- project name from `--project-name` or target folder name
- project type from `composer.json`, `package.json`, `go.mod`
- active paths from `git ls-files`

Unknown values are intentionally left as `unknown`.

## Verification Workflow

Run this after installation:

1. `php tools/ai/validate-ai-config.php`
2. `php tools/ai/validate-ai-catalog.php` (if catalog surfaces changed)
3. `php tools/ai/generate-ai-catalog.php --check`
4. `php tools/ai/generate-repo-structure.php --check --with-scc`

For shell hygiene (installer wrappers):

- `bash -n tools/ai/install-ai-kit.sh`
- `bash -n tools/ai/install-copilot-kit.sh`

## Official Runtime References

GitHub Copilot:

- repository custom instructions: `.github/copilot-instructions.md`
- path instructions: `.github/instructions/*.instructions.md` with `applyTo` frontmatter

OpenCode:

- agents: `.opencode/agents/*.md`
- commands: `.opencode/commands/*.md`
- skills: `.opencode/skills/<name>/SKILL.md`

## What To Do When Data Is Missing

- If runtime docs are ambiguous or changed upstream, document the uncertainty as `unknown`.
- Add a follow-up note in this file or `docs/ai/failure-handling.md` with command evidence.
- Prefer small, explicit defaults over guessing unsupported runtime behavior.
