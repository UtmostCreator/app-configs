# Security Policy

## Reporting

If you find a security issue in this repository, please do not open a public issue with exploit details.

Instead:

- describe the affected file or workflow surface
- explain the risk and likely impact
- include reproduction steps if they are safe to share privately

If the issue involves credentials, local-machine secrets, private endpoints, or a workflow that could cause destructive behavior, treat it as sensitive.

## Scope

Security-sensitive areas include:

- AI workflow instructions that could weaken approval boundaries
- hooks, scripts, or validation logic that could run unsafe commands
- machine-specific setup guidance that risks secret leakage
- release packaging or generated metadata that misstates trust boundaries

## Remediation Expectations

- prefer the smallest safe fix
- document fallback behavior when a runtime surface cannot enforce the same guardrail
- add validation coverage when the defect could drift back in later
