# External Repo Install

Use the installer to bootstrap this AI workflow kit into another repository.

## Dry-Run First

```bash
php tools/ai/install-ai-kit.php --target /path/to/target-repo --profile dual --dry-run
```

## Apply Install

```bash
php tools/ai/install-ai-kit.php --target /path/to/target-repo --profile dual
```

## Profiles

- `minimal`: core policy + project context + guardrails + three base capabilities
- `copilot`: `minimal` plus Copilot instructions, agents, and prompts from templates
- `opencode`: `minimal` plus OpenCode agents, commands, and skills from templates
- `dual`: `minimal` plus both Copilot and OpenCode runtime adapters
- `guarded`: same assets as `dual`, with an explicit prompt to apply local guard/hook policies manually

Legacy wrapper still works:

- `tools/ai/install-copilot-kit.sh --profile minimal|copilot|copilot-guarded`
- `tools/ai/install-ai-kit.sh` (shell wrapper around PHP installer)

## Overwrite Behavior

- existing files are skipped by default
- use `--force` to overwrite existing paths
- use `--no-base` when you only want runtime adapters (`.github` and/or `.opencode`) without replacing base policy files
- core base policy paths remain protected even with `--force`; pass `--allow-core-overwrite` only when intentional

## Adaptation Behavior

The installer adapts placeholders in installed markdown files based on target repo signals:

- project name from target folder (or `--project-name`)
- project type from `composer.json`, `package.json`, or `go.mod`
- primary language from `scc` when available
- active paths from top-level tracked files

Unknown values remain explicit as `unknown` instead of guessed.

## Runtime

Current installer runtime support:

- `github-copilot`
- `opencode`
- `both` (via `--runtime both` or `--profile dual`)

## Notes

- this installer is intentionally starter-focused
- review and refine `AGENTS.md` and `docs/ai/project-context.md` after install
- run repo-specific verification after installation
- for folder-level install wiring and intent mapping, consult `docs/ai/repo-directory-map.json`
- for architecture and complete installed asset map, read `docs/ai/installer-architecture.md`
