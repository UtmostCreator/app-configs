---
name: new-feature
description: Use when implementing a bounded feature with existing repository patterns and focused verification
argument-hint: "Describe the feature, expected behavior, and any constraints"
---

This prompt file is an optional workflow asset. It is not a guaranteed equivalent to a native command system and may require preview support or feature enablement on the active Copilot surface.

Use this prompt for a bounded feature slice that should follow existing repository patterns.

Do not use this prompt for broad architecture changes, large migrations, or bug-first regression work.

Implement the feature with the smallest safe change.

Steps:

1. Inspect the current implementation in `.ai-install-manifest.json,.copilot-logs,.editorconfig,.eslintrc.json,.github,.gitignore,.husky,.lefthook.yml,.markdownlint-cli2.yaml,.opencode,.prettierrc.json,.repomixignore,.schemas,.shellcheckrc,.stylelintrc.json,AGENTS.md,CLAUDE.md,CONTRIBUTING.md,README.md,SECURITY.md,SUPPORT.md,composer.json,composer.lock,configs,docs,justfile,llms.txt,packages,phpunit.xml.dist,policies,reference,scripts,tests,tools`.
2. Identify the existing owner of the behavior.
3. Extend current patterns before adding new abstractions.
4. Add focused tests if behavior changes.
5. Verify with the most relevant command, starting from `unknown` or `unknown`.

Defer to project context for repository facts and to `verify-change` or `review-diff` when those narrower workflows fit better.

Gotchas:

- do not introduce a new subsystem when an existing owner already fits
- do not skip risk and rollout notes for medium or high-risk changes
