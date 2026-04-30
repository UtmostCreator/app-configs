# AI Toolkit Readiness Scorecard

Use this scorecard to track maturity for release-grade reusable package quality.

## Target Bands

| Area | Current | Target |
| --- | ---: | ---: |
| Context/advisor packs | 66 | 88-90 |
| Generated artifacts policy | 70 | 86-90 |
| Validation/CI | 74 | 90+ |
| Package boundary | 78 | 90+ |
| Runtime adapters | 76 | 88+ |
| Installer architecture | 84 | 92+ |
| Overall maturity | 78 | 90+ |

## Locked Preconditions

- Reusable package source remains `packages/ai-universal-rules/`.
- Template payload source remains `packages/ai-universal-rules/templates/`.
- Root runtime files remain dogfood/live usage.
- Export output remains generated-only under `dist/`.
- Placeholder syntax remains `<PLACEHOLDER>`.
- PHP installer remains canonical.

## Release Gate Expectation

Release readiness should require:

- deterministic install profile behavior
- reproducible generated package outputs
- explicit safety policy enforcement and validation
- external install proof across representative fixtures
- documented adapter asymmetry where parity is not possible

## Evidence Rule

- A score change must cite command evidence (validators/tests/fixtures), not assumptions.
- Keep direct evidence separate from planned follow-up work.
