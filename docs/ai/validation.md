# Validation

Use the root validator to catch the most common AI workflow setup failures before they drift further.

## Command

```powershell
php tools/ai/validate-ai-config.php
php tools/ai/validate-ai-catalog.php
php tools/ai/generate-ai-catalog.php --check
php tools/ai/export-ai-universal-rules.php --check
```

## What It Checks

- required root AI workflow files exist
- unresolved placeholder leaks like `<PROJECT_NAME>`
- broken backtick path references in the live root AI docs and adapters
- obvious stack leakage from old mismatched instructions
- a few key drift rules between `AGENTS.md`, `CLAUDE.md`, `README.md`, and `.github/copilot-instructions.md`
- package manifest and generated catalog structure
- generated docs and `llms.txt` drift against source metadata
- starter profile export definitions for `AI-universal-rules`

## Scope

This validator is intentionally narrow.

- it checks the root live-instantiation layer first
- it does not try to fully validate every example under `AI-universal-rules/examples/`
- it treats warnings as review signals and errors as must-fix issues

## Output

- `OK` - the root layer passed the current checks
- `WARN` - likely drift or stale wording worth reviewing
- `ERROR` - missing files, placeholders, or broken references

## When To Run It

- after editing `AGENTS.md`, `CLAUDE.md`, `README.md`, `docs/ai/`, or `.github/`
- after editing `AI-universal-rules/manifest.json`, cataloged templates, or examples
- before creating a baseline commit for workflow changes
- after copying templates into a new repo instance
