# Review Diff Capability

## Purpose

Review the proposed change set for accuracy, drift, portability, and missing verification.

## Trigger When

- a slice is ready for review
- a runtime adapter changed
- canonical docs and implementation may have drifted

## Workflow

1. review the diff first
2. check whether canonical docs and adapters still agree
3. inspect surrounding files only when a concern requires it
4. flag missing evidence, stale paths, and needless complexity

## Output Contract

- verdict
- findings with file references
- drift assessment
- recommended next step
