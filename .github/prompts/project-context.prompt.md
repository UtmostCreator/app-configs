---
name: project-context
description: Use when planning or reviewing work in an unfamiliar area, choosing verification depth, or checking approval boundaries before editing
argument-hint: 'Describe what you are planning or reviewing in this repository'
---

## What I Do

I provide durable repository context for `app-configs` and point to the support files that other workflows should read next.

## When To Use Me

- before architecture decisions in unfamiliar areas
- before implementation when multiple active paths could own the change
- before review or verification when risk or ownership is unclear
- when another workflow needs repository facts first

## Do Not Use Me For

- purely general coding questions with no repository context
- trivial edits where the owner and verification path are already obvious

## Read Alongside

Read `docs/ai/capabilities/project-context/CAPABILITY.md`, its support files, and relevant context-gate, architecture, or target instructions.

## Task Context Sources

Load the smallest relevant task context first when available. If none exists, stay read-only and produce the missing ownership, path, target, and verification map.

## Project Shape

- Project type: `dotfiles-config-repo`
- Summary: `Personal dev-environment manager (dotfiles, CLI, GUI, runtimes) via chezmoi + mise + Nix/Home Manager + nix-darwin/Homebrew + Lefthook`
- Primary language: `Bash + Nix`
- Primary runtime: `chezmoi + mise + Nix/Home Manager`
- Active paths: `.chezmoiroot,.editorconfig,.eslintrc.json,.gitattributes,.gitignore,.lefthook.yml,.opencode,.prettierrc.json,.repomixignore,.stylelintrc.json,AGENTS.md,CONTRIBUTING.md,PLACEHOLDERS.md,README.md,SECURITY.md,SUPPORT.md,home,llms.txt,mise.toml,nix,ops,reference,repo-docs,tests`
- Inactive paths: `repo-docs/archive/, repo-docs/migration-*.md`
- Targets: `macOS, Linux desktop, Linux CLI/headless, WSL2 (CLI/dev only)`

## Architecture Notes

- Primary entrypoints: `README.md, ops/install.sh, ops/bootstrap.sh, mise.toml, nix/flake.nix`
- Notes: `Keep policy and capability docs canonical; keep runtime adapters thin.`
- Risk areas: `chezmoi templates, nix flake modules, install/update/cleanup scripts, NixOS system layer, secrets in personal.yaml`

## Verification Expectations

- Main verification command: `bash ops/validate-config.sh`
- Main build command: `mise run repo:check`
- Main test command: `mise run test:bash`
- Preferred narrow-first pattern: `start with the narrowest repo-local check and escalate only if needed`

## Review Priorities

- `correctness, secrets leakage, idempotency of install/apply, host-profile compatibility, chezmoi/nix template drift`

## Change Hygiene

Search for nearby patterns before changing code, config, docs, or workflow logic; reuse when overlap is roughly `>=75%`; after changes, sweep edited files and nearby references for stale paths, placeholders, and generated-output drift.

## Approval Boundaries

- `secrets, destructive changes, NixOS system layer (sys-setup), install/apply scripts, uninstall actions`

## Common Gotchas

- `stale paths, broad edits without evidence, guessed behavior`

## Output Contract

- current owner or `unknown`
- affected paths and targets
- canonical docs to read next
- approval boundaries relevant to the request
- focused verification starting point
- recommended next stage: research, plan, implement, review
