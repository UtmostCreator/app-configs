# AI Toolkit Architecture Locks

This file locks the core architecture decisions for the reusable AI toolkit.

Changes to these rules must **strengthen** the model, not replace it.

## 1) Canonical Package Source

- Canonical reusable package source: `packages/ai-universal-rules/`.
- Canonical install payload source: `packages/ai-universal-rules/templates/`.

## 2) Install Payload Source

- Target repositories install from package templates and installer pack mappings.
- Runtime adapters are installed as outputs; they are not the canonical authoring source.

## 3) Root Dogfood / Live Usage

- Root `.github/`, `.opencode/`, `docs/ai/`, and related runtime files are live dogfood usage for this repository.
- Root runtime files may be repository-specific when required by local ownership and verification flows.

## 4) Export Boundary

- `dist/` is generated export output only.
- Export bundles are reproducible artifacts derived from package source and export profile definitions.

## 5) Placeholder Syntax

- Canonical placeholder syntax is angle-bracket uppercase tokens, for example `<PROJECT_NAME>`.
- Placeholder references are documented in `packages/ai-universal-rules/PLACEHOLDERS.md`.

## 6) Installer Ownership

- Canonical installer implementation is `php tools/ai/install-ai-kit.php`.
- Shell installers are wrappers (`tools/ai/install-ai-kit.sh`, `tools/ai/install-copilot-kit.sh`).
- Profile composition remains deterministic and pack-based.

## 7) Runtime Adapter Asymmetry

- OpenCode and GitHub Copilot adapters may be asymmetric by design.
- Canonical workflow policy and reusable procedure live in neutral docs/capabilities first.

## 8) Advisor Optionality

- Advisor remains optional and dry-run-first.
- Advisor behavior must not silently assume network/provider execution.

## 9) Generated Artifact Policy Summary

- Deterministic generated assets are validated for drift.
- Transient runtime logs are not canonical package source.
- Generated artifacts must remain tied to explicit generator/check commands.

## 10) Safety Gate Requirements

- Safety policy is not docs-only; runtime enforcement hooks/scripts must remain active where supported.
- Dangerous command classes are denied or gated by confirmation policy.
- Approval boundaries are explicit and must not be silently widened.
