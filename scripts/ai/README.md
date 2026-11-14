# AI Scripts

This directory holds one script. Earlier revisions of this README described
a larger wrapper suite (`ai-search.sh`, `preview-file.sh`, `pack-context.sh`,
and others); none of those exist in this repository.

| Script          | Purpose                                                        | Run directly? |
| --------------- | -------------------------------------------------------------- | ------------- |
| `repo-stats.sh` | Per-file and per-directory line and size metrics (via `scc`)   | Yes           |

```bash
bash scripts/ai/repo-stats.sh [root] [options]   # --help lists the options
```

It needs Bash 4+, `scc` and `jq`, honours `.repomixignore`, `.ignore` and
`.gitignore`, writes only to stdout, and is read-only.
