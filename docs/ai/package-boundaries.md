# AI Package Boundaries

Use this file to prevent source-of-truth drift between package assets, root dogfood assets, examples, and generated exports.

## Boundary Roles

## A) Reusable package source (canonical)

- Path: `packages/ai-universal-rules/`
- Purpose: canonical reusable toolkit source.

Includes:

- `templates/` (install payload source)
- `docs/` (package-level guidance)
- `manifest.json` / `manifest.yml`
- `catalog.json` and generated package browse docs

## B) Install payload source (canonical for installation)

- Path: `packages/ai-universal-rules/templates/`
- Purpose: authoritative install-time file source.

Rule:

- Installer pack mappings should point to template/package sources for reusable behavior.

## C) Root live files (dogfood / in-repo operations)

- Paths: `.github/`, `.opencode/`, `docs/ai/`, `scripts/`, `tools/ai/`, `policies/`
- Purpose: this repository’s live runtime and verification environment.

Rule:

- Root dogfood/live files are allowed to be repo-specific when needed for local operations.
- Root runtime files are not the canonical reusable package source.

## D) Educational examples

- Path: `packages/ai-universal-rules/examples/`
- Purpose: educational/example trees for adopters.

Rule:

- Examples may include fictional project naming and worked setup patterns.
- Examples must not be mistaken for canonical package source or deterministic fixture contracts.

## E) Generated export artifacts

- Path: `dist/`
- Purpose: generated export bundles only.

Rule:

- `dist/` is never hand-authored source-of-truth.
- Exports must be reproducible from package source and export profiles.

## Guardrails

- Do not redefine package source ownership in runtime adapter files.
- Do not treat root `.github` or `.opencode` as canonical package authoring source.
- Do not treat example trees as deterministic test fixtures unless explicitly promoted and documented as fixtures.
