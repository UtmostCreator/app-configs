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
4. require duplicate-logic screening evidence before passing review
5. flag similar existing patterns with roughly `>=75%` overlap as reuse or replacement candidates
6. flag missing evidence, stale paths, and needless complexity

## Output Contract

- verdict
- findings with file references
- drift assessment
- duplicate-logic screening result (`pass` | `issue` | `not-applicable`) with evidence path
- recommended next step
