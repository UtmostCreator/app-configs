---
name: dependency-upgrade
description: Use when a library, runtime, framework, or toolchain upgrade is requested; assess compatibility and verification, and route the install and lockfile change to the role that holds dependency authority.
---

## What I Do

I scope dependency upgrade risk, identify the real usage surface, and drive proportional verification.

## When To Use Me

- when a package, framework, runtime, or toolchain dependency changes
- when security or compatibility updates are requested
- when dependency drift may affect build or runtime behavior

## Owner

This skill grants no install authority. Apply installs and lockfile changes only when the user asked for them; otherwise scope the risk, verify what you can, and report the change for the user to approve.

## Read Alongside

- `infra-risk-audit` — build and supply-chain risk
- `release-safety` — rollout and rollback posture
- `verify-change` — the proof the upgrade needs
- `safe-refactor` — the preparatory structural wave, when one is needed first


## Migration Strategy Selection

When the upgrade requires a consumer, data, or implementation migration, choose
the migration strategy before changing code, and return work that crosses a
service boundary to whoever owns the design. A routine version bump does not
require a migration plan.

- `technical-change-planning` helps select the strategy.
For each temporary compatibility construct, record its owner, removal condition,
and removal trigger before implementation.

## Workflow

1. inspect current version and usage surface
2. review likely migration impact
3. define the minimum required change; the dependency-authorized owner applies the install and lockfile change, and code adaptation stays within the acting role's own permissions
4. run focused verification
5. summarize compatibility risks and follow-up work

## Output

- upgrade scope
- compatibility risk
- verification evidence
- follow-up work or rollout notes

## Gotchas

- do not treat a build success as full compatibility proof
- do not skip runtime behavior checks for major version changes
<!-- glyphbrace:user:begin id=user -->
<!-- glyphbrace:user:end id=user -->
