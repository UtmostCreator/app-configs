# Tool Policy

Prefer read-only inspection first and wrapper scripts when available.

Preferred execution order:

1. repository wrapper scripts (`scripts/ai/*`, `scripts/copilot/*`)
2. content/file discovery search
3. history tracing
4. rule/security checks
5. context packaging after secret scan

Never run without approval:

- destructive filesystem operations
- privileged/elevated commands
- package installations with system impact
- deployment/release operations
- credential mutation
- remote write operations
