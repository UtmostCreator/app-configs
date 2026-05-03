---
name: plan-slice
description: Use when a task is multi-step, ambiguous, or architecture-affecting and needs a bounded plan before implementation
argument-hint: 'Describe the goal, scope, and any known constraints or risks'
---

## What I Do

I produce a bounded implementation plan with risk posture, acceptance criteria, and recommended next stage before any implementation begins.

## When To Use Me

- when a task is multi-step, ambiguous, or affects architecture
- when ownership is unclear and needs to be scoped first
- when a slice may grow beyond one safe change

## Do Not Use Me For

- trivial single-step changes where the owner and approach are obvious
- combined planning and implementation in one pass unless explicitly requested

## Workflow

1. use researcher or project-context if ownership is unclear
2. define the bounded slice and acceptance criteria
3. call out risk level and affected areas
4. propose the smallest sound approach
5. list verification implications and recommended next stage

## Output

- bounded plan with acceptance criteria
- risk level
- affected paths and owners
- recommended next stage (implement, research, architect)

## Gotchas

- do not implement as part of this workflow unless explicitly asked
- do not produce a plan so broad it cannot be reviewed in one sitting
