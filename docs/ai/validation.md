# Validation

Use the root validator to catch the most common AI workflow setup failures before they drift further.

## Command

```powershell
php tools/ai/validate-ai-config.php
php tools/ai/validate-ai-catalog.php
php tools/ai/generate-ai-catalog.php --check
php tools/ai/generate-repo-structure.php --check --with-scc
php tools/ai/export-ai-universal-rules.php --check
```

## What It Checks

- required root AI workflow files exist
- unresolved placeholder leaks like `app-configs`
- broken backtick path references in the live root AI docs and adapters
- obvious stack leakage from old mismatched instructions
- a few key drift rules between `AGENTS.md`, `CLAUDE.md`, `README.md`, and `.github/copilot-instructions.md`
- package manifest and generated catalog structure
- generated docs and `llms.txt` drift against source metadata
- generated repo-structure outputs drift against source metadata and tracked files
- starter profile export definitions for `AI-universal-rules`

## Scope

This validator is intentionally narrow.

- it checks the root live-instantiation layer first
- it does not try to fully validate every example under `packages/ai-universal-rules/examples/`
- it treats warnings as review signals and errors as must-fix issues

## Output

- `OK` - the root layer passed the current checks
- `WARN` - likely drift or stale wording worth reviewing
- `ERROR` - missing files, placeholders, or broken references

## Hook Adapters

This repository keeps both Husky and Lefthook surfaces as optional hook adapters.

- Canonical hook behavior lives in `scripts/hooks/`
- `.husky/` is the optional Node/Husky adapter
- `.lefthook.yml` is the optional polyglot Lefthook adapter

## When To Run It

- after editing `AGENTS.md`, `CLAUDE.md`, `README.md`, `docs/ai/`, or `.github/`
- after editing `packages/ai-universal-rules/manifest.json`, cataloged templates, or examples
- before creating a baseline commit for workflow changes
- after copying templates into a new repo instance
- after changing agent responsibilities, failure-handling policy, or approval-free read-only rules
- after updating the phased checklist or concept coverage matrix for AgentOps integration
