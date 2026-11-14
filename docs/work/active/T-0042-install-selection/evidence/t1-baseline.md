# T-0042 T1: baselines and the selection-input spike

Gate evidence for AC0. Nothing in nix/ was changed in the repository; the spike ran in a
scratch copy.

## Environment

- Date: 2026-11-14
- HEAD (base): 972422faeabfdf0d5f42272c7ab692f3664190ad
- Nix: nix (Nix) 2.34.7 (from `nix --version`)
- Home Manager: 26.11-pre (from `home-manager --version`)
- nix-darwin locked rev: ff0e21a414d4547183396da1b44a66f2577b65e9
- Repository flake.lock sha256 (unchanged for the whole task):
  14e717638923efa6d6309b6e6660854dbc6b70c5f04ab8eed1424cc3d0178090
- Spike copy (kept for the reviewer, outside the repository): scratchpad directory
  t42-spike-HkQnp5 (a git repo with commits base, spike: selection input,
  spike: probe consumer), override dir t42-spike-ov-dir beside it.
- Spike flake.lock sha256 after the one lock write:
  44847d34cfeb9d8e119e22934bcf8a12d97bc3b3187cd4c09088c4c15a61ceee

## 1. Baseline drvPaths at HEAD

The flake exposes `homeConfigurations.{linux-desktop,linux-cli,wsl,macos}` and
`darwinConfigurations.macos`. All five evaluate from this x86_64-linux host
(aarch64-darwin drvPath evaluation needs no builder). Command, run from the repository
root with P set to each name:

```
nix eval --raw "path:$PWD/nix#homeConfigurations.$P.activationPackage.drvPath"
nix eval --raw "path:$PWD/nix#darwinConfigurations.macos.system.drvPath"
```

| output | drvPath |
| --- | --- |
| homeConfigurations.linux-desktop | /nix/store/9vz288c6ym5x5pijxnpkc4sp9r7g997j-home-manager-generation.drv |
| homeConfigurations.linux-cli | /nix/store/mbpxd5hmx572s9kakj3h15h3dls8svyk-home-manager-generation.drv |
| homeConfigurations.wsl | /nix/store/mbpxd5hmx572s9kakj3h15h3dls8svyk-home-manager-generation.drv |
| homeConfigurations.macos | /nix/store/97njhnqb61dvif72l6r5yv2c3458f9m6-home-manager-generation.drv |
| darwinConfigurations.macos.system | /nix/store/9lacxzqbh0zsbcdlvns577raqvk9dz1l-darwin-system-26.11.ff0e21a.drv |

Facts:
- linux-cli and wsl have the same drvPath today. An AC1 comparison therefore cannot tell
  those two apart.
- The same drvPaths come out of a `path:` ref and a `git+file://...?dir=nix` ref of a
  git copy of HEAD (linux-desktop checked under both, darwin under git+file), so the
  ref kind does not enter the drvPath.
- The repository flake.lock sha256 was identical before and after these runs.

## 2. Mechanism spike (scratch copy)

Setup, in a private directory SP: `git archive HEAD | tar -x`, `git init`, commit. Then:
- nix/flake.nix inputs gain
  `selection = { url = "path:./selection"; flake = false; };` after nix-openclaw;
- a new empty file selection.toml inside a new selection directory next to flake.nix;
- later (for the consumer probes only) one extra flake output
  `selectionProbe = builtins.fromTOML (builtins.readFile (inputs.selection + "/selection.toml"));`
  The probe was added only after clause (f) was measured.
- Override dir OV holds selection.toml with
  `profile = "personal"` and a `[groups]` table with `media = false`.

### (a) Relative input under bare and path: refs

- Untracked new file, bare ref, `nix eval --raw "./nix#...drvPath"` in the git copy:
  evaluates, prints `warning: Git tree ... is dirty` and
  `warning: updating lock file`, `Added input 'selection': 'path:./selection'`. Nothing
  read the input here, so this does not show the file is visible.
- After `git add` and again after commit: bare `./nix` ref, `path:$SP/nix` ref and
  `git+file://$SP?dir=nix` ref all evaluate with no lock warnings.
- `nix flake check ./nix` on the committed spike: "all checks passed!" (x86_64-linux;
  aarch64-darwin omitted as incompatible, as at baseline).
- Reading the file from an untracked path under a bare git ref FAILS. After
  `git rm --cached` of the toml: `nix eval --json "./nix#selectionProbe"` errors with
  the standard "To make it visible to Nix, run: git add ..." message. The same file
  under a `path:$SP/nix` ref evaluates (`{}`).

Verdict: PROVEN for committed (tracked) files under bare, `path:` and `git+file` refs.
Documented hazard: an untracked selection file is invisible to git refs.

### (b) What the lock gains

`git diff` of nix/flake.lock after the first evaluation, 13 inserted lines, 0 removed:
- root inputs gain `"selection": "selection"`;
- a new node:
  `"selection": { "flake": false, "locked": { "path": "./selection", "type": "path" }, "original": { "path": "./selection", "type": "path" }, "parent": [] }`.

The node has no narHash, no lastModified and no rev. Changing the content of the
tracked selection.toml (to `profile = "work"`), under both a `path:` ref and the dirty
bare git ref, left the lock sha256 unchanged (44847d34...). The lock does not churn when
the file changes.

Verdict: PROVEN. Only the node and its root input are added; the node is content-stable.

### (c) --override-input

All with an absolute-path override `path:$OV`:
- `nix eval --json "./nix#selectionProbe" --override-input selection path:$OV`, the
  same with a `path:$SP/nix` ref and with `git+file://$SP?dir=nix`:
  all print `{"groups":{"media":false},"profile":"personal"}`.
- `nix eval --pure-eval ...` the same: `{...}` with no `--impure` anywhere.
- `nix build --no-link --dry-run "path:$SP/nix#homeConfigurations.linux-cli.activationPackage" --override-input selection path:$OV`
  succeeds.
- `home-manager build --flake "path:$SP/nix#linux-cli" --override-input selection path:$OV`
  built and linked a generation (run from a scratch directory because home-manager
  writes ./result); the same with `--flake "./nix#linux-cli"` from the spike. The
  home-manager script at /nix/store/244wxpdn0r4i12hmw88d8v8dv815g8jr-home-manager
  collects `--override-input` into PASSTHROUGH_OPTS (lines 1160-1164) and appends it to
  its nix calls. The `home-manager build` command has no `-o` option; it links ./result
  in the current directory, and `--no-out-link` (mapped to `--no-link`) skips the link.
- darwin-rebuild is not installed here and cannot run on Linux. Code-inspected in the
  pinned nix-darwin source (rev ff0e21a4...), file pkgs/nix-tools/darwin-rebuild.sh:
  `--override-input` is case-handled (lines 98-102) into extraLockFlags, and the build
  is `nix build --json "${extraBuildFlags[@]}" "${extraLockFlags[@]}" -- "$flake#$flakeAttr.system"`
  (lines 197-199). So the flag reaches `nix build`. Real run is the AC14 human check.

Verdict: PROVEN for nix eval, nix build and home-manager build. darwin-rebuild: code
inspected only, runtime unknown (AC14).

### (d) flake.lock after override runs; warnings

- Spike lock sha256 before the override runs and after all of them (nix eval x5 refs,
  nix build dry-run, home-manager build x2, store-path refs):
  44847d34cfeb9d8e119e22934bcf8a12d97bc3b3187cd4c09088c4c15a61ceee, identical. `git status`
  in the spike stayed clean.
- Nix prints, on stderr, for every override run, a block
  `warning: not writing modified lock file of flake '...'`, `Updated input 'selection':`,
  the old and new ref with `lastModified` and `narHash` of the override dir. With an
  explicit `--no-write-lock-file` the "not writing modified lock file" line is still
  printed (correction after review: it was counted in all 8 flag combinations on Nix
  2.34.7), together with the "Updated input" lines. So `--no-write-lock-file` is not
  needed for safety (override already implies it, matching the ticket) and it does not
  silence the noise.
- Design fact: scripts that parse nix stderr, or tests asserting empty stderr, will see
  this block whenever a local selection is in use.

Verdict: PROVEN (lock byte-identical; warnings are cosmetic).

### (e) builtins.fromTOML in pure evaluation

`builtins.fromTOML (builtins.readFile (inputs.selection + "/selection.toml"))` returned
`{}` for the empty committed file, and the override file's contents
(`{"groups":{"media":false},"profile":"personal"}`) under `nix eval --pure-eval`. No
`--impure` was used anywhere.

Verdict: PROVEN.

### (f) drvPaths with the input added and nothing consuming it

Spike committed state, refs `path:$SP/nix` (all five) and bare `./nix` (all five):
every drvPath equals the section 1 baseline exactly, including darwin. The same five
with `--override-input selection path:$OV` and no consumer are also equal to the
baseline (the override does not enter the drvPaths by itself). The drvPaths were
not re-measured after adding the selectionProbe output (unknown).

Why equal (inferred, not separately tested): nothing in the existing modules reads
`self.outPath` or the flake source path, and the HM and darwin generations do not
embed the flake source. A consumer that did, would change drvPaths.

Verdict: PROVEN for AC1's "adding the input changes no activation drvPath" premise.
The T2 code that reads the TOML must keep `selection = {}` semantics exact when the
file is empty, or AC1 breaks at that point instead.

### (g) Nix version and ref behaviour of a relative path: input

- Tested on Nix 2.34.7 only. Minimum version that supports it: unknown (not tested on
  other versions). The Determinate Nix on macOS is not tested here (AC14).
- `path:$PWD/nix` ref: relative `./selection` resolves to the directory next to
  flake.nix; works.
- Bare git ref `./nix` and `git+file://...?dir=nix`: resolves inside the git tree and
  works for tracked files only (see (a)).
- Store-path ref, `path:/nix/store/...-source` (the copy `nix flake metadata --json`
  reports for the flake): the input resolves inside the store copy (default file read,
  `{}`) and `--override-input` works on it
  (`{"groups":{"media":false},"profile":"personal"}`).
- In all refs the relative input lock entry has no hash (see (b)).

Verdict: PROVEN on 2.34.7 for path:, git and store refs; older versions unknown.

## 3. AC0 verdicts

| AC0 clause | verdict |
| --- | --- |
| baseline drvPaths for 4 activation packages and darwin system recorded | proven |
| relative input evaluates under bare ref | proven (tracked files) |
| relative input evaluates under path: refs | proven |
| --override-input works with nix build | proven |
| --override-input works with home-manager build --flake | proven |
| --override-input through darwin-rebuild | unknown at runtime; code-inspected only (AC14) |
| nix/flake.lock byte-identical after override runs | proven |

## 4. Facts that bear on the design (no redesign proposed)

1. linux-cli and wsl share a drvPath today; AC1 equality cannot distinguish them.
2. The lock gains one 13-line node with no hash. No lock churn on content change.
3. An untracked selection file is invisible to git refs and visible to `path:` refs
   (confirmed by failure message). The committed default is tracked, so the default
   path is safe; the repository-local file must stay tracked.
4. Every override run prints a lock-update warning block on stderr, with or without
   `--no-write-lock-file`.
5. darwin-rebuild behaviour, and minimum Nix version, are unverified.
6. The home-manager `build` subcommand cannot take `-o`; it links ./result in the
   current directory unless `--no-out-link` is passed.
7. Adding the input changes no drvPath, but only while nothing consumes it; any T2
   consumer must keep an empty file equal to no selection.
