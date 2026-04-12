# Workflow Integration (Basic, Replaceable Defaults)

This setup intentionally stays **simple** so you can replace parts per machine/project.

## 1) Add a command control plane (`justfile`)

Run from repo root:

```bash
just --list
just doctor
just bootstrap
just hook-run-precommit
just php-test
just ai-review
```

## 2) Enable doctor checks

`doctor` runs `scripts/doctor.sh` and validates:
- key binaries (`git`, `rg`, `php`, `nvim`, `tmux`, `just`, ...)
- core config files
- hook framework files (Husky + Lefthook)
- secret scanner presence (gitleaks or trufflehog)
- basic AI config presence (VS Code + Neovim Copilot files)

Use this as a base and add your local checks.

## 3) Source shared shell helpers

Add to your `~/.zshrc`:

```bash
source /path/to/app-configs/shell/zshrc.shared
```

Then use:
- `acfg` (jump to repo)
- `acfg-doctor`
- `acfg-bootstrap`
- `acfg-ai-review`

## 4) Hooks + secret scanning

- Husky hooks live in `.husky/*`
- Lefthook config lives in `.lefthook.yml`
- Both call shared scripts in `scripts/hooks/*`

See: `docs/hooks-secret-scanning.md`

## 5) PHP automation and AI assistance

You now have starter PHP commands in `justfile`, and a roadmap for faster test authoring + AI helper agents.

See: `docs/php-automation-and-ai.md`

## 6) Extra workflow areas to improve

- **Git hygiene**: commit-msg lint + conventional commits.
- **Branch protections**: required checks + linear history.
- **Secrets safety**: local + CI scanning split.
- **Dependency safety**: scheduled update checks + lockfile policy.
- **Terminal productivity**: tmux session templates per project.
- **AI quality loop**: standard prompt template for plan → patch → verify.
