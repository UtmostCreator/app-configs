# app-configs Project Context

Use this file as durable project context for instructions, agents, prompts, and capabilities.

## Project Shape

- Project type: `php project`
- Summary: `AI workflow starter for app-configs`
- Primary language: `unknown`
- Primary runtime: `unknown`
- Supported targets: `unknown`
- Active paths: `.ai-install-manifest.json,.copilot-logs,.editorconfig,.eslintrc.json,.gitattributes,.github,.gitignore,.husky,.lefthook.yml,.markdownlint-cli2.yaml,.opencode,.prettierrc.json,.repomixignore,.schemas,.shellcheckrc,.stylelintrc.json,AGENTS.md,CLAUDE.md,CONTRIBUTING.md,README.md,SECURITY.md,SUPPORT.md,composer.json,composer.lock,configs,docs,justfile,llms.txt,packages,phpunit.xml.dist,policies,reference,scripts,tests,tools`
- Inactive paths: `unknown`

## Architecture

- Primary entrypoints: `README.md, docs/ai/project-context.md`
- Architecture notes: `Keep policy and capability docs canonical; keep runtime adapters thin.`
- Risk areas: `stale docs, adapter drift, unsafe command usage`

## Verification

- Main verification command: `unknown`
- Main build command: `unknown`
- Main test command: `unknown`
- Preferred narrow-first verification pattern: `start with the narrowest repo-local check and escalate only if needed`

## Review Focus

- `correctness, regressions, configuration drift`

## Change Hygiene

- Before changing code, config, docs, or workflow logic, search for similar existing patterns in the touched area and nearby owners and report the closest overlap as a percentage.
- If overlap is roughly `>=75%`, flag reuse or replacement immediately and recommend updating the existing pattern instead of adding a duplicate.
- After completing the change, run a touched-scope stale sweep on edited files and nearby references for stale methods, stale data assumptions, stale commands/paths, outdated docs, unresolved placeholders, and generated-output drift.

## Approval Boundaries

- `secrets, destructive changes, auth or billing changes`

## Workflow Notes

- Capability composition hints: `start with project-context, then verify-change, then review-diff`
- Tool selection: `when the repository provides a tool map or command wrappers, follow that routing first; prefer rg, fd, ast-grep/sg, and structured queries over grep, find, or broad file dumps`
- Release safety notes: `define rollback posture for medium/high risk changes`
- Known gotcha themes: `stale paths, broad edits without evidence, guessed behavior`
