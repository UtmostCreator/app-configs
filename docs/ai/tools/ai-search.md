# AI Search Tool Contract

Use `scripts/ai/ai-search.sh` as the default repository evidence retrieval API.

## Command

```bash
AI_OUTPUT=json bash scripts/ai/ai-search.sh <mode> <query> <root> [flags]
```

## Modes

- `text`: General text/code search
- `files`: File discovery
- `struct`: AST/structural search
- `tracked`: Search git-tracked files
- `changed`: Search changed working-tree files
- `staged`: Search staged files
- `docs`: Search documentation
- `tests`: Search test files
- `config`: Search safe config files
- `schema`: Search schemas/OpenAPI/workflows/structured metadata
- `secrets`: approval required
- `unsafe-all`: approval required

## Required JSON envelope statuses

- `ok`
- `no_matches`
- `error`
- `unsafe_blocked`
- `dry_run`

Safety controls to keep explicit in prompts and reviews:

- `unsafe-all` needs explicit approval.
- `secrets` needs explicit approval.
- `AI_ALLOW_UNLIMITED=1` needs explicit approval.
