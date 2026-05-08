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
