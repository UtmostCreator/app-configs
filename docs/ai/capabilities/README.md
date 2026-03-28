# Capabilities

These folders are the canonical reusable workflow layer for the root repository.

- `project-context` - load durable repo facts first
- `verify-change` - choose the smallest valid proof
- `review-diff` - review slices for drift and missing evidence
- `bug-regression` - reproduce, fix, and prove config or workflow defects
- `docs-sync` - keep setup guidance aligned with repo truth
- `config-change-safety` - manage blast radius for editor, shell, runtime, and machine-facing config edits

Keep runtime-specific adapters thin and point them back here.
