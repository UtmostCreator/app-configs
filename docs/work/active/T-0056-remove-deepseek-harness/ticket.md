Source: local

# T-0056: Remove the DeepSeek harness (DSH) and its remote access, for now (chore)

Status: done, pending human (removed on main e889726; live leftovers on the desktop: dsh-remote*, its unit, mise conf.d). SHAs below predate the 2026-11-18 rewrite
Related: ADR-0029 (`docs/architecture/decisions/0029-networking-and-remote-access.md`, Tailscale personal-only), ADR-0032 (`docs/architecture/decisions/0032-ai-clis-context-tools-and-desktop-apps.md`, AI tools; DSH recorded as removed)
Note: T-0054 and T-0055 are reserved by other sessions.

## Why
Owner instruction, relayed from the Windows session: "remove deepseek harness for now". The removal is meant to be reversible. Owner follow-up: "record deepseek removed commits and we might return back to it."

## History (commits on main)
All are ancestors of main (checked with `git merge-base --is-ancestor`), oldest first.

Removal commits:
- 4b152795fb1a73cb7ad91138fee047865ba3d9ac (2026-11-16): removed the harness from the repo.
- f9e2434c576001494f52d821a5c742161d3822d6 (2026-10-26, "feat(docs): delete stale files"): deleted the DSH Android guide. Recover it with `git show f9e2434^:docs/ai/deepseek-harness-android.md`.

| Date | SHA | Subject |
| --- | --- | --- |
| 2026-09-05 | 315b9f5c8b23b45da7badc5a25fafbf8610c2458 | feat: expand development environment tooling (added the mise `tools:deepseek-harness:*` install task and the software-list entry) |
| 2026-09-11 | 5ce0cddf8ff31af67d0702b1f228262db42cc93e | feat(dsh): tailnet-only remote access for the DeepSeek Harness (added dsh-remote, -setup, -status, the systemd unit, mise tasks, Android guide) |
| 2026-10-22 | 5be9bd59695081baceab1c1f85bb980aca2716a2 | fix(ssh): default agent key to id_ed25519 and tidy helper scripts (touched dsh-remote only) |
| 2026-10-22 | 1ff7a6f45daf8477d56494e449bbc19539c0f33d | docs: move repo-docs into docs/ and ignore AI run output (moved the Android guide to docs/ai/; a rename, not a deletion) |
| 2026-10-26 | f9e2434c576001494f52d821a5c742161d3822d6 | feat(docs): delete stale files (deleted the Android guide) |
| 2026-11-14 | d563555b6a4d6a00a5bb70467e6cdd2d802630a1 | fix(dsh-remote): add arg parser and Linux-only guard before mutating tailscale/systemd |
| 2026-11-16 | 653ccfe9fdbf1f307f0761b67c30c21f770d21eb | feat(dsh): make DeepSeek Harness remote autostart opt-in |
| 2026-11-16 | 4b152795fb1a73cb7ad91138fee047865ba3d9ac | chore(dsh): remove the DeepSeek harness and its remote access for now |

Incidental DSH lines (tests, docs, tooling): bb97fb85c92865e7d766b779b80812f94d8de7c8, ccc20b3c9066c087cb0a331c5510085a32fe8a7f, 0a33b3d88e945f8f170bb756fa005ac535858aaf, 1f0219c2f64cc81e4be84ea42c860ec11568fde0, 288c8dc94e31d205b3946573ccea57c7b552b787, c2f4b7138beb7990caf30c9554c5a41d4b4efc8f, 3cccb417f9f72723e37b3935ec2819190e2f70d4. Docs-only mentions: dab431c1bc87047eed4e772f98967d558074e2a7 (Tailscale sharing guide), 7a6dc9785318edaa95f7326d64f7119dd1c5ad3b and 5b3c89bcead5e52048e8803d87db5b664336840a (ADR-0032 records the removal).

Do not use 80b797d or 4c12460. They are duplicates of 5ce0cdd and d563555 that are not on main.

## Restore
- The last commits with the harness content are 63d206a and 403a182 (identical DSH content; full SHA of 63d206a: 63d206a63f42892fc171fdfa12f33de4084eff7e). `git show 63d206a:<path>` recovers any single removed file.
- To find the removal: `git log --format='%h %s' --grep='^chore(dsh): remove the DeepSeek harness'`.
- `git revert 4b15279` does not apply cleanly on current main. Conflicts: `docs/work/index.md` (keep both rows), `ops/system-setup.sh` (keep HEAD's `ENABLE_TAILSCALE` logic, the ADR-0029 personal-only default; restore only the dsh-remote-setup comment), and this ticket (modify/delete; keep or archive it deliberately). Run the full `bats tests/bash` suite before committing.
- Alternative: `git restore --source=63d206a -- <DSH-only paths>` (the three `dsh-remote*` scripts, the systemd unit, its bats file (`63d206a:tests/bash/dsh-remote-setup.bats`)), then hand-merge the shared files from `git show 4b15279`: `mise.toml`, `ops/system-setup.sh`, `home/.chezmoiignore`, `tests/bash/arg-contract.bats`, `tests/bash/chezmoiignore-selection.bats`, `ops/history-report.py`, `docs/architecture/tool-ownership.md`, and the software list. Do not cherry-pick 5be9bd5 (it would reintroduce old ssh-agent code).

## Returning to DSH later
1. Restore by one of the two routes above.
2. Run `chezmoi apply`, then the restored mise install task `tools:deepseek-harness:install`.
3. Re-enable remote access only through the opt-in added in 653ccfe (autostart is off by default). Running `dsh-remote-setup` always adds the Tailscale Serve rule.
4. Re-check ADR-0029 (Tailscale personal-only) and ADR-0032 (AI tools; DSH recorded as removed) first, and amend them if DSH returns.
5. Re-add the Serve rule only if wanted. To remove it later use `tailscale serve --https=443 off`; `tailscale serve reset` clears all Serve rules.

## What was removed
- `63d206a:home/dot_local/bin/executable_dsh-remote`, `63d206a:home/dot_local/bin/executable_dsh-remote-setup`, `63d206a:home/dot_local/bin/executable_dsh-remote-status`
- `63d206a:home/dot_config/systemd/user/dsh-remote.service`
- `home/.chezmoiignore`: the macOS exclusion of `.local/bin/dsh-remote-setup`
- `mise.toml`: tasks `tools:deepseek-harness:{install,list,remote-setup,remote-status}` (pin was `npm:@deepseek-ai/dsh@0.1.2-rc.1`)
- `63d206a:tests/bash/dsh-remote-setup.bats`, and the dsh entries in `tests/bash/arg-contract.bats` and `tests/bash/chezmoiignore-selection.bats`
- `ops/history-report.py`: `dsh-remote`, `dsh-remote-status` from the known-command list and `dsh-remote` from the "remote shell" pattern (both DSH-only)
- `ops/system-setup.sh`: comment reference only
- Docs: DSH entry in `repo-docs/software-and-cli-tools.md`, the DSH row and the `tcp:443` note in `docs/guides/tailscale-local-services.md`, the dsh-remote.service exception in `docs/architecture/tool-ownership.md`
- Not touched: `ops/windows/bootstrap.ps1` has no DSH reference. `tests/windows/bootstrap.tests.ps1` has no DSH logic (its case-insensitive "dsh" matches are all `HeadSha` fixtures).

The repo has no `.chezmoiremove`, so chezmoi does not delete the deployed files.

## Live cleanup (owner, on each host that applied it)
Systemd steps are Linux/WSL only.
1. Linux/WSL: `systemctl --user disable --now dsh-remote.service` (if present).
2. Run `tailscale serve status`. If it shows https:443 proxying to http://127.0.0.1:3080, remove only that rule with `tailscale serve --https=443 off`. Use `tailscale serve reset` only if that is the sole rule.
3. `rm -f ~/.local/bin/dsh-remote ~/.local/bin/dsh-remote-setup ~/.local/bin/dsh-remote-status`
4. Linux/WSL: `rm -f ~/.config/systemd/user/dsh-remote.service`, then `systemctl --user daemon-reload`.
5. Optional: `mise uninstall npm:@deepseek-ai/dsh@0.1.2-rc.1`, then `rm -f ~/.config/mise/conf.d/deepseek-harness.toml` (written by the removed mise task, not repo-managed; "Safe to delete").
6. Optional: remove `tcp:443` from the Tailscale ACL grant if it was added for DSH.
7. DSH's own settings outside the repo (they hold the DeepSeek key) are deliberately left in place. Do not read or print them; delete them yourself if you want them gone.
