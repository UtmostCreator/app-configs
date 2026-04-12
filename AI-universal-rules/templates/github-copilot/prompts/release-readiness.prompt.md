---
name: release-readiness
description: Use when a diff or planned change needs rollout, rollback, observability, and migration-safety review
argument-hint: "Describe the change, risk, and deployment surface"
---

Use this prompt for `medium` or `high` risk changes.

Return:

- rollout posture
- rollback or disable path
- observability or smoke signal
- unresolved release risks

Do not present local test success as a complete release-safety answer.
