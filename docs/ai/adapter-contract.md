# Adapter Contract

Canonical docs under `docs/ai/` define workflow and policy.

Adapter files (`.github/**`, `.opencode/**`, `AGENTS.md`) must stay thin and must:

- link back to canonical docs
- avoid duplicating long procedures
- avoid introducing project/domain-specific hardcoding
- declare fallback behavior when a runtime feature is unsupported

Adapter files must not:

- redefine approval boundaries
- redefine risk levels in contradiction to canonical docs
- become the sole source of critical workflow steps

If adapter and canonical docs drift, update adapters first unless canonical behavior intentionally changed.
