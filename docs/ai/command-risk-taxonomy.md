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
| `scripts/copilot/ai-search.sh` | any | 1 | read-only discovery |
| `scripts/copilot/ai-verify.sh` | any | 1 | verification-only checks |
| `scripts/copilot/fd-files.sh` | any | 1 | read-only file discovery |
| `scripts/copilot/rg-code.sh` | any | 1 | read-only content search |
| `scripts/copilot/preview-file.sh` | any | 1 | read-only preview |
| `scripts/copilot/git-forensics.sh` | any | 1 | history inspection |
| `scripts/copilot/gh-pr-context.sh` | read metadata/checks/reviews | 1 | read-only PR context |
| `scripts/copilot/repo-stats.sh` | any | 1 | read-only local metrics |
| `scripts/copilot/query-usage.sh` | any | 1 | read-only token/usage estimate |
| `scripts/copilot/pack-context.sh` | generated-output only | 1 | writes generated context artifacts only |
| `scripts/copilot/ai-edit.sh` | dry-run | 1 | no source mutation |
| `scripts/copilot/ai-edit.sh` | apply mode | 2 | mutates source files |
| `scripts/copilot/ai-rollback.sh` | list/show | 1 | inspection only |
| `scripts/copilot/ai-rollback.sh` | apply/prune | 3 | destructive recovery operations |
| `scripts/copilot/repomix-scc-router.sh` | `stats`, `plan`, `pack`, `all` | 1 | generated-output workflow |
| `scripts/copilot/repomix-scc-router.sh` | `clean`, `purge` | 3 | deletes generated outputs |
| `scripts/copilot/repomix-context-tree.sh` | `analyze`, `plan`, `pack`, `all` | 1 | generated-output workflow |
| `scripts/copilot/repomix-context-tree.sh` | `clean`, `purge` | 3 | deletes generated outputs |

## Notes

- Classify mixed-risk wrappers by subcommand or flag, not script name.
- Treat remote mutation, auth, billing, and secret-bearing actions as higher risk even if a command appears read-only.
- If uncertain, choose the higher tier and document the rationale.
