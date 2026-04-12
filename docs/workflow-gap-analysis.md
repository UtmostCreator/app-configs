# Workflow Gap Analysis (Config Coverage Audit)

## TL;DR — Biggest Gap

The biggest high-impact gap is **lack of an execution system for AI-assisted work** (repeatable prompts/skills/commands wired into your day-to-day tools), even though you already have strong baseline editor/tool configs.

You have Copilot enabled in VS Code and inline Copilot in Neovim, but there is no shared “AI workflow operating system” (no checked-in slash commands, no reusable review/fix templates, no project-level AGENTS rules applied to active repos, no eval loop). This means AI usage is likely ad-hoc and inconsistent.

## Why this is the biggest gap (evidence)

1. **VS Code has AI toggles but no repository-local AI operating rules in this repo.**
   - Copilot + chat features are enabled in user settings.
   - But no repo-level `.github/prompts/`, `.vscode/prompts`, or task commands are wired to enforce repeatable flows.

2. **Neovim AI is currently inline completion-only.**
   - `copilot.lua` is configured for suggestions and panel is disabled.
   - No chat, no structured refactor/review/test command integrations.

3. **You already maintain an AI framework template repo (`AI-universal-rules/`) but it is not integrated into this actual setup as executable workflow defaults.**
   - This signals a gap between “available framework” and “daily execution.”

## Secondary high-value gaps

### 1) Missing shell orchestration layer in-repo

`docs/shell-setup.md` references `shell/.zshrc`, but only `shell/starship.toml` exists. That means aliases/functions/bootstrap logic are either missing from source control or split elsewhere.

**Impact:** no reproducible command UX, slower context switching, no shared AI helper commands.

### 2) No standard task runner entrypoint

`just` is listed as a preferred CLI, but there is no root `justfile`.

**Impact:** setup/healthcheck/lint/fix/ai-review flows are not one-command standardized.

### 3) No bootstrap/healthcheck automation

Tool lists and docs are strong, but there is no `bootstrap` or `doctor` script validating:
- required binaries
- symlink/copy status
- VS Code extension parity
- nvim plugin health
- AI provider login status

**Impact:** onboarding and machine rebuild friction.

### 4) Neovim coverage is intentionally minimal

Current nvim plugin set is tiny (Copilot, Neotest, tmux navigation). Good for stability, but there’s no LSP/completion/debug/profiled AI workflows checked in.

**Impact:** mismatch vs your heavily optimized VS Code environment.

## Highest ROI improvements (ordered)

## Phase 1 (1–2 days) — biggest immediate lift

1. **Add a root `justfile` as workflow control plane**
   - `just bootstrap`
   - `just doctor`
   - `just ai-review`
   - `just ai-fix`
   - `just sync-vscode-ext`
   - `just sync-config`

2. **Add shell command layer in `shell/.zshrc` (or `shell/zshrc.shared`)**
   - include aliases/functions that call the `just` commands above.
   - add a small `ai` helper namespace (`ai-review`, `ai-plan`, `ai-test`).

3. **Turn AI-universal-rules into active defaults**
   - expose ready-to-use prompts/skills from `AI-universal-rules/templates/...` into your working repos via copy/symlink automation.

## Phase 2 (2–4 days) — lock consistency

4. **Create an `audit/` folder with machine-readable checks**
   - `audit/extensions.required.txt`
   - `audit/binaries.required.txt`
   - `audit/health.sh` that validates everything.

5. **Standardize editor parity**
   - Decide VS Code as primary AI editor and document “nvim minimal mode,” or
   - Expand nvim to parity for your core loops (test, refactor, review).

6. **Add an AI work loop playbook**
   - one markdown file defining: Plan → Implement → Verify → Review → Commit.
   - include exact command sequence for each stage.

## Phase 3 (optional but compounding)

7. **Create weekly workflow telemetry (manual/log-based)**
   - track repetitive tasks and failures (`onboarding time`, `broken tooling`, `manual repetition count`).
   - optimize top-3 pain points every week.

## Suggested “do-this-first” ticket

**Title:** `feat(workflow): add justfile + shell AI commands + doctor checks`

**Definition of done:**
- root `justfile` with bootstrap/doctor/ai commands
- `shell/.zshrc` tracked (or a tracked shared fragment)
- `scripts/doctor.sh` validates tools and config links
- docs updated with one canonical setup path

## Expected outcomes if you implement Phase 1

- Faster setup on new/rebuilt machines
- Less cognitive load switching between VS Code / terminal / nvim
- AI usage becomes deterministic and reusable instead of ad-hoc
- Easier delegation/collaboration because workflows become executable, not tribal knowledge

## Post-integration next gaps to consider

After adding `just` + doctor + shell shared layer, the next biggest upgrades are:

1. **Git hooks enforcement**
   - choose Husky or Lefthook and enforce lint/format/test-smoke.
2. **CI parity checks**
   - run the same doctor/lint/test commands in CI to avoid local-vs-CI drift.
3. **Secrets and policy guardrails**
   - add secret scanning and commit-message conventions.
4. **Dependency risk management**
   - add periodic dependency update/audit workflow.
5. **AI quality gate**
   - add a tiny checklist for AI-generated changes (tests, rollback note, risk note).
