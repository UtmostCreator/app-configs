# Copilot Getting Started

Use this guide for a small, practical GitHub Copilot setup in this repository or when copying the pattern to another repository.

## What this repo gives Copilot

- Canonical workflow policy under `docs/ai/`.
- Thin runtime adapter at `.github/copilot-instructions.md`.
- Optional runtime extras in `.github/instructions/`, `.github/agents/`, `.github/prompts/`, `.github/skills/`, and `.github/hooks/`.
- Wrapper scripts in `scripts/copilot/` for search, edit safety, verification, and context packing.

## Minimum install for another repo

Copy these first:

- `.github/copilot-instructions.md`
- `docs/ai/project-context.md`
- `docs/ai/workflow.md`
- `docs/ai/agents.md`
- `docs/ai/failure-handling.md`
- `docs/ai/capabilities/project-context/`
- `docs/ai/capabilities/verify-change/`
- `docs/ai/capabilities/review-diff/`

Then update project-specific facts in `docs/ai/project-context.md`.

## Optional folders after baseline

- `.github/instructions/` for path-scoped coding rules.
- `.github/agents/` for staged role workflows.
- `.github/prompts/` for repeatable task entrypoints.
- `.github/skills/` for reusable workflow packs.
- `.github/hooks/` and `scripts/copilot/` for stronger guardrails and telemetry.
- `docs/ai/copilot-tooling.md` for wrapper-first routing details.

## Read order

1. `README.md`
2. `.github/copilot-instructions.md`
3. `docs/ai/project-context.md`
4. `docs/ai/workflow.md`
5. `docs/ai/agents.md`
6. `docs/ai/failure-handling.md`
7. relevant `docs/ai/capabilities/*`

Use `docs/ai/catalog.md` when you need the full generated inventory of live AI assets.

## Example flow: investigate a bug

1. Read `.github/copilot-instructions.md` and `docs/ai/project-context.md`.
2. Load `docs/ai/capabilities/bug-regression/CAPABILITY.md` for the fix posture.
3. Use `.github/prompts/investigate-bug.prompt.md` if your Copilot surface supports prompt files.
4. Prefer narrow checks before broad verification.
5. Record evidence with exact file paths and command outputs.

## Example flow: review workflow drift

1. Read `.github/copilot-instructions.md` and `docs/ai/project-context.md`.
2. Compare adapter surfaces with canonical docs in `docs/ai/`.
3. Check `docs/ai/agents.md` and `docs/ai/integration-matrix.md` for declared coverage.
4. Run `php tools/ai/validate-ai-config.php` and `php tools/ai/validate-ai-catalog.php`.
5. Use `workflow-auditor` when drift risk is the primary concern.
