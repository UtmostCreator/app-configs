Source: local

# T-0051: Git hooks must work on Windows end to end (bug)

Status: open
Relates to: T-0047 (task T2), T-0050
Note: T-0049 is reserved by another session.

Verified on this PC 2026-11-15: Windows 11, Git for Windows, lefthook 2.2.2, gitleaks 8.30.1, chezmoi 2.74.1.

## Findings
- F1 (blocks commits on Windows): the inline `no-personal-yaml` command in `.lefthook.yml` fails under lefthook on Windows. Lefthook runs it as `"C:\Program Files\Git\bin\sh.exe" -c "<multi-line script>"` and the embedded double quotes break the command (`unexpected EOF while looking for matching ')'`, exit 2). `lefthook run pre-commit` therefore exits 1 although `ops/hooks/pre-commit.sh` itself passes. Fix direction: move the inline script into a file under ops/hooks and call it with `bash`, like the other hooks; keep the same check and add a bats test.
- F2: once WSL is installed, `bash` on the Windows PATH resolves to the WindowsApps WSL launcher, not Git Bash. Lefthook used Git's own sh.exe here, and the hook commands call `bash ops/hooks/...`. Which bash they get when a commit starts from PowerShell versus Git Bash is unknown. A hook must never run inside a WSL distro by accident.
- F3 (policy conflict): on a commit with partially staged files lefthook creates and drops a temporary `git stash` ("lefthook auto backup"). `AGENTS.md` forbids saving, popping or applying stashes (the stash is shared across worktrees). Observed once during a manual `lefthook run pre-commit`; the user's existing stash and the worktree were verified intact afterwards. Decide: configure lefthook to skip that behaviour if possible, document the exception, or avoid partially staged commits.
- F4: `ops/hooks/pre-commit.sh` uses `gitleaks protect --staged`, deprecated since gitleaks v8.19.0 (still works in 8.30.1). Maintained form: `gitleaks git --staged`.

## Verified OK
- `bash ops/doctor.sh` exit 0 and `bash ops/validate-config.sh` exit 0 under Git Bash with chezmoi installed.
- `ops/hooks/pre-commit.sh` passes via lefthook ("[hook] pre-commit passed").

## Acceptance criteria
| AC | Check |
|----|-------|
| AC-1 | `lefthook run pre-commit` exits 0 on Windows with a clean staged docs file. |
| AC-2 | A planted personal.yaml path is refused on Windows and Linux. |
| AC-3 | A planted fake token is caught by the secret scan in a real `git commit` on Windows. |
| AC-4 | commit-msg good and bad cases behave. |
| AC-5 | A commit started from PowerShell and from Git Bash runs the hooks with Git's bash, never WSL. Probe: a temporary hook line printing `uname -s` and `$BASH` shows MINGW/Git bash, not Linux. |
| AC-6 | The stash question (F3) is decided and recorded. |
| AC-7 | The full `bats tests/bash` passes on Linux after the `.lefthook.yml` change. |

## Owned files
- `.lefthook.yml`, `ops/hooks/pre-commit.sh`, a new hook script under ops/hooks, tests.
- Shared files: coordinate with the NixOS session; Linux verification happens there.

## Until fixed
- Commits on this Windows PC are blocked by the hook. Never bypass it.
- Commit on the NixOS machine or in WSL.
- This supersedes the T-0047 hand-run commit path on Windows.
