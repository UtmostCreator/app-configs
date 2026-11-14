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

When the installed version differs, the updater runs Home Manager for the
detected host and restarts the dashboard. Home Manager applies the current
configuration in this checkout, including other local configuration edits.
No flake inputs are updated, and no changes are committed or pushed.
Failed activation leaves the release lock available for retry on the next run.
The timer finds the checkout through `chezmoi source-path`, so the clone can
live anywhere chezmoi is configured to use.

```bash
systemctl --user list-timers 'codebase-memory-mcp-*'
systemctl --user start codebase-memory-mcp-update.service
journalctl --user -u codebase-memory-mcp-update.service -n 40
# Refresh the package lock without activating:
bash ops/update-codebase-memory-mcp.sh
```

This schedule is configured for Linux. macOS can consume the same release
lock on its next Home Manager or nix-darwin rebuild.
