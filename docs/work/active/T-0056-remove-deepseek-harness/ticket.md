Source: local

# T-0056: Remove the DeepSeek harness (DSH) and its remote access, for now (chore)

Status: removed from the repo; owner live cleanup pending
Note: T-0054 and T-0055 are reserved by other sessions.

## Why
Owner instruction, relayed from the Windows session: "remove deepseek harness for now". The removal is meant to be reversible.

## Restore
- The last commit with the harness is 63d206a (full SHA 63d206a63f42892fc171fdfa12f33de4084eff7e). `git show 63d206a:<path>` recovers any single removed file.
- To restore everything: find the removal with `git log --format='%h %s' --grep='^chore(dsh): remove the DeepSeek harness'` and `git revert` it. Then run `chezmoi apply` and run the restored `tools:deepseek-harness:install` task with mise.
- A revert also removes this ticket (it was added by the same commit). Archive T-0056 after restoring.

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
