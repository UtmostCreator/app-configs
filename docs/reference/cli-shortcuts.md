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
| `gti`, `it` | `git` (typo catchers) |
| `pa` `pat` | `php artisan`, `php artisan test` |
| `punit` `pint` | `./vendor/bin/phpunit`, `./vendor/bin/pint` |
| `nr` `ni` | `npm run`, `npm install` |
| `ll` `lt` | `eza -lah --git`, `eza --tree -L 2` |
| `lg` | `lazygit` |
| `reload` | `exec fish` (zsh: `exec zsh`) |

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
| `git git ...` | runs `git ...` (typed `git` twice) |

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
| `rgc [rg args]` | ripgrep only changed files; `LZ=1 rgc` runs lizard on them |

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
