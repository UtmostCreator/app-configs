# Config Change Safety Capability

## Purpose

Apply editor, shell, runtime, or machine-facing config changes without widening risk silently.

## Trigger When

- editing user settings
- changing shell startup behavior
- modifying runtime config with machine-specific paths
- altering instructions that affect automation behavior across tools

## Workflow

1. identify the blast radius of the config surface
2. preserve existing behavior unless the task explicitly changes it
3. call out machine-specific assumptions in shared docs
4. validate with the closest safe check available
5. document rollback posture for medium or high risk changes

## Output Contract

- affected surface
- compatibility notes
- verification notes
- rollback note when relevant
