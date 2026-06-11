# app-configs Project Context

Use this file as durable, canonical project context for instructions, agents, prompts, and capabilities.

## 1) Project Identity

- Project type: `dotfiles-config-repo`
- Summary: `Personal dev-environment manager (dotfiles, CLI, GUI, runtimes) via chezmoi + mise + Nix/Home Manager + nix-darwin/Homebrew + Lefthook`
- Primary language: `Bash + Nix`
- Primary runtime: `chezmoi + mise + Nix/Home Manager`
- Supported targets: `macOS, Linux desktop, Linux CLI/headless, WSL2 (CLI/dev only)`
- Primary stack: `chezmoi (dotfiles) + mise (runtimes/tasks) + Nix/Home Manager (CLI pkgs) + nix-darwin/Homebrew (macOS GUI) + Lefthook (git hooks)`
- Package manager: `mise + Nix (Home Manager) + Homebrew (macOS)`

## 2) Scope and Ownership

- Active paths: `home, nix, ops, mise.toml, .lefthook.yml, tests, repo-docs, reference, README.md, AGENTS.md`
- Inactive/legacy paths: `repo-docs/archive/, repo-docs/migration-*.md`
- Primary entrypoints: `README.md, ops/install.sh, ops/bootstrap.sh, mise.toml, nix/flake.nix`
- Architecture notes: `chezmoi owns dotfiles; Nix/Home Manager owns CLI packages; nix-darwin/Homebrew owns macOS GUI; mise owns runtimes/tasks; ops/*.sh owns install/update/cleanup/validation. Keep runtime adapters thin.`
- Risk areas: `chezmoi templates, nix flake modules, install/update/cleanup scripts, NixOS system layer, secrets in personal.yaml`

## 3) Source Of Truth

When files disagree, use:

1. Current git diff and working tree
2. Source code
3. Tests
4. Schemas/contracts/public interfaces
5. Runtime/build config
6. `docs/ai/project-context.md`
7. Other `docs/ai/*.md`
8. Adapter files (`AGENTS.md`, `.github/**`, `.opencode/**`)
9. Generated files

Stale markdown must not override code evidence.

## 4) Task-Context Gate

Establish one before planning/editing:

- `docs/ai/generated/task-context/latest.md` (if a task-context generator has produced it)
- otherwise read-only discovery via `scripts/ai/ai-search.sh` plus `git status --short` and `git diff`

If missing, perform read-only discovery first and produce a plan before edits.

## 5) Placement, Naming, and Reuse

- File placement rules: `Dotfiles/app config under home/ (chezmoi source); Nix host/package modules under nix/; install/setup/maintenance scripts under ops/; bats tests under tests/bash; extended docs under repo-docs/`
- Naming rules: `chezmoi source naming (dot_*, *.tmpl); kebab-case ops/*.sh; mise tasks namespaced with ':' (e.g. repo:check); nix modules under nix/modules/<platform|home>/`
- Golden examples: `ops/validate-config.sh, ops/install.sh, mise.toml, nix/flake.nix, home/dot_gitconfig.tmpl, tests/bash/detect-os-disks.bats`

Before adding non-trivial logic, search for overlap and report nearest reuse percentage.
If overlap is `>=75%`, extend or adapt existing patterns instead of adding duplicates.

## 6) Formatting, Ignored Files, and Script Rules

- Formatter config files: `.editorconfig, .prettierrc.json, .stylelintrc.json`
- Linter config files: `.eslintrc.json, .stylelintrc.json, .lefthook.yml`
- EditorConfig path: `.editorconfig`
- Ignore files (`.gitignore`, lint ignore lists, etc.): `.gitignore, .gitattributes, .repomixignore`

Script rules:

- Prefer repository wrappers from `docs/ai/script-registry.md` and `docs/ai/script-registry.json`.
- Treat `scripts/ai/pre-tool-use.sh` as canonical pre-execution policy gate.
- Treat `scripts/ai/post-tool-use.sh` as canonical post-execution evidence writer.
- Unknown or external scripts must be `ask` unless explicitly approved.

## 7) Generated and Protected Files

- Generated files/paths: `docs/ai/generated/, result, result-*, scc-by-file*.csv`
- Protected files/paths: `home/.chezmoidata/personal.yaml, home/.chezmoidata/personal.local.yaml, nix/flake.lock`

Do not edit generated files directly unless the task explicitly requires regeneration.

## 8) Verification Commands

- Main verification command: `bash ops/validate-config.sh`
- Main build command: `mise run repo:check`
- Main test command: `mise run test:bash`
- Preferred narrow-first strategy: `start with the narrowest repo-local check and escalate only if needed`

Additional project commands:

- Install: `bash ops/install.sh`
- Lint: `mise run lint:shell`
- Format: `mise run nix:fmt`

## 9) Approval Boundaries

- `secrets, destructive changes, NixOS system layer (sys-setup), install/apply scripts, uninstall actions`

Never claim verification that was not run.

## 10) Unknowns / Do-Not-Invent

If a convention is missing from code, tests, config, or this file:

- do not invent new conventions
- inspect nearest existing example
- ask before introducing new architecture patterns

Blocked response format:

```text
Blocked by unknown: <UNKNOWN>
Evidence checked: <FILES_OR_COMMANDS_CHECKED>
Safe next step: <NEXT_STEP>
```

## 11) Workflow Notes

- Capability composition hints: `start with project-context, then verify-change, then review-diff`
- Release safety notes: `define rollback posture for medium/high risk changes`
- Known gotcha themes: `stale paths, broad edits without evidence, guessed behavior, secrets in personal.yaml`
- Review priorities: `correctness, secrets leakage, idempotency of install/apply, host-profile compatibility, chezmoi/nix template drift`

## 12) Project-Specific Rule Placeholders

Fill and maintain these for each installed project:

- Formatting exceptions: `nix/flake.lock, docs/ai/generated/, result, result-*`
- Additional ignored files/paths: `home/.chezmoidata/personal.yaml, home/.chezmoidata/personal.local.yaml, mise.local.toml, .dotfiles-snapshots/`
- Allowed scripts list: `ops/*.sh (validate-config, doctor, detect-host, snapshot-home, bootstrap dry-run)`
- Forbidden script patterns: `ops/install.sh --apply, ops/system-setup.sh --apply, ops/uninstall.sh --apply without explicit approval`
- Additional security rules: `Never commit or echo home/.chezmoidata/personal.yaml; never log SSH keys, API tokens, or real identity values; only home/personal.yaml.example is tracked`

## 13) Additional Project Docs

Extra project docs the AI should reference. Manage these under `context.extraDocs`
in `.ai/project.yml`; the list is re-rendered here on every install/upgrade.

_No additional project docs configured. Add paths under `context.extraDocs` in `.ai/project.yml`._
