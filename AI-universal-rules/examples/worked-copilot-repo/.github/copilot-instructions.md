# Repository Instructions For Acme Web

- Project: `Acme Web`
- Type: `web app`
- Summary: `Customer-facing storefront and account portal.`
- Active paths: `apps/web, packages/ui, packages/api-client`
- Avoid by default: `legacy-web/`
- Project context file: `docs/ai/project-context.md`
- Capability folders available: `project-context, verify-change, review-diff, bug-regression`

## Working Style

- Prefer the smallest safe change.
- Keep this file policy-focused.
- Classify non-trivial work as `low`, `medium`, or `high`.
- Ask for approval before auth, billing, env, or dependency changes.
- Say `unknown` instead of guessing when repo evidence is missing.

## Quality Bar

- Use focused component, route, or Playwright proof before broader workspace checks.
- Treat build success as smoke evidence.
- For `medium` and `high` risk changes, define rollback or disable path and post-deploy signal.
