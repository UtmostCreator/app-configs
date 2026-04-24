---
applyTo: "**/*.php"
description: "PHP investigation and verification routing"
---

For PHP work:

- Prefer `scripts/copilot/ai-search.sh text ...` or `scripts/copilot/rg-code.sh --mode php` before wider scans.
- Check related tests and config before edits.
- Prefer `scripts/copilot/git-forensics.sh L ...` for method history in service/controller files.
- Use `semgrep` only for targeted security or framework pattern checks.
