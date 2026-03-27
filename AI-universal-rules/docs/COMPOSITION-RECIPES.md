# Composition Recipes

Use this guide to map a request type to a small capability sequence. Start with the shortest sequence that fits the task.

The canonical workflow details still live in the capability folders themselves.

## How To Read A Recipe

- use when: the request pattern this recipe fits
- primary sequence: the default capability order
- optional add-ons: extra capabilities only when risk or scope justifies them
- expected output: what the combined flow should produce
- common mistake: the most likely overreach or omission

## Unfamiliar Area

- use when: the task touches an unclear owner, unfamiliar path, or multi-surface repo area
- primary sequence: `project-context`
- optional add-ons: `review-diff` if changes already exist
- expected output: likely owners, affected paths, risks, and verification surface
- common mistake: starting implementation before confirming the owner

## Bounded Bug Fix

- use when: behavior is wrong and should be fixed with the smallest safe change
- primary sequence: `project-context` -> `bug-regression` -> `verify-change`
- optional add-ons: `review-diff`
- expected output: reproduction, minimal fix, and direct evidence
- common mistake: skipping reproduction or broadening the fix too early

## Bounded Feature

- use when: behavior is being extended without a broad architecture change
- primary sequence: `project-context` -> `verify-change`
- optional add-ons: `review-diff`, `release-safety`
- expected output: affected owner, implementation slice, and proportional verification
- common mistake: treating a bounded feature as a full redesign

## Review Existing Change

- use when: a diff already exists and needs correctness and risk review
- primary sequence: `project-context` -> `review-diff`
- optional add-ons: `verify-change` if evidence is weak or missing
- expected output: findings, risk assessment, and missing verification
- common mistake: expanding into broad implementation planning instead of reviewing the actual change

## Dependency Upgrade

- use when: a package, framework, runtime, or toolchain version changes
- primary sequence: `project-context` -> `dependency-upgrade` -> `verify-change`
- optional add-ons: `review-diff`, `release-safety`
- expected output: compatibility risk, verification evidence, and rollout notes when relevant
- common mistake: treating install success as proof of runtime safety

## Risky Change Or Rollout-Sensitive Change

- use when: rollout, rollback, migration, or shared-contract risk matters as much as local correctness
- primary sequence: `project-context` -> `review-diff` -> `verify-change` -> `release-safety`
- optional add-ons: none by default
- expected output: release posture, rollback path, success signal, and unresolved risk
- common mistake: stopping at local test success without release planning

## Migration Or Schema Change

- use when: data shape, contracts, or expand-contract sequencing matters
- primary sequence: `project-context` -> `verify-change` -> `review-diff` -> `release-safety`
- optional add-ons: `bug-regression` when fixing a migration-related regression
- expected output: migration safety, compatibility notes, and rollout guidance
- common mistake: treating a risky migration like a normal local refactor

## Architecture Or Exploration Question

- use when: the task is mostly about ownership, options, or next steps before implementation
- primary sequence: `project-context`
- optional add-ons: none at first
- expected output: owner, boundaries, risks, and the next recommended capability
- common mistake: triggering implementation-heavy workflows before the task is scoped

## Escalation Rules

- add `review-diff` when a real change set exists and needs assessment
- add `verify-change` when the request makes a behavior claim
- add `release-safety` when the risk level is `medium` or `high`
- add `dependency-upgrade` only for actual version or tooling changes
- add `bug-regression` when a bug should start from focused reproduction

## Common Composition Mistakes

- composing too many capabilities before the task is scoped
- skipping `project-context` when ownership is unclear
- using `review-diff` before a diff exists
- using `release-safety` for trivial local changes
- using `dependency-upgrade` as a generic cleanup workflow
