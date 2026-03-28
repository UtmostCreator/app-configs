# Docs Sync Capability

## Purpose

Keep setup and workflow documentation aligned with the actual repository after behavior, file, or path changes.

## Trigger When

- commands changed
- paths moved or were renamed
- adapter files were rewritten
- setup docs mention the changed area

## Workflow

1. list the changed files, commands, and paths
2. search for all user-facing references to them
3. update docs to match current repo truth
4. remove or mark stale guidance instead of leaving partial drift

## Output Contract

- docs touched
- stale references removed
- remaining docs not updated
