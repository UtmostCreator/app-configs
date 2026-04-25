# Preview Environments Capability

## Purpose

Define a vendor-neutral operating model for temporary end-to-end environments used during review and verification.

## Trigger When

- medium or high-risk changes need realistic integration validation
- pull-request workflows require isolated environment checks
- environment-tier expectations are unclear across runtime surfaces

## Workflow

1. classify whether the change requires a preview environment
2. define environment naming, lifecycle, and TTL rules
3. apply synthetic data and isolated secret rules
4. run targeted verification in the preview scope
5. record environment identifier in evidence output
6. enforce cleanup and expiry after review

## Output Contract

- preview requirement decision and rationale
- environment lifecycle and TTL posture
- data and secret isolation notes
- verification evidence tied to environment identifier
- cleanup confirmation or blocker

## Acceptance Criteria

- preview environments use deterministic naming and TTL
- production secrets are never reused in preview scope
- preview data is synthetic or anonymized
- cleanup is mandatory and recorded
