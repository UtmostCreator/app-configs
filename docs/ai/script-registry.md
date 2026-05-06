# Script Registry

This file is the canonical allowlist reference for scripts installed by `scripts-pack`.

## Scripts

| id | label | source_path | installed_path | risk | required_tools | supports_dry_run | default_args |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `repomix-context` | Generate Repomix context bundle | `scripts/ai/run-repomix-context.sh` | `scripts/ai/run-repomix-context.sh` | `read-only` | `bash, git, repomix` | `true` | `[]` |
| `repomix-tree` | Generate Repomix context tree | `scripts/ai/repomix-context-tree.sh` | `scripts/ai/repomix-context-tree.sh` | `read-only` | `bash, git, repomix` | `true` | `[]` |
| `repomix-scc-router` | Generate SCC-ranked Repomix context | `scripts/ai/repomix-scc-router.sh` | `scripts/ai/repomix-scc-router.sh` | `read-only` | `bash, git, jq, rg, repomix, scc` | `true` | `[]` |
| `pack-context` | Pack AI context bundle | `scripts/ai/pack-context.sh` | `scripts/ai/pack-context.sh` | `read-only` | `bash, git, jq, rg` | `true` | `[]` |
| `repo-tool-inventory` | Generate/check required tools inventory doc | `scripts/ai/repo-tool-inventory.sh` | `scripts/ai/repo-tool-inventory.sh` | `read-only` | `bash, git` | `false` | `[]` |
| `install-mandatory-tools` | Install mandatory CLI tools by OS | `scripts/ai/install-mandatory-tools.sh` | `scripts/ai/install-mandatory-tools.sh` | `mutating` | `bash` | `true` | `["--dry-run"]` |

## Policy Notes

- Keep this file aligned with `docs/ai/script-registry.json`.
- Keep this file aligned with `tools/ai/install/script-registry.php`.
- Only scripts listed here are approved for allowlisted shell execution via AI workflow policy.
