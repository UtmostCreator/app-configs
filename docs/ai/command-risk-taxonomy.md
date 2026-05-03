# Command Risk Taxonomy

Use this matrix to classify single command invocations by reversibility and approval posture.

## Tiers

| Tier | Label | Meaning | Default Approval |
| --- | --- | --- | --- |
| 1 | read-only | reads repo state, metadata, or generated analysis without mutating source or remote systems | auto-approve |
| 2 | modification | writes source, config, staged state, or local artifacts that change working state | confirm |
| 3 | deletion / recovery | destructive delete, rollback, or history rewrite with elevated blast radius | deny or explicit approval |

## Wrapper Entry Points

| Surface | Invocation Shape | Tier | Notes |
| --- | --- | --- | --- |
| `scripts/ai/ai-search.sh` | any | 1 | read-only discovery |
| `scripts/ai/ai-verify.sh` | any | 1 | verification-only checks |
| `scripts/ai/fd-files.sh` | any | 1 | read-only file discovery |
| `scripts/ai/rg-code.sh` | any | 1 | read-only content search |
| `scripts/ai/preview-file.sh` | any | 1 | read-only preview |
| `scripts/ai/git-forensics.sh` | any | 1 | history inspection |
| `scripts/ai/gh-pr-context.sh` | read metadata/checks/reviews | 1 | read-only PR context |
| `scripts/ai/repo-stats.sh` | any | 1 | read-only local metrics |
| `scripts/ai/query-usage.sh` | any | 1 | read-only token/usage estimate |
| `scripts/ai/pack-context.sh` | generated-output only | 1 | writes generated context artifacts only |
| `scripts/ai/ai-edit.sh` | dry-run | 1 | no source mutation |
| `scripts/ai/ai-edit.sh` | apply mode | 2 | mutates source files |
| `scripts/ai/ai-rollback.sh` | list/show | 1 | inspection only |
| `scripts/ai/ai-rollback.sh` | apply/prune | 3 | destructive recovery operations |
| `scripts/ai/repomix-scc-router.sh` | `stats`, `plan`, `pack`, `all` | 1 | generated-output workflow |
| `scripts/ai/repomix-scc-router.sh` | `clean`, `purge` | 3 | deletes generated outputs |
| `scripts/ai/repomix-context-tree.sh` | `analyze`, `plan`, `pack`, `all` | 1 | generated-output workflow |
| `scripts/ai/repomix-context-tree.sh` | `clean`, `purge` | 3 | deletes generated outputs |

## Notes

- Classify mixed-risk wrappers by subcommand or flag, not script name.
- Treat remote mutation, auth, billing, and secret-bearing actions as higher risk even if a command appears read-only.
- If uncertain, choose the higher tier and document the rationale.
