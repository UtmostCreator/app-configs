# AI Tool Map

Prefer repository scripts over ad-hoc shell commands.

- `AI_OUTPUT=json bash scripts/ai/ai-search.sh <mode> <query> . --fixed`
- `bash scripts/ai/preview-file.sh <path>`
- `bash scripts/ai/query-usage.sh <symbol-or-path>`
- `bash scripts/ai/git-forensics.sh <path>`
- `bash scripts/ai/ai-verify.sh`
- `bash scripts/ai/pack-context.sh`

Search escalation order:
1. `changed`
2. `staged`
3. `tracked`
4. `docs/tests/config/schema`
5. `text`
6. `struct`
7. `unsafe-all` (approval required)

## File preview

Use `preview-file.sh` after `ai-search.sh` finds a relevant file or line.

```bash
bash scripts/ai/preview-file.sh <path> --around <line> --context 30
AI_OUTPUT=json bash scripts/ai/preview-file.sh <path> --around <line> --context 30
```

Rules:

- Preview one file only.
- Prefer `--around` or `--range`.
- Do not use raw `cat` for large or unknown files.
- Do not use unsafe file paths without approval.
- Use JSON mode for evidence pipelines.
