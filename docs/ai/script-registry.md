# Script Registry

This file is the canonical allowlist reference for scripts installed by `scripts-pack`.

## Scripts

| id | label | source_path | installed_path | risk | required_tools | supports_dry_run | default_args |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `common` | Shared helper library for AI shell scripts | `scripts/ai/common.sh` | `scripts/ai/common.sh` | `read-only` | `bash` | `false` | `[]` |
| `ai-search` | Safe repository text search wrapper | `scripts/ai/ai-search.sh` | `scripts/ai/ai-search.sh` | `read-only` | `bash, git, jq, rg, fd, ast-grep` | `false` | `[]` |
| `rg-code` | Code-focused ripgrep wrapper | `scripts/ai/rg-code.sh` | `scripts/ai/rg-code.sh` | `read-only` | `bash, rg` | `false` | `[]` |
| `fd-files` | File discovery wrapper | `scripts/ai/fd-files.sh` | `scripts/ai/fd-files.sh` | `read-only` | `bash, fd` | `false` | `[]` |
| `preview-file` | Safe file preview wrapper | `scripts/ai/preview-file.sh` | `scripts/ai/preview-file.sh` | `read-only` | `bash, jq` | `false` | `[]` |
| `query-usage` | Symbol usage query wrapper | `scripts/ai/query-usage.sh` | `scripts/ai/query-usage.sh` | `read-only` | `bash, rg` | `false` | `[]` |
| `git-forensics` | Read-only git history tracing wrapper | `scripts/ai/git-forensics.sh` | `scripts/ai/git-forensics.sh` | `read-only` | `bash, git` | `false` | `[]` |
| `gh-pr-context` | GitHub PR context wrapper | `scripts/ai/gh-pr-context.sh` | `scripts/ai/gh-pr-context.sh` | `read-only` | `bash, gh, git` | `false` | `[]` |
| `ai-doc-check` | AI docs consistency checker wrapper | `scripts/ai/ai-doc-check.sh` | `scripts/ai/ai-doc-check.sh` | `read-only` | `bash, git, rg` | `true` | `["--check"]` |
| `ai-diff-context` | Diff-aware context extraction wrapper | `scripts/ai/ai-diff-context.sh` | `scripts/ai/ai-diff-context.sh` | `read-only` | `bash, git` | `false` | `[]` |
| `ai-verify` | Verification workflow wrapper | `scripts/ai/ai-verify.sh` | `scripts/ai/ai-verify.sh` | `read-only` | `bash, git` | `false` | `[]` |
| `ai-rollback` | Rollback snapshot helper | `scripts/ai/ai-rollback.sh` | `scripts/ai/ai-rollback.sh` | `mutating` | `bash, git` | `false` | `[]` |
| `ai-edit` | Scoped repository edit wrapper | `scripts/ai/ai-edit.sh` | `scripts/ai/ai-edit.sh` | `mutating` | `bash, git, python3` | `true` | `[]` |
| `pre-tool-use` | Pre-tool policy decision hook | `scripts/ai/pre-tool-use.sh` | `scripts/ai/pre-tool-use.sh` | `read-only` | `bash, jq` | `false` | `[]` |
| `post-tool-use` | Post-tool evidence writer hook | `scripts/ai/post-tool-use.sh` | `scripts/ai/post-tool-use.sh` | `read-only` | `bash, jq, date` | `false` | `[]` |
| `repomix-context` | Generate Repomix context bundle | `scripts/ai/run-repomix-context.sh` | `scripts/ai/run-repomix-context.sh` | `read-only` | `bash, git, repomix` | `true` | `[]` |
| `repomix-tree` | Generate Repomix context tree | `scripts/ai/repomix-context-tree.sh` | `scripts/ai/repomix-context-tree.sh` | `read-only` | `bash, git, repomix` | `true` | `[]` |
| `repomix-scc-router` | Generate SCC-ranked Repomix context | `scripts/ai/repomix-scc-router.sh` | `scripts/ai/repomix-scc-router.sh` | `read-only` | `bash, git, jq, rg, repomix, scc` | `true` | `[]` |
| `pack-context` | Pack AI context bundle | `scripts/ai/pack-context.sh` | `scripts/ai/pack-context.sh` | `read-only` | `bash, git, jq, rg` | `true` | `[]` |
| `repo-tool-inventory` | Generate/check required tools inventory doc | `scripts/ai/repo-tool-inventory.sh` | `scripts/ai/repo-tool-inventory.sh` | `read-only` | `bash, git` | `false` | `[]` |
| `install-mandatory-tools` | Install mandatory CLI tools by OS | `scripts/ai/install-mandatory-tools.sh` | `scripts/ai/install-mandatory-tools.sh` | `mutating` | `bash` | `true` | `["--dry-run"]` |
| `watch-loop` | Watched command retry wrapper | `scripts/ai/watch-loop.sh` | `scripts/ai/watch-loop.sh` | `read-only` | `bash` | `false` | `[]` |

## Policy Notes

- Keep this file aligned with `docs/ai/script-registry.json`.
- Keep this file aligned with `tools/ai/install/script-registry.php`.
- Only scripts listed here are approved for allowlisted shell execution via AI workflow policy.
