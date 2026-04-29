# AI Installer Architecture

This document explains the full installer model, what gets installed, and how to verify it.

## Entrypoints

- `php tools/ai/install-ai-kit.php` is the canonical installer implementation.
- `bash tools/ai/install-ai-kit.sh` is a thin shell wrapper that forwards all args to PHP.
- `bash tools/ai/install-copilot-kit.sh` is a compatibility wrapper for legacy Copilot-only workflows.

## V2 Compatibility And Design Lock

- Preserve existing command compatibility during migration:
  - keep `adapter-plan`, `adapter-validate`, `preflight`, `package-lock`, `package-verify`, `install`, `upgrade`, `rollback`
  - add `plan` as `adapter-plan` successor/alias
  - evolve `verify` without removing existing install-validation surfaces
- Keep direct installer compatibility:
  - `install-ai-kit.php` remains a stable entrypoint
  - implementation moves to shared installer core so `install-ai-kit.php` and `ai.php install` do not diverge
- Manifest authority model:
  - canonical machine state: `.ai-install-manifest.json`
  - derived evidence copy: `docs/ai/generated/install-manifest.json`
  - verify must detect drift between canonical and derived copy
- Placeholder syntax remains `<PLACEHOLDER_NAME>` in v2.
- Distribution baseline remains `git-tag` for source-aware upgrades.
- `docs-reference-pack` is optional add-on and not part of default `full-governance` install.
- `fd` is optional in scripts validation unless a selected script explicitly requires it.
- `ext_zip` is optional for backups:
  - preferred: zip backup via `ZipArchive`
  - fallback: directory backup
- Hook executable checks are platform-aware:
  - Windows: warning/info only
  - Unix with explicit hook wiring: error if non-executable

## Install Profiles

- `minimal`: base policy + project context + guardrails + 3 core capabilities.
- `copilot`: `minimal` + GitHub Copilot runtime assets.
- `opencode`: `minimal` + OpenCode runtime assets.
- `dual`: `minimal` + both runtime adapters.
- `guarded`: same files as `dual`; adds explicit operator reminder for guard/hook policy layering.

V2 target profile model:

- `minimal`: `base + setup-docs + capabilities-core`
- `copilot`: `minimal + adapter-copilot`
- `opencode`: `minimal + adapter-opencode`
- `dual`: `minimal + adapter-copilot + adapter-opencode + capabilities-extended-lite`
- `accelerated`: `dual + scripts-pack + policy-pack + evidence-pack`
- `full-governance`: `accelerated + capabilities-extended-full + hooks-pack + ci-pack`
- `docs-reference`: optional add-on only

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
