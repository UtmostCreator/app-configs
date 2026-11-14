# Codebase Memory MCP dashboard and updates

Open <http://127.0.0.1:9749/?tab=stats>. On Linux, Home Manager enables
`codebase-memory-mcp-ui.service` at login. It restarts after failures and package
changes. A health timer checks HTTP every two minutes and restarts the service
if the dashboard disappears.

MCP clients should use an empty argument list. Since the shared daemon was
introduced, `--ui=false` disables its HTTP listener for every client and saves
that setting in `_config.db`. The old `config.json` may still say `true`.
The service's `--ui=true --port=9749` restores the listener at startup.

```bash
systemctl --user restart codebase-memory-mcp-ui.service
journalctl --user -u codebase-memory-mcp-ui.service -n 40
```

`codebase-memory-mcp-update.timer` checks stable GitHub releases every Monday
at 10:00 local time, with up to 15 minutes of jitter. Missed runs happen at the
next login. The updater validates release asset URLs and SHA-256 metadata for
Linux and macOS before atomically refreshing
`nix/packages/codebase-memory-mcp/release.json`; Nix verifies the downloaded
archive against that hash. It does not use the binary's self-updater because
the installed executable belongs to the immutable Nix store.

With `--apply` (what the timer runs), a changed release is written to the lock
and, when the installed version differs, Home Manager is switched for the
detected host (`-b hm-bak`, after the nix-profile conflict check) and the
dashboard is restarted. Home Manager applies the current configuration in this
checkout, including other local configuration edits. No flake inputs are
updated and nothing is pushed. It takes the same state lock as `sys-update`,
so the two never run together.
On macOS the updater only runs `home-manager switch`: the dashboard service is
a Linux systemd user unit, so there is no restart or dashboard probe.

The lock is never left modified, because a dirty worktree stops the next
`sys-update`. If `home-manager switch` fails, the previous `release.json` is
put back. Once the switch succeeds, the lock is committed on its own
(`chore(nix): update codebase-memory-mcp release to …`), provided it matched
HEAD before the run; a lock with local edits is left for you to commit. If the
restart, dashboard probe or version check then fails, the new generation stays
active and the committed lock records it; the updater says so on stderr and
points at `home-manager generations` for going back.
The timer finds the checkout through `chezmoi source-path`, so the clone can
live anywhere chezmoi is configured to use.

```bash
systemctl --user list-timers 'codebase-memory-mcp-*'
systemctl --user start codebase-memory-mcp-update.service
journalctl --user -u codebase-memory-mcp-update.service -n 40
# Report the latest release without changing anything:
bash ops/update-codebase-memory-mcp.sh
```

This schedule is configured for Linux. macOS can consume the same release
lock on its next Home Manager or nix-darwin rebuild.
