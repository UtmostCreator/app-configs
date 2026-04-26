# Context Packing

Use this workflow when you want more targeted repository context than a single full-repo `repomix` export.

This repo uses:

- `scc` to analyze files and folder weight
- `repomix` to pack exact file lists into AI-friendly bundle files

The router script lives at `scripts/copilot/repomix-scc-router.sh`.

For recursive whole-project contextualization with parent/child references, use `scripts/copilot/repomix-context-tree.sh`.

## Why This Exists

Full-repo context packing is still useful, but it can add noise when the task really targets one subsystem.

This workflow helps by:

- counting folder-level code, comments, blank lines, bytes, and complexity
- ranking folders by implementation weight
- creating one repomix bundle per selected folder group
- keeping bundle selection explicit and repeatable

## Outputs

By default the script writes to `.repomix-context/`.

Treat `.repomix-context/` as local generated output. It is for analysis and bundle handoff, not for source control.

- `scc-openmetrics.txt` - raw `scc` output
- `file-metrics.tsv` - per-file metrics plus assigned folder group
- `folder-metrics.tsv` - aggregated folder metrics with ranking score
- `bundle-plan.tsv` - the selected groups that will be packed
- `bundle-plan.json` - machine-friendly version of the bundle plan for agent or script consumption
- `bundles/` - generated repomix bundle files

The recursive tree planner writes its own outputs under `.repomix-context/tree-context/` by default:

- `tree-plan.tsv` - shell-friendly recursive split plan
- `tree-plan.json` - machine-friendly recursive plan with status and budgets
- `tree-manifest.json` - budget/config summary plus node list
- `bundles/` - leaf context artifacts that fit the usable budget
- `indexes/` - parent reference artifacts that point to child contexts instead of duplicating them
- `index.md` / `index.json` - top-level project context tree entrypoints

## Default Grouping

The script groups files by folder depth.

Examples:

- `--depth 1` -> `.github`, `docs`, `tools`, `AI-universal-rules`
- `--depth 2` -> `docs/ai`, `tools/ai`, `tools/nvim`, `AI-universal-rules/docs`

Root-level files are grouped as `_root`.

## Default Ranking

Folder score is calculated from repository share:

- 55% code share
- 25% complexity share
- 10% file-count share
- 10% byte-size share

This is meant to bias toward implementation-heavy folders without ignoring breadth or payload size.

## Common Commands

### For AI workflow prep

```bash
# analyze the repo at top-level folders
bash scripts/copilot/repomix-scc-router.sh stats . --depth 1

# create a bundle plan from the strongest folders
bash scripts/copilot/repomix-scc-router.sh plan . --depth 1 --top 25 --min-code 300 --min-files 2

# pack the selected folders into repomix bundles
bash scripts/copilot/repomix-scc-router.sh pack .

# run the full flow in one step
bash scripts/copilot/repomix-scc-router.sh all . --depth 1 --top 25 --min-code 300 --min-files 2

# skip mostly declarative folders when you only want implementation-heavy bundles
bash scripts/copilot/repomix-scc-router.sh plan . --depth 2 --min-complexity 1

# remove generated bundles but keep metrics and plans
bash scripts/copilot/repomix-scc-router.sh clean .

# remove the full generated output directory
bash scripts/copilot/repomix-scc-router.sh purge .
```

### For developers using `just`

````bash
just context-stats
just context-plan
just context-pack
just context-pack-all
just context-plan-json
just context-clean
just context-purge
just context-tree-analyze opts='--compress'
just context-tree-plan opts='--compress'
just context-tree-pack opts='--compress'
``

## Recommended Usage Patterns

### 1. Explore first

Start with `stats` or `plan` and inspect `folder-metrics.tsv` before packing everything.

### 2. Use `--depth 1` first

This is the best default when you want a quick top-level routing view.

### 3. Use `--depth 2` for AI workflow internals

When the task is clearly inside `docs/ai`, `tools/ai`, or one package area, `--depth 2` is usually more useful.

### 4. Keep filters narrow

The most useful tuning knobs are:

- `--depth`
- `--top`
- `--min-code`
- `--min-files`
- `--min-complexity`

Use `--min-complexity 1` when you want to skip folders that are mostly docs or declarative config and focus on implementation-heavy bundles.

## Repomix Options Passed Through

The router supports these packing options:

- `--style`
- `--compress`
- `--split-size`
- `--include-logs`
- `--include-logs-count`
- `--include-diffs`

Example:

```bash
bash scripts/copilot/repomix-scc-router.sh all . \
  --depth 1 \
  --top 20 \
  --compress \
  --split-size 10mb \
  --include-logs \
  --include-logs-count 20
````

## Ignore Behavior

The router filters files before analysis using tracked or unignored repository files plus `.repomixignore` exclusions.

This repo intentionally keeps `AI-universal-rules/examples/` packable by default because those examples are useful reference material.

The hard local exclusion to keep is:

- `tools/karabiner/karabiner.json`

Generated router output is also excluded from future runs through `.repomixignore`.

## For AI Agents

Use this workflow when:

- the full repo is too noisy for the current task
- you need a ranked view of the heaviest folders first
- you want one bundle per subsystem instead of one monolithic export

Suggested agent flow:

1. run `stats` or `plan` for ranked folder weight
2. run `context-tree-analyze` when the task may need full-project coverage under a fixed token budget
3. inspect `folder-metrics.tsv` or `tree-plan.json`
4. choose the smallest useful folder bundle or recursive leaf context
5. open only that bundle or leaf context first
6. expand to neighboring bundles or follow parent/child references only if the task crosses boundaries

## Dependencies

Install the tools first if they are missing:

```bash
brew install scc
npm install -g repomix
```

Other install methods are listed in `docs/software-and-cli-tools.md`.

## Verification

The script itself can be syntax-checked with:

```bash
bash -n scripts/copilot/repomix-scc-router.sh
```

End-to-end verification requires local `scc` and `repomix` binaries.
