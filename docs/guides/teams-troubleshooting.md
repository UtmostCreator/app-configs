# Microsoft Teams (macOS): messages not sending, reactions reverting

Symptoms: messages stay unsent, emoji reactions appear and then disappear.
A restart sometimes helps, which points to stale client state.

## Teams data locations (new Teams, `com.microsoft.teams2`)

App: `/Applications/Microsoft Teams.app`

| Path | Role | Size seen |
|------|------|-----------|
| `~/Library/Containers/com.microsoft.teams2/Data/Library/Caches/Microsoft` | Cache (safe to delete) | ~97M |
| `~/Library/Containers/com.microsoft.teams2/Data/Library/Caches/com.microsoft.teams2` | Cache (safe to delete) | ~3M |
| `~/Library/Containers/com.microsoft.teams2/Data/Library/Application Support/Microsoft/Teams` | Web-view and app data (sign-in state) | ~54M |
| `~/Library/Containers/com.microsoft.teams2/Data/Library/Application Support/Microsoft/MSTeams` | Web-view and app data (sign-in state) | ~523M |
| `~/Library/Group Containers/UBF8T346G9.com.microsoft.teams` | Shared app data | ~345M |

Do not delete the whole `com.microsoft.teams2` or group container folders
unless you accept signing in again and losing local Teams data.

## Step 1: clear the cache

Quit Teams first, then delete only the cache folders:

```sh
osascript -e 'quit app "Microsoft Teams"'
rm -rf "$HOME/Library/Containers/com.microsoft.teams2/Data/Library/Caches/Microsoft"
rm -rf "$HOME/Library/Containers/com.microsoft.teams2/Data/Library/Caches/com.microsoft.teams2"
open -a "Microsoft Teams"
```

## Step 2: reset web-view data (signs you out)

Only if Step 1 does not help. You will need to sign in again:

```sh
osascript -e 'quit app "Microsoft Teams"'
rm -rf "$HOME/Library/Containers/com.microsoft.teams2/Data/Library/Application Support/Microsoft/Teams"
rm -rf "$HOME/Library/Containers/com.microsoft.teams2/Data/Library/Application Support/Microsoft/MSTeams"
open -a "Microsoft Teams"
```

## Other checks

- Test the same chat in Teams on the web. If the web version works, the desktop client is the problem. If it fails too, check the account or tenant policy.
- Check the Microsoft 365 service health page for outages.
- Connection tools (VPN, Private Relay, firewall or content filters such as Little Snitch) can drop the real-time connection that sends and reactions depend on.
- Karabiner: the global Ctrl-to-Cmd rules in [`home/dot_config/karabiner/karabiner.json`](../../home/dot_config/karabiner/karabiner.json) do not exclude Teams. Add `^com\\.microsoft\\.teams2$` to the exclusion list in the `[CORE] Ctrl shortcuts → Cmd shortcuts` rule if Ctrl shortcuts misbehave in Teams.
- Check the system date and time are correct, and sign out and back in to refresh the token.
