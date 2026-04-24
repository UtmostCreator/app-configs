---
applyTo: "**/*.php"
description: "PHP investigation and verification routing"
---

For PHP work:

- Treat `tools/design-patterns/` as the primary local reference for design pattern examples.
- Treat `tools/design-principles/` as the secondary local reference for principles and composition examples.
- Treat `tools/php-built-ins/` as the tertiary local reference for built-in PHP usage examples.
- Prefer `scripts/copilot/ai-search.sh text ...` or `scripts/copilot/rg-code.sh --mode php` before wider scans.
- Prefer targeted local searches before external references, for example:
  - `scripts/copilot/ai-search.sh text "singleton|factory|strategy" tools/design-patterns`
  - `scripts/copilot/ai-search.sh text "SOLID|composition" tools/design-principles`
  - `scripts/copilot/ai-search.sh text "array_" tools/php-built-ins`
- Check related tests and config before edits.
- Prefer `scripts/copilot/git-forensics.sh L ...` for method history in service/controller files.
- Use `semgrep` only for targeted security or framework pattern checks.
