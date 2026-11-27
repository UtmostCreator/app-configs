Source: local

# T-0032: Prove the Niri installation and trial session

Status: in progress (system and session built, VM installation and recovery exercised, physical Niri login reported, storage follow-up and laptop acceptance open)

## Installation progress and next steps

**24 November 2026 · 50% (5 of 10 evidenced delivery milestones) · high complexity.** Each row below counts once when its stated result has evidence. This measures delivery coverage. The remaining rows vary greatly in effort. The decision register has the [individual ADR scores](../../../architecture/decisions/0046-niri-desktop-installation-decision-register.md#laptop-delivery-by-decision) and [ranked software list](../../../architecture/decisions/0046-niri-desktop-installation-decision-register.md#software-installation-order). [First-boot handoff](../../../platforms/nixos/niri-first-boot-handoff.md)

| State or next priority | Milestone | Evidence or completion condition | Decisions |
| --- | --- | --- | --- |
| Complete | Build the locked host and ISO | Target and integrated home built; installer checksum verified. | [ADR-0006](../../../architecture/decisions/0006-ai-clis-claude-code-and-codex.md), [ADR-0012](../../../architecture/decisions/0012-desktop-compositor-gnome-niri-hyprland.md), [ADR-0047](../../../architecture/decisions/0047-gnome-dependency-retirement-and-wayland-components.md) |
| Complete | Install and log in on a blank VM disk | UEFI/LUKS boot, installed CLI startup, TTY and Niri login exercised. | [ADR-0038](../../../architecture/decisions/0038-disko-nixos-anywhere-fresh-hosts.md), [ADR-0041](../../../architecture/decisions/0041-login-greeter-gdm-greetd-tuigreet-regreet.md), [ADR-0049](../../../architecture/decisions/0049-niri-safest-staged-installation-order.md) |
| Complete | Recover a virtual installation | Rollback and offline rescue passed. Encrypted VM exercised authenticated TTY rollback and offline rescue. | [ADR-0038](../../../architecture/decisions/0038-disko-nixos-anywhere-fresh-hosts.md), [ADR-0049](../../../architecture/decisions/0049-niri-safest-staged-installation-order.md) |
| Complete | Rehearse the first-boot handoff | Offline VM user login restored the checkout and bootstrap tools, wrote private reports and preserved local edits on a second run. | [ADR-0009](../../../architecture/decisions/0009-two-machines-one-history.md), [ADR-0040](../../../architecture/decisions/0040-macos-home-layout-and-cleanup-policy.md), [ADR-0050](../../../architecture/decisions/0050-nixos-niri-home-layout.md) |
| Complete (operator evidence) | Discover the destination hardware | USB console, x86-64 EFI bootloader, keyboard input, identified storage, two Niri outputs and working Wi-Fi reported. | [ADR-0012](../../../architecture/decisions/0012-desktop-compositor-gnome-niri-hyprland.md), [ADR-0038](../../../architecture/decisions/0038-disko-nixos-anywhere-fresh-hosts.md) |
| 2 · P0 | Freeze the destination kit | Review hardware, select a clean revision and match lock, system, ISO and target-specific preparation bundle. | [ADR-0009](../../../architecture/decisions/0009-two-machines-one-history.md), [ADR-0038](../../../architecture/decisions/0038-disko-nixos-anywhere-fresh-hosts.md), [ADR-0049](../../../architecture/decisions/0049-niri-safest-staged-installation-order.md) |
| 3 · P0 | Install and cold-boot the Kingston | Physical boot and NVIDIA-backed Niri are operator-reported. Verify the running generation, enrolled user, both CLIs, checkout, folders and persisted log together on the installed disk. | [ADR-0006](../../../architecture/decisions/0006-ai-clis-claude-code-and-codex.md), [ADR-0038](../../../architecture/decisions/0038-disko-nixos-anywhere-fresh-hosts.md), [ADR-0041](../../../architecture/decisions/0041-login-greeter-gdm-greetd-tuigreet-regreet.md), [ADR-0050](../../../architecture/decisions/0050-nixos-niri-home-layout.md) |
| 4 · P0 | Recover on the laptop | Retain a known-good generation. Demonstrate TTY rollback, offline rescue and a subsequent disk-only boot. | [ADR-0038](../../../architecture/decisions/0038-disko-nixos-anywhere-fresh-hosts.md), [ADR-0049](../../../architecture/decisions/0049-niri-safest-staged-installation-order.md) |
| 5 · P1 | Accept a normal work session | Test ordinary-user Wi-Fi/DNS, lock/resume, portals and capture privacy, actual launcher search, clipboard and exact Code project. Measure bare Niri, trial the shell and run one PHP/JS project. | [ADR-0012](../../../architecture/decisions/0012-desktop-compositor-gnome-niri-hyprland.md), [ADR-0013](../../../architecture/decisions/0013-desktop-shell-bar-notifications-trial.md), [ADR-0021](../../../architecture/decisions/0021-cross-platform-parity-and-profiles.md), [ADR-0022](../../../architecture/decisions/0022-browsers.md), [ADR-0025](../../../architecture/decisions/0025-terminal-environment.md), [ADR-0026](../../../architecture/decisions/0026-editors-and-ides.md), [ADR-0027](../../../architecture/decisions/0027-launcher-clipboard-windows-input-macos-ux.md), [ADR-0028](../../../architecture/decisions/0028-files.md), [ADR-0036](../../../architecture/decisions/0036-screenshots-media-images-and-pdf.md), [ADR-0045](../../../architecture/decisions/0045-niri-windows-like-desktop-shell-ux.md), [ADR-0047](../../../architecture/decisions/0047-gnome-dependency-retirement-and-wayland-components.md), [ADR-0048](../../../architecture/decisions/0048-niri-launcher-vscode-project-workflows.md) |
| 6 · P0 before personal data | Accept existing-home migration | MIME fixtures cover restored regular files, conflicting associations and repeat activation. Verify the applications open correctly in the restored session. Restore representative project, state and vault from the intended Kopia repository to independent storage. | [ADR-0022](../../../architecture/decisions/0022-browsers.md), [ADR-0023](../../../architecture/decisions/0023-password-managers-and-secrets-cli.md), [ADR-0033](../../../architecture/decisions/0033-communication-sync-notes-and-backup.md), [ADR-0040](../../../architecture/decisions/0040-macos-home-layout-and-cleanup-policy.md), [ADR-0050](../../../architecture/decisions/0050-nixos-niri-home-layout.md) |

The Kingston has booted on the destination laptop. The operator reports working Niri graphics and Wi-Fi. The exported rescue evidence records an offline filesystem repair and a successful read-only recheck. The operator verified base and NVIDIA boots, both display outputs, DRM modesetting, healthy mount flags and zero failed units, and set the working NVIDIA entry as default. The next gate is a first-login report from the reviewed automated profile, followed by recovery from a retained generation. Keep the existing installation in place. The daily-PC attached-disk route remains deferred. [24 November incident review](physical-install-2026-11-24.md) · [External Kingston walkthrough](../../../platforms/nixos/kingston-install-walkthrough.md)

25 November verification passed for the locked Linux flake, graphical-session VM, eight-stage installation/recovery VM and 2,123 shell tests. Five platform-dependent shell cases skipped. The [verification record](physical-install-2026-11-24.md#first-login-and-maintenance-regression-checks) distinguishes the tested update and rollback paths from the physical checks still due.

### Related ticket delivery

Each percentage covers the listed checkpoints for the named scope. Complexity reflects integration and recovery effort. T-0029's existing-PC work runs independently of the laptop.

| Ticket and scope | Priority | Complexity | Complete | Completed checkpoints | Next checks |
| --- | --- | --- | --- | --- | --- |
| [T-0029](../T-0029-nixos-system-ownership/ticket.md) System ownership | P0 laptop / independent PC work | High | 50% (2/4) | GNOME pilot built · Dedicated laptop output built | Review the destination module · Resolve the existing PC takeover separately |
| [T-0030](../T-0030-validator-nixos-programs-and-niri/ticket.md) Configuration ownership | P0 build | Medium | 100% (3/3) | Positive and negative fixture suites passed · Six evaluated user profiles passed · Disposable chezmoi render checked the KDL exclusion | Repeat these checks if the deployment revision changes the relevant modules. |
| [T-0031](../T-0031-compositor-neutral-window-actions/ticket.md) Window actions | P1 daily use | High | 50% (2/4) | Backend contract recorded · GNOME backend landed | Implement the Niri backend · Verify focus and keyboard parity on hardware |
| [T-0033](../T-0033-refresh-stale-migration-docs/ticket.md) Migration documentation | P1 maintenance | Medium | 38% (3/8) | Identify the historical in-place route · Link the dedicated runbook · Correct the account guidance | Reconcile GNOME retirement wording · Audit launcher assumptions · Audit greeter comparisons · Audit portal and chooser claims · Mark historical install instructions |
| [T-0042](../T-0042-install-selection/ticket.md) Installer selection | P0 Niri selector | Medium | 100% (3/3) | Explicit locked build tested · Conflicting selection rejected · Installed-host legacy bootstrap guard tested | The original selection ticket retains its separate real-Mac checks and extension decisions. |

Earlier VM result: `a464c0dxyllg2nbhbvsqamlynpic7i5k-vm-test-run-linux-niri-install-recovery`. Its installer digest matched that development record. The [physical incident report](physical-install-2026-11-24.md) covers subsequent laptop boots and outstanding acceptance.

Use the [installation runbook](../../../platforms/nixos/niri-install.md) and [ADR-0049](../../../architecture/decisions/0049-niri-safest-staged-installation-order.md). The existing GNOME PC can run Claude and build the target while the laptop is offline. Its takeover under T-0029 is independent. T-0031 supplies the window-focus backend for daily acceptance. Shell research follows installation and recovery.

## Evidence by environment

| Gate | What counts | Result |
| --- | --- | --- |
| Preparation | Run the packaged Claude Code as the ordinary user on the project ISO or installed laptop | CLI startup verified on both. After enrolment, ask Claude to explain a read-only step from the runbook and record whether a response arrives, the environment and the CLI version. Authenticated use is pending. |
| A. Build | Actual locked `linux-niri` toplevel and integrated user; validate KDL, commands, forbidden closure paths and session configuration | See verification record below |
| B. Disposable VM | Session smoke test; blank UEFI disk with LUKS unlock, valid login on the installed system and working home. Repeat from the actual ISO on a standalone store | Passed on the actual project ISO and blank virtual SSD. Installed TTY login, graphical login and the matching system path were verified. |
| C. Recovery | Boot two different generations, recover a deliberately failed desktop and rescue from installation media | Two distinct generations, password-backed TTY rollback and offline installer rescue exercised in QEMU. |
| D. Destination laptop | Cold boot actual laptop, test its devices, lock, suspend and daily workflows | Physical boot, graphics and networking reported. Filesystem recovery recorded. Repeat first-boot verification and complete device, suspend and workflow checks. |

For each accepted run retain commit, lock digest, host, hardware revision, ISO/checksum, installed store path, expected and actual results. Record only sanitized results. VM-only fixture passwords and virtual hardware belong exclusively to the tests.

## Deferred physical acceptance

Keep using the test laptop with disposable data. Run the live baseline below before and after a generation or shell change. Repeat the physical checks that apply on the next laptop, even when the same repository revision passed on this one.

1. [ ] **Recovery before the next update.** Confirm the working boot entry and variant, authenticate on a TTY, and verify the offline USB can recover the existing installation and return to a disk-only boot. During the first update, retain the working entry and verify rollback from the second generation. Record both generation IDs, their variants, and the entry that actually booted. Stop update writes if EXT4 reports `ro`, `emergency_ro`, or recorded errors. [Recovery runbook](../../../platforms/nixos/niri-install.md#5-prove-recovery-before-selecting-a-shell)
2. [ ] **Lock, suspend, and displays.** On bare Niri, reject an incorrect lock password. Check idle lock and lid-triggered sleep, then resume to a still-locked session. Disconnect and reconnect the external monitor while locked. Verify that both outputs, keyboard, touchpad, and brightness controls work after unlock.
3. [ ] **Calls, files, and authentication.** In the intended browser and call client, use speakers, microphone, and camera. Have a receiver verify a window share and a monitor share, including exclusion of a dummy KeePassXC window. Open and save via the GTK chooser, complete a polkit prompt, retrieve a dummy keyring item after relogin, pair a Bluetooth device, and mount and eject removable media.
4. [ ] **Daily work and shell parity.** Search for and launch a known app in Vicinae, retrieve a test clipboard item, save and reopen a screenshot, and open the intended MIME and URI targets. Under both US and Russian layouts, focus the correct VS Code project with several windows open and run a representative project build and tests. After recovery, trial Dux followed by Noctalia if needed. Verify task switching, tray and notification behavior, and that applications, locking, and polkit still work when the trial shell stops. Use the shell gates below.
5. [ ] **Restore before migrating personal data.** From the intended Kopia repository, restore a representative project and vault onto independent storage and open both. Record the restore and access results before enrolling sync or moving personal data.

## Repeatable live baseline

Run as the ordinary installed user from inside Niri. The acceptance command wraps the first-boot verifier, captures deployment identities and probes the live session without changing it. The `--online` option checks DNS and HTTPS against the Nix cache. Omit it for an offline baseline. A nonzero exit indicates that a required probe failed or was unavailable. Service and hardware discovery evidence covers presence only. Keep the output in a private file when recording a physical session.

```bash
bash ops/niri/acceptance.sh --online
```

At 10:59 UTC on 25 November, the live run exited zero on `26f3bbd`. Both internal and external outputs were present. The audio and desktop service probes passed and notifications remained unowned. The first-login timer and disk identity receipt were absent on this older installation. Boot entry details and full journal verification require elevated access on this laptop. Building the committed candidate `4dd74c6` stopped at a missing `python3.14-cryptography-50.0.2` store path that the local database still lists. The public cache has the path and the daemon denied repair to the ordinary account. There was no boot or profile change.

### 25 November 2026 baseline

| Scope | Observed result |
| --- | --- |
| Live `26f3bbd`, generation 1, `nvidia-open` | Required readiness checks passed. Registered boot matches the active system. LUKS root and EFI mount share the same disk, EXT4 is read-write with zero recorded errors, and neither manager reports failed units. Owned work directories and private `Scratch` and `Archive` passed. Wi-Fi, DNS and Nix cache HTTPS passed. |
| Live session | Niri CLI and compositor report 26.04. The deployed KDL parses and matches the repo copy. US and Russian layouts are listed. Internal display ran at 1920×1080 at 144 Hz, with external outputs disconnected. PipeWire exposed a default sink, source and camera. NVIDIA backlight and Xwayland socket were present. |
| Desktop services | Vicinae, swayidle and Soteria were active. D-Bus exposed GTK and GNOME portals, GNOME Keyring and Vicinae's tray watcher. FileChooser, ScreenCast and Notification portal versions were readable. No `org.freedesktop.Notifications` owner was observed. |
| App presence and defaults | Brave handles HTTPS and PDFs. VS Code handles `vscode:` and folders. `mailto:` is unset. Claude Code 2.1.323 and Codex 0.169.0 responded to version probes. Ghostty, Vicinae, VS Code, Brave, KeePassXC and Kopia are present. PHP, Composer, pnpm and Python were absent from the installed user's PATH. |
| Live warnings | This older install lacks a recorded disk identity. `smartctl`, `nvme`, `lspci`, `lsusb` and `jq` were unavailable on the installed user's PATH. The automated first-login unit and timer were absent. A pre-existing local edit to `nix/hosts/linux-niri/home.nix` was present during the baseline. |
| Committed candidate `4dd74c6` | Offline Linux flake evaluation and the offline `niri-config` check build both exited zero. They used committed sources and the lock with SHA-256 `8c63826a77cae798e0cb662144d46710f1d4e24aa4372a74d9275f203c1b745d`. Darwin evaluation, the full system build and guest boots were outside this run. |
| Isolated fixtures | All 80 selected Bats cases passed, including 18 first-boot cases that require Bubblewrap. Coverage includes installer guards, shell seeding, offline first login, update staging, restored MIME, and the existing GNOME window backend. The full Bats suite was outside this run. |

To repeat the committed candidate evaluation without including local edits, run from the repository root and supply the full reviewed Git revision.

```bash
revision=$(git rev-parse HEAD)
timeout 120s nix flake check --offline --no-build --no-update-lock-file \
  "git+file://$PWD?dir=nix&rev=$revision"
timeout 60s nix build --offline --no-update-lock-file --no-link \
  "git+file://$PWD?dir=nix&rev=$revision#checks.x86_64-linux.niri-config"
```

To repeat the focused fixture run, put `bats`, `bwrap`, `chezmoi`, `jq` and `python3` on PATH. This laptop used cached Nix package binaries for those tools. Use the repository runner to isolate the home directory and session. Bubblewrap needs user mount namespaces for the first-boot fixtures. Check the summary for skips as well as failures.

```bash
selection=$(python3 -c '
import re, sys
from pathlib import Path
names = []
for file in sys.argv[1:]:
    names.extend(re.findall(r"^@test ([\x27\x22])(.*?)\1 \{", Path(file).read_text(), re.M))
print("^(" + "|".join(re.escape(name) for _, name in names) + ")$")
' tests/bash/{niri-first-boot,niri-first-login,niri-maintenance,niri-media-install,niri-seed-shell,mimeapps-migration,window-backend}.bats) &&
  RUN_BATS_JOBS=1 timeout 120s bash ops/run-bats.sh --filter "$selection"
```

## Manual Dux trial

Build the standalone `niri-dux-trial` package on Linux. It uses Dux and Quickshell from the existing flake lock. Building it requires no change to the booted generation.

```bash
nix build --no-link --no-update-lock-file ./nix#niri-dux-trial
nix run --no-update-lock-file ./nix#niri-dux-trial -- --version
```

Preparation verified on 25 November 2026. The package built, the version probe reported Dux 2.1.2, and the launcher refused a missing Niri socket and an already-owned notification name on a private test bus. The evaluated Niri configuration contains no Dux startup unit. Flake evaluation and the six Niri configuration fixtures passed. The full flake check stopped at a missing `xwininfo` store derivation during installation-test evaluation. A direct `xwininfo` build from the committed baseline reproduced the error. The physical shell trial is open.

Before starting the trial, confirm a console login with Ctrl+Alt+F2 and return to Niri. Record the working NVIDIA boot entry and a bare-Niri lock and resume result. Ghostty is a terminal within Niri. The console login is the recovery check for a failed graphical session.

From Ghostty inside Niri, start the shell manually and inspect the transient service and notification owner.

```bash
nix run --no-update-lock-file ./nix#niri-dux-trial
systemctl --user status niri-dux-trial.service --no-pager
busctl --user status org.freedesktop.Notifications
```

Check the bottom taskbar, existing and newly opened windows, tray, and a test notification. Launch test applications through the existing Vicinae or Niri shortcuts so they use their normal profiles. The Dux process uses a private temporary home and the service removes it on exit. The trial disables Dux clipboard history, automatic lock integration, polkit, and theme generation. Its lock action delegates to the existing session locker via logind.

Stop it from Ghostty or the TTY, then check that Niri, Vicinae, swayidle, and Soteria still respond. Use the normal lock shortcut and confirm it still works. Record any residual notification owner or Dux process as a failure. This launcher is an explicit user action with no Niri startup hook or boot entry.

```bash
systemctl --user stop niri-dux-trial.service
niri msg --json version  # Run from the Niri session.
systemctl --user is-active vicinae swayidle polkit-soteria
```

## Shell trial gates (run on whichever shell is under trial: Dux first, Noctalia second)
These G1 to G11 are local to this ticket. ADR-0046's gaps are written with two digits (G01 to G28) and are a different list.
Depends on the pre-migration backup gate in the acceptance list above. Source: `docs/research/niri-shell-dux-vs-noctalia.md` (user-supplied audit, upstream issue states unverified). These apply during the shell comparison trial (in scope per plan decision 4, user confirmed 2026-11-15), not to creating the niri session itself. The existing "External monitor, suspend/resume, lock" and "Flameshot" items above are extended by these, not replaced. Use the repo's KDL binds only, with exactly one owner each for notifications, clipboard, lock/idle and polkit.
- [ ] G1: Lock, then disconnect and reconnect an external monitor N = 10 times while locked; record shell RSS before and after; fail if RSS grows more than 200 MiB in total or keeps growing (Dux #4259)
- [ ] G2: Lock, suspend, unplug an output, resume: the session unlocks without re-login (Noctalia #5349)
- [ ] G3: Notification flood while locked, then unlock: no crash (Noctalia #2836 regression)
- [ ] G4: Polkit: exactly one agent is running and an auth prompt appears (Noctalia `polkit_agent` defaults to false; #4565)
- [ ] G5: The shell UI renders on this GPU setup (Noctalia #4714); N/A if not hybrid NVIDIA with the proprietary driver (host currently AMD iGPU + NVIDIA dGPU on nouveau)
- [ ] G6: capture and pin with the selected capture tool both work under the shell (reported against Flameshot, Noctalia #1325)
- [ ] G7: The shell's IPC works on NixOS/niri (Dux #1153): the shell's documented IPC command responds (for example `dms ipc ...` or `noctalia msg ...`; exact command not confirmed here)
- [ ] G8: U2F unlock works, only if a security key is used (Dux #2789)
- [ ] G9: Notifications have one owner: exactly one `org.freedesktop.Notifications` owner (for example `busctl --user status org.freedesktop.Notifications`)
- [ ] G10: Clipboard history has one owner: the shell's clipboard history is disabled and Vicinae's is active
- [ ] G11: Lock/idle has one owner: exactly one idle controller and exactly one locker run. swayidle with swaylock is one such pair; the shell's own idle or lock service must not run beside it

NixOS generations are not data backups; back up mutable `$HOME` data and secrets separately.

## Verification record

The retained local verification bundle is in the Git-ignored directory **result-niri-verification** at the root of the prepared checkout. It contains the base revision, two independently reviewable source patches, the resulting Git tree ID, artifact identities and observed check exits. The general installer selector and its tests are a separate patch from the host and migration work. The evidence lives outside the candidate so recording outcomes cannot change the code under test.

Working tree based on `c345f55b9e40ba9f43f985efb0cf7569df67ddfb`, 2026-11-22. The tested lockfile SHA-256 is `2301a65066c29c9782acf5c83f2357c417be609cb67c2fe4ed925e7d7dd426ca`. Disko v1.13.0 is the only new lock node. This is development evidence. A physical deployment record needs the final clean commit with its reviewed hardware module and the installer ISO checksum.

- The existing workstation CLI reported Claude Code 2.1.330. `nix run --no-update-lock-file ./nix#install-claude -- --version` ran the target package, 2.1.323.
- The installer ISO with both CLIs is `nixos-minimal-26.11.20261114.5d2b81a-x86_64-linux.iso`, 3,972,317,184 bytes. SHA-256 is `9770b226d1a5216aaa245a8ecc2dc20f0f2cbd44524790f08ab29d5c14ae3022`. Its live system publishes the prebuilt target at `/etc/app-configs/linux-niri-toplevel`.
- The installed system with Claude Code 2.1.323 and Codex 0.169.0 built at `/nix/store/1csjysr94lg1aqjrjdrqwxpy201db40i-nixos-system-linux-niri-26.11.20261114.5d2b81a`. The 1,207 runtime paths passed the checks excluding GDM, GNOME session/Shell, Shell extensions and Nautilus. Android Studio, Obsidian, Syncthing, Telegram and Vesktop were absent from this first-install closure. The generated portal preferences select GTK FileChooser, GNOME ScreenCast and GNOME Keyring Secret.
- **GNOME removal rehearsal.** An offline evaluation used a 136 KiB source copy containing only the locked flake, the Niri host, shared MIME defaults, package overlay, Brave package and public profile variables. With the same configuration revision, it resolved to the exact system store path above, including Codex. Both GNOME host directories, all GNOME Home Manager modules and the legacy GUI helpers were absent.
- Native `nix flake check ./nix --no-update-lock-file`, cross-platform `--all-systems --no-build` evaluation, the existing workstation home activation-package build, `bash ops/install.sh --host linux-niri` and all six ownership-validator evaluations passed. A disposable chezmoi source and home verified host-specific KDL ownership. In an isolated dirty checkout, the update report correctly refused to proceed. The live home diff and live updater were left to the operator because they inspect personal managed files. The complete isolated shell suite finished with 2,044 passing tests and five platform/tool skips.
- The Niri session VM accepted the declared KDL, rejected a bad password, logged into Niri through tuigreet and observed a Ghostty window after the terminal shortcut and a Vicinae window after Alt+Space. The Vicinae first-run welcome window can satisfy that assertion. Logout returned to the greeter. The VM also checked registration of the locked VS Code recents extension and invoked the clipboard and recents commands. On hardware, finish the launcher welcome screen, close Ghostty, press Alt+Space, search for Ghostty and press Enter. Confirm a new Ghostty window opens. Retrieve a known clipboard entry and select the correct project among several Code windows as separate checks.
- **Actual ISO rehearsal.** A second read-only CD supplied the target-specific Disko store export and expected system path, as described in the [prepared offline installation](../../../platforms/nixos/niri-install.md#4-install-enrol-the-account-cold-boot). On a 2,304 MiB UEFI guest with networking disabled, the ordinary live user ran Claude, Codex and its login help. Disko prepared a blank virtual SSD. Offline installation and fallback-loader verification took 482 s after the mounts were checked. The SSD cold-booted with a fresh EFI variable store after removal of the USB image. The installed user authenticated on a TTY and in Niri, ran both assistants and validated the KDL. Niri IPC confirmed Ghostty and Vicinae, and NetworkManager reported the virtual Ethernet link connected. Logout returned to tuigreet. The virtual GPU advertised no display output to Niri, so visible rendering is an older-laptop check.
- **Offline rescue from the project ISO.** On original candidate tree `55b064e3e5a3bb7e49344c05d3763697a19ec224`, ISO SHA-256 `9770b226d1a5216aaa245a8ecc2dc20f0f2cbd44524790f08ab29d5c14ae3022` installed generation 1 and recovered it after generation 2 booted with greetd masked. The operator authenticated on a TTY, restored the generation and bootloader from the offline ISO, then cold-booted the disk and authenticated on a TTY and in Niri. Both running system paths matched generation 1. The LUKS, ext4 and ESP identities and a home sentinel survived. An initial console observer missed a password prompt; the successful continuation reused the installed disk. No physical disk was involved.
- The encrypted installation VM ran Disko and `nixos-install` on a blank disk. It booted the fallback EFI loader, unlocked LUKS, booted a distinct generation with greetd disabled and restored the working generation via password-backed sudo on tty2. The offline installer mounted the existing disk, restored the recorded generation and cold-booted it again.
- The final `niri-install-test.driver` ran all seven subtests successfully in a standalone, resource-limited scope. Driver `/nix/store/9jqx0ylnnfxqkv3w99p6ia3rc1vv0qz4-nixos-test-driver-linux-niri-install-recovery` booted distinct test generations, recovered twice and exited zero. The earlier full run is retained in the timing comparison below.
- The separate 15-package `niri-workflow-apps` bundle built successfully. It stages the application closures for daily-use testing without enabling accounts or starting services.
- A local Kopia 0.23.1 rehearsal snapshotted a sample project, application preferences, public recovery instructions and a disposable KeePassXC database. Restoring into a new directory reproduced every file byte-for-byte. KeePassXC 2.8.0 opened the restored database and listed its test entry. All fixtures were on the same temporary filesystem. An independent storage device and owner-verified access to real backups remain required for migration.

## Performance at each milestone

Repeat the relevant row after changing the host, installer, services, shell or applications. Record the commit, lock digest, system path, hardware or VM limits, storage, cache state and background load. Run one heavy workload at a time. Compare the previous and candidate generations on the same machine and repeat after reverting a suspected regression. Keep the samples with the acceptance record. Report the median, range and change from the baseline. Claim an improvement only when it repeats beyond ordinary run-to-run variation and the same functional tests still pass.

| Milestone | Measurement to repeat |
| --- | --- |
| A · Build | Record system closure bytes, ISO bytes, KDL validation time and validator peak RSS. Time a cold build and a cached build separately on a dedicated builder. Preserve a working configuration before removing any dependency. |
| B · Blank-disk installation | From the same ISO and blank virtual disk, time formatting, copying the closure and reaching the greeter separately. Exclude human passphrase entry. Record guest RAM and vCPUs, host swap and the peak memory of the build or VM cgroup. |
| C · Recovery | Time boot to the known-good greeter after TTY rollback and offline rescue. Record the exact generations, correct login and restore result alongside timings. |
| D · Laptop and daily workflow | With identical displays and power settings, measure three cold boots and fresh logins. Record whole-machine used memory as `MemTotal - MemAvailable` from `/proc/meminfo` after 60 idle seconds at the greeter and again in Niri. Separately sample compositor, launcher and candidate shell user units with `systemctl --user show UNIT -p MemoryCurrent -p MemoryPeak`. Compare bare Niri, Dux and, if trialled, Noctalia. Time shortcut-to-visible terminal/launcher and correct Code-project focus. Repeat the existing lock, hotplug and recovery checks and record surviving processes and memory growth. |

**Initial measurement, 2026-11-22 21:45 UTC.** On the x86-64 support PC, Hyperfine 2.0.0 ran the built Niri 26.04 binary against the exact Home Manager KDL. Seven serial warm measurements after two warmups gave **16.56 ms median** (15.88–19.84 ms) and **19.62 MiB median peak RSS** (19.38–19.71 MiB). This measures launching the validator and parsing the configuration. A bounded ISO build was starting, and host I/O pressure (`some avg10`) was 82% just before measurement. Repeat on a quiet machine before treating it as a comparison baseline.

```bash
hyperfine --warmup 2 --runs 7 --metrics time_wall_clock:ms,memory_peak_resident:MiB \
  '/nix/store/d2r1zcvri3fiz8wfzmj1mbylv3rnvbnl-niri-26.04/bin/niri validate -c /nix/store/i60rvlpwww94ncndns8q3dks6c3qd0jp-hm_config.kdl'
```

**Capped final fixture.** On the 4 GiB VM with host write bandwidth capped at 24 MB/s, `nixos-install --system` took 552.06 s. All seven subtests completed in 973.93 s. They covered install/enrolment (604.48 s), UEFI/LUKS boot and first-user checks (84.55 s), Ethernet (0.43 s), graphical login, apps and logout (26.37 s), booting the failed greeter (77.63 s), authenticated TTY rollback (87.43 s) and offline rescue through cold boot (92.92 s). The test cgroup peaked at 5.37 GiB including page cache, used zero swap and recorded zero OOM or hard-limit events. The host retained at least 10.76 GiB available. The private test disks were removed.

**First installation and recovery timings.** The completed 4 GiB guest rehearsal above took 569.78 s. Blank-disk preparation, installation and enrolment took 176.04 s. The first UEFI/LUKS boot and assertions took 57.38 s. Booting the faulty generation took 35.18 s, authenticated TTY recovery 42.60 s and offline rescue through the final cold boot 258.46 s. These single wall-clock samples include test-driver and passphrase-prompt waits under workstation load. Use the same fixture for comparisons and measure the older laptop separately.

**Installer build with both CLIs.** One Nix job with two compression workers and a 512 MiB compressor cache limit built the 3,972,317,184-byte ISO in 125.1 s. Minimum host `MemAvailable` was 14,699,876 KiB. The sampled peak for the whole Nix daemon cgroup during this build was 9,680,666,624 bytes (9.02 GiB), including cache. The 8 GiB hard ceiling in the source-verification run applied to its own scope. It did not cap the Nix daemon or the workstation. The previous Claude-only image was 405,749,760 bytes smaller. The package list and compression settings both changed, so this is a new build baseline.

**Physical-image rehearsal in QEMU.** UEFI live boot through both CLI checks took at most 48 s. After entering the LUKS passphrase the installed disk reached tuigreet in 27 s. Peak sampled QEMU process RSS was 2,374,644 KiB during installation and 2,330,996 KiB after cold boot. There were two vCPUs, a 150% host CPU quota, a 4 GiB cgroup limit, zero guest-scope swap and host storage rate limits of 40 MB/s read and 24 MB/s write. The 482 s offline install includes the EFI setup.

**Package footprint.** `nix path-info --closure-size` reported 8,115,154,232 bytes for the pre-Codex toplevel and 8,774,464,288 bytes for the system including Codex 0.169.0. The measured increase is 628.77 MiB. Both counts use NAR bytes with transitive dependencies. Whole-project flake evaluation exceeded a 5 GiB client cgroup limit. Both native checks and all-platform evaluation passed sequentially with an 8 GiB limit, zero scope swap and `GC_FREE_SPACE_DIVISOR=8`. The optional workflow bundle and live USB are separate outputs.

For the next generation substitute its store binary and HM KDL. The result above establishes no desktop idle-memory figure, boot-time target or shell ranking. Those baselines require the corresponding VM or hardware measurements.

## Data migration

Restore a project, application data, access-recovery material and a KeePassXC database to an independent destination with Kopia. Verify access before enrolling account-bound services. Real personal data comes after capture-privacy tests and shell acceptance.
