# CLI shortcuts

Shortcuts chosen from about 27,000 commands of real shell history and the
runbooks in the private notes and PR-tooling repos. Every name works on macOS
and Linux/WSL2 in fish, and in zsh where a twin is listed.

How the history breaks down (March to October 2026):

| Bucket | Share |
| --- | --- |
| Plain tool calls, no shortcut needed | about 33% |
| Already covered (git aliases, `ws` launcher, functions, zoxide) | about 45% |
| Covered by the shortcuts on this page | about 17% |
| One-off project scripts and multi-line pastes | about 5% |

`git` alone is 51% of all commands, and `git st` is 15%.

## Abbreviations (fish `conf.d/cli.fish`, zsh aliases)

fish abbreviations expand in place, so history keeps the full command.

| Type this | Expands to |
| --- | --- |
| `gst` `gco` `gl` `gp` `gd` | `git st`, `git co`, `git pull`, `git push`, `git diff` |
| `gau` `gaa` `gai` `gcmsg` | `git add -u`, `git add .`, `git add -i`, `git commit -m` |
| `gsw`, `gswr` | `git-switch-pick`, `git-switch-pick --remote` (fzf branch pickers, see below) |
| `gti`, `it` | `git` (typo catchers) |
| `pa` `pat` | `php artisan`, `php artisan test` |
| `punit` `pint` | `./vendor/bin/phpunit`, `./vendor/bin/pint` |
| `nr` `ni` | `npm run`, `npm install` |
| `ll` `lt` | `eza -lah --git`, `eza --tree -L 2` |
| `lg` | `lazygit` |
| `reload` | `exec fish` (zsh: `exec zsh`) |

The abbreviations and aliases above exist in both fish and zsh. The functions
below (`gi`, `nreset`, `patw`, `zc`, `hms`) are **fish-only**; zsh has no
twin for them.

Functions: `gi tst` runs `git st` (fixes the misplaced space); `nreset`
removes `node_modules`, `.nuxt`, `.next` and runs `npm ci`; `patw <filter>`
reruns one artisan test on every PHP change (watchexec).

## Git aliases (`dot_gitconfig.tmpl`)

| Alias | Does |
| --- | --- |
| `git s` | `status -sb` |
| `git sync [branch]` | update the default branch without leaving yours (pulls if you are on it) |
| `git nb <name>` | new branch from a freshly fetched default branch |
| `git rbd` | rebase the current branch onto the freshly fetched default branch |
| `git ppr [args]` | push (hooks run), then `gh pr create --fill` (e.g. `git ppr --base develop`) |
| `git prreview`, `git prfiles [N]` | PRs waiting for my review; files in a PR |
| `git merged-prs <base> [head]` | PR branches merged in a range (release notes) |
| `git changed` | modified, staged and untracked files (NUL-separated) |
| `git dnew` | diff stat including new files |
| `git wtn <branch>` | new worktree `../<repo>-<branch>` on a new branch from fresh `origin/main` (no stash, no switch) |
| `git wta` `wtl` `wtp` | `worktree add`, `list`, `prune` |
| `git linelog START,END:path` | history of a line range (`git log -L`), e.g. `git linelog 10,20:src/app.php`; `git linelog :func:path` follows one function |
| `git git ...` | runs `git ...` (typed `git` twice) |

`push.followTags` (push annotated tags that point at the pushed commits) is
not enabled; `dot_gitconfig.tmpl` carries it commented out in `[push]`, and
`git config --global push.followTags true` turns it on.

`help.autocorrect = prompt` offers the fix for typos such as `commi`, `stas`
or `pul`. `commit.template` shows the conventional-commit format when you
commit without `-m`.

Safety rules (enforced by `tests/bash/git-shortcuts.bats`): no alias skips
hooks (`--no-verify` is typed out on purpose), force pushes always use a
lease (`git pf`), `git cleanf` and `git undohard` show what they would
destroy and ask first, and no alias duplicates another or shadows a git
command.

## Helpers (`~/.local/bin`, any shell)

| Command | Does |
| --- | --- |
| `ports [PORT]` | listening sockets with their process, or who holds PORT |
| `killport PORT [SIG]` | show, then signal (default TERM) whatever listens on PORT |
| `psmem [N]` | top processes by resident memory |
| `conns [N]` | established TCP connections per remote IP |
| `topn [N]` | `sort \| uniq -c \| sort -nr \| head`, for any stdin |
| `logtop FIELD [N] FILE...` | rank access logs by `ip`, `path`, `status`, `pathstatus` or `ua`; reads `.gz` |
| `curl-timing URL` | status plus DNS, connect, TLS, TTFB and total time |
| `gh-stars-export [--format clean\|full\|both] [--out-dir DIR]` | back up your GitHub stars as JSON (gh + jq) |
| `xh` | readable HTTP client for manual API calls (`xh DELETE <url>`); keep curl in scripts |
| `hyperfine 'a' 'b'` | benchmark two commands with warmups before claiming a speedup |
| `git-switch-pick [--remote] [name]` | fzf branch picker behind `gsw` (local) and `gswr` (remote); also runs as `git switch-pick` |
| `rgc [rg args]` | ripgrep only changed files; `LZ=1 rgc` runs lizard on them |

### Branch pickers: `gsw` and `gswr`

`gsw` lists local branches, `gswr` remote branches, newest commit first with
the newest row next to the prompt (`--no-sort`: typing filters but never
re-ranks, so matches stay newest first).
Each row shows the last commit's age, short hash, author, branch and subject.
Git stores no branch creation date, so the date is the last commit, not the
branch creation. The preview pane adds, for the highlighted branch, the first
commit off the default branch (`origin/HEAD`, else `main` or `master`), the
oldest reflog entry (local branches only) and the last 20 commits as a graph.

- `gsw` leaves out the current branch, marks branches checked out in another
  worktree with `⊕ wt` (still listed), and runs `git switch <branch>`.
- `gswr` leaves out symbolic refs such as `*/HEAD`, marks branches that already have a local branch
  with `✓ local` (still selectable), and keeps slashed names whole (only the
  remote name is stripped; remote names containing `/` work). It switches to the existing local branch, else
  runs `git switch --track <remote>/<name>`; a name on several remotes
  follows the remote you picked.
- With arguments fzf is skipped: `gsw <args>` is `git switch <args>`;
  `gswr <name>` or `gswr <remote>/<name>` applies the same switch-or-track
  rule, and a bare name on several remotes is refused as ambiguous.
- Nothing is fetched; run `git fetch --prune` first to see new or deleted
  remote branches.

## Measure before and after

`mise run history:report` writes a sanitised report of this machine's
history (atuin, fish, bash and sys-update runs) to
`~/.local/state/history-report/report.md`: top patterns, workflow failure
rates with median and P90 times, retries, typos, tool adoption, and how
often each shortcut on this page is actually used. Only allowlisted tool
names and git aliases are printed; arguments, paths, hosts and unknown
commands are masked. Compare two reports from the same time window to keep
or drop a shortcut. `hyperfine` measures single-command speedups.

## Not ported

- Project-specific scripts (issue-tracker exports, the PR dashboard, app
  artisan commands, VPN DNS switching) stay in their project repos.
- `alias grep='rg -n'` and `alias find='fd'`: their flags differ, so pasted
  commands would break.
- Writing npm tokens into `.npmrc`: the 1Password `NPM_TOKEN` helper replaces it.
- `git list-files-*` and the switch-with-stash helpers used on the old Mac:
  their definitions are not in any repo. Add them here when found.
