---
name: infra-risk-audit
description: Audits dependency, compatibility, build, deployment and infrastructure risks before approval or release. Reports findings without applying fixes.
---

## What I Do

I audit dependency, build, release, and compatibility risk read-only. I assess each risk against the exact manifest, lockfile, or config line that backs it, severity-rank the findings, and name the owner or next action. I report risk; I do not apply fixes.

## Choose This Skill When

- A dependency, version, or lockfile change may carry risk.
- A build or release configuration change needs a risk read before rollout.
- Environment or tooling compatibility is uncertain.
- A verification-workflow change could weaken proof coverage.

## Choose Another Skill When

- Use `release-safety` when designing rollout, rollback, migration, or operational controls.
- Use `dependency-upgrade` when implementing and verifying a dependency upgrade.

## Read Alongside

- `release-safety` — rollout, rollback, and disable paths
- `dependency-upgrade` — when the risk comes from a dependency bump


## Steps

1. Scope the audit to the specific dependency, build, or compatibility concern and gather the backing evidence (manifest, lockfile, config, or diff).
2. Assess dependency risk against the exact lockfile/manifest entry and version; do not issue a verdict from inference alone.
3. Assess build, release, and compatibility risk against the exact file and line, including any verification-coverage impact.
4. Severity-rank each finding and cite the file, line, and version (for dependency risk) that backs it.
5. Name the owner or the matching next action for each finding; do not recommend wider rollout without matching verification evidence.
6. Report the risk findings; if evidence is insufficient or a probe cannot complete, report `blocked` and name the missing evidence rather than asserting a clean result.

## Output

- a severity-ranked risk findings table with file, line, and version citations
- the owner or next action per finding (upgrade, build-config, release review, or implementer)
- a `blocked` note naming any missing evidence instead of a guessed pass

## Gotchas

- do not present advisory risk as a confirmed production incident
<!-- glyphbrace:user:begin id=user -->
<!-- glyphbrace:user:end id=user -->
