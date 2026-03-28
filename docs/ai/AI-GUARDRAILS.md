# AI Guardrails

## Default Rules

- Do not invent stack details, runtime support, or commands that are not proven in this repository.
- Keep canonical workflow knowledge in `docs/ai/` and thin adapter knowledge in runtime-specific files.
- Require proof for completion claims.
- Prefer narrow changes and narrow verification.
- Surface uncertainty explicitly.

## Approval Required

- secrets or credential handling
- destructive cleanup beyond clearly stale files
- compatibility-breaking runtime changes
- machine-wide runtime edits that are hard to undo quickly

## Evidence Standard

- Name the command, parser, linter, or manual check that produced the claim.
- Separate executed verification from recommended next checks.
- Treat documentation updates as incomplete if they leave stale commands or paths behind.

## Drift Signals

- adapter files no longer match canonical docs
- examples treated as live repo facts
- project instructions mention frameworks not used here
- setup docs point to missing files or wrong paths
