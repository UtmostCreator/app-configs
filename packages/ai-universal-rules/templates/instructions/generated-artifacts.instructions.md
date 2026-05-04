---
applyTo: 'docs/ai/generated/**,.schemas/**,tools/ai/**,scripts/ai/**'
description: 'Generated artifact, schema, catalog, and drift-control rules'
---

# Generated Artifact Rules

- Do not manually edit generated artifacts unless the policy explicitly allows it.
- Change the source, schema, or generator first.
- Run generator checks after changing generator input.
- Keep generated outputs deterministic.
- Record evidence logs for generator, installer, and validation changes.
- Treat generated-output drift as a verification failure unless intentionally approved.

## Required Checks

Use relevant commands:

- `php tools/ai/validate-ai-config.php`
- `php tools/ai/validate-ai-catalog.php`
- `php tools/ai/generate-ai-catalog.php --check`
- `php tools/ai/verify-full-install.php`
- `php tools/ai/ai.php install --profile <profile> --dry-run`
