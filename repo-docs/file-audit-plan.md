# Repository File Audit & `docs/` -> `repo-docs/` Migration Plan

Status: **IN PROGRESS**. No `docs/` files have been moved yet. No references rewritten.
Tracking ledger: [`../scc-by-file.csv`](../scc-by-file.csv) (one `Status` checkbox per file).

### CSV `Status` legend

- `- [ ]` — repo-bounded, audit pending / **gated candidate** (3 files: `SUPPORT.md`,
  `.husky/pre-commit`, `.husky/commit-msg` — findings logged, edits need approval).
- `- [x]` — repo-bounded, audit complete (171 files, disposition recorded).
- `- [-]` — **out of scope: AI-kit auto-shipped** by the `ai-universal-rules`
  package (288 files). Identified from `.ai-install-manifest.json` `files` map
  plus kit roots (`docs/ai/`, `.opencode/`, `.schemas/`, `scripts/ai/`,
  `tools/ai/`, `.github/hooks/`, AI workflows, `AGENTS.md`, `PLACEHOLDERS.md`).
  These are never audited, edited, moved, or checked off here.

## 1. Goal

Audit every file listed in `scc-by-file.csv` (463 files) for staleness and
correctness, and separate repo-owned documentation (move target: `repo-docs/`)
from AI-kit files generated/maintained by another project (leave in place,
keep visible as not-repo-owned).

A file's checkbox flips `- [ ]` -> `- [x]` **only when its full audit passes**:

1. **Required** — the repo needs it; it is referenced, used, or directly helpful.
2. **Not a stale duplicate** — if it duplicates another file, the duplicate is
   rewritten/merged from the most recent data, not left as a copy.
3. **Up to date** — commands, paths, descriptions, and docs match current code.
4. **Config fresh / no bugs** — config files parse, validate, and have no
   obvious errors.
5. **Disposition recorded** — one of: keep / merge / remove / edit / update /
   add-needed, noted in the follow-up log.

## 2. Ownership classification (grounded in evidence)

Evidence: `.gitignore` (lines 43-57), `docs/ai/generated/README.md`,
`docs/ai/source-of-truth.md`, `AGENTS.md`, `docs/README.md`.

| Bucket | Paths | Owner | Action |
|--------|-------|-------|--------|
| **A. Repo-owned docs** | `docs/*.md`, `docs/*.sh`, `docs/*.ps1`, `docs/architecture/`, `docs/projects/`, `docs/research/`, `docs/templates/`, `docs/unix/`, `docs/windows/` | This repo | **Candidate to move to `repo-docs/`** |
| **B. AI-kit (foreign, auto-shipped)** | `docs/ai/**` (incl. capabilities, snippets, shared, schemas refs), `.opencode/**`, `AGENTS.md`, `PLACEHOLDERS.md`, `.ai-install-manifest.json` | Auto-shipped by another project (ai-universal-rules kit) | **OUT OF SCOPE.** Do NOT audit, edit, move, or check off. These are always shipped automatically and are not this repo's concern. Leave their CSV rows as `- [ ]`. |
| **C. Generated (never committed)** | `docs/ai/generated/**`, `docs/generated/**` | Generators in `tools/ai/` | Out of scope to move; verify generator still produces them. |
| **D. Repo source/config** | `home/**`, `nix/**`, `scripts/**`, `tools/**`, `tests/**`, `reference/**`, `.schemas/**`, root dotfiles/configs | This repo | Audit in place; not a `docs/` move target. |

> **Scope rule (Bucket B):** `docs/ai/` and other AI-kit files are auto-shipped
> by another project and are out of this audit's scope entirely — we do not
> audit, edit, move, or check them off. We only care about repo-bounded files
> (Buckets A, C, D). Their CSV rows stay `- [ ]` as a visible marker that they
> are not repo-owned.

## 3. `docs/` -> `repo-docs/` migration plan (THOROUGH — execution still gated)

### Progress tracker

Checkboxes flip `[ ]` -> `[x]` as each item completes. Tallies (update as we go):

- Moves: **41 / 41** done (Tier 1: 9/9, Tier 2: 27/27, Tier 3: 5/5)
- Referrer rewrites: **36 / 36** done
- Phases: **M0–M5 ALL DONE**

> Status: COMPLETE (2026-06-02). All 41 repo-owned docs moved `docs/` ->
> `repo-docs/` via `git mv`; 184 path rewrites across 37 repo-owned files; AI
> kit (`docs/ai/`) untouched; all verification gates pass.

### 3.0 Authoritative ownership boundary (confirmed against upstream)

Verified against the upstream kit `UtmostCreator/awesome-ai-utmostcreator`
(README, fetched 2026-06-02). The kit's "What Gets Installed" table installs
exactly: `AGENTS.md`, `CLAUDE.md`, `.github/`, `.opencode/`, **`docs/ai/`**,
`scripts/ai/`, `schemas/ai/` (-> `.schemas/` here), `policies/`. Its "Untracked
Folders" note says `docs/` is "Created by installer or self-install" but only
the **`docs/ai/`** subtree is kit content.

**Therefore the boundary is exact:**

- **AI-kit (auto-shipped, DO NOT move/edit):** `docs/ai/**` (113 files),
  including `docs/ai/generated/**` (gitignored).
- **Repo-owned (move candidates):** every `docs/**` path **outside `docs/ai/`**
  = **41 files**. None are gitignored; all are app-configs' own.

`docs/` keeps existing after the move (it still holds `docs/ai/`). `repo-docs/`
receives the 41 repo-owned files, mirroring their sub-structure.

### 3.1 Target layout (mirror substructure to preserve relative links)

| Source (under `docs/`) | Target (under `repo-docs/`) |
|------------------------|-----------------------------|
| `docs/*.md`, `docs/*.sh`, `docs/*.ps1` (root-level) | `repo-docs/<same name>` |
| `docs/architecture/**` | `repo-docs/architecture/**` |
| `docs/projects/**` | `repo-docs/projects/**` |
| `docs/research/**` | `repo-docs/research/**` |
| `docs/templates/**` | `repo-docs/templates/**` |
| `docs/unix/**` | `repo-docs/unix/**` |
| `docs/windows/**` (incl. `windows/scripts/*.ps1`) | `repo-docs/windows/**` |

Mirroring the subtree keeps **intra-subtree relative links valid** (e.g.
`docs/windows/ssh-agent-setup.md` links `scripts/Setup-SshAgent.ps1` relatively;
that link survives a whole-subtree move). Only **absolute** `docs/...` strings
elsewhere need rewriting.

Dev-tool scripts (`docs/install-dev-tools.sh`, `verify-dev-tools-*.sh/ps1`,
`repair-dev-tools-windows.ps1`) stay under `repo-docs/` (NOT moved to
`scripts/`) so the rewrite set stays small and `generate-package-matrix.sh` /
`doctor.sh` only change a path prefix, not a directory concept.

### 3.2 Move-readiness tiers (from exhaustive manifest)

Manifest helper: `repo-docs/docs-move-manifest.py` (regenerate any time).
Snapshot: `repo-docs/docs-move-manifest.json`. Counts (2026-06-02):
**Tier 1 = 9, Tier 2 = 27, Tier 3 = 5.**

**Tier 1 — zero inbound refs (9): move freely, fix only own outbound links.**

- [x] `docs/install-dev-tools-windows.ps1` -> `repo-docs/install-dev-tools-windows.ps1`
- [x] `docs/pr-body-2026-05-24.md` -> `repo-docs/pr-body-2026-05-24.md`
- [x] `docs/repair-dev-tools-windows.ps1` -> `repo-docs/repair-dev-tools-windows.ps1`
- [x] `docs/verify-dev-tools-powershell.ps1` -> `repo-docs/verify-dev-tools-powershell.ps1`
- [x] `docs/templates/vscode/workspace-example.json` -> `repo-docs/templates/vscode/workspace-example.json`
- [x] `docs/windows/README.md` -> `repo-docs/windows/README.md`
- [x] `docs/windows/ssh-agent-setup.md` -> `repo-docs/windows/ssh-agent-setup.md`
- [x] `docs/windows/scripts/Enable-SshAgentService.ps1` -> `repo-docs/windows/scripts/Enable-SshAgentService.ps1`
- [x] `docs/windows/scripts/Install-SshAgentProfileSnippet.ps1` -> `repo-docs/windows/scripts/Install-SshAgentProfileSnippet.ps1`

**Tier 2 — repo-only inbound refs (27): move + rewrite repo-owned referrers.**

Referrers are all editable repo-owned files (see §3.3 rewrite set).

- [x] `docs/INSTALL.md` -> `repo-docs/INSTALL.md`
- [x] `docs/app-list.md` -> `repo-docs/app-list.md`
- [x] `docs/architecture/tool-ownership.md` -> `repo-docs/architecture/tool-ownership.md`
- [x] `docs/bootstrap.md` -> `repo-docs/bootstrap.md`
- [x] `docs/git-history-email-rewrite.md` -> `repo-docs/git-history-email-rewrite.md`
- [x] `docs/install-nixos.md` -> `repo-docs/install-nixos.md`
- [x] `docs/keyboard.md` -> `repo-docs/keyboard.md`
- [x] `docs/migration-audit-2026-05-24.md` -> `repo-docs/migration-audit-2026-05-24.md`
- [x] `docs/migration-decisions.md` -> `repo-docs/migration-decisions.md`
- [x] `docs/migration-implementation-plan.md` -> `repo-docs/migration-implementation-plan.md`
- [x] `docs/migration-package-ownership.draft.md` -> `repo-docs/migration-package-ownership.draft.md`
- [x] `docs/migration-package-ownership.md` -> `repo-docs/migration-package-ownership.md`
- [x] `docs/migration-source-of-truth.draft.md` -> `repo-docs/migration-source-of-truth.draft.md`
- [x] `docs/migration-source-of-truth.md` -> `repo-docs/migration-source-of-truth.md`
- [x] `docs/nix-specific-and-replacements.md` -> `repo-docs/nix-specific-and-replacements.md`
- [x] `docs/nixos-rebuild.md` -> `repo-docs/nixos-rebuild.md`
- [x] `docs/nvim-setup.md` -> `repo-docs/nvim-setup.md`
- [x] `docs/projects/README.md` -> `repo-docs/projects/README.md`
- [x] `docs/research/nix-config-borrow-analysis.md` -> `repo-docs/research/nix-config-borrow-analysis.md`
- [x] `docs/software-and-cli-tools.md` -> `repo-docs/software-and-cli-tools.md`
- [x] `docs/templates/vscode/workspace-template.json` -> `repo-docs/templates/vscode/workspace-template.json`
- [x] `docs/unix/QUICKSTART.md` -> `repo-docs/unix/QUICKSTART.md`
- [x] `docs/unix/ssh-agent-setup.md` -> `repo-docs/unix/ssh-agent-setup.md`
- [x] `docs/unix/ssh-agent-snippets.md` -> `repo-docs/unix/ssh-agent-snippets.md`
- [x] `docs/vscode-extensions.md` -> `repo-docs/vscode-extensions.md`
- [x] `docs/windows/QUICKSTART.md` -> `repo-docs/windows/QUICKSTART.md`
- [x] `docs/windows/scripts/Setup-SshAgent.ps1` -> `repo-docs/windows/scripts/Setup-SshAgent.ps1`

**Tier 3 — also referenced by auto-shipped AI-kit (5): kit ref goes stale.**

| Done | File -> target | AI-kit referrer (goes stale, DO NOT edit) | Repo referrers (rewrite) |
|------|----------------|-------------------------------------------|--------------------------|
| [x] | `docs/README.md` -> `repo-docs/README.md` | `docs/ai/repo-directory-map.json` (`install_guide`/`ai_entrypoint`, L71-73) | `migration-followups.md`, `migration-implementation-plan.md` |
| [x] | `docs/install-dev-tools.sh` -> `repo-docs/install-dev-tools.sh` | `repo-directory-map.json` (`install_script`), `repo-required-tools.md` | `doctor.sh`, `generate-package-matrix.sh`, 4 migration docs |
| [x] | `docs/shell-setup.md` -> `repo-docs/shell-setup.md` | `repo-directory-map.json` (`install_guide`) | `migration-implementation-plan.md`, `software-and-cli-tools.md`, `unix/ssh-agent-setup.md` |
| [x] | `docs/verify-dev-tools-gitbash.sh` -> `repo-docs/verify-dev-tools-gitbash.sh` | `repo-required-tools.md` | (none) |
| [x] | `docs/migration-followups.md` -> `repo-docs/migration-followups.md` | `AGENTS.md` (prose example in failure-flagging rule) | 5 docs |

**Tier-3 impact is acceptable, NOT blocking:** `repo-directory-map.json` and
`repo-required-tools.md` are **kit-generated reflections** of the repo layout
(produced by `tools/ai/generate-repo-structure.php`), not hard runtime
dependencies. After a move they describe a stale path until the kit regenerates
them on its next install/sync — no app-configs tooling fails. The `AGENTS.md`
reference is a prose example, not a path lookup. We never edit kit files.

### 3.3 Exhaustive repo-owned rewrite set (36 files — ALL must change in the move slice)

These are the ONLY files to edit. Grouped by risk:

**Critical — functional script dependencies (break if not rewritten):**

- [x] `scripts/doctor.sh` — reads `docs/software-and-cli-tools.md`,
  `docs/vscode-extensions.md`, `docs/migration-{source-of-truth,package-ownership,decisions}.md`,
  `docs/install-dev-tools.sh` in its check loops.
- [x] `scripts/validate-config.sh` — existence-checks
  `docs/migration-source-of-truth.md`, `docs/migration-package-ownership.md`.
- [x] `scripts/check-source-of-truth.sh` — **writes** `docs/migration-source-of-truth.draft.md`;
  reads `docs/templates/vscode`.
- [x] `scripts/generate-package-matrix.sh` — parses `docs/install-dev-tools.sh`,
  `docs/software-and-cli-tools.md`; **writes** `docs/migration-package-ownership.draft.md`.
- [x] `scripts/install.sh` — references `docs/INSTALL.md`, `docs/nixos-rebuild.md` in messages.
- [x] `scripts/readiness.sh` — references `docs/nixos-rebuild.md` in messages.

**Config / build:**

- [x] `mise.toml` (comment ref to `docs/software-and-cli-tools.md`)
- [x] `nix/modules/home/cli.nix` (comment ref)
- [x] `nix/modules/home/gui.nix` (comment ref)
- [x] `nix/modules/darwin/homebrew.nix` (comment ref)

**Root + cross-link docs (repo-owned):**

- [x] `README.md` (the repo index — many `docs/...` links)
- [x] `docs/INSTALL.md`
- [x] `docs/app-list.md`
- [x] `docs/architecture/tool-ownership.md`
- [x] `docs/bootstrap.md`
- [x] `docs/git-history-email-rewrite.md`
- [x] `docs/install-nixos.md`
- [x] `docs/migration-audit-2026-05-24.md`
- [x] `docs/migration-followups.md`
- [x] `docs/migration-implementation-plan.md`
- [x] `docs/migration-package-ownership.md`
- [x] `docs/migration-package-ownership.draft.md`
- [x] `docs/migration-source-of-truth.md`
- [x] `docs/migration-source-of-truth.draft.md`
- [x] `docs/nix-specific-and-replacements.md`
- [x] `docs/nixos-rebuild.md`
- [x] `docs/nvim-setup.md`
- [x] `docs/pr-body-2026-05-24.md`
- [x] `docs/projects/README.md`
- [x] `docs/research/nix-config-borrow-analysis.md`
- [x] `docs/shell-setup.md`
- [x] `docs/software-and-cli-tools.md`
- [x] `docs/unix/QUICKSTART.md`
- [x] `docs/unix/ssh-agent-setup.md`
- [x] `docs/unix/ssh-agent-snippets.md`
- [x] `docs/windows/README.md`

> Each referrer is checked off once its moved-path `docs/<non-ai>` strings are
> rewritten to `repo-docs/<...>`. Many of these docs are ALSO in the move lists
> above (they cross-link each other) — moving and rewriting are tracked
> separately. NOTE: `docs/migration-*` and dated archives are repo-owned but
> moved; keep intentional history references that describe the OLD layout as-is
> and annotate them.

> NOTE: many `docs/**` files appear in BOTH the moved set and the referrer set
> (they cross-link each other). After moving a whole batch, rewrite remaining
> absolute `docs/<non-ai>` strings repo-wide, then re-verify (§3.5).

### 3.4 Phased execution (each phase = one reviewed slice)

Mark `[x]` as each phase completes (sub-file checkboxes live in §3.2 / §3.3).

- [x] **M0 (prep):** create target dirs
  `mkdir -p repo-docs/{architecture,projects,research,templates/vscode,unix,windows/scripts}`.
  (`repo-docs/README.md` index arrives via M3 `git mv docs/README.md`, then its
  links are rewritten — no separate stub created to avoid a move collision.)
- [x] **M1 (Tier 1, 9 files):** `git mv` each (§3.2 Tier 1 list) — all 9 renamed,
  history preserved. No stale inbound refs. NOTE: `repo-docs/windows/README.md`
  links `QUICKSTART.md` + `scripts/Setup-SshAgent.ps1` relatively — those Tier-2
  siblings still in `docs/windows/`; links restore when M2 moves them.
- [x] **M2 (Tier 2, 27 files):** all 27 `git mv`'d. Rewrote 35 repo referrers
  (153 path rewrites) + 2 stale moved-DIR refs (`check-source-of-truth.sh`,
  `README.md` templates/vscode) + README `docs/` index row. Zero stale
  moved-path refs remain. Verified: `validate-config.sh` exit 0 (finds
  `repo-docs/migration-*`), `generate-package-matrix.sh` exit 0 (writes to
  `repo-docs/`), `doctor.sh` doc loop resolves, all scripts `bash -n` clean,
  nix parse clean, mise parses.
- [x] **M3 (Tier 3, 5 files):** all 5 `git mv`'d (`docs/README.md` ->
  `repo-docs/README.md` is now the index). 31 repo-referrer rewrites; AI-kit
  refs (`repo-directory-map.json`, `repo-required-tools.md`, `AGENTS.md`) left
  stale by design. Empty leftover `docs/` subdirs removed — `docs/` now holds
  only `docs/ai/`. `git status docs/ai` empty (kit untouched). Functional
  scripts re-verified exit 0.
- [x] **M4 (kit map note):** `repo-docs/README.md` (the moved index) now explains
  the `repo-docs/` vs `docs/ai/` split and notes the kit map may lag until
  regenerated. Relative links in the index resolve (whole tree moved together).
- [x] **M5 (final verify):** all §3.5 gates pass — 41 renames (history kept),
  zero stale moved-path refs (kit excluded), `validate-config.sh` +
  `generate-package-matrix.sh` exit 0, all scripts `bash -n` clean,
  `lychee --offline` = same 4 code-span false-positives as pre-move baseline
  (no NEW broken links), `git status docs/ai` empty. `scc-by-file.csv` paths +
  dispositions updated to `repo-docs/`. Completion recorded in followups.

### 3.5 Verification gates (per phase — blocking)

- `git mv` only (preserve history); never copy+delete.
- After rewrites: `rg -n "docs/(?!ai/)" <referrer-set>` shows no stale moved
  paths (use the manifest to diff expected vs remaining).
- `rg -l -F "docs/<movedfile>"` returns 0 outside `docs/ai/**`, dated archives,
  and intentional history notes.
- Run functional scripts that read docs: `bash scripts/doctor.sh` (or its doc
  loop), `bash scripts/validate-config.sh`, `bash scripts/generate-package-matrix.sh --dry-run` if supported.
- `lychee --offline repo-docs/**/*.md README.md` -> no new broken links.
- Confirm **no `docs/ai/**` file modified**: `git status -- docs/ai` empty.

### 3.6 "Don't lose required docs" guarantee

Every one of the 41 repo-owned docs is accounted for in the manifest with its
referrers. The move is loss-free because: (a) `git mv` preserves content+history;
(b) the §3.3 rewrite set is exhaustive (generated, not hand-listed); (c)
functional script dependencies are explicitly enumerated and rewritten; (d)
verification gates fail the slice if any stale `docs/<moved>` path remains.
Nothing required by the repo is dropped — only relocated with references fixed.

## 4. Per-file audit procedure (apply to each `scc-by-file.csv` row)

For each file, in order, using repo-local tools (no raw `cat` on large/binary):

1. **Locate & preview**
   `AI_OUTPUT=json bash scripts/ai/preview-file.sh <path> --around <line> --context 30`
2. **Reference check (required?)**
   `bash scripts/ai/ai-search.sh` or `rg -n "<basename>"` across repo.
   Zero references + not an entrypoint + not user-facing => removal candidate.
3. **Duplicate check (>=75% overlap rule, per AGENTS.md)**
   Search for sibling files with same role (e.g. two `keybindings.json`, two
   `settings.json.tmpl`, duplicated READMEs). If overlap >=75%, mark
   merge/rewrite-from-newest, not keep-both.
4. **Freshness check (by type):**
   - Markdown: commands run? paths exist (`fd`/`rg`)? descriptions match code?
   - Shell/PS1: `bash -n <f>` / shellcheck; referenced commands exist.
   - PHP: `php -l <f>`; referenced files/classes exist.
   - JSON: `php -r 'json_decode(...)'` or `jq .` parses; schema-validated where a
     `.schemas/*.json` applies.
   - YAML/TOML: parse with available validator (`mise`, `yq`, `tomlq`).
   - Nix: `nix-insttable`/`nixfmt --check` if available; else structural read.
   - Templates (`.tmpl`): chezmoi-render dry check where practical.
5. **Empty-file check:** the 17 zero-byte `reference/php/design-patterns/**/README.md`
   files are add-needed candidates (write content) or remove candidates.
6. **Record disposition** in the follow-up log (Section 6) and flip Status to
   `- [x]` in `scc-by-file.csv` when all of 1-5 pass.

## 5. Batching plan (each batch = one bounded, reviewable slice)

Ordered by risk and cohesion. Audit only; moves are separate approved slices.

| # | Batch | Approx files | Notes |
|---|-------|-------------|-------|
| B1 | Empty `reference/php` READMEs | 17 | Add content or remove; lowest risk |
| B2 | Root config/dotfiles (`.eslintrc`, `.prettierrc`, `.stylelintrc`, `.lefthook.yml`, `mise.toml`, `.editorconfig`) | ~8 | Parse + lint |
| B3 | `.schemas/**` JSON schemas | ~15 | Validate; cross-check consumers |
| ~~B4~~ | ~~`docs/ai/**` AI-kit docs~~ | — | **DROPPED — out of scope (auto-shipped, foreign)** |
| ~~B5~~ | ~~`.opencode/**` agents/commands/skills~~ | — | **DROPPED — out of scope (auto-shipped, foreign)** |
| B6 | `scripts/**` shell | ~50 | `bash -n` + ref check |
| B7 | `tools/ai/**` PHP | ~70 | `php -l` + ref check |
| B8 | `tests/**` | ~2 | Run suite |
| B9 | `home/**` dotfiles/templates | ~40 | chezmoi render checks |
| B10 | `nix/**` | ~30 | nix parse/eval |
| B11 | **Bucket A `docs/` repo-owned** — audit + plan move to `repo-docs/` | ~50 | Each move = own slice w/ reference rewrite |
| B12 | Duplicate-merge pass (keybindings.json x2, settings.json.tmpl x2, etc.) | varies | Rewrite from newest data |

## 6. Follow-up / disposition log

Record every candidate (merge/remove/edit/update/add) and every failed command
in `docs/migration-followups.md` (existing follow-up doc) per AGENTS.md failure
flagging rule. Each entry: file, finding, chosen disposition, evidence command.

## 7. Known duplicate candidates spotted during planning (verify in B12)

- `home/dot_config/Code/User/keybindings.json` and
  `home/Library/Application Support/Code/User/keybindings.json` (both 1135 lines).
- `home/dot_config/Code/User/settings.json.tmpl` and
  `home/Library/Application Support/Code/User/settings.json.tmpl` (both 5 lines).
- `home/dot_config/ghostty/config.tmpl` and
  `home/Library/Application Support/com.mitchellh.ghostty/config.tmpl`.
- `scripts/git-branch-origin.sh` and
  `home/dot_local/bin/executable_git-branch-origin` (both 424 lines).

These are flagged only; confirm overlap with `diff`/`rg` before merging.

## 8. Verification per batch

Run the smallest proof first, escalate only if needed:
- syntax/parse check (`bash -n`, `php -l`, `jq`, schema validate)
- repo doc/ref checks (`bash scripts/ai/ai-doc-check.sh`, `scripts/check-source-of-truth.sh`)
- focused tests where behavior changes
Report executed vs recommended commands separately. Never claim unrun checks.
