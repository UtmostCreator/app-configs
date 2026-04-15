---
applyTo: "**/*.php"
description: "PHP investigation and verification routing"
---

For PHP work:

- Prefer `rg -n -tphp` through `scripts/copilot/rg-code.sh` before wider scans.
- Check related tests and config before edits.
- Prefer `scripts/copilot/git-forensics.sh L ...` for method history in service/controller files.
- Use `semgrep` only for targeted security or framework pattern checks.
