# Kingston installation handoff

Use this checklist with the [step-by-step external Kingston installation](kingston-install-walkthrough.md), the [installation runbook](niri-install.md), and the [trial ticket](../../work/active/T-0032-niri-trial-session/ticket.md). Prepare the Kingston from the verified live USB on the destination laptop or an isolated UEFI helper. Verify the destination hardware first and use a clean deployment commit and its matching artifacts. Keep the attached-disk route on the running daily PC closed until its disk guards pass.

## Prepare the offline checkout

On the build PC, create a Git bundle from the clean, reviewed deployment checkout. Use the same commit that produced the installation artifacts. Transfer the bundle and its digest on the preparation medium and verify the digest before using it. A Git bundle carries committed repository history. Leave local settings, credentials, and untracked files on the source machine.

```bash
test -z "$(git status --porcelain)" &&
  test "$(git rev-parse HEAD)" = "${INSTALL_REV:?supply the reviewed commit}" &&
  git bundle create "${KIT:?supply the preparation directory}/app-configs.bundle" HEAD &&
  git bundle verify "$KIT/app-configs.bundle" &&
  sha256sum "$KIT/app-configs.bundle"
```

## Keep a private installation log

In the live environment, create a private temporary log before Disko. Record the deployment commit, ISO and bundle digests, expected system path, and the outcome of disk checks. Record the exit status of each step and capture output from noninteractive checks and the system copy. Keep encryption, password enrolment, and account sign-in outside the logger. Use no terminal transcript or shell tracing. Keep the raw log private and review it before sharing excerpts.

```bash
install_log_dir=$(mktemp -d)
install_log="$install_log_dir/install.log"
(umask 077; : > "$install_log")

log_install_step() {
  local label=$1 rc
  shift
  printf '%s  START  %s\n' "$(date -u +%FT%TZ)" "$label" >> "$install_log" || return
  if (set -o pipefail; "$@" 2>&1 | tee -a "$install_log"); then
    rc=0
  else
    rc=$?
  fi
  printf '%s  EXIT %s  %s\n' "$(date -u +%FT%TZ)" "$rc" "$label" >> "$install_log" || return
  return "$rc"
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

The integrated Home Manager profile creates `Projects`, `Documents`, `Downloads`, and `Pictures/Screenshots`. Before seeding the checkout, use the following one-time setup from the installed ordinary account on a **fresh** home. It also supplies the `Scratch` and `Archive` directories from the [shared folder convention](../../architecture/decisions/0040-macos-home-layout-and-cleanup-policy.md#shared-work-folder-convention). Review [ADR-0050](../../architecture/decisions/0050-nixos-niri-home-layout.md) before using the workflow on a restored home.

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
