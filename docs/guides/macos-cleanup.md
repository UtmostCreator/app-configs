# macOS disk cleanup: what is safe to clear

Goal: free space without breaking apps or losing data. Check sizes first,
delete second. Caches regenerate on their own. Anything under
`Documents`, `Desktop`, `Photos`, or app data folders needs your decision.

## Check disk usage first

```sh
df -h /                                             # free space on the system disk
du -sh ~/Library/Caches ~/Library/Logs ~/.Trash     # main cleanup candidates
du -sh ~/Library/Caches/* 2>/dev/null | sort -h | tail -20   # biggest caches
du -sh ~/Library/Developer 2>/dev/null               # Xcode and simulator data
find ~ -type f -size +500M 2>/dev/null               # large files in home
```

The built-in view is also useful: Apple menu, System Settings, General,
Storage. It lists categories and suggests what to review.

## Where to look

| Location | What it holds | Safe to clear? | How to open |
|----------|---------------|----------------|-------------|
| `~/.Trash` | Files you moved to Trash | Yes, after review | Click Trash in the Dock, or `open ~/.Trash` |
| `~/Library/Caches` | App and tool caches | Yes, apps rebuild them | Finder: Cmd+Shift+G, paste the path |
| `~/Library/Logs` | App logs | Yes, old files only | Finder: Cmd+Shift+G, paste the path |
| `~/Library/Developer/Xcode/DerivedData` | Xcode build output | Yes | Finder: Cmd+Shift+G, paste the path |
| `~/Library/Developer/CoreSimulator` | iOS simulators | Mostly, use `simctl` below | Finder: Cmd+Shift+G, paste the path |
| `~/Downloads` | Downloaded installers, archives, SQL dumps | Review manually | Finder sidebar, Downloads |
| `~/.npm`, `~/Library/pnpm`, `~/.cache/uv` | Package manager stores | Yes, via tool commands below | Use the commands below |
| `~/Library/Containers/com.microsoft.teams2` | Teams data | Cache only, see the Teams guide | See [teams-troubleshooting.md](teams-troubleshooting.md) |

To open a hidden folder in Finder, use Cmd+Shift+G (Go to Folder) and
paste the path. Use `~` for your home folder.

## Trash

Open and review:

```sh
open ~/.Trash          # opens Trash in Finder
du -sh ~/.Trash        # size
ls -la ~/.Trash        # contents
```

Empty it:

```sh
osascript -e 'tell application "Finder" to empty trash'
```

Or in Finder: Cmd+Shift+Delete (asks for confirmation). Cmd+Option+Delete
deletes selected files without going through Trash, so use it only when sure.

## Caches (safe to clear)

Quit the app first, then delete its cache folder. Example for an app cache:

```sh
rm -rf ~/Library/Caches/<app-folder>
```

Replace `<app-folder>` with a name from the `du` list above.

Package manager caches, cleared with their own tools:

```sh
brew cleanup -s                 # old Homebrew versions and downloads
npm cache clean --force         # npm cache (about 5.7G seen here)
pnpm store prune                # pnpm store, removes unreferenced packages
uv cache prune                  # uv cache, keeps what is in use
composer clear-cache            # PHP Composer cache
go clean -cache                 # Go build cache (GOCACHE)
go clean -modcache              # Go module cache, re-downloads on next build
```

Check the path before a full wipe: `brew --cache`, `npm config get cache`,
`go env GOCACHE GOMODCACHE`.

## Developer tools

```sh
rm -rf ~/Library/Developer/Xcode/DerivedData       # Xcode build output
xcrun simctl delete unavailable                    # simulators whose runtime is gone
```

Xcode archives (`~/Library/Developer/Xcode/Archives`) and iOS device
support (`~/Library/Developer/Xcode/iOS DeviceSupport`) are kept on
purpose. Delete them only if you no longer need old builds or device symbols.

## Docker (Colima)

Docker data lives inside the Colima VM. Check first, then prune
selectively:

```sh
docker system df                   # totals and reclaimable space
docker container prune             # stopped containers
docker image prune                 # dangling (untagged) images
docker builder prune               # unused build cache
docker volume ls -f dangling=true  # unused volumes, review before pruning
docker volume prune                # removes unused volumes
```

Avoid `docker system prune -a --volumes` unless you want every unused image
and volume removed. Volumes can hold database data, so review them first.

## Large files and old downloads

```sh
find ~/Downloads -type f -size +100M -exec ls -lh {} +
find ~ -type f -size +1G 2>/dev/null
```

Move files to Trash by hand after you review them. Check that they are not
database dumps or project data you still need.

## Time Machine local snapshots

macOS keeps local snapshots that can take space on the system disk. Check
them in Storage settings. Deleting snapshots is rarely needed and is best
left to macOS, which removes them automatically when space is low.

```sh
tmutil listlocalsnapshots /
```

## Do not delete without a plan

- `~/Library/Application Support` (app data, sign-in state, local databases)
- `~/Library/Containers` and `~/Library/Group Containers` (except the
  cache folders named in the Teams guide)
- Keychains (`~/Library/Keychains`)
- Mail, Messages, Photos libraries, iCloud Drive folders
- Herd site data and MariaDB or MySQL data directories (live database files)
- Docker volumes that hold database data (`*_dbdata`, `*_mariadb`)

## After cleanup

```sh
df -h /     # confirm the free space
```

Restart apps you cleared so they rebuild their caches. Check that they still
open and sync.
