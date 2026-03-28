# app-configs - Repository Instructions

## Project Summary

- Project: `app-configs`
- Type: `configuration repo + AI workflow kit`
- Summary: `Opinionated editor, shell, terminal, PHP, and keyboard configuration plus a reusable cross-tool AI workflow package.`
- Primary language: `Markdown, JSON, shell config, Lua`
- Primary runtime: `local developer tooling`
- Active paths: `AI-universal-rules/, docs/, vscode/, shell/, tools/, php/, .github/`
- Inactive or legacy paths: `none declared; treat unreferenced examples as reference material unless a task targets them`
- Primary entrypoints: `README.md, AI-universal-rules/README.md, docs/ai/project-context.md, vscode/user/settings.json, shell/.zshrc`

## Default Workflow

- `research the target area -> classify risk -> update the smallest coherent slice -> review the diff -> verify with direct evidence -> sync docs when behavior or setup changed`

Workflow rules:

- Prefer the smallest safe change that keeps configuration readable.
- Keep canonical workflow logic in `docs/ai/capabilities/`, not in one giant instruction file.
- Treat this repository as both a live config repo and a worked example of repo-scoped AI workflow design.
- Preserve portability where practical; avoid coupling the root design to one assistant runtime.
- Say `unknown` when the repository does not prove a claim.

## Approval Required Before Proceeding

- destructive file deletion outside stale AI setup assets
- secrets, tokens, local machine credentials, or private endpoint configuration
- broad dependency/runtime upgrades with machine-wide impact
- changes that intentionally drop compatibility with a supported AI surface

## Core Engineering Rules

- Keep the canonical model simple: policy, project context, capability packs, runtime adapters.
- Prefer thin runtime adapters that point back to canonical docs.
- Do not let tool-specific files drift away from repository truth.
- Do not turn examples into hidden production defaults.
- Keep guidance actionable for a human and a coding agent.

## Architecture Notes

- `AI-universal-rules/` is the reusable package and benchmark model.
- Root `docs/ai/` is the live instantiation for this repository itself.
- Root `.github/` is the GitHub Copilot adapter, not the canonical source of truth.
- Root `AGENTS.md` and `CLAUDE.md` are portable memory surfaces that should stay short and durable.

## Risk Areas

- stale paths or commands in setup docs
- editor settings that accidentally assume a single project stack
- AI adapter drift between `AGENTS.md`, `CLAUDE.md`, `.github/`, and `docs/ai/`
- config changes that break local developer workflows silently

## Capability Map

- Core project context file: `docs/ai/project-context.md`
- Available capabilities: `project-context, verify-change, review-diff, bug-regression, docs-sync, config-change-safety`
- Capability composition notes: `start with project-context for unfamiliar areas; use config-change-safety before risky editor or shell edits; use docs-sync whenever setup or workflow behavior changes`

## Verification Rules

- Primary verification command: `use the narrowest repo-relevant check first; no single root command exists for every path`
- Primary build command: `none required for most config/docs edits`
- Primary test command: `validate by targeted lint, parse, launch, or dry-run commands when the changed tool supports it`
- Preferred narrow-first verification pattern: `read the target config -> run the closest non-destructive validation available -> only escalate to broader checks when the slice crosses tools`
- Do not claim verification you did not run.
- Treat successful parsing, linting, or launch as evidence only for the layer actually exercised.

## Review Priorities

- repo truth matches adapter files
- commands and paths are real
- setup guidance is copy-paste safe
- runtime-specific instructions have clear fallbacks
- changes do not add needless workflow complexity

## Common Gotchas

- this repo is not a Laravel app, frontend app, or monolith product codebase
- examples inside `AI-universal-rules/examples/` are references, not root-repo facts
- user settings may intentionally contain local-machine assumptions; shared docs must call those out explicitly

## Do Not

- do not reintroduce stack-specific instructions that do not match this repository
- do not claim cross-tool parity where support differs by surface
- do not bury key workflow logic only inside `.github/` or only inside a single vendor file
- do not overbuild the framework when a smaller capability or note will do
