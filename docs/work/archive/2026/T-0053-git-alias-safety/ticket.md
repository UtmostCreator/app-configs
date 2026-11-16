Source: local

# T-0053: Git aliases that delete tags or change repository state while looking read-only (bug)

Status: closed (2026-11-16): fixed on main by feat/ssh-key-lifetime, landed in 8f6b4eb; AC-1 to AC-5 verified there
Opened: 2026-11-15
Note: T-0052 is claimed by the Windows session (status line); T-0049 is reserved.
Relates to: T-0051 F3 (lefthook's temporary stash, the same shared-stash conflict)
Counterpart: RestSift T-0235 (the RestSift half of the same review)

## Origin

The owner pasted two external reviews (2026-11-15) that compared Git books
with `home/dot_gitconfig.tmpl` at `400a30b` and RestSift at `f253a9d`. They are
advice, not decisions. Every claim below was checked against local `main`
`f9b0236` (the template is the same at `400a30b`) and, where it concerns
behaviour, reproduced in a scratch repository with a scratch `GIT_CONFIG_GLOBAL`
and `HOME`, Git 2.56. This ticket changes no configuration.

**Already being fixed.** The `__AppConfigs_fixes` session's branch
`feat/ssh-key-lifetime` (`4d9e030`, reviewed) implements T1 to T3 below:
`fp` becomes `fetch --prune` with a separate `fptags`; `git up` refuses a dirty
tree and `rebase.autoStash = false`; `lostcommits` uses `--unreachable` and
writes nothing; `dnew` is read-only; `cleanf` keeps ignored files. That branch
also decides some points differently from the proposals below: it enables
`rerere` and adds mainline and config-origin aliases. Those are its owner's
decisions; this ticket keeps the evidence and the acceptance checks.

## Confirmed findings

| # | Entry (template line) | What it does | Evidence | Proposed priority |
|---|---|---|---|---|
| F1 | `fp = fetch --prune --prune-tags` (49) | Deletes every local tag that the remote does not have, with no prompt. | Probe: a local-only tag survived a plain `git fetch` (with `fetch.prune = true`) and was gone after `git fp`. | P0 |
| F2 | `up = pull --rebase --autostash` (50) and `[rebase] autoStash = true` (375) with `[pull] rebase = true` (372) | Every `git up`, plain `git pull` and `git rebase` on a dirty tree sets the edits aside and re-applies them, printing "Created autostash" and "Applied autostash". Git keeps them in `.git/rebase-merge/autostash`, inside the one worktree. Only when re-applying conflicts does Git push them onto the stash, which all worktrees share and `AGENTS.md` forbids agents to touch. | Probe: a dirty-tree `git pull` succeeded, kept the edit and left `git stash list` empty. Independent review reproduced the same, also partway through a rebase stopped on a conflicting commit; a shared entry (`stash@{0}: autostash`) appeared only when the re-apply conflicted. | P2 |
| F3 | `lostcommits = "!git fsck --no-reflogs --lost-found ..."` (194) | Writes the dangling objects under `.git/lost-found/` on every run, although it is used to look. | Probe: `.git/lost-found/` absent before, created after. The same pipeline without `--lost-found` listed the same dangling commits and wrote nothing. | P1 |
| F4 | `dnew = !git add -N . && git diff --stat` (276) | Marks every untracked file intent-to-add in the index. Its comment calls it a preview. | Probe: `git ls-files --stage` shows the new file staged empty; `git status` shows ` A`. `{ git diff --stat HEAD; git ls-files --others --exclude-standard; }` printed the same files and left `.git/index` byte-identical. | P1 |

## Checked and not confirmed as written

- **`cleanf` is already guarded.** It runs `git clean -dxn` first, names
  `.env`, asks `[y/N]` and deletes only on `y`; `tests/bash/git-shortcuts.bats`
  ("cleanf shows what it would delete and deletes nothing unless confirmed")
  pins that. The review's P0 "retire" assumes an unguarded alias. What remains
  is a judgement for the owner: an irreversible delete of ignored files sits
  behind one keystroke. Proposed P3, decide only.
- **The second review says `git pull` merges by default.** Wrong: `pull.rebase
  = true` is set, which is why F2 reaches plain `git pull`.
- **"Extend the existing navi recipes".** There are none in this repository:
  `navi` is installed by `nix/modules/home/cli.nix`, but no cheat file is
  managed. Adding one is new work, not an extension. Not proposed.
- **`fco` duplicates `git-switch-pick`.** Both pick a branch with fzf.
  `git-switch-pick` (behind `gsw`/`gswr`, landed in `f9b0236`) sorts by
  recency and has its own tests; `fco` lists local and remote names and checks
  out. Overlap is real; whether `fco` is still used is not known. See T4.
- **`acp` and `ppr`.** `acp` stages tracked files (`add -u`), commits and
  pushes; `ppr` pushes and opens a PR (`gh pr create --fill`). Hooks run in
  both. They are human conveniences; agents are already bound by
  `AGENTS.md` landing rules, which an alias cannot widen. No change proposed.

## Proposed additions, checked (as first assessed; `feat/ssh-key-lifetime` adds some of them)

| Proposal | Why not |
|---|---|
| `whyignored = check-ignore -v --no-index` | The native command is the same length to type and is not in the shell-history analysis. Document it instead (T5). |
| `cfgwhere = config --show-origin --show-scope --get-all` | Same reason; rare use. Document it (T5). |
| `git rerere` | Off today; the review also says keep it off. Nothing to do. |
| More aliases for `log --first-parent`, `log --follow`, `show --format=fuller` | Native commands, already short; adding aliases grows the 146 the audit (T4) is meant to reduce. |

## Tasks (implemented on `feat/ssh-key-lifetime` except T4 and T5; verify on main after it lands)

- [ ] **T1 (F1):** `fp` becomes `fetch --prune` (branches only). Tag pruning
  stays available as the explicit native `git fetch --prune-tags`. Test:
  extend `tests/bash/git-shortcuts.bats` with a bare remote and a local-only
  tag that survives `git fp`.
- [ ] **T2 (F2), owner decision first:** set `rebase.autoStash = false` and
  drop `--autostash` from `up`, so a dirty tree is refused instead of set
  aside. Trade-off for the owner: the shared stash is touched only in the
  conflicting case, while a human loses the one-step pull on a dirty tree.
  Keeping it as is and noting the conflict case in `AGENTS.md` is the
  alternative.
  Test: `gitconfig-template.bats` asserts the setting; `git-shortcuts.bats`
  asserts a dirty-tree `git up` exits non-zero, keeps the edit and adds no
  stash entry, and a clean-tree `git up` still rebases.
- [ ] **T3 (F3, F4):** drop `--lost-found` from `lostcommits`; replace `dnew`
  with the read-only pair above and correct its comment. Tests assert the
  repository state before and after (no `.git/lost-found/`, `.git/index`
  unchanged), not only the output.
- [ ] **T4:** audit the aliases against `docs/reference/cli-shortcuts.md`
  (git is 51% of recorded commands): for each candidate check callers,
  frequency and whether it carries safety behaviour of its own, starting with
  `fco` against `git-switch-pick`. Remove only with the owner's agreement and a
  documented replacement.
- [ ] **T5:** add `git check-ignore -v --no-index FILE` and
  `git config --show-origin --show-scope --get-all KEY` to
  `docs/reference/cli-shortcuts.md` as native commands, not aliases.

## Acceptance criteria

| AC | Check |
|----|-------|
| AC-1 | A local-only tag survives `git fp` (bats, bare remote fixture). |
| AC-2 | With T2 approved: a dirty-tree `git up` and `git pull` exit non-zero, keep the edit, and `git stash list` is unchanged, including when the edit conflicts with the incoming change; a clean-tree `git up` rebases. |
| AC-3 | `git lostcommits` lists a dangling commit and creates no `.git/lost-found/`. |
| AC-4 | `git dnew` lists new files and leaves `.git/index` byte-identical. |
| AC-5 | `bats tests/bash/git-shortcuts.bats tests/bash/gitconfig-template.bats` and `bash ops/validate-config.sh` pass; `chezmoi diff` shows only the intended template lines. |

## Not verified

- macOS: the aliases are POSIX shell and Git, but no macOS run was made.
- Whether anyone relies on `fp` deleting tags, or on `dnew`'s intent-to-add
  side effect (for example to make `git diff` show new files afterwards).

## Closure (2026-11-16)

Verified on `main` at `8f6b4eb`, in a detached worktree:

- `bats tests/bash/git-shortcuts.bats tests/bash/gitconfig-template.bats`:
  41 of 41 pass. They include "fp keeps local-only tags; fptags is the explicit
  tag-pruning variant" (AC-1); "up refuses a dirty tree", "a conflicting up
  stops in the rebase and leaves the stash list empty" and "up on a clean tree
  pulls and rebases" (AC-2); "lostcommits lists a dropped commit and never
  writes .git/lost-found" (AC-3); "dnew shows tracked stat and untracked files
  without touching the index" (AC-4).
- `bash ops/validate-config.sh`: all invariants pass. `chezmoi diff
  ~/.gitconfig`: empty, so the live config matches the template (the
  `__AppConfigs_fixes` session applied it on 2026-11-16) (AC-5).
- Not run: macOS.
- T5 was done differently by the landed fix: `docs/reference/cli-shortcuts.md`
  documents the new `git cfgwhere` and `git mainline` aliases; the ignore-rule
  check (`git check-ignore -v`) is not documented there.
- T4 (audit of the 146 aliases) was not part of the landed fix and is not
  done. It needs its own ticket if the owner wants it.
