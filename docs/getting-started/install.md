# Install & maintenance guide

One place for: **install once unattended**, **keep it updated**, and **clean
up safely**. Targets macOS / Linux desktop / Linux CLI / WSL2, with explicit
NixOS handling.

- Stack & ownership: `docs/architecture/tool-ownership.md`
- App inventory (per OS): `docs/reference/app-catalog.md`
- NixOS specifics & failure modes: `docs/platforms/nixos/install.md`
- macOS setup and first-run status: `docs/platforms/macos/setup.md`
- Cold-start runbook (manual, step-by-step): `docs/getting-started/bootstrap.md`

## 0. "Am I all set?" — check in one command

```bash
sys-readiness        # or: bash ops/readiness.sh   or: mise run readiness
```

It verifies core tooling, all apps/CLI, dotfiles, git aliases, health checks,
and the NixOS system layer. The system-layer check reads the **live activated
system** (your actual login shell, `nix show-config` trusted-users, and the
`nix-gc`/`nix-optimise` systemd timers) — not a specific config file — so it is
accurate no matter whether settings live in `configuration.nix` or in the
`app-configs-extra.nix` module that `sys-setup` writes. Verdict + exit code:

- **`ALL SET`** (exit 0) — **you are fully set up; nothing else to run.**
- **`User environment READY, system rebuild pending`** (exit 2) — apps +
  dotfiles done; the NixOS system layer (fish login shell, trusted-users, GC
  timer, Europe/London time zone) is not active yet. Run
  **`sudo sys-setup --apply`** (below).
- **`User environment READY, N TODO item(s) left`** (exit 3) — nothing
  required is missing, but `[TODO]` lines remain (for example systemd or
  interop off on WSL2, an app not on PATH, dotfile drift). Fix each `[TODO]`
  line and run `sys-readiness` again.
- **`NOT READY`** (exit 1) — a required tool/file is missing; run `sys-install`.

Precedence: a missing item (exit 1) wins over a pending rebuild (exit 2),
which wins over TODO items (exit 3). The `mise run readiness` task reports
every non-zero exit as a failed task, which is intended: only exit 0 means done.

You are **done** exactly when `sys-readiness` prints `ALL SET` and exits 0.

### Do I need `nixos-rebuild switch`?

Yes, **once**, only for the NixOS **system** layer (fish as login shell,
trusted-users, declarative GC, Europe/London time zone) — Home Manager cannot set these. Everything else
(every app, CLI tool, dotfile) is already applied by `sys-install`/`sys-update`
without sudo. Automate the system step:

```bash
sudo sys-setup --apply      # or: sudo bash ops/system-setup.sh --apply
```

This idempotently writes `/etc/nixos/app-configs-extra.nix` (backing up your
config first), imports it, and runs `nixos-rebuild switch --flake /etc/nixos#nixos`.
It writes `time.timeZone = lib.mkForce "Europe/London";` so the shipped default
wins over the stock installer line in `/etc/nixos/configuration.nix` without
hand-editing that file.
Preview first without sudo: `sys-setup` (report only). After it finishes, open a
**new terminal** (you'll land in fish); reboot only if a kernel/driver changed.
Details: `docs/platforms/nixos/rebuild.md`.

### The complete "I'm set" sequence on a fresh machine

```bash
git clone <your-fork> ~/dotfiles && cd ~/dotfiles
bash ops/install.sh            # 1. apps + CLI + dotfiles (unattended, no sudo)
sudo bash ops/system-setup.sh --apply   # 2. system layer + nixos-rebuild (once)
exec fish                          # 3. (or open a new terminal)
sys-readiness                      # 4. confirm: should print ALL SET
```

Notes:
- Every step is **idempotent** — safe to re-run; it only changes what's not
  already in the desired state.
- After step 2 succeeds you'll see `nix-gc.timer` / `nix-optimise.timer`
  started and the `auto-optimise-store` warnings disappear (trusted-users took
  effect). That is expected and means the system layer is active.
- When step 4 prints `ALL SET`, **nothing else is needed.** Day-to-day you only
  run `sys-update` (keep current) and `sys-cleanup` (reclaim disk).
- A reboot is **not** required for this stack; it only matters if a later
  change touches the kernel, drivers, or bootloader.

## 1. Install — one command, walk away

```bash
git clone <your-fork> ~/dotfiles && cd ~/dotfiles
bash ops/install.sh
```

`ops/install.sh` is **unattended and idempotent**. The one exception is the
first run on a terminal with no stored selection, which asks what to install
(see "Choose what to install" below); without a terminal, or with
`--profile`, it never asks:

- Detects the host; on **NixOS** it uses the system Nix and **skips** the
  Determinate Systems installer (which would conflict).
- Installs base tools (`chezmoi`, `mise`, `home-manager`, `lefthook`) only if
  missing.
- Validates the flake, resolves the install selection (below), **snapshots
  `$HOME`**, then `chezmoi apply --force`.
- Runs `home-manager switch` (or `darwin-rebuild switch` on macOS).
- Runs `mise install`, installs the git hooks with
  `ops/install-git-hooks.sh` (then `--check`; see "Partial commits" below), the
  ssh-agent helper, and `doctor.sh` (must pass).
- Seeds `home/.chezmoidata/personal.yaml` from the example if absent (edit it
  afterwards for real name/email/host profile).

Preview without mutating anything:

```bash
bash ops/install.sh --dry-run                # or: DRY_RUN=1 bash ops/install.sh
HOST_PROFILE=linux-cli bash ops/install.sh   # pin the host profile
```

### Remember linux-desktop or linux-cli

On plain Linux the host is `linux-desktop` or `linux-cli`, and nothing in the
machine reliably says which. `ops/install.sh` therefore remembers it per
machine in `${XDG_CONFIG_HOME:-$HOME/.config}/app-configs/host` (an
`XDG_CONFIG_HOME` on a Windows drive, `/mnt/<letter>`, is ignored). The file
holds one line, exactly `linux-desktop` or `linux-cli`; nothing else is
allowed. It sits beside the `selection/` directory, is not a flake input and is
not managed by chezmoi. `bash ops/detect-host.sh --host-file` prints the path
and `--source` prints where the answer came from (`env`, `detected`, `file` or
`default`).

**Precedence**, first match wins: `HOST_PROFILE`, then macOS or WSL2 detection
(the file is never read there), then the host file (plain Linux only), then
`HOST_PROFILE_DEFAULT`, then `linux-desktop`. Every script (`sys-update`,
bootstrap, the `mise` sync tasks, `hms`, readiness, audit) asks
`ops/detect-host.sh`, so they all give the same answer. The file is exactly one
line (only trailing whitespace is allowed; a leading blank line, a second line
or a comment is invalid). An invalid file on plain Linux (empty, `wsl`, `macos`,
anything else) makes `detect-host.sh` exit 1 with a message that names the file,
the two accepted values and the fixes. `sys-update`, bootstrap, `sys-install`,
`hms`, the `sync:apply` task and the Codebase Memory updater stop and show that
message. Readiness and the `sync:dry-run` task hide detect-host's stderr and
report the host as `unknown`, and the audit shows an empty host; none of the
three changes anything.

```bash
bash ops/install.sh --host linux-cli    # write the file, never ask (also --host=linux-cli)
bash ops/install.sh --reconfigure       # ask the host again first (default: the current value), then the selection
```

With no file, `install.sh` asks once on a terminal, with a default taken from
whether a graphical session is running (`WAYLAND_DISPLAY`, `DISPLAY`,
`XDG_SESSION_TYPE`, or `systemctl get-default` printing `graphical.target`),
or, when no host file exists yet, a valid `HOST_PROFILE_DEFAULT` (it wins over
that check), and writes the answer. Without a terminal it asks nothing, writes nothing, never
blocks, and prints a hint to run `sys-install --host linux-cli`. `q` or end of
input at the question exits 1 before anything changes. `--dry-run` asks but
writes nothing and prints `dry run: would write <file> (<value>)`. `--host` is a
usage error (exit 2, nothing written) with a conflicting `HOST_PROFILE` or on a
detected macOS or WSL2 host. Bootstrap and `sys-update` never ask and never write
the file.

**Drift warning.** chezmoi renders from `home/.chezmoidata/personal.yaml`
(`hostProfile`, `gui`), not from the host file. When the host came from the host
file and `personal.yaml` disagrees, `install.sh`, `bootstrap.sh` and `sys-update`
(report and apply) warn before any `chezmoi apply`, showing the detected host,
the configured `hostProfile` and `gui`, and the fix: set `hostProfile: "<p>"` and
`gui: true|false` in `personal.yaml`, then run `chezmoi apply`. The warning only
reads those two keys and never edits `personal.yaml`.

Equivalent mise task:

```bash
mise run install
```

> Difference vs `ops/bootstrap.sh`: bootstrap defaults to a dry-run and
> prompts before applying. `install.sh` is the non-interactive, NixOS-aware
> "set and forget" path.

### Choose what to install (install selection)

Some tools are optional. A host can leave them out with a **local selection**
that names a profile and, if wanted, switches individual groups off. With no
selection, everything installs exactly as before: the committed profiles
turn every group on, and the build output is identical.

**Groups** (declared in `nix/modules/home/profile.nix`; core tools such as
fish, git, ripgrep and the tools `sys-update` needs are never in a group):

| Group | What it gates |
| --- | --- |
| `media` | ffmpeg, yt-dlp, imagemagick, viu |
| `security` | trivy, osv-scanner |
| `go` | the Go toolchain and Go tooling (go, gopls, golangci-lint, delve and the rest of the Go block in `nix/modules/home/dev.nix`) |
| `macInput` | macOS only: the `karabiner-elements` and `linearmouse` casks and their configs. It has no effect on Linux and WSL2, and the Linux prompt does not offer it. |

**Profiles** are `work` and `personal` (the values of `myConfig.profile`). Each
is a table of group toggles in `nix/profiles/work.toml` and
`nix/profiles/personal.toml`; both turn every group on. On `linux-desktop`,
`personal` also installs the personal-only apps (Vesktop, Telegram, Syncthing
helpers, OpenClaw); that set is empty on macOS, `linux-cli` and `wsl`. This selection profile is not the same thing as `HOST_PROFILE`
(`macos`, `linux-desktop`, `linux-cli`, `wsl`), which says what kind of machine
this is. The host default selection profile is `personal` on `linux-desktop`
and `work` everywhere else.

**The selection file** is per machine and never synced or committed:

```text
${XDG_CONFIG_HOME:-$HOME/.config}/app-configs/selection/selection.toml
```

```toml
profile = "work"      # required whenever [groups] is present

[groups]              # only the differences from the profile
media = false
go = false
```

The committed `nix/selection/selection.toml` is empty and means "no selection".
When your file exists the scripts pass it to Nix as
`--override-input selection path:<dir>`; `flake.lock` is not touched. The
directory comes from `XDG_CONFIG_HOME`, else `$HOME/.config`. On WSL2 an
`XDG_CONFIG_HOME` on a Windows drive mount (`/mnt/<letter>/...`) is ignored in
favour of `$HOME/.config`, with a note on stderr; any other location, and
`APP_CONFIGS_SELECTION_DIR` (a test and preview override), is honoured as given.

**Precedence**, first match wins: `--profile` flag, then the first-run prompt,
then your local file, then the committed profile default, then the host default
profile.

#### First run, and what you are asked

With no selection file, on a terminal, `sys-install` asks before it changes
anything beyond Nix and the base tools. It prints a **present-state table**
(for each group, how many of its packages are installed now; on a first
install, with no Home Manager generation yet, it also names any copy that is on
`PATH` but not from Home Manager; on macOS the casks a group gates are counted
against `brew list --cask`, or listed with "cask state unknown" when brew is
not available), asks for the profile (default: the
host's) and then each group (`[Y/n]` when the profile turns it on, `[y/N]`
when off), prints a **preview**, and offers `[a]pply [c]hange selection
[q]uit`:

- `a` writes only the differences from the profile defaults and continues;
- `c` asks again with your answers pre-filled;
- `q` (or end of input) stops with exit 1. It writes no selection and runs no
  `chezmoi apply` and no switch. It does not undo what earlier steps already
  did: Nix, the base tools and the seeded `personal.yaml` stay.

The preview is read-only (evaluation only, nothing is built). Its sections:

- **Outcome by group**: per group, what is kept, added or removed;
- **Packages, from your selection** and **Packages, pending changes (repo, or a
  selection not yet applied)**: the first lists only what your selection
  changes against what is installed, the second lists everything else the next
  switch would change, for example repo updates, or a selection you wrote
  earlier and have not applied yet;
- the same split for Home Manager files and services, plus a chezmoi file
  count (not a diff; `chezmoi diff` shows it);
- on macOS, **macOS casks**.

#### Flags and later runs

```bash
bash ops/install.sh --profile work     # write profile = "work", drop group overrides, preview, continue
bash ops/install.sh --reconfigure      # ask again, with the current values pre-selected (needs a terminal)
bash ops/install.sh --dry-run          # prompt and preview; write and apply nothing
```

- `--profile NAME` never asks, also on a terminal. It **replaces** any group
  overrides in your file (the preview says so) and continues. An unknown name
  exits 2 before anything runs.
- `--reconfigure` without a terminal exits 1 before any change.
- `--dry-run` never writes a selection; answering `a` prints what it would write.
- With a file already present, a plain run prints one line
  (`Selection: <path> (profile X)`), asks nothing and shows no preview, but
  still **validates** the file.
- With no file and no terminal, nothing is written and the committed default is
  used. The run never blocks.
- `sys-update`, `sys-install`, `hms` and `mise run sync:apply` all use the same
  stored selection, silently; none of them ever prompts.
- To see what the next `sys-update` would do with your selection, without
  applying anything, run `sys-update --selection-diff` (see below).

#### Invalid files

An unknown key, profile or group, `[groups]` without `profile`, or a group that
is not `true`/`false` fails Nix evaluation on every host (a module assertion
forces every group, so `macInput = "no"` fails on Linux too), and therefore
**before any change**: `install.sh` validates before `chezmoi apply` and the
switch, and `sys-update`, `hms` and `mise run sync:dry-run` fail at their build,
before anything is activated. `mise run sync:apply` runs its snapshot and
`chezmoi apply` first, so with an invalid selection it applies the dotfiles and
then fails at the build, before the switch. The Nix error names the key, for example
`unknown group 'bogus'`. Fix the file, or run `bash ops/install.sh --profile
work` to replace it. On macOS the chezmoi ignore rules also read the file, so
a file with broken TOML syntax makes `chezmoi` fail (the error names
`.chezmoiignore ... fromToml`) and `sys-update` stop with
`managed files: chezmoi status failed ...`; correct or remove the selection
file. A `macInput` key in a selection file on Linux has no effect, and a
reconfigure on Linux rewrites the file without it.

#### What removal does

- **Linux, WSL2 (Nix packages):** a deselected package leaves `PATH` at the next
  switch. Files in `$HOME` and application data stay.
- **macOS casks:** nothing is uninstalled. Homebrew cleanup is `none`, so a
  deselected cask stays installed, and the preview says so for each one:
  `stays installed (Homebrew cleanup = none); remove by hand: brew uninstall --cask <name>`.
  With `macInput` off, chezmoi stops deploying the Karabiner and LinearMouse
  configs but does not delete ones already in `~/.config`.
- **Personal to work on `linux-desktop`:** choosing `work` removes the personal
  apps (Vesktop, Telegram, Syncthing and its helper commands, OpenClaw and its
  gateway unit). The preview lists them under "personal apps".

#### See what the next update would change (`--selection-diff`)

```bash
sys-update --selection-diff            # read-only: what would the next --apply add, remove or change?
sys-update --selection-diff --json     # the same, as one JSON envelope on stdout
bash ops/update-all.sh --selection-diff
```

It compares the **declared** state (the committed profile with your local
selection applied, evaluated with `--no-write-lock-file`) with what is
**installed** (the Home Manager generation, `chezmoi status` and, on macOS,
`brew list --cask`). It is strictly read-only: it builds nothing, writes
nothing outside a temporary directory it removes, runs no pull, install or
cleanup, never takes, waits for or probes the update lock (so it works while an
update runs), and never recovers an interrupted run. Both `sys-update` wrappers
(the command and the fish function) add `--apply`; `--selection-diff` always
overrides it, in either argument order, so `sys-update --selection-diff` is a
diff, never an apply. `--yes`, `--no-pull` and `--verbose` are accepted and
ignored; `rollback`, `--force`, `--gc`, `--allow-dirty`, `--skip-verify`,
`--full-check` and `--no-cleanup` are usage errors with it, and `--json` is only
valid with it (exit 2).

The text output shows where the selection comes from (the file, the profile and
each group, as `local` or `profile`), the group totals, the packages, Home
Manager files and units, chezmoi files and casks, then the sections **REMOVE**
(first), **CONFLICT**, **ADD**, **CHANGE**, **MANUAL**, **UNSUPPORTED** and
**UNKNOWN**, each capped at 30 lines plus `and N more`, the limitations, and a
final `RESULT:` line. An item whose source could not be read is listed as
unknown, never as unchanged.

| Exit | Meaning |
| --- | --- |
| 0 | in sync |
| 1 | execution failure: nix missing, the declared state does not evaluate (the Nix error is on stderr), an internal error |
| 2 | invalid arguments |
| 10 | changes pending: any add, remove or change |
| 11 | action required: any conflict (a chezmoi target edited here and in the repo, `MM`), an incomplete assessment (a component that is `unknown` or `error`), an unfinished or failed last run |

Precedence is 1, then 11, then 10, then 0. Codes 3 to 5 keep their meaning from
the update itself. Homebrew casks that a deselected group leaves installed
(cleanup is `none`) are listed as manual (`remove by hand: brew uninstall --cask
<name>`) and do **not** count towards the exit code.

`--json` prints exactly one envelope on stdout (diagnostics go to stderr) with
a stable key order, entries sorted with `LC_ALL=C`, and changed items only;
unchanged items appear as counts:

```
{ "schema_version": 1, "command": "selection-diff", "check": true, "applied": false,
  "outcome": "in-sync|changes-pending|action-required", "exit_code": 0|10|11, "host": ...,
  "repo": {rev, dirty}, "selection": {file, sha256, profile, groups, sources},
  "applied_selection": null | {file, sha256}, "installed": {state, generation, generation_number},
  "record": {state}, "causes": {selection_changed, repo_changed, generation_changed_outside},
  "sources": {packages, hm_files, chezmoi, casks}, "counts": {add, remove, change, keep,
  conflict, manual, unsupported, unknown}, "entries": [...], "limitations": [...], "notes": [...] }
```

`repo.dirty` is `yes`, `no` or `unknown` (the same encoding as the record).
`complete` is true only when every requested check completed. `checks` has one
object per component (`packages`, `hm_files`, `chezmoi`, `casks`, `run`,
`record`) with a `status` and, when it helps, a structured `reason`, a fixed
`detail` and what is `required`:

- `in_sync`: compared and equal. `pending`: compared and different (a `reason`
  such as `no_generation` or `conflicts_present` may say why).
- `unknown`: missing information prevents the comparison (`machine_data_missing`,
  `machine_data_unreadable`, `chezmoi_missing`, `generation_unreadable`,
  `brew_missing`, `run_unfinished`, `record_absent`, `record_invalid`,
  `record_stale`).
- A Home Manager profile directory without a generation link is `pending` with
  reason `no_generation` (a first install); no profile directory at all is `unknown`
  with `generation_unreadable`. Conflicts make chezmoi `pending` with reason
  `conflicts_present`.
- `error`: the comparison failed unexpectedly (`chezmoi_failed` with a class such as
  `state_locked` or `template_error`, `brew_failed`, `last_run_failed`).
- `not_applicable`: casks off macOS.

Unknown is never reported as pending, in sync or an empty list, and one unknown
component does not erase the verified counts of the others. The `record` check
is a limitation (`"affects_exit": false`): it never changes `complete` or the exit
code. Example, a worktree without the machine-local data:

```
"complete": false,
"checks": {
  "packages": {"status": "in_sync"}, "hm_files": {"status": "in_sync"},
  "chezmoi": {"status": "unknown", "reason": "machine_data_missing", "required": ["home/.chezmoidata/personal.yaml"]},
  "casks": {"status": "not_applicable"}, "run": {"status": "in_sync"},
  "record": {"status": "unknown", "reason": "record_absent", "affects_exit": false} }
```

and the text output says it plainly: `chezmoi: unknown — machine-local data missing
(home/.chezmoidata/personal.yaml); 194 other items in sync; assessment incomplete`.

chezmoi needs the machine-local file `home/.chezmoidata/personal.yaml`, which is
gitignored and holds private values. One function decides whether it is there, by
testing that it exists and is readable only: the diff never opens, reads, hashes or
prints it, never creates a placeholder and never borrows another checkout's copy,
so a git worktree reports it missing (exit 11) and the real checkout can report 0.
If the file is present and `chezmoi status` still fails, the check is `error` with
a fixed class, never the raw message (which could quote private values).

`causes` has two real answers and one
placeholder: `selection_changed` and `repo_changed` are `yes`, `no` or `unknown`
(`unknown` whenever the record is not ok, a hash or revision is unknown, or the
tree is dirty on both sides, since the uncommitted content may differ;
`repo_changed` is `no` only for a clean tree at the same revision on both sides).
`generation_changed_outside` is `no` whenever the record is ok (an ok record is
by definition for the current generation) and `unknown` otherwise; it is kept so
the shape does not change when a better answer exists.

On an early failure (exit 1) `--json` prints a minimal envelope instead of the
full one: `schema_version`, `command`, `check`, `applied` (false), `outcome`
(`failed`), `exit_code` (1) and `error`. Usage errors (exit 2) print nothing on
stdout.

Consumers should key on each entry's `operation`, and on `exit_code` and
`outcome`, not on entry names or on the counts alone: `counts.manual` mixes the
casks a deselected group leaves behind (not counted in the exit code) with an
unfinished or failed last run (which is), and an unknown source is an entry named
`(all)`. The evaluations take about half a
minute on a desktop host (measured at roughly 27 s: 19 s for the group members,
8 s for the current state).

**The applied-state record.** After a successful `sys-update --apply` (after
the verification and the commit phase) and after a successful `sys-install`
switch (never on a dry run), the machine writes
`${XDG_STATE_HOME:-~/.local/state}/app-configs/installed.meta` (override the
directory with `APP_CONFIGS_STATE_DIR`): eleven `key=value` lines holding the
writer, the time, the run id, the host, the generation, the repo revision and
whether `nix` and `home` were dirty (`yes`, `no` or `unknown`), and the **sha256** of the selection file
(never its content). It is machine-local state and is never committed; the write
is atomic and a failed write only warns. `--selection-diff` reads it to say
*why* something is pending (the selection changed, the repo changed). When the
record is absent, invalid or stale (the profile moved since), the causes are
reported as `unknown`, not as "no", and the diff still works.

Not covered here: native Windows, and tools that mise installs.

### What the next install looks like (timeline)

On a **fresh machine**, one command does it all and you can walk away:

```bash
git clone <your-fork> ~/dotfiles && cd ~/dotfiles && bash ops/install.sh
```

Expected wall-clock time (most of it is unattended download from the binary
cache — the closure is ~7.7 GiB / ~300 binaries):

| Phase | What happens | Typical time |
| --- | --- | --- |
| Nix present (NixOS) or install (other) | skipped on NixOS; ~2–4 min via Determinate elsewhere | 0–4 min |
| Base tools (`nix profile install`) | chezmoi/mise/home-manager/lefthook | 1–3 min |
| `nix flake check` | evaluate the flake | 10–60 s |
| `chezmoi apply` | snapshot + write ~37 dotfiles | < 30 s |
| `home-manager switch` | **fetch ~7.7 GiB closure from cache.nixos.org** + activate | **10–30 min** (network-bound) |
| `mise install` | no-op on NixOS (runtimes from Nix) | < 10 s |
| `lefthook` + ssh-agent + `doctor` | hooks + health check | < 30 s |
| **Total (warm cache, good network)** | | **~15–35 min, unattended** |

A **re-run on the same machine** (warm `/nix/store`) is mostly cache hits and
finishes in **1–3 minutes**.

### Is it truly "one click, walk away"?

Yes for the **user environment** — `ops/install.sh` needs no prompts once a
selection exists (or with `--profile`, or without a terminal). On Linux
and WSL it runs no `sudo` itself, though the Nix installer may ask for it on a
fresh non-NixOS host; macOS needs `sudo` for the nix-darwin switch and checks it
before changing anything. The **only** manual step that needs you is the
optional **system** rebuild, because it requires `sudo` and edits `/etc/nixos`.
On NixOS the installer **detects** whether that is needed by checking the live
system for the fish login shell, an active `nix-gc.timer` (`nix-optimise.timer`
alone does not count) and the Europe/London time zone, and prints the command
to run at the end: `sudo bash <repo>/ops/system-setup.sh --apply` (alias
`sudo sys-setup --apply`), which writes `/etc/nixos/app-configs-extra.nix` and
runs `nixos-rebuild`. It does not check or recommend `trusted-users`.

The last line tells you how it went: `Install complete` only when every step
succeeded; otherwise `finished with degraded steps` and one `degraded:` line per
step (VS Code extensions, Syncthing, ssh-agent, a pending system rebuild) with
the command to re-run. Degraded steps still exit 0; a failed required step exits
non-zero with an `[install:error]` line. See `docs/platforms/nixos/rebuild.md`.

### Complete-the-build steps (run after install on NixOS)

1. `bash ops/install.sh` — finishes the user environment (no sudo). ✅ done.
2. **(recommended)** add the snippet from `docs/platforms/nixos/rebuild.md` to
   `/etc/nixos/configuration.nix`, then:
   ```bash
   sudo nixos-rebuild switch --flake /etc/nixos#nixos     # or: nh os switch /etc/nixos
   ```
3. **Reboot only if** a kernel/driver/bootloader changed; otherwise just open a
   new terminal (you'll land in fish).
4. **Confirm readiness:**
   ```bash
   nixos-rebuild list-generations | head     # new generation is Current
   systemctl --failed ; systemctl --user --failed
   bash ops/doctor.sh ; chezmoi verify
   ```

## 2. Keep it updated — the `brewup` equivalent

On macOS you ran a `brewup` function (update + upgrade + cleanup). The
cross-platform equivalent here:

```bash
mise run update            # report only: shows the full plan, mutates nothing
mise run update:apply      # apply unattended (brewup equivalent)
```

`ops/update-all.sh` runs as a transaction. **Nothing is mutated until every
precondition passes**, and each phase reports one line instead of raw output:

| Phase | What it does |
| --- | --- |
| `PRECHECK` | canonical repo path, git worktree + upstream, required tools, free disk |
| `PULL` | `git pull --ff-only`; when it brings new commits the run restarts in the updated `update-all.sh` (same lock, run id and log) before anything is configured |
| `SNAPSHOT` | `$HOME` dotfiles, `flake.lock`, current Home Manager generation (pinned by a GC root), mise versions |
| `PREPARE` | `nix flake update` + `check` · host build; a failure restores `flake.lock` |
| `ACTIVATE` | `chezmoi apply` · `home-manager switch` / `darwin-rebuild switch`; the profile must then point at the built closure (never skipped) |
| `VERIFY` | gate: Brave runs and is the default browser (`--skip-verify` skips it) |
| `COMMIT` | the new `flake.lock` is committed only after a verified activation; just before it, `ops/install-git-hooks.sh` (+ `--check`) installs the git hooks so the commit is guarded |
| `MAINTAIN` | `nix profile upgrade` · `mise upgrade` · Syncthing ignores (warnings only) |
| `CHECKS` | advisory: no chezmoi drift, core commands on `PATH`, no failed user units, no missing mise tools |
| `CLEANUP` | safe, non-destructive (section 3 below) unless `NO_CLEANUP=1` |
| `SUMMARY` | package delta, warnings worth acting on, rollback handle, log path |

A **dirty worktree aborts the run** before anything changes: updating on top of
local edits mixes your changes, upstream commits and a new lock into one
conflict. Commit, save the change as a patch (never `git stash`), or pass `--allow-dirty` to accept that deliberately.
Once the update has built, activated and been verified, the new `flake.lock` is
committed on its own (`chore(nix): update flake inputs`), so the next run starts
clean. With `--skip-verify` the commit body says it was not runtime-verified.
A lock that already had local edits before the run, or one something else
changed while the update ran, is left for you to commit. If verification
fails, the lock stays uncommitted and the run prints both ways out:
`sys-update rollback`, or the `git commit --only` command that keeps it. A
failed or interrupted run before activation restores the lock it wrote (unless
it was edited meanwhile). A failure while activating restores the lock too, but
the profile may already have moved to the new generation: the run then names
`sys-update rollback`, which you need to get back to the previous generation.
Only one update or rollback runs at a time; a second
one exits 5.

Command output goes to a per-run log under
`~/.local/state/sys-update/runs/<timestamp>.log`; the terminal only shows raw
text when a step fails or you pass `--verbose`.

```bash
sys-update                             # apply, with one confirmation prompt
bash ops/update-all.sh                 # report only: the full plan, no mutation
bash ops/update-all.sh --apply --yes   # no prompt (cron/unattended)
bash ops/update-all.sh --apply --allow-dirty   # update with local changes
bash ops/update-all.sh --apply --verbose       # mirror raw output too
NO_CLEANUP=1 bash ops/update-all.sh --apply
```

Useful flags: `--full-check` (`nix flake check --all-systems`, every platform
rather than this host), `--force` (`chezmoi apply --force`, overwrite local
edits to managed files), `--no-pull`, `--skip-verify`, `--gc` (also reclaim
generations older than `KEEP_DAYS`).

### What the package summary reports

Only **top-level** packages — the ones you asked for — compared before and
after, per manager:

```text
Home Manager
  ↑ 12 upgraded   + 2 added   - 1 removed   (143 unchanged)

  REMOVED
    claude-code             2.1.263
  UPGRADED
    firefox                 155.0.1 → 156.0
```

Removals are listed first, because an unexpected disappearance matters more
than a routine patch bump. Dependency/closure churn is deliberately *not*
reported: it is noise in an answer to "what happened to my tools?".

Package ownership is one-way, so nothing is managed twice:

| Layer | Owns |
| --- | --- |
| Home Manager | applications and CLI packages declared in `nix/` |
| `nix profile` | only the bootstrap tools installed from a flake by hand (`chezmoi`, `mise`, `lefthook`, …) |
| mise | language runtimes and npm-only CLIs |

`nix profile upgrade` is given the exact element names it owns, so
`home-manager-path` — which Home Manager installs — is never asked to upgrade
itself.

### Undo an update

Every applied run records a rollback handle (Home Manager generation, pinned by
a GC root so garbage collection cannot remove it; `flake.lock` backup; dotfiles
snapshot) and the phase it reached:

```bash
sys-update rollback          # switch the profile back to the previous generation + restore the lock
```

Rollback takes the same lock as an update, checks that the profile really is on
the previous generation afterwards, and restores `flake.lock` only while it
still holds what the update wrote. If the update had already been committed it
prints the `git commit --only` / `git checkout HEAD --` choices. A run that
stopped before activation has nothing to roll back. On macOS the files are
restored and the system switch is manual. If cleanup collected the previous
generation the update warns and records `rollback_handle=lost`.

The dotfiles snapshot is *shown*, not auto-restored — the command prints the
exact `cp -a <snapshot>/. ~/` to run if you want it back.

## 3. Clean up safely (non-destructive by default)

`ops/cleanup.sh` reclaims disk **without destroying rollbacks**.

```bash
mise run cleanup           # report only (shows the plan + generation count)
mise run cleanup:apply     # SAFE tier: store optimise + cache prune; keeps ALL generations
mise run cleanup:gc        # SAFE + remove generations older than KEEP_DAYS (default 14d)
```

- **SAFE tier** (`--apply`): `nix store optimise` (hard-links identical files —
  never deletes references), `mise cache prune`, `npm cache verify`. Verified
  to free multiple GiB while keeping every Home Manager generation.
- **AGED tier** (`--apply --gc`): `home-manager expire-generations` +
  `nix-collect-garbage --delete-older-than ${KEEP_DAYS}d`. This removes only
  generations **older than** the window, so recent rollbacks survive.

```bash
KEEP_DAYS=30 bash ops/cleanup.sh --apply --gc
```

This script **never** runs `nix-collect-garbage -d` (delete all old
generations) — that would wipe every rollback point. Run that yourself only if
you are certain.

### Declarative GC (already configured)

`nix/modules/common/nix-settings.nix` declares scheduled GC
(`nix.gc`, weekly, `--delete-older-than 14d`, matching `KEEP_DAYS` in
`ops/cleanup.sh`) as a systemd user timer on Linux. It deletes this user's
old generations, then every unreachable store path, so it overlaps the NixOS
system timer where one exists. On macOS GC belongs to Determinate Nix, so
Home Manager sets no GC there. Home Manager does not write
`auto-optimise-store` by default. Nothing in this repo sets it system-wide
either; on NixOS `ops/system-setup.sh` adds `nix.optimise.automatic = true`
(a periodic deduplication timer, a different mechanism), and on other hosts
neither is set unless you configure `/etc/nix/nix.conf` yourself.
`ops/cleanup.sh` gives you an explicit, on-demand path
regardless. To run GC declaratively at the system level on NixOS, add to
`/etc/nixos/configuration.nix`:

```nix
nix.gc = { automatic = true; dates = "weekly"; options = "--delete-older-than 14d"; };
nix.optimise.automatic = true;
nix.settings.trusted-users = [ "root" "utmostcreator" ];  # silences the
                                                          # auto-optimise warning
```

then `sudo nixos-rebuild switch`.

## 4. Verify

```bash
mise run repo:check        # git diff --check + doctor + validate + flake check
bash ops/doctor.sh
chezmoi verify             # all managed dotfiles match (exit 0)
```

## 5. Maintaining the Nix config (best practices)

This repo ships a small Nix maintenance toolchain (in
`nix/modules/home/dev.nix`):

```bash
mise run nix:fmt           # nixfmt (RFC 166 style) — format all .nix files
mise run nix:lint          # statix + deadnix + nixfmt --check (advisory)
nix-locate <file>          # which package provides a missing command/file
nh os switch ./nix         # friendlier home-manager/nixos-rebuild + GC wrapper
```

Discipline that keeps the config maintainable (per Nix community guidance):

- Keep `flake.lock` committed; update it deliberately via `mise run update`.
- Keep modules small and split by concern (`modules/home/{cli,dev,gui,shell}`,
  `modules/common`, `modules/darwin`); avoid one giant file.
- System packages → `configuration.nix` (system); user packages/dotfiles →
  Home Manager; project runtimes → flake dev shells / mise.
- Prefer the **stable** nixpkgs channel for the OS; pull specific newer
  packages via an overlay/input rather than moving everything to unstable.
- Learn rollback before you need it: `home-manager generations`,
  `sudo nixos-rebuild switch --rollback`.

## 6. Uninstall / handoff

```bash
bash ops/uninstall.sh             # report only (safe any time)
bash ops/uninstall.sh --apply     # actually run
```

`--apply` unsets `core.hooksPath` (only when it is the installed hooks
directory), deletes `<git-common-dir>/app-configs-hooks`, and removes
lefthook-generated hooks. It never runs `lefthook uninstall`.

Never removes Nix itself and never deletes snapshots under
`~/.local/state/dotfiles-snapshots/`.

## Partial commits and the git hooks

The git hooks are tracked dispatchers (`ops/githooks/`), installed by
`bash ops/install-git-hooks.sh` into `<git-common-dir>/app-configs-hooks`
(an absolute `core.hooksPath`, shared by every worktree). They run before
lefthook and refuse a commit when:

- any `LEFTHOOK*` variable is set (other than `LEFTHOOK_VERBOSE`,
  `LEFTHOOK_QUIET`, or `LEFTHOOK_CONFIG` already pointing at this checkout's
  `.lefthook.yml`), or `SKIP_HOOKS` is set;
- a `lefthook-local.*` or `.lefthook-local.*` file exists at the top or in
  `.config/`;
- `.lefthook.yml` is missing or `lefthook` is not on `PATH`;
- a staged path also has unstaged changes. Lefthook may stash the unstaged
  part (some versions, or jobs with `stage_fixed`), and `git stash` is shared
  by every worktree (AGENTS.md forbids it). The refusal changes nothing.

The installer copies the dispatchers from the committed `HEAD`, so an
uncommitted edit is not installed. Check the install any time with
`bash ops/install-git-hooks.sh --check`; `ops/doctor.sh` and
`ops/readiness.sh` run it too. Re-run the installer from the **main
worktree** after pulling changes to `ops/githooks/`.

**Migration (once per clone):** after this lands, run
`bash ops/install-git-hooks.sh` in each clone's MAIN worktree (linked
worktrees are refused; they share the result). Until then `ops/doctor.sh`
warns and `ops/readiness.sh` shows `[MISS]`. `sys-update` runs the installer
itself before it commits.

To commit only part of a file without a stash (your own changes only; never
touch another session's work):

```bash
d="$(mktemp -d)"                                  # a private directory
git diff -- <path> > "$d/unstaged.patch"          # 1. save the unstaged part
git restore --worktree -- <path>                  # 2. worktree = staged version
git commit                                        # 3. commit what is staged
git apply "$d/unstaged.patch"                     # 4. bring the rest back
```

If the commit is refused or fails (step 3), re-apply the patch right away
(`git apply "$d/unstaged.patch"`) so the unstaged part is not lost.

Rules: never run `lefthook install --force`, never run `lefthook run
pre-commit` by hand (it may stash), commit with `git commit`. After moving or
copying a clone, run the installer from its main worktree: a `core.hooksPath`
that ends in `/app-configs-hooks` but whose directory is gone is treated as
ours and repaired; a copy that still points at the original clone's live
directory is refused as foreign, so unset it first
(`git config --local --unset core.hooksPath`).

## Short commands (installed to PATH + fish)

After install, these are on `PATH` (`~/.local/bin`) and as fish functions, so
you can run them from any directory / any shell. They manage **installed
applications + CLI tools + dotfiles**, not just dotfiles:

| Command (PATH) | fish function | Does |
| --- | --- | --- |
| `sys-install` | `sys-install` | Re-run the unattended full install (Nix base + all apps/CLI via home-manager + dotfiles + git hooks). Runs `home-manager switch`, so it APPLIES user-layer config like keybindings/layouts. |
| `sys-update` | `sys-update` | Update all apps/CLI + config (brewup equivalent) + safe cleanup. Also runs `home-manager switch`, so it APPLIES user-layer config changes. |
| `sys-cleanup` | `sys-cleanup` | De-dup Nix store + prune caches (keeps all rollbacks) |
| `sys-cleanup --gc` | `sys-cleanup-gc` | + remove aged generations (keeps recent) |
| `sudo sys-setup --apply` | — | Apply the NixOS SYSTEM layer Home Manager cannot: fish login shell, trusted-users, declarative GC, timezone, then `nixos-rebuild switch`. Run WITHOUT `--apply` (no sudo) for a report-only preview. Does NOT touch user-layer config. |
| — | `sys-doctor` / `syscd` | Health check / cd into the repo |
| `sys-readiness` | `sys-readiness` | Report whether the system layer is active (login shell, trusted-users, GC timers) |

### Which command applies what (important)

- **User layer** (keybindings, keyboard layouts, GNOME extensions, app packages,
  dotfiles): owned by **Home Manager + chezmoi**. Applied by **`sys-install`** or
  **`sys-update`** (both run `home-manager switch` + `chezmoi apply`). A change to a
  `nix/modules/home/*.nix` file is NOT live until one of these runs.
- **System layer** (fish as login shell, `nix.settings.trusted-users`, GC timers,
  timezone): owned by **`sudo sys-setup --apply`** (`nixos-rebuild`). This is a
  separate, root-only layer and does NOT apply user-layer keybinding/layout changes.

### Preferred order

First-time or after pulling repo changes:

```
sys-install                 # or: sys-update   (applies user layer: apps, dotfiles, keybindings, layout)
sudo sys-setup --apply      # only if the system layer changed (login shell / trusted-users / GC / timezone)
sys-cleanup                 # optional: reclaim disk, keeps all rollbacks
```

Routine maintenance (the usual loop):

```
sys-update                  # update + apply everything in the user layer, then safe cleanup
sys-cleanup --gc            # occasional deeper reclaim (removes aged generations, keeps recent)
```

Notes:

- `sys-setup` is only needed when the **system layer** changed. Day-to-day app/dotfile/keybinding
  work needs only `sys-install` / `sys-update`.
- `sys-update` already runs a safe cleanup at the end, so a separate `sys-cleanup` is only for
  extra disk reclaim.
- After a change that adds/enables a **GNOME extension** or changes the **keyboard layout**, log
  out and back in (GNOME Shell on Wayland cannot hot-reload extensions or fully reset input-source
  runtime state).

## Quick reference

| Goal | Command |
| --- | --- |
| Install everything, unattended | `sys-install` · `mise run install` · `bash ops/install.sh` |
| Preview install | `bash ops/install.sh --dry-run` · `DRY_RUN=1 bash ops/install.sh` |
| Choose what to install | `bash ops/install.sh --reconfigure` · `bash ops/install.sh --profile work` |
| Update everything (brewup) | `sys-update` · `mise run update:apply` |
| Safe cleanup (keep rollbacks) | `sys-cleanup` · `mise run cleanup:apply` |
| Reclaim aged generations | `sys-cleanup --gc` · `mise run cleanup:gc` |
| Format / lint Nix | `mise run nix:fmt` · `mise run nix:lint` |
| Health check | `sys-doctor` · `mise run repo:check` |
| Make fish the login shell (NixOS) | see `docs/platforms/nixos/install.md` |
