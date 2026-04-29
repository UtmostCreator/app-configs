# Risk Taxonomy

Use this shared model for non-trivial AI-assisted changes.

| Risk | Score | Typical scope | Required controls |
| --- | ---: | --- | --- |
| Low | 0-30 | docs, comments, narrow config, bounded no-behavior edits | focused verification |
| Medium | 31-70 | behavior changes, multi-file script/tool changes, generated artifacts | rollback note + affected checks |
| High | 71-100 | secrets, auth/permissions, schema/migrations, public contracts, release path | explicit approval + release-safety review |

## Escalation Rules

- If blast radius grows beyond one bounded slice, reclassify risk.
- If rollback is unclear, classify at least medium.
- If external/provider writes are involved, classify high until proven otherwise.
