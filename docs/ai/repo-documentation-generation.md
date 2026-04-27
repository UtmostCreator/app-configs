# Repo Documentation Generation

Generate a deterministic repository structure map for AI-assisted documentation work.

## Goals

- use tracked files only (`git ls-files`) for stable output
- emit folder-to-files output with comma-separated file lists
- optionally enrich with `scc` metrics for sizing and prioritization

## Command

```bash
php tools/ai/generate-repo-structure.php --with-scc
```

Check mode (no writes):

```bash
php tools/ai/generate-repo-structure.php --check --with-scc
```

## Outputs

Default output directory: `docs/ai/generated/`

- `docs/ai/generated/repo-structure.json`
- `docs/ai/generated/repo-structure.csv`
- `docs/ai/generated/repo-structure.md`

The CSV is the canonical folder map for "folder -> comma-separated files" workflows.

## Flags

- `--with-scc` include per-folder `lines`, `code`, `comments`, `blanks`, `complexity`, and `bytes`
- `--check` compare generated outputs without writing
- `--root=<path>` run against another repository root
- `--output-dir=<path>` write outputs to a custom location

## Suggested AI Workflow

1. generate structure outputs
2. open `repo-structure.md` for the high-level map
3. use `repo-structure.csv` for exact folder-to-files expansion
4. use `repo-structure.json` for scripted filtering or prompt assembly
5. update docs with AI using only the needed folder slices
