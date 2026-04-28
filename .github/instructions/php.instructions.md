---
applyTo: "**/*.php"
description: "PHP investigation and verification routing"
---

For PHP work:

- Treat `reference/php/design-patterns/` as the primary local reference for design pattern examples.
- Treat `reference/php/design-principles/` as the secondary local reference for principles and composition examples.
- Treat `reference/php/php-built-ins/` as the tertiary local reference for built-in PHP usage examples.
- Prefer `scripts/copilot/ai-search.sh text ...` or `scripts/copilot/rg-code.sh --mode php` before wider scans.
- Prefer targeted local searches before external references, for example:
  - `scripts/copilot/ai-search.sh text "singleton|factory|strategy" reference/php/design-patterns`
  - `scripts/copilot/ai-search.sh text "SOLID|composition" reference/php/design-principles`
  - `scripts/copilot/ai-search.sh text "array_" reference/php/php-built-ins`
- Check related tests and config before edits.
- Prefer `scripts/copilot/git-forensics.sh L ...` for method history in service/controller files.
- Use `semgrep` only for targeted security or framework pattern checks.
