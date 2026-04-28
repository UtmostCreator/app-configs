# Repo Documentation Generation

Generate a deterministic repository structure map for AI-assisted documentation work.

## Goals

- use tracked files only (`git ls-files`) for stable output
- emit one folder-to-files CSV with comma-separated file lists
- optionally enrich with `scc` metrics for sizing and prioritization
- enrich every tracked top-level folder with validated metadata (purpose, install, AI entrypoint)

## Command

```bash
php tools/ai/generate-repo-structure.php --with-scc
```

Check mode (no writes):

```bash
php tools/ai/generate-repo-structure.php --check --with-scc
```

Metadata file override:

```bash
php tools/ai/generate-repo-structure.php --metadata=docs/ai/repo-directory-map.json
```

## Outputs

Default output directory: `docs/ai/generated/`

- `docs/ai/generated/repo-structure.json`
- `docs/ai/generated/repo-structure.csv`
- `docs/ai/generated/repo-structure.md`
- `docs/ai/generated/repo-structure.log`

The JSON is canonical for machine workflows. The CSV is convenience output for spreadsheet and human review workflows.

## Metadata Contract

Metadata source: `docs/ai/repo-directory-map.json`

- `schema_version` is required and must be supported
- root-level tracked files are grouped under path `.` and require metadata when present
- directory entries must include: `path`, `purpose`, `designed_for`, `install_guide`, `install_script`, `ai_entrypoint`, `notes`
- empty strings are invalid; use `none` when a field does not apply
- `path` values must be unique and match tracked top-level paths
- `install_guide`, `install_script`, and `ai_entrypoint` must reference existing tracked files unless set to `none`
- every tracked top-level path must have metadata unless explicitly listed in `metadata_exemptions`
- `metadata_exemptions` entries must include `path` and `reason`

## Flags

- `--with-scc` include per-folder `lines`, `code`, `comments`, `blanks`, `complexity`, and `bytes`
- `--check` compare generated outputs without writing
- `--root=<path>` run against another repository root
- `--output-dir=<path>` write outputs to a custom location
- `--metadata=<path>` use a custom metadata contract file

## Determinism

Generated output is intentionally deterministic:

- no wall-clock timestamps or machine-local absolute paths in generated files
- directory rows sorted by `path`
- per-directory file lists sorted lexicographically
- deterministic key-value log format in `repo-structure.log`

`--check` never writes files and exits non-zero when generated outputs are stale or metadata validation fails.

## Suggested AI Workflow

1. generate structure outputs
2. open `repo-structure.md` for the high-level map and folder purpose notes
3. use `repo-structure.csv` for exact folder-to-files expansion
4. use `repo-structure.json` for scripted filtering or prompt assembly
5. consult `repo-structure.log` for deterministic generation status
6. update docs with AI using only the needed folder slices
