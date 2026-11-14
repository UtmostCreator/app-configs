---
name: release-safety
description: "Assesses rollout, rollback, migration, compatibility and observability safeguards for medium- or high-risk changes. Reports unresolved risks; does not deploy."
---

## What I Do

I assess rollout posture, rollback options, observability, and unresolved release risk for medium and high-risk changes.

## Choose This Skill When

- A change introduces rollout, rollback, migration, compatibility, or operational risk.
- Contracts, migrations, or deployment behavior changed.
- Review or planning needs explicit release safeguards.

## Choose Another Skill When

- Use `infra-risk-audit` when assessing technical-system risks.
- Use `verify-change` when running targeted verification of implementation claims.

## Read Alongside

- `infra-risk-audit` — dependency, build, and infrastructure risk
- `verify-change` — the proof depth a release needs

## Safeguard Checklist

1. Confirm rollout shape — flag/config/staged/big-bang — and who or what
   controls the exposure.
2. Confirm a rollback or disable path exists and how fast it can be taken.
3. Confirm the observability or smoke-check signal that would surface a bad
   release, and whether it already exists or still needs to be added.
4. Confirm migration and compatibility behavior — forward and backward — for
   any contract, schema, or data change in the release.
5. Name the release risks that remain unresolved after the above.

## Output

- rollout posture
- rollback or disable path
- observability or smoke-check signal
- unresolved release risks

## Gotchas

- do not present local test success as a release-safety verdict
- do not use this for low-risk or trivial changes
<!-- glyphbrace:user:begin id=user -->
<!-- glyphbrace:user:end id=user -->
