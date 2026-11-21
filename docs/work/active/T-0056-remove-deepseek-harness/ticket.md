Source: local

# T-0056: Remove the DeepSeek harness (DSH) and its remote access, for now (chore)

Status: done, pending human (removed on main e889726; live leftovers on the desktop: dsh-remote*, its unit, mise conf.d). SHAs remapped to main after the 2026-11-18 rewrite; originals in backup-18-11-2026
Related: ADR-0029 (`docs/architecture/decisions/0029-networking-and-remote-access.md`, Tailscale personal-only), ADR-0032 (`docs/architecture/decisions/0032-ai-clis-context-tools-and-desktop-apps.md`, AI tools; DSH recorded as removed)
Note: T-0054 and T-0055 are reserved by other sessions.

## Why
Owner instruction, relayed from the Windows session: "remove deepseek harness for now". The removal is meant to be reversible. Owner follow-up: "record deepseek removed commits and we might return back to it."

## History (commits on main)
All are ancestors of main (checked with `git merge-base --is-ancestor`), oldest first.

Removal commits:
- e889726035d28114d30f53901eacc87813ce296c (2026-11-16): removed the harness from the repo.
- c7578b612f32406d0e07b6c7ed27a03a4adae763 (2026-10-26, "feat(docs): delete stale files"): deleted the DSH Android guide. Recover it with `git show c7578b6^:docs/ai/deepseek-harness-android.md`.

| Date | SHA | Subject |
| --- | --- | --- |
| 2026-09-05 | 8aaa94efd3a20dba3ff803eeffd95eeff83ca10d | feat: expand development environment tooling (added the mise `tools:deepseek-harness:*` install task and the software-list entry) |
| 2026-09-11 | 1968d191f5e1618397eecd27d007e90010572ed7 | feat(dsh): tailnet-only remote access for the DeepSeek Harness (added dsh-remote, -setup, -status, the systemd unit, mise tasks, Android guide) |
| 2026-10-22 | 536d1572593b71164279c74e2b2b66794ccbeb81 | fix(ssh): default agent key to id_ed25519 and tidy helper scripts (touched dsh-remote only) |
| 2026-10-22 | fad6f25bf2fe4ad89dc82427ebf4faa7290bd1d8 | docs: move repo-docs into docs/ and ignore AI run output (moved the Android guide to docs/ai/; a rename, not a deletion) |
| 2026-10-26 | c7578b612f32406d0e07b6c7ed27a03a4adae763 | feat(docs): delete stale files (deleted the Android guide) |
| 2026-11-14 | dcbde0555d45d0f74a4564d31e116a7f82a1f64c | fix(dsh-remote): add arg parser and Linux-only guard before mutating tailscale/systemd |
| 2026-11-16 | b27bd3d31da07e5e493e181086120f6b8f21a20c | feat(dsh): make DeepSeek Harness remote autostart opt-in |
| 2026-11-16 | e889726035d28114d30f53901eacc87813ce296c | chore(dsh): remove the DeepSeek harness and its remote access for now |

Incidental DSH lines (tests, docs, tooling): b9fbb6cbae9953a9de5f1c9a704ae008f331e464, 024d3ed4e43efb825f33748549c804630c5774df, ea14c51bba0e0d8450f267e0923c869dae041aae, 2e7aa67e5b3a632d0a8bcd755499c924fc8e5184, e3e40a09e138c30519f0e144eef016836307868d, 1b3617e8f02c99a764b7e69fccc11fd5d86e0f02, 29753d68c42158c2aecddcb195aa1279b53b3674. Docs-only mentions: efe168b64797005b1db7f8ba297e3584c7ffe5d9 (Tailscale sharing guide), 6ba5959dabeae2a85313211e41a5bb98666aa452 and e416d2f61b7ee630bc7fe7aff0108162baba94bc (ADR-0032 records the removal).

Do not use 1968d19 or dcbde05. They are duplicates of 1968d19 and dcbde05 that are not on main.

## Restore
- The last commits with the harness content are 5533fdc and 86ff52e (identical DSH content; full SHA of 5533fdc: 5533fdca7983ef3c8457caa219a0fc614bab0484). `git show 5533fdc:<path>` recovers any single removed file.
- To find the removal: `git log --format='%h %s' --grep='^chore(dsh): remove the DeepSeek harness'`.
- `git revert e889726` does not apply cleanly on current main. Conflicts: `docs/work/index.md` (keep both rows), `ops/system-setup.sh` (keep HEAD's `ENABLE_TAILSCALE` logic, the ADR-0029 personal-only default; restore only the dsh-remote-setup comment), and this ticket (modify/delete; keep or archive it deliberately). Run the full `bats tests/bash` suite before committing.
- Alternative: `git restore --source=5533fdc -- <DSH-only paths>` (the three `dsh-remote*` scripts, the systemd unit, its bats file (`5533fdc:tests/bash/dsh-remote-setup.bats`)), then hand-merge the shared files from `git show e889726`: `mise.toml`, `ops/system-setup.sh`, `home/.chezmoiignore`, `tests/bash/arg-contract.bats`, `tests/bash/chezmoiignore-selection.bats`, `ops/history-report.py`, `docs/architecture/tool-ownership.md`, and the software list. Do not cherry-pick 536d157 (it would reintroduce old ssh-agent code).

## Returning to DSH later
1. Restore by one of the two routes above.
2. Run `chezmoi apply`, then the restored mise install task `tools:deepseek-harness:install`.
3. Re-enable remote access only through the opt-in added in b27bd3d (autostart is off by default). Running `dsh-remote-setup` always adds the Tailscale Serve rule.
4. Re-check ADR-0029 (Tailscale personal-only) and ADR-0032 (AI tools; DSH recorded as removed) first, and amend them if DSH returns.
5. Re-add the Serve rule only if wanted. To remove it later use `tailscale serve --https=443 off`; `tailscale serve reset` clears all Serve rules.

## What was removed
- `5533fdc:home/dot_local/bin/executable_dsh-remote`, `5533fdc:home/dot_local/bin/executable_dsh-remote-setup`, `5533fdc:home/dot_local/bin/executable_dsh-remote-status`
- `5533fdc:home/dot_config/systemd/user/dsh-remote.service`
- `home/.chezmoiignore`: the macOS exclusion of `.local/bin/dsh-remote-setup`
- `mise.toml`: tasks `tools:deepseek-harness:{install,list,remote-setup,remote-status}` (pin was `npm:@deepseek-ai/dsh@0.1.2-rc.1`)
- `5533fdc:tests/bash/dsh-remote-setup.bats`, and the dsh entries in `tests/bash/arg-contract.bats` and `tests/bash/chezmoiignore-selection.bats`
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
