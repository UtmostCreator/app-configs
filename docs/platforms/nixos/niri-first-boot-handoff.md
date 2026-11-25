# Kingston installation handoff

Use this checklist with the [step-by-step external Kingston installation](kingston-install-walkthrough.md), the [installation runbook](niri-install.md), and the [trial ticket](../../work/active/T-0032-niri-trial-session/ticket.md). Prepare the Kingston from the verified live USB on the destination laptop or an isolated UEFI helper. Verify the destination hardware first and use a clean deployment commit and its matching artifacts. Keep the attached-disk route on the running daily PC closed until its disk guards pass.

## What happens at login

1. Unlock the encrypted disk and sign in at **tuigreet**. Integrated Home Manager provisions the work folders and private SSH directory as part of system activation. The ordinary user's timer starts the local setup about 30 seconds after their user manager starts.
2. Open **Documents → app-configs-setup → Latest → Summary.txt**. Open **Details.log** alongside it for step results, exit codes on failure and individual health checks. For installations made with the maintained helper, the detail log also includes installer stage start times, elapsed time and the account/loader verification milestone. The last stage starts before unmounting. Each login attempt has its own private directory. The original installer copy and disk-preparation logs are available with `sudo ls -lt /var/log/app-configs/`. They may contain device identities and remain private.
3. A healthy storage check permits the runner to recover a missing checkout from the recorded offline bundle. It keeps an existing checkout and local edits. It adds missing Chezmoi, Mise and Lefthook from the pinned local Nix store to the user's bootstrap profile. It seeds the canonical Bash startup and Bash/Fish SSH client loaders only where those files are absent. Open a **new terminal** to use the shell configuration. Fish, Atuin, Starship, PHP/Composer, Node/pnpm, Python/uv and the selected Go group come from the integrated home. `DEV_ROOT`, `SCRATCH_ROOT` and `ARCHIVE_ROOT` name the work folders.
4. Connect to your chosen Wi-Fi and enrol your assistant accounts and SSH identity when you need them. Keychain handles client agent setup in the interactive shell. Keep existing keys, passphrases and local shell customisations. To check the agent locally, `ssh-add -l` reports its status. A new account can legitimately have no identities. Pair Bluetooth, test sound, suspend and verify your backup restore with your own devices. Select any desired display mode in your own session.
5. To repeat the automatic steps after correcting a failure, run the following in Ghostty as your ordinary user. Look for `RESULT  Automatic steps passed`. Offline operation skips external probes. If no report appeared, the user journal shows early failures including the storage gate. On `emergency_ro`, follow the storage rescue instructions below.

```bash
systemctl --user start app-configs-first-login.service
systemctl --user status app-configs-first-login.service --no-pager
cat ~/Documents/app-configs-setup/Latest/Summary.txt
journalctl --user -u app-configs-first-login.service -b --no-pager -n 30
```

To request DNS and HTTPS tests and read the individual statuses as JSON, run the packaged verifier as your ordinary user:

```bash
app-configs-verify-first-boot --json --online --current-profile \
  "$(cat /var/lib/app-configs/install-revision)"
```

For a suspected damaged checkout, run `git -C ~/Projects/app-configs fsck --full` on demand. To inspect user activation, run `systemctl status "home-manager-$USER.service" --no-pager`. Audio routing (`wpctl status`), actual sound, Bluetooth pairing and suspend require their own session tests.

If checkout recovery fails, compare `cat /var/lib/app-configs/install-revision` with `git bundle list-heads /var/lib/app-configs/install.bundle` and inspect `git -C ~/Projects/app-configs status --short --branch`. If a bootstrap tool is missing, check `nix profile list` and `type -a chezmoi mise lefthook` in a fresh terminal. For an existing custom Bash startup file, source `~/.config/app-configs/ssh-agent.sh` from the interactive shell to opt into the client agent.

A login or interrupted setup can be repeated without another reboot. User configuration, credential enrolment and evidence of successful authentication remain separate. Automatic setup uses the local install receipt and leaves boot entry, driver, firmware and external drives under operator control.

## Adopt this profile on an existing Niri installation

A laptop already reporting a healthy root and a working NVIDIA-backed Niri session can keep running that generation. Its older installed software will gain the timer and commands when a reviewed revision containing this change is staged and booted. First obtain that clean revision through the project's usual release process. On the installed laptop, open **Super+T** and start Bash for these commands.

```bash
cd ~/Projects/app-configs
git status --short --branch
readlink -f /run/booted-system
sudo bootctl list
```

The physical November kit records commit `26f3bbdc116a474d175d2d8c2ff09145cf64e889`. After the co-author trailer cleanup its published equivalent is `000f889360c327bb65615cee3948f250141ba8b2`. Both commits have the same repository tree. Keep the original installation receipt and bundle for exact recovery. To adopt the new history from that kit, first confirm `origin` is the project remote, then run the following from the original checkout. This retains your old local branch and stops for a dirty tree or unexpected ancestry.

```bash
(
  set -eu
  test -z "$(git status --porcelain)"
  original=26f3bbdc116a474d175d2d8c2ff09145cf64e889
  equivalent=000f889360c327bb65615cee3948f250141ba8b2
  test "$(git rev-parse HEAD)" = "$original"
  git fetch origin main
  test "$(git rev-parse "$original^{tree}")" = "$(git rev-parse "$equivalent^{tree}")"
  git merge-base --is-ancestor "$equivalent" origin/main
  git log -1 --oneline origin/main
)
```

After reviewing the fetched commit, select it with `git switch --detach origin/main`. If your branch contains additional local commits, review them separately before changing checkouts.

Start with the desired working boot entry both selected and default. With the reviewed change checked out and a clean tree, build it without activation. Run the newly built command by absolute path on the older deployment. This checks storage again, matches the selected variant, preserves a known working entry and records the rollback generation number.

```bash
(
  set -eu
  test -z "$(git status --porcelain)"
  candidate=$(nix build --max-jobs 1 --cores 2 --no-update-lock-file \
    --no-link --print-out-paths ./nix#nixosConfigurations.linux-niri.config.system.build.toplevel)
  PATH="$candidate/sw/bin:$PATH" "$candidate/sw/bin/sys-update" --apply
)
```

After staging succeeds, inspect `sudo bootctl list`, save your work and reboot **once** when ready. Unlock LUKS and log in. On subsequent updates, `sys-update` shows the checkout and generations. `sys-update --apply` stages the reviewed local revision for next boot. `sys-install` builds the integrated host, `sys-readiness` checks the booted generation, and `sys-cleanup` previews cache maintenance. The NixOS system owns both assistant binaries. Their versions follow the reviewed system revision. A change to protected disk state or credentials needs a separate decision.

On a restored home, the shared Home Manager MIME activation first preserves independent source files under `${XDG_STATE_HOME:-$HOME/.local/state}/home-manager/mimeapps-backups/`. The visible XDG configuration takes precedence over legacy data, followed by the existing mutable state. The declared Brave and Code defaults apply last. Unrecognised external links or unreadable files require review before activation can replace them.

For rollback, hold **Space** at systemd-boot and choose the previous working generation with the same graphics variant. From a working session, `sys-update rollback N` selects retained generation number `N` for the next boot only. On recovery, confirm `readlink -f /run/booted-system` and run the first-boot checks before selecting a persistent default.

## Choose a display mode for this session

The shared Niri configuration lets each display advertise its preferred mode. In Ghostty, run `niri msg outputs` and find the connector and supported mode for the monitor in front of you. To try a different mode, open Bash and run:

```bash
read -rp 'Output name from niri msg outputs: ' output
read -rp 'Advertised WIDTHxHEIGHT@RATE, or auto: ' mode
niri msg output "$output" mode "$mode"
niri msg outputs
```

Check **Current mode** after the change. To return to automatic selection, use `niri msg output "$output" mode auto`. A temporary mode requires no reboot. Leave refresh rate, scaling, layout and VRR as per-user choices.

## Verify a disk after moving it

New installations record the selected whole-disk identity under `/var/lib/app-configs/install-disk-id`. The guided installer prefers the drive's WWN link when the enclosure exposes it. The verifier compares the recorded link with the mounted root's backing disk. Older installations report a missing identity as unknown. A USB bridge may identify the enclosure; moving the same SSD to another port or controller can change the link. On mismatch, inspect the disk label, serial, WWN and the complete root/EFI topology on the destination. Reconcile the receipt only after independently identifying the original drive. Keep identifiers out of Git and shared reports.

## Prepare the offline checkout

On the build PC, create a Git bundle from the clean, reviewed deployment checkout. Use the same commit that produced the installation artifacts. Transfer the bundle and its digest on the preparation medium and verify the digest before using it. A Git bundle carries committed repository history. Leave local settings, credentials, and untracked files on the source machine.

```bash
test -z "$(git status --porcelain)" &&
  test "$(git rev-parse HEAD)" = "${INSTALL_REV:?supply the reviewed commit}" &&
  git bundle create "${KIT:?supply the preparation directory}/app-configs.bundle" HEAD &&
  git bundle verify "$KIT/app-configs.bundle" &&
  sha256sum "$KIT/app-configs.bundle"
```

## Check an existing installation

Use the installed user's ordinary TTY or terminal. Read the **base** system path and the full commit from the installation receipt. The checker also recognises that base generation’s NVIDIA specialisation. When checking an older deployment, run the verifier from the reviewed newer copy and leave the installed checkout at its recorded revision.

```bash
read -rp 'Recorded base system store path: ' ACCEPTED_SYSTEM
read -rp 'Full deployment commit: ' INSTALL_REV
bash ops/niri/verify-first-boot.sh "$ACCEPTED_SYSTEM" "$INSTALL_REV"
```

A read-only root, the exact option `emergency_ro` even alongside `rw`, or a nonzero mounted-root EXT4 error counter fails this check. Missing evidence returns a nonzero result. If the root is in emergency mode, stop update and installation writes. From the live USB, identify the physical backing disk and inspect the unmounted, decrypted EXT4 device. An offline read-only check uses `e2fsck -fn` on the verified **unmounted mapper**. Preserve its output and exit status before deciding on repairs. The November incident already has a post-repair read-only check. [Physical incident record](../../work/active/T-0032-niri-trial-session/physical-install-2026-11-24.md)

For an incident on another boot, select its boot ID from `sudo journalctl --list-boots`. Examine a bounded, storage-specific kernel excerpt locally. A missing boot or an empty filter leaves the cause unknown. Keep the host identifiers and raw output in the private incident record. Verify system and user unit status separately with `systemctl --failed --no-pager` and `systemctl --user --failed --no-pager`. Journal verification, SMART and offline filesystem checks are separate diagnostic operations. For the extended SMART test, verify the Kingston whole-disk by-ID path, use the duration reported for **the long test**, then read its self-test log. Preserve any already quarantined journal.

For a local review of a selected boot:

```bash
sudo journalctl --list-boots
read -rp 'Boot ID for the incident: ' boot_id
sudo journalctl -k -b "$boot_id" --no-pager -n 80 \
  --grep='EXT4-fs (error|warning)|JBD2|I/O error|emergency_ro|Aborting journal|resetting link|uas_eh'
```

Run `sudo journalctl --verify` separately when journal integrity is in question. Preserve a failing file and its verification result. Verify its full path and whether journald is actively using it before any manual quarantine. Keep quarantined material in a root-owned private location. A successful check of the remaining files covers only those files.

For missing commands, check the environment where the error occurred. Run `type -a nmcli ping nmtui codex claude` in the affected shell. The retained installer and base installed system both expose these commands. The installed system gets Codex and Claude Code through the reviewed Nix lock. To update them, follow the generation build and boot procedure in the [installation runbook](niri-install.md); retain the previous working generation and NVIDIA selection for rollback. To check for local overrides, inspect `type -a codex claude` and `systemctl --user list-timers --all codex-auto-update.timer claude-auto-update.timer` in the installed account. The standalone CLI update timers apply to other profiles. [ADR-0006](../../architecture/decisions/0006-ai-clis-claude-code-and-codex.md)

## Keep a private installation log

In the live environment, create a private temporary log before Disko. Record the deployment commit, ISO and bundle digests, expected system path, and the outcome of disk checks. Record the exit status of each step and capture output from noninteractive checks and the system copy. Keep encryption, password enrolment, and account sign-in outside the logger. Use no terminal transcript or shell tracing. Keep the raw log private and review it before sharing excerpts.

```bash
install_log_dir=$(mktemp -d)
install_log="$install_log_dir/install.log"
(umask 077; : > "$install_log")

log_install_step() {
  local label=$1 record_rc=0
  local -a result
  shift
  printf '%s  START  %s\n' "$(date -u +%FT%TZ)" "$label" >> "$install_log" || return 1
  if "$@" 2>&1 | tee -a "$install_log"; then
    result=( "${PIPESTATUS[@]}" )
  else
    result=( "${PIPESTATUS[@]}" )
  fi
  printf '%s  %s  command_exit=%s logger_exit=%s\n' "$(date -u +%FT%TZ)" "$label" "${result[@]}" >> "$install_log" ||
    { printf 'Could not save step status.\n' >&2; record_rc=1; }
  if (( result[0] != 0 )); then return "${result[0]}"; fi
  if (( result[1] != 0 )); then return "${result[1]}"; fi
  return "$record_rc"
}
```

For example, authenticate sudo separately, then wrap the runbook's noninteractive `nixos-install` command with `log_install_step 'Copy and register system' sudo -n nixos-install …`. Stop on a failed return status. Before the verified target mounts exist, keep the log in the live environment. If installation stops there, export it to separate trusted media before shutting down.

After the runbook has checked the target root and ESP, persist the log. Refresh that same file after the system copy, account enrolment, and fallback-loader check. Record the exit status of the interactive step without recording its terminal output.

```bash
sudo install -d -m 0700 /mnt/var/log/app-configs &&
  persisted_log=$(sudo mktemp /mnt/var/log/app-configs/install-XXXXXXXX.log) &&
  sudo install -m 0600 -- "$install_log" "$persisted_log" &&
  printf 'Installed log: %s\n' "${persisted_log#/mnt}"
```

After each subsequent step, copy the updated log to `"$persisted_log"` again. Verify that the log is present before unmounting. It will be under `/var/log/app-configs/` after boot.

## Seed and verify the installed user's home

After installing the reviewed system and verifying the target mounts, copy the checked bundle to the installed filesystem for the handoff. Within the installed system, use the installed ordinary account to clone it into an empty `~/Projects/app-configs`. Verify `git rev-parse HEAD` equals `INSTALL_REV`. Leave a checkout already at that revision in place. Stop for a different checkout or unrelated files. This allows reading the runbook and working on the configuration before network sign-in. The checkout alone does not provide the offline Nix build cache, which is covered by the offline recovery kit in the deployment revision’s [installation runbook](niri-install.md).

The current integrated Home Manager activation preflights and creates all work folders and `~/.ssh`. **Earlier installer revisions** provisioned only the base paths. For those revisions, use the following one-time setup on a fresh home to supply the `Scratch` and `Archive` directories from the [shared folder convention](../../architecture/decisions/0040-macos-home-layout-and-cleanup-policy.md#shared-work-folder-convention). Review [ADR-0050](../../architecture/decisions/0050-nixos-niri-home-layout.md) before using the workflow on a restored home.

```bash
(
  set -eu
  test "$(id -u)" -ne 0
  home_dir=${HOME:?}
  [[ "$home_dir" = /* && "$home_dir" != / && -d "$home_dir" && ! -L "$home_dir" ]]
  dirs=(
    Projects Documents Downloads Pictures Pictures/Screenshots
    Scratch Scratch/{temp,logs,benchmarks,reports,screenshots}
    Archive Archive/{projects,snapshots,imports}
  )
  for dir in "${dirs[@]}"; do
    path="$home_dir/$dir"
    if [[ -L "$path" || ( -e "$path" && ! -d "$path" ) ]]; then
      printf 'Expected a directory at %s\n' "$path" >&2
      exit 1
    fi
  done
  for dir in "${dirs[@]}"; do
    path="$home_dir/$dir"
    if [[ ! -d "$path" ]]; then
      mkdir -m 0700 -- "$path"
    fi
  done
)
```

On the first cold boot without the USB, verify LUKS unlock, TTY and Niri login, and the system path against the deployment record. From the ordinary account, check `git -C ~/Projects/app-configs rev-parse HEAD`, `claude --version`, and `codex --version`. Sign in separately after networking works. Read the persisted log with `sudo less /var/log/app-configs/<recorded-install-log>`. Keep the system path, the checkout revision, and the first-login results with the deployment record.
