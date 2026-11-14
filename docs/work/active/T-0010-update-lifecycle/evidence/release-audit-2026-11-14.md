# T-0010 release audit record, 2026-11-14

Record of the release-auditor's final report on `af13fb0`, taken verbatim in
substance from the audit hand-back. This is NOT a completed release-audit PASS:
the verdict is "PRE-DEPLOYMENT PASS — LIVE ROLLBACK PENDING". The live apply and
rollback (H-1 to H-5) still need a supervised run under separate authorisation.

H-1.2 pins af13fb0. Before H-1, the runbook owner must re-pin it to the landed
main after reviewing the delta af13fb0..<landed main>. That delta in this landing
touches no sys-update code (ops/update-all.sh, ops/lib, nix/, home/ are
unchanged). The auditor's scratch probe artefacts and ci.log referenced below
were not preserved.

Method: isolated, pre-deployment. Fresh detached worktree, stub toolchain, fake
HOME and a repo copy; nothing wrote outside scratch. The real `/nix/store` was
never collected.

## Release Verdict
**PRE-DEPLOYMENT PASS — LIVE ROLLBACK PENDING**

Nothing I found blocks authorising the first supervised real Linux `sys-update` apply and rollback. The final release verdict is recorded only after that run (H-1 to H-5 below), which needs its own user authorisation. Four conditions apply to that run: C1 to C4 under Blocking Risks.

**#29 is not a deployment blocker.**
- In a fresh detached worktree of `af13fb0`, `bash ops/ci-local.sh` passed every stage: 1130 of 1130 bats tests passed, including #29, and it exited 0. That differs from the known state you gave me ("ci-local exited 1").
- #29 fails only under `bash ops/run-bats.sh` with the developer PATH: "ops/projects/workspace/components-local.sh: --help exited 1".
- sys-update never calls `components-local.sh`. The pre-commit and commit-msg hooks that the auto-commits pass through (gitleaks, `doctor.sh`, `validate-config.sh`, conventional subject) run no bats tests. Both `doctor.sh` and `validate-config` pass at `af13fb0`.
- It stays a CI and merge item for the owner of `fix/arg-contract-components-local` (`a071f43`).

## Audited Subject
- `af13fb007cf83a446a57b2bb78b2edff21116621` (`main` = `origin/main`). It did not change during the audit (checked at start and end).
- Scope: T-0010 Gate A and Gate B (`23e3578`…`016528e`), T-0011 `1cc9f2a`, the R4-01 fix `ae18daf`.
- Code read in full: `ops/update-all.sh`, `ops/lib/update-ui.sh`, `ops/lib/hm-switch.sh`. Partly read: `ops/cleanup.sh`, the hooks, README, `install.md`.
- Main checkout state is unchanged (`git status` hash compared before and after). The audit worktree has been removed.
- Mismatches:
  - The main checkout has 6 untracked paths from other sessions. A real apply would refuse on them (dirty-worktree precheck).
  - `plan.md` has no ticked items and its progress log stops at "implementation not started" (documentation lag only).

## Risk Level
high. It switches the live Home Manager profile, commits to `main`, and depends on GC roots.

## Scenarios 1–5 (proof)
"CI" means the result in my `ci-local` run at `af13fb0` (`tests/bash/…`). "Probe" means my scratch run of the real `update-all.sh` from `af13fb0`, with a stub toolchain, a fake HOME and a repo copy. `BATS_TEST_TMPDIR` was set so the script's own guard refuses any path outside scratch.

| # | Proof | Status |
|---|---|---|
| 1 Apply → rollback | CI: `update-all-apply.bats` "rollback restores the previous generation and the previous lock" (ok 734), "rollback restores both the browser release and flake lock" (728), "S36…" (812). `update-all-recovery.bats` "rollback commits the restored files so the next sys-update starts clean" (865). Probe 1a: after runs A then B, rollback returned to B's `hm_path_before` (not A's); B's record became `rolled-back`; tree clean. | **verified (isolated)** |
| 2 Foreign `flake.lock` edit | CI: "S22…" (783), "a rollback keeps a lock that was edited after the update" (818), "rollback commits nothing when a file it wrote was kept" (868), "rollback leaves a Brave bump committed by another session on a host that never wrote it" (867), F-01 (834/835), F-02 (836/837). Probes 1d, 1d′, 1e: the foreign edit was kept every time, nothing was committed, and the git choices were printed. | **verified for preservation.** The reporting is only partly what you expected (see note) |
| 3 Backup creation fails | CI: "G-04: a flake.lock backup failure stops before PREPARE…" (762), "S42: a GC root that cannot be created stops…" (825), "S08…" (753/754), "a failed snapshot stops…" (742/787). Probe 2: real `nix-store` could not realise the HM path → exit 1, `failed:snapshot`, no flake update ran, lock and HEAD unchanged, `last-run` not moved. | **verified (isolated).** Gap: no test for a failed Brave `release.json` backup (same code path) |
| 4 Activation or verification fails | CI: "S24: a verification failure keeps the lock uncommitted and offers both ways out" (789), "S18…even with --skip-verify" (779), "S19" (780), "S21" (781/782), "a failed update leaves the lock uncommitted" (730). Probe 3: Brave broken or wrong MIME in a graphical session → exit 1, `failed:verify`, 0 commits, both choices printed, and a rollback afterwards restored the profile and the lock with a clean tree. A switch that exits 0 without moving the profile under `--skip-verify` → `failed:activate`, lock restored, rollback named. | **verified (isolated)** |
| 5 Ctrl-C or SIGKILL | CI: "T-0011: after SIGKILL of the updater the ticker exits and the next run gets the lock" (832), "T-0011: a normal exit, SIGINT and SIGTERM leave no ticker behind" (833), "S48…SIGINT on a terminal" (764), "S48: SIGTERM exits 143…" (760), "S49/S50" (785/786). Pty probe: Ctrl-C to the foreground group → 130, `failed:prepare`, lock free, ticker gone, tree clean, next apply ok. SIGTERM → 143, delivered only after the running step finished. SIGKILL mid-PREPARE → ticker gone, lock free, but see gaps. | **verified (isolated)**, with 2 coverage gaps |

**Note on scenario 2.** In a full rollback, a kept foreign file gives exit 0 with "rollback done (files that changed since the update were left in place)" plus a `!` warning that names the file. The other restored file is left uncommitted, so the tree is dirty and the next `sys-update` refuses until the user runs one of the printed commands. Nothing is lost and the warning names the file, but the run is not labelled "incomplete". Reviewer question: should a kept file give a non-zero exit or the word "incomplete"? This is next to R5-02 and R5-03. It does not block a fresh run with no concurrent editors.

**Gaps for an implementer** (each found only by a scratch probe):
- G1: SIGKILL after `nix flake update` wrote the lock leaves the tree dirty. The next apply exits 1 ("1 modified"); it is not exit 5. `sys-update rollback` (status `started`) restored the lock, and the following apply passed. No test covers this. The docs say "an interrupted run … restores the lock", which is not true for SIGKILL.
- G2: SIGKILL inside the SNAPSHOT window leaves one `sys-update-snapshot.*` and one `sys-update-step.*` file in `$TMPDIR`. SIGKILL cannot be trapped, so this cannot be prevented. Checklist item 6 claims none are left; correct its wording. Harmless.
- G3: GC roots are tested only with a stub `nix-store`. Check 2 below used the real binary on a chroot store.
- G4: no test for a failed Brave release backup.

## Other checks
1. **Rollback lock and `.failed` copies — verified (isolated).**
   - Probe 1b: while an apply was paused mid-PREPARE, a rollback got exit 5, and the profile, lock, `last-run`, run record, state tree, HEAD and stub-call count were all unchanged.
   - Probe 1c (mkdir mode): exit 5, owner and `rm -rf` hint printed, `lock.d` kept.
   - Probe 1d′ (linux-cli, R4-01): Brave showed "never wrote it", the foreign 7.7.7 was kept, and only `nix/flake.lock` was committed as `chore(nix): roll back flake inputs`.
   - `.failed` copies: `<id>.flake.lock.failed` held the new lock, and it survived a second rollback.
2. **GC roots — verified (isolated).** Real `nix-store` 2.34.7 with `--store local?root=$S/e2/chroot`, substituters disabled:
   - root symlink at `gcroots/<id>/hm` pointing to `hm_path_before`;
   - indirect root registered in `chroot/nix/var/nix/gcroots/auto`, and listed by `--gc --print-roots`;
   - after `--gc`, `hm_path_before` survived while an unrooted control path was collected;
   - a root younger than 14 days survived the next run plus GC; one aged 20 days was removed by the next apply and its path was collected;
   - with `KEEP_DAYS=0`, the current run's root was kept.
   - The real `/nix/store` was never collected.
3. **No lock commit after a failed verify — verified (isolated)** (probe 3).
   - `--skip-verify`: `runtime_verified=0`, `verify-skipped`, and the commit body says "Not runtime-verified: applied with sys-update --skip-verify."
   - linux-cli and wsl: `runtime_verified=n/a`, "no runtime verification gate for …" (checklist item 7).
   - Note: when MIME cannot be judged (a tty or an empty query), the record still says `runtime_verified=1` and the run commits with a warning. So the gate is only real in a graphical session (condition C3).
4. **Re-exec — verified (isolated)** (probe 4a, with a bare upstream and a pushed new updater):
   - the child printed the new version's marker with the same pid and run id;
   - one log and one record, one `run_id=` line; the log holds both the parent and child parts;
   - a separate `flock -n` during the child's step saw HELD; free afterwards;
   - "repo was at <old>" printed; tree clean.
   - A forged `SYS_UPDATE_RUN_ID` with a bad argument → exit 2 and no record.
5. **VERIFY gate prerequisites — reasoned, then needs a real machine.**
   - `brave --version` must run.
   - `xdg-mime` must be on PATH.
   - `xdg-mime query default` must return `brave-browser.desktop` for `x-scheme-handler/http`, `x-scheme-handler/https`, `text/html` and `application/pdf`.
   - The gate is hard only when `WAYLAND_DISPLAY` or `DISPLAY` is set, or `XDG_SESSION_TYPE` is set and not `tty`.
   - User files such as `~/.config/*-mimeapps.list` can override the declared defaults.
   - Read-only on this host now: all four types return Brave; the session is GNOME Wayland; `~/.config/mimeapps.list` exists.
6. **Recovery docs — reasoned; covered, with gaps (non-blocking; owner: docs/implementer).**
   - Covered: rollback, moved profile ("names sys-update rollback"), exit 5, the GC root and `KEEP_DAYS`, macOS "manual".
   - Gaps:
     - `install.md` says that if the update was committed, rollback "prints the `git commit --only` / `git checkout HEAD --` choices". The code actually auto-commits the rollback when the restored files were clean.
     - No doc covers recovering from SIGKILL (G1).
     - Stale-lock steps exist only in the refusal message (flock: kill the stray process; mkdir: the printed `rm -rf`).
     - The `flake.lock` backup and `.failed` paths (`~/.local/state/sys-update/runs/<id>.flake.lock[.failed]`) are not documented. They are printed at rollback time.
     - The Nix 2.4 or newer requirement is not documented. Older Nix fails closed at the GC root step.
     - The macOS hint `sudo <path>/activate` does not move the system profile (untested; R4-05).
7. **Open notes:**
   - R4-02 (guarded rm, clear `SNAPSHOT_ERR`): non-blocking. The leftover `rm -f` targets an already-deleted random `mktemp` name.
   - R4-03 (no `nix-env` stub in `update-all-recovery.bats`): non-blocking for deployment. It is a test-hygiene risk only, and only against scratch profile paths.
   - R4-05 (macOS rollback leaves a dirty worktree): non-blocking for Linux. It would block a first macOS rollback, which is untested anyway.
   - R5-01 (an old record's rollback only switches the profile): non-blocking only under condition C2. Real `last-run` today points at `runs/20261114T152437Z-2839963.meta`, which has no gcroot key. A rollback before a fresh apply would target it, so treat it as **blocks-first-rollback unless the runbook gate in H-4 holds**.
   - R5-02 (early-exit wording): non-blocking, wording only.
   - R5-03 (settle hint on the incomplete path): non-blocking. The H-5 checks catch a dirty tree.

## Verification Reviewed
- `bash ops/ci-local.sh`: whole repository, fresh detached worktree `$S/wt` (0 untracked files), `TMPDIR` under scratch, no timeout. Ran by me in 78 s; exit 0; PASS for validate-config, lint:shell, bats (1..1130, 0 not ok), `nix flake check`, `nix flake check --all-systems --no-build`, linux activation build (the default linux-cli and wsl only; linux-desktop is not built in CI, so it is `unknown` until H-2).
- `bash ops/run-bats.sh -f 'every entry-point script answers --help' tests/bash/arg-contract.bats`: same worktree, developer PATH. Ran by me: not ok (`components-local.sh --help` exited 1).
- `bash ops/doctor.sh` in the worktree: rc 0, gitleaks found.
- Filtered `run-bats.sh -f` reruns gave 0 not ok, but bats warned "Executed N instead of expected" (a test-dir collision in parallel mode). I relied on the CI run for the named results.
- Scratch probes (by me, scratch `audit-t0010-3940977/{e1a…e4-*}`, scripts in `…/h/`): t1-rollback, t1b, t2-gcroot, t3-verify, t4-reexec, t4-signals and t4-signals2. My first SIGINT attempt was an artefact (SIGINT is ignored in background jobs); the rerun used `env --default-signal=INT`. No probe wrote outside scratch.
- `unknown`: GitHub CI status for `af13fb0`; a real host apply or rollback; macOS.

## Required Verification Before Release (human, separately authorised)
These are the supervised steps H-1 to H-5. Run them in **bash** inside the GNOME Wayland session, from `~/Projects/app-configs`, with `D=~/.local/state/sys-update; P=~/.local/state/nix/profiles/home-manager`. Commands marked [RO] are read-only; [SC] changes state.

**H-1 Pre-checks [RO].** Stop if any of these fail.
1. `git status --short` must be empty. Today the 6 untracked T-0029…T-0033 and research paths make it non-empty; their owning session must settle them. Never stash another session's work.
2. `git rev-parse HEAD; git ls-remote origin refs/heads/main` must both show `af13fb0…`. If origin moved, the run re-execs into code this audit did not cover: stop.
3. `nix --version` must be 2.4 or newer (2.34.7 now). `df -h /nix` must show at least 10 GiB free (324 GiB now).
4. No other agent session may be active on this repo (`git worktree list`, and ask). `flock -n $D/lock true && echo free` must print `free`.
5. Take your usual home or filesystem backup (the method is unknown here). Also run `mkdir -p ~/sys-update-audit && cp nix/flake.lock nix/packages/brave/release.json ~/sys-update-audit/`.
6. Record a baseline:
   - P0=`readlink -f $P`; N0=`readlink $P` (now `home-manager-109-link`);
   - H0=`git rev-parse HEAD`;
   - L0/B0=`git hash-object nix/flake.lock nix/packages/brave/release.json`;
   - OLD=`cat $D/last-run`.
7. `bash ops/update-all.sh` must exit 0 with no `✗` (report mode, no lock).
8. `brave --version` must work, and `for m in x-scheme-handler/http x-scheme-handler/https text/html application/pdf; do xdg-mime query default $m; done` must print `brave-browser.desktop` four times. `echo $WAYLAND_DISPLAY` must not be empty.

**H-2 Apply [SC].** Run `bash ops/update-all.sh --apply` (the same as `sys-update`). Answer `y`. Do not pass `--skip-verify` or `--gc`.
- Expected: exit 0, with these lines:
  - `✓ gc root  Home Manager generation pinned`
  - `✓ home-manager  generation <N0+1>`
  - `✓ default browser  Brave (HTTP, HTTPS, HTML, PDF)`
  - `✓ flake.lock  committed (<sha>)`
  - final `updated and verified` (or `with warnings`; read each one).
- Stop if: any `✗`; exit ≠ 0; `failed:verify` (choose `sys-update rollback`, then H-5); "the profile moved … roll back" (run H-4 straight away).
- If the output says "already current" or "generation … unchanged", the rollback will only prove "already on generation". Decide before going on.

**H-3 Post-apply checks [RO].**
1. `M=$(cat $D/last-run)` must differ from OLD (R5-01 gate). `grep -E '^(run_id|host|hm_path_before|gcroot|runtime_verified|exit_code)=|^status=' $M | tail -8` must show: `host=linux-desktop`, `hm_path_before=`P0, `gcroot=$D/gcroots/<id>/hm`, `runtime_verified=1`, last status `done`, `exit_code=0`.
2. `readlink $D/gcroots/<id>/hm` must equal P0. `nix-store --gc --print-roots | grep sys-update/gcroots` lists it; `--print-roots` only lists and never collects.
3. `readlink -f $P` must differ from P0.
4. `git log -1 --format='%h %s'` must show `chore(nix): update flake inputs`, `git status --short` must be empty (the hooks passed), and `git log --oneline origin/main..HEAD` must show 1 commit. **Do not push.**
5. Human VERIFY: `xdg-open https://example.org` must open Brave. Opening a local PDF must open Brave.

**H-4 Rollback of the fresh run [SC, separate approval].**
- Gate: `cat $D/last-run` must still equal the M from H-3. Otherwise stop: an old record is targeted (R5-01).
- Run `bash ops/update-all.sh rollback` and answer `y`.
- Expected, exit 0:
  - `ROLLBACK · <fresh id>`, `run status  done`
  - `✓ home-manager  generation <N0> is active again`
  - `✓ flake.lock  restored` (and `✓ Brave release  restored` if it changed)
  - `✓ locks  committed (<sha>)`
  - `✓ rollback  done`
- Stop if: exit 1 or `incomplete`; any `left in place` (a newer edit exists, so settle it with the printed choices and do not force); exit 5 (another run holds the lock: wait for it, never delete `$D/lock`).

**H-5 Post-rollback checks (the user's stop condition) [RO].**
1. `readlink -f $P` must equal P0, and `readlink $P` should be `home-manager-<N>-link` pointing at P0.
2. `git hash-object nix/flake.lock nix/packages/brave/release.json` must equal L0 and B0.
3. `git log -2 --format=%s` must show `chore(nix): roll back flake inputs`, then the update commit. `git diff H0 HEAD --stat` must be empty: no newer edits lost, and nothing else landed. If other commits appear, confirm their content is unchanged.
4. `git status --short` must be empty (the rollback commit's hooks passed). `grep '^status=' $M | tail -1` must show `status=rolled-back`.
5. `readlink $D/gcroots/<id>/hm` must still equal P0 (the root is kept). `ls $D/runs/<id>.flake.lock.failed` must exist.
6. `flock -n $D/lock true && echo free`, then `bash ops/update-all.sh` must exit 0 with `worktree clean` and no lock message. That shows the next sys-update can run. A second real apply would re-apply the update, so it needs its own decision.
7. chezmoi-managed dotfiles are not rolled back. Restore them by hand only if needed, with the printed `cp -a <snapshot>/. ~/`.
8. The two local commits stay unpushed. Pushing or dropping them is the user's decision.

**Send back:** the exit codes, the `✓`/`!`/`✗` lines, the H-3 and H-5 outputs, and the run id.

## Blocking Risks
None block pre-deployment. These conditions apply to the supervised run (owner: the operator, i.e. the user):
- **C1:** a clean worktree (the 6 untracked paths belong to another session).
- **C2:** roll back only the fresh run (`last-run` must equal H-3's M).
- **C3:** run in the graphical session, otherwise the MIME gate is only advisory.
- **C4:** no concurrent agent sessions on the repo during H-2 to H-5.

Non-blocking follow-ups:
- G1 to G4 tests (implementer).
- Doc drift in item 6 (implementer/docs).
- The scenario-2 exit and wording question (reviewer).
- R4-02, R4-03, R4-05, R5-02, R5-03 (implementer).
- Tick `plan.md` against the recorded evidence (plan-writer).
- #29 (owner of the parallel branch).

## Recommended Next Step
Ask the user for separate authorisation to run H-1 to H-5 on linux-desktop. Record the final release verdict from the H-5 evidence. Send G1 and G4 plus the doc fixes to `implementer`, and the scenario-2 reporting question to `reviewer`.
