# External Repo Install

Use the installer to bootstrap this AI workflow kit into another repository.

## Dry-Run First

```bash
bash tools/ai/install-copilot-kit.sh --target /path/to/target-repo --profile minimal --dry-run
```

## Apply Install

```bash
bash tools/ai/install-copilot-kit.sh --target /path/to/target-repo --profile copilot
```

## Profiles

- `minimal`: core policy + project context + guardrails + three base capabilities
- `copilot`: `minimal` plus Copilot instructions, agents, and prompts from templates
- `copilot-guarded`: `copilot` plus hook and wrapper script surfaces

## Overwrite Behavior

- existing files are skipped by default
- use `--force` to overwrite existing paths

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

## Notes

- this installer is intentionally starter-focused
- review and refine `AGENTS.md` and `docs/ai/project-context.md` after install
- run repo-specific verification after installation
- for folder-level install wiring and intent mapping, consult `docs/ai/repo-directory-map.json`
