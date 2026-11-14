---
name: detect-tech-stack
description: Identifies languages, frameworks, package managers and tools from repository manifests and CI, or checks recorded stack facts for staleness. Read-only.
---

## What I Do

I detect the repository's languages, frameworks, package managers and tools
from its own manifests and CI configuration, and report them with the file that
proves each one. I read and report; I write nothing.

## When To Use Me

- before choosing build, test or lint commands in an unfamiliar repository
- when a project's language or tool signals changed (a new manifest, a new CI workflow)
- when a previously recorded stack description looks stale against the repository's current files

## Do Not Use Me For

- deciding which commands an agent may run: that belongs to the host's
  permission settings and the user, not to a stack scan

## Workflow

1. enumerate manifests and lockfiles (language, framework, package manager)
2. read CI configuration for the commands the project actually runs
3. record each signal with the file that proves it; mark anything unproven `unknown`
4. report the detected stack and the evidence path per signal

## Gotchas

- a dependency present in a manifest is not proof the project uses it at runtime
- a monorepo can carry several stacks; report them all rather than picking one
<!-- glyphbrace:user:begin id=user -->
<!-- glyphbrace:user:end id=user -->
