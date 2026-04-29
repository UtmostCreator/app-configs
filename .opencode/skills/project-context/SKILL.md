---
name: project-context
description: Use when planning or reviewing work in an unfamiliar area, choosing verification depth, or checking approval boundaries before editing
compatibility: opencode
---

## What I Do

I provide durable repository context for `app-configs` and point to the support files that other workflows should read next.

## When To Use Me

- before architecture decisions in unfamiliar areas
- before implementation when multiple active paths could own the change
- before review or verification when risk or ownership is unclear
- when another skill needs repository facts first

## Do Not Use Me For

- purely general coding questions with no repository context
- trivial edits where the owner and verification path are already obvious

## Read Alongside

- `docs/ai/capabilities/project-context/CAPABILITY.md`
- `docs/ai/capabilities/project-context/gotchas.md`
- `docs/ai/capabilities/project-context/examples.md`

## Project Shape

- Project type: `php project`
- Summary: `AI workflow starter for app-configs`
- Primary language: `unknown`
- Primary runtime: `unknown`
- Active paths: `.copilot-logs,.editorconfig,.eslintrc.json,.github,.gitignore,.husky,.lefthook.yml,.markdownlint-cli2.yaml,.prettierrc.json,.repomixignore,.schemas,.shellcheckrc,.stylelintrc.json,AGENTS.md,CLAUDE.md,CONTRIBUTING.md,README.md,SECURITY.md,SUPPORT.md,composer.json,composer.lock,configs,docs,justfile,llms.txt,packages,phpunit.xml.dist,policies,reference,scripts,tests,tools`
- Inactive paths: `unknown`
- Targets: `unknown`

## Architecture Notes

- Primary entrypoints: `README.md, docs/ai/project-context.md`
- Notes: `Keep policy and capability docs canonical; keep runtime adapters thin.`
- Risk areas: `stale docs, adapter drift, unsafe command usage`

## Verification Expectations

- Main verification command: `unknown`
- Main build command: `unknown`
- Main test command: `unknown`
- Preferred narrow-first pattern: `start with the narrowest repo-local check and escalate only if needed`

## Review Priorities

- `correctness, regressions, configuration drift`

## Change Hygiene

- Before changing code, config, docs, or workflow logic, search for similar existing patterns in the touched area and nearby owners and report the closest overlap as a percentage.
- If overlap is roughly `>=75%`, flag reuse or replacement immediately and recommend updating the existing pattern instead of adding a duplicate.
- After completing the change, run a touched-scope stale sweep on edited files and nearby references for stale methods, stale data assumptions, stale commands/paths, outdated docs, unresolved placeholders, and generated-output drift.

## Approval Boundaries

- `secrets, destructive changes, auth or billing changes`

## Common Gotchas

- `stale paths, broad edits without evidence, guessed behavior`
