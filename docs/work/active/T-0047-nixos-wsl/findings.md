# T-0047 findings: issues faced during the Windows 11 WSL2 setup

Date range: 2026-11-15..16. One line per issue. Commit-message audit: [evidence/commit-traceability-audit-2026-11-16.md](evidence/commit-traceability-audit-2026-11-16.md).

Status: **fixed** (commit SHA), **worked around** (manual or temporary; repo unchanged), **open** (owner named), **process** (way of working, not a defect).

Evidence column: `final-run` = `evidence/final-run-2026-11-16.md`; `h1-*` = the other files in `evidence/`. "Session log" = the 2026-11-15..16 working sessions, not recorded in the repo.

Owner "all-reviewed-landing" is the NixOS-desktop Claude session (formerly named __AppConfigs_fixes).

## Issues from the final run and its preparation

| # | Issue | Cause | Resolution / status | Evidence |
|---|-------|-------|---------------------|----------|
| 1 | Windows ssh-agent service would not start | The service is Disabled by default | Set to Automatic and Running; the only elevated step of the final run. **worked around** (manual) | final-run A1 |
| 2 | Agents could not use the SSH key | The key is passphrase protected, so agents cannot load it | The user ran `ssh-add`; `ssh -T git@github.com` then authenticated as UtmostCreator. **worked around** | final-run A2 |
| 3 | Bootstrap run 5 failed at step 12 | Home Manager collision, on 4568249 | The fix stack landed as 8316e94; the collision fix is likely 3ef84a6 (by commit subject, not re-measured). **fixed** (8316e94) | final-run "Runs 3-5" |
| 4 | The fix stack existed only on the NixOS machine | Agent pushes are refused there | The user pushed 8316e94 to main. **fixed** (8316e94 on origin/main) | final-run B1 |
| 5 | The user could not see the stack | It sat on local branch `land/all-reviewed`, checked out in a /tmp worktree, while ~/Projects/app-configs had main checked out | **process** (explained; pushed by SHA) | Session log |
| 6 | origin/main had to stay still during the NixOS session's rebase | Three sessions were coordinating | Push guarded with `test "$(git rev-parse origin/main)" = <sha>`. **process** | Session log |
| 7 | Bootstrap refuses elevated runs, but the admin agent session was elevated | The agent shell was elevated | De-elevated launch through explorer.exe and runner .cmd files, with a logged `IsInRole` check = False. **worked around** | Session log; h1-elevated (step C skipped when elevated) |
| 8 | Old WSL clone had diverged and held the seeded personal.yaml | The clone at b3d113c was behind main | Moved to `~/app-configs.old-20261116T002506Z`; personal.yaml copied without being read. **fixed** (process) | final-run B3, B5 |
| 9 | `install-git-hooks --check` failed on Windows: "_lefthook.sh is not executable" | MSYS on NTFS reports -x only for files with a shebang; `_lefthook.sh` is a sourced helper | Check only the dispatchers for +x. **fixed** (8f6b4eb); Windows and WSL `--check` exit 0 | final-run open item a |
| 10 | `codebase-memory-mcp-ui` restart loop on a fresh WSL | The wrapper exports `CBM_ALLOWED_ROOT=$HOME/Projects`, which did not exist | `mkdir -p ~/Projects` and restart. Final health check 2026-11-16: UI healthy (active (running), HTTP 200 on 127.0.0.1:9749, NRestarts=0 across 4 boots). **worked around**; repo fix **fixed** (d03a095 on origin/main; not yet pulled) | final-run open item c and "Final health check"; nix/modules/home/dev.nix:14 |
| 11 | `systemctl --failed` hid the loop | The unit stays "activating", never "failed" | Readiness now flags a looping unit (NRestarts); the final health check showed no failed units because the unit is now healthy, not because the check is fixed. **fixed** (1f88958 on origin/main; not yet pulled) | final-run open item c and "Final health check" |
| 12 | `wsl -d NixOS -- bash -c '...$?...'` gave the wrong exit status | fish is the WSL login shell and expands `$?` itself ("$? is not the exit status") | Use `wsl -d NixOS --exec bash -lc '...'`. **worked around** | Session log |
| 13 | WSL git over SSH had no key | The clone uses an SSH remote; the key lives in the Windows ssh-agent | Repo-local `core.sshCommand=/mnt/c/Windows/System32/OpenSSH/ssh.exe`. **worked around**; permanent config is a follow-up, **open** | final-run open item e |
| 14 | First SSH connection from WSL prompted for GitHub's host key | Empty `known_hosts` | Checked against GitHub's published ED25519 fingerprint `SHA256:+DiY3wvvV6TuJJhbpZisF/zLDA0zPMSvHdkr4UvCOqU`. **fixed** (one-off) | Session log |
| 15 | An agent was blocked from using the user's SSH credentials | The host permission classifier refuses it | The user ran the test. **process** | Session log |
| 16 | Pull and merge could not be done by agents | Repo rules and the orchestrator role require the user's explicit action | The user ran the fast-forward commands. **process** | Session log; CLAUDE.md "Scope and Mutation" |
| 17 | Uncommitted CLAUDE.md edit adds a grant to the protected-action rule (line 19: ", or if user says all permissions lifted") | Inside the glyphbrace-managed region, so `glyphbrace update` flags it. Author unknown; mtime 2026-11-16 00:16 UTC | Revert or accept deliberately. **open** (owner: the user) | `git diff CLAUDE.md` |
| 18 | Agent token blow-up (400k to 800k) | The same agents were resumed for 12 to 25 rounds and re-read the ~1800-line bootstrap.ps1 and ~3000-line tests file | Fresh agent per slice, diff-first reviews; split of the two files proposed. **process** | Session log |
| 19 | Windows time zone was Pacific Standard Time | Unknown (session log) | Now GMT Standard Time; 24-hour format read as HH:mm. T-0048 windows.yaml timezone updated; time-format key still missing. **fixed** (manual) | final-run AC-TZ rows; T-0048 windows.yaml |
| 20 | The C1 import grep looked like a failure | `app-configs-wsl.nix` is imported indirectly through the root-only `app-configs-extra.nix` | Confirmed (grep -c 2, `wsl.enable` true). **fixed** (false alarm) | final-run C1 |
| 21 | `nix profile list \| grep -c home-manager` printed 2 | It counts the name and the store path | Misleading check; only `home-manager-path` is present. **fixed** (false alarm) | final-run C1 |
| 22 | bats unavailable in Windows Git Bash | `path-contract.bats` also needs python3 on PATH | Doc tests ran in a disposable copy inside WSL. **worked around** | Session log |
| 23 | CRLF in the Windows worktree | `.gitattributes` has `text eol=lf` for `*.sh` and other types; `*.ps1` is not checked here | Follow-up: add `*.ps1 text eol=lf`. **open** (owner unassigned) | Session log; .gitattributes |
| 24 | Work held only in temp folders can be lost | The /tmp stack worktree and design drafts in agent scratchpads | Durable copies recommended (T-0054 draft). **process** | Session log |
| 25 | Cross-session messaging over Remote Control gives no delivery or idle notice | Tool limitation | Replies awaited manually. **process** | Session log |

## Issues added from mining the repo (earlier runs and tickets)

| # | Issue | Cause | Resolution / status | Evidence |
|---|-------|-------|---------------------|----------|
| 26 | Pending-reboot marker stayed set after a plain restart (run 1) | Only Settings > Windows Update > Restart now clears it | Use that restart path. **worked around** | h1-elevated "Prerequisite learned" |
| 27 | About 3 minutes of silence before step 0, no progress on the ~550 MB download, "imported NixOS" read as completion (runs 1 and 2) | Bootstrap printed no heartbeat or summary | Output contract proposed in T-0050. 6862dfc added the wait feedback and heartbeat to the bash install scripts (ops/install.sh, ops/lib/wait-feedback.sh) and does not touch `ops/windows/bootstrap.ps1`. **fixed** (bash install scripts, 6862dfc); **open** (bootstrap.ps1, T-0050) | T-0050-user-feedback-during-waits/findings.md; h1-elevated, h1-normal; `git show --stat 6862dfc` |
| 28 | `lefthook run pre-commit` failed on Windows (T-0051 F1) | The inline `no-personal-yaml` command broke under `sh.exe -c` with embedded quotes | Guard moved into a script. **fixed** (7731a31) | T-0051-windows-git-hooks/ticket.md; h1-verification |
| 29 | `bash` on the Windows PATH resolves to the WSL launcher once WSL is installed (T-0051 F2) | The WindowsApps launcher comes before Git Bash | 8beb383 routes hook installs through `ops/install-git-hooks.sh`; it does not touch `bootstrap.ps1` or mention the WindowsApps launcher, so this is not shown as resolved. Which bash a commit gets is `unknown`. **open** (T-0051) | T-0051-windows-git-hooks/ticket.md; `git show --stat 8beb383` |
| 30 | lefthook made a temporary `git stash` on partially staged commits (T-0051 F3) | Conflicts with the AGENTS.md no-stash rule | Partially staged commits refused before lefthook runs; hook install routed through one script. **fixed** (f7619da, 8beb383) | T-0051-windows-git-hooks/ticket.md |
| 31 | `gitleaks protect --staged` is deprecated (T-0051 F4) | Deprecated since gitleaks 8.19.0; works in 8.30.1 | Maintained form is `gitleaks git --staged`; no fix commit found. **open** | T-0051-windows-git-hooks/ticket.md |
| 32 | Git alias `fp` deleted local tags with no prompt while looking read-only (T-0053 F1) | `fetch --prune --prune-tags` | Aliases made safe and read-only. **fixed** (e888a5d; 51a11c6 dropped autostash) | T-0053-git-alias-safety/ticket.md |
| 33 | WSL mount-guard unit used a path that does not exist on NixOS | Inferred from the subject: the unit lacked a NixOS path | Given a NixOS path; activated configs kept on unit failure. **fixed** (9a4c97d) | Commit subject only |
| 34 | NixOS-WSL lacked system tools that `install` needs before Home Manager | Inferred from the subject: stock image is minimal | Tools provided by the setup. **fixed** (b1391bf) | Commit subject only |
| 35 | Activate-script failures were not treated as activated, and the rollback restore was not spelled out | Inferred from the subject | Treated as activated; restore documented. **fixed** (7df0c1f) | Commit subject only |
| 36 | sys-readiness reports "chezmoi has pending changes" falsely on WSL | `ops/readiness.sh:67` runs plain `chezmoi verify`; no persisted sourceDir (`ops/install.sh:571`) | With `--source=$HOME/app-configs`: 88 managed, status empty, verify exit 0. **fixed** (ca3b67b on origin/main; not yet pulled) | final-run health check |
| 37 | No git identity in WSL | personal.yaml name/email not filled; `dot_gitconfig.tmpl` renders `[user]` only with real values | The user fills personal.yaml, then runs `chezmoi --source="$HOME/app-configs" apply`. **open** (owner: the user) = ticket item (b) | final-run health check |
| 38 | setup.md contradicted the one-engine Docker rule (windows-and-wsl.md "Docker"; ticket Decision "Docker: declarative via sys-setup") | The runbook offered Docker Desktop or docker.io | One engine: NixOS `virtualisation.docker` via `sudo ENABLE_DOCKER=1 sys-setup --apply` (export first: `bootstrap.ps1 -Export before-docker`). **fixed** (docs) | docs/platforms/wsl/setup.md |
| 39 | `ops/projects/workspace/config.sh:88-89` still recommends Docker Desktop WSL integration | AC-DOCKER-MSG | Needs a code change and a commit. **open** (follow-up) | ticket AC-DOCKER-MSG |
| 40 | Claude/Codex CLIs not installed in WSL; update timers skip silently | Vendor installers are outside the repo by design; timers skip via ConditionPathExists (ai-cli-updates.nix:41) | Install with the vendor installers into ~/.local/bin, then log in. **open** (owner: the user) | final-run "Acceptance measurements" |
| 41 | Tailscale not installed on Windows (AC-WSL tailnet) | C:\Program Files\Tailscale\tailscale.exe missing | Install and log in on Windows. **open** (owner: the user) | final-run "Acceptance measurements" |
| 42 | sys-update --apply, audit.sh and bootstrap.sh call chezmoi without --source on WSL | no persisted sourceDir (`ops/install.sh:571`) | Workaround `chezmoi --source="$HOME/app-configs" apply`; shared helper in progress. **open** (owner `all-reviewed-landing`) | Session all-reviewed-landing, 2026-11-16 |
| 43 | fish start error from ssh-agent.fish:83 on WSL | $SHELL is the wrapped-fish `wrapper` path, so keychain emits POSIX syntax | **fixed** (cb81798, 249b073 on origin/main; not yet pulled) | session log; home/dot_config/fish/conf.d/ssh-agent.fish; ops/unix/ssh-agent-setup.sh |
| 44 | repo-audit and codebase-memory-mcp-update units fail on WSL | they locate the repo via `chezmoi source-path` (no persisted sourceDir) | **open** (owner all-reviewed-landing) | session log |
| 45 | bats tests leak 1Password `op daemon` processes | unknown (session-reported) | **open** (owner all-reviewed-landing) | session log |
