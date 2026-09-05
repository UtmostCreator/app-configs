# Verdict

> **TRIAGE COMPLETE — REFERENCE ONLY.**
> Every item in this document has been adjudicated and folded into
> `repo-docs/nvim-migration-plan.md` (v3), which is the single source of truth.
> Do not implement from this file. Status markers below record each decision.
> Triaged: 2026-07-25.

> **STATUS: ACCEPTED** — folded into `repo-docs/nvim-migration-plan.md` (v3). No further action.

**Do not implement either plan unchanged.** Your plan is substantially stronger on inventory, repository integration, language coverage, rollout, and learning. My earlier plan was safer around key conflicts and terminal behaviour, but it was too plugin-heavy and lacked reproducibility and acceptance-test design.

| Plan                  | Coverage | Technical correctness | Conflict safety | Reproducibility | Verification |    Overall |
| --------------------- | -------: | --------------------: | --------------: | --------------: | -----------: | ---------: |
| My earlier mapping    |       87 |                    81 |              84 |              62 |           55 | **76/100** |
| Your migration plan   |       96 |                    76 |              63 |              79 |           61 | **79/100** |
| Corrected merged plan |       95 |                    94 |              93 |              91 |           94 | **93/100** |

**Benchmark:** 90+ is production-ready; 80–89 needs bounded corrections; below 80 should not be implemented as one large change.

Your Neovim version claim is correct: **0.12.4 is currently stable**. However, this version also makes two architecture decisions important: use `vim.lsp.config()` rather than deprecated `require("lspconfig").setup()`, and account for the rewritten `nvim-treesitter` main branch. ([GitHub][1])

# 1. Blocking keymap errors

> **STATUS: ACCEPTED** — folded into `repo-docs/nvim-migration-plan.md` (v3). No further action.

These are actual collisions inside the proposed plan, independent of Vim defaults.

| Severity     | Key                     | Competing actions                                    | Required resolution                                              |
| ------------ | ----------------------- | ---------------------------------------------------- | ---------------------------------------------------------------- |
| **Critical** | `Ctrl+Alt+B`            | Definition and implementation                        | Keep implementation; definition becomes `gd` and `<leader>ld`    |
| **Critical** | `Ctrl+Alt+D`            | Duplicate line and peek definition                   | Keep peek definition; duplicate becomes `<leader>ed`             |
| **Critical** | `Ctrl+Alt+W`            | Select word and expand selection                     | Select word only; expand through Visual `Ctrl+W` or `<leader>ve` |
| **Critical** | `Ctrl+Alt+L`            | Format and focus right window                        | Keep format; windows use `Ctrl+H/J/K/L`                          |
| **Critical** | `Ctrl+Alt+J`            | Select all occurrences and focus lower window        | Keep multi-cursor; windows use `Ctrl+H/J/K/L`                    |
| **Critical** | `Alt+Shift+Up/Down`     | Move line and Git hunk navigation                    | Keep Git hunks; line movement uses `Ctrl+Shift+Up/Down`          |
| **Critical** | `Ctrl+Alt+Shift+Arrows` | Pane resize and add cursor                           | Keep multi-cursor; pane resize uses `<leader>w`                  |
| **High**     | `Ctrl+Enter`            | Insert line and stage hunk                           | Insert in Normal/Insert; stage only in Visual                    |
| **High**     | `Ctrl+Alt+Enter`        | Insert above and unstage hunk                        | Insert in Normal/Insert; unstage only in Visual                  |
| **High**     | `<leader>r`             | Replace and Run namespace                            | Replace becomes `<leader>sr`; `<leader>r` remains Run            |
| **High**     | `<leader>a`             | Select all and AI namespace                          | Select all becomes `<leader>va`; `<leader>a` remains AI          |
| **High**     | `Tab`                   | Completion, snippet jump, Copilot, NES, indentation  | Requires one central dispatcher                                  |
| **High**     | `Esc`                   | Clear search, close popup, dismiss AI, clear cursors | Requires one central dispatcher                                  |

`multicursor.nvim` supports mappings that activate only while multiple cursors exist. Use that layer for cursor-state-specific actions instead of registering globally conflicting mappings. ([GitHub][2])

## Correct window policy

> **STATUS: ACCEPTED** — `Ctrl+W` stays the native Normal-mode window prefix; expand-selection is Visual-mode `Ctrl+W` plus `<leader>ve`. Folded into `repo-docs/nvim-migration-plan.md` (v3). No further action.

| Action                       | Final key                    |
| ---------------------------- | ---------------------------- |
| Focus left/down/up/right     | `Ctrl+H/J/K/L`               |
| Fallback window navigation   | `<leader>wh/wj/wk/wl`        |
| Format                       | `Ctrl+Alt+L`                 |
| Select all occurrences       | `Ctrl+Alt+J`                 |
| Resize                       | `<leader>wH/J/K/L`           |
| Native window command prefix | Keep `Ctrl+W` in Normal mode |

This removes the largest contradiction between both plans.

# 2. Several “native Vim” mappings are incorrect

> **STATUS: ACCEPTED** — additionally confirmed against official Neovim 0.12 docs; also note `Ctrl+]` is native goto-definition via `tagfunc` and must not be remapped in Normal mode. Folded into `repo-docs/nvim-migration-plan.md` (v3). No further action.

Neovim 0.12 provides these built-in LSP mappings:

| Action          | Correct Neovim 0.12 mapping | Incorrect value in plan |
| --------------- | --------------------------- | ----------------------- |
| Code action     | `gra`                       | —                       |
| Implementation  | `gri`                       | `gI`                    |
| Rename          | `grn`                       | —                       |
| References      | `grr`                       | `gr`                    |
| Type definition | `grt`                       | `gy`                    |
| Code lens       | `grx`                       | —                       |

`gI` means insert at the first column; it does not mean implementation. The current built-in LSP mappings are documented by Neovim. ([Neovim][3])

Other semantic corrections:

| Existing claim                        | Problem                                                                                  | Correction                                                                                 |
| ------------------------------------- | ---------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------ |
| `g-` = cursor undo                    | `g-` traverses older **text states** in the undo tree                                    | No exact native cursor-undo equivalent; use `g;`/`g,` for changes and `Ctrl+O/I` for jumps |
| `` `. `` = global last edit           | It is buffer-local and not equivalent to VS Code’s cross-file history                    | Use change list plus recent/jump picker                                                    |
| `Ctrl+Shift+U` = toggle case          | Your VS Code source uppercases a selection but lowercases without a selection            | Preserve those exact context semantics or explicitly redesign it                           |
| `Ctrl+Shift+T` = reopen closed editor | A recent-file picker does not restore an unsaved deleted buffer or complete editor state | Mark as **approximate**, not exact                                                         |
| `Alt+Up/Down` = breadcrumb navigation | Both VS Code bindings invoke the same focus command                                      | Treat as “focus breadcrumbs”, not previous/next breadcrumb                                 |

# 3. The 88.2% parity figure is overstated

> **STATUS: ACCEPTED** — folded into `repo-docs/nvim-migration-plan.md` (v3). No further action.

The correct wording is:

> **88.2% are syntactically expressible as Neovim mappings. Their reliable transport rate is unknown until terminal, tmux, and desktop interception are tested.**

Modern Neovim can negotiate CSI-u or `modifyOtherKeys`, allowing terminals to distinguish combinations such as `Ctrl+I` from `Tab` and some shifted control keys. This depends on terminal support and can still be affected by tmux and terminal-owned bindings. ([Neovim][4])

## Key transport classes

| Class                       | Examples                                                     | Policy                                                            |
| --------------------------- | ------------------------------------------------------------ | ----------------------------------------------------------------- |
| **A: reliable**             | Leader sequences, ordinary function keys, normal letters     | May be primary                                                    |
| **B: capability-dependent** | `Ctrl+Shift+N`, `Shift+Enter`, `Ctrl+Shift+\`, keypad chords | Must have leader fallback                                         |
| **C: host-intercepted**     | `Alt+F2`, terminal new-tab/copy bindings                     | Must be unbound at GNOME/Ghostty level or relocated               |
| **D: impossible directly**  | `Shift Shift`                                                | Use `<leader><leader>` or OS remap to an unused key such as `F13` |

`Shift Shift` is not solved by adding Neovide. A bare modifier normally does not produce an editor key event. Keep `<leader><leader>` as the canonical shortcut; an OS-level remapper may emit `F13` for double Shift if exact muscle memory is essential.

On your GNOME system, **`Alt+F2` is already the global Run Command shortcut**, so it will not reliably reach Neovim unless you disable or remap it. ([GNOME Help][5])

Ghostty can also consume bindings before the PTY receives them. Its `unbind` and `unconsumed` facilities should be part of the migration, not treated as unrelated terminal configuration. ([Ghostty][6])

## Add Phase 0: key transport certification

Create a `:KeyProbe` command and test every non-leader shortcut through this chain:

```text
Physical keyboard
  → GNOME
  → Ghostty
  → tmux, if active
  → Neovim input decoder
  → final mapping
```

Each mapping record should carry:

```text
transport = reliable | extended | host_reserved | unavailable
fallback  = <leader>...
verified  = linux_ghostty | macos_ghostty | neovide
```

No parity percentage should be published before this probe.

# 4. Mode-scoped layering has real costs

> **STATUS: ACCEPTED** — folded into `repo-docs/nvim-migration-plan.md` (v3). No further action.

Your central strategy remains correct, but this sentence is inaccurate:

> “Put Ctrl+C/V/X/A/S/Z in Insert and Visual modes only, where Vim barely uses them.”

Several are meaningful in those modes:

| Key             | Native Insert/Visual responsibility displaced |
| --------------- | --------------------------------------------- |
| Insert `Ctrl+V` | Insert the next character literally           |
| Insert `Ctrl+X` | Completion-family prefix                      |
| Insert `Ctrl+A` | Reinsert previously inserted text             |
| Insert `Ctrl+Z` | Suspend editor                                |
| Visual `Ctrl+V` | Switch to blockwise Visual mode               |
| Insert `Ctrl+S` | Built-in LSP signature help in current Neovim |

The approach can still be used, but add a **displaced-key ledger**.

| IDE operation     | Primary        | Native capability fallback                                    |
| ----------------- | -------------- | ------------------------------------------------------------- |
| Insert paste      | `Ctrl+V`       | Literal insertion relocated to `Ctrl+Q` where supported       |
| Visual paste      | `Ctrl+V`       | Block selection always starts from Normal `Ctrl+V`            |
| Undo              | `Ctrl+Z`       | `u` in Normal                                                 |
| Redo              | `Ctrl+Shift+Z` | `Ctrl+R` in Normal                                            |
| Completion family | Blink UI       | Native `Ctrl+X` family documented but intentionally displaced |

Insert-mode undo also requires explicit undo boundaries. Neovim treats an Insert session as an undo block unless mappings add `Ctrl+G u` boundaries. Cursor and paste mappings must preserve correct undo granularity. ([Neovim][7])

# 5. The Visual Block example is off by one

> **STATUS: ACCEPTED** — corrected to `Ctrl+V 39j $ A; Esc` and re-described as "one short command sequence". Folded into `repo-docs/nvim-migration-plan.md` (v3). No further action.

To modify **exactly 40 lines**, starting on the first line:

```text
Ctrl+V
39j
$
A;
Esc
```

`40j` selects the current line plus 40 additional lines, meaning **41 lines**. The `$A…Esc` mechanism itself is correct and is the proper way to append to ragged line endings. ([Neovim][8])

It is also more than “six keystrokes” when individual count digits and commands are counted. Describe it as **one short command sequence**, not a measured six-keystroke operation.

# 6. Capability ownership is the most important missing architecture

> **STATUS: ACCEPTED** — folded into `repo-docs/nvim-migration-plan.md` (v3). No further action.

Your plan repeatedly assigns one responsibility to multiple systems. That creates duplicate diagnostics, duplicate completions, competing edits and unstable save behaviour.

## Final ownership matrix

| Capability          | Primary owner                                        | Secondary policy                                                                                         |
| ------------------- | ---------------------------------------------------- | -------------------------------------------------------------------------------------------------------- |
| Completion UI       | `blink.cmp`                                          | No second completion menu                                                                                |
| PHP intelligence    | Intelephense                                         | Phpactor used for explicit refactor/code-generation commands, not overlapping completion and diagnostics |
| Vue and TypeScript  | `vue_ls` + `vtsls` in supported hybrid configuration | Do not run two independent TypeScript completion providers for Vue                                       |
| Formatting          | Conform                                              | LSP formatting only as explicit fallback                                                                 |
| ESLint diagnostics  | ESLint LSP **or** `nvim-lint`, not both              | Prefer ESLint LSP                                                                                        |
| Ruff diagnostics    | Ruff LSP **or** `nvim-lint`, not both                | Prefer Ruff LSP                                                                                          |
| PHP static analysis | PHPStan through `nvim-lint`/task                     | Keep separate from ordinary language-server diagnostics                                                  |
| Git hunks           | Gitsigns                                             | LazyGit handles repository operations                                                                    |
| Repository Git UI   | LazyGit                                              | Diffview only for history/diff workflows                                                                 |
| Explorer            | Snacks Explorer                                      | Oil optional for bulk filesystem editing                                                                 |
| Search              | Snacks picker                                        | Grug-far only for replacement                                                                            |
| Folding             | Neovim Tree-sitter fold expression first             | Add UFO only after demonstrating a missing feature                                                       |
| AI NES              | Sidekick                                             | Do not enable a competing NES engine                                                                     |
| AI CLI              | Sidekick terminal                                    | CopilotChat optional, not baseline                                                                       |
| Tests               | Neotest adapters detected per project                | Overseer fallback for unsupported runners                                                                |

Conform explicitly supports controlling whether LSP formatting runs and can stop after the first formatter. Use `lsp_format = "never"` where an external formatter is canonical, and `"fallback"` only where needed. `nvim-lint` describes itself as complementary to LSP for cases where a standalone linter adds something the LSP does not already provide. ([GitHub][9])

## PHP correction

> **STATUS: ACCEPTED** — folded into `repo-docs/nvim-migration-plan.md` (v3). No further action.

Running Intelephense and Phpactor as full overlapping LSP clients is not a safe default. Phpactor currently describes itself as a language server with useful code actions but also warns about performance, accuracy and maintainability limitations. Use:

```text
Intelephense:
  completion
  hover
  diagnostics
  navigation
  symbols

Phpactor:
  explicit refactoring
  code generation
  import-class operations
  project transforms
```

This can be achieved by invoking Phpactor as a command-line/refactoring backend or disabling its overlapping LSP capabilities. ([GitHub][10])

## Vue correction

> **STATUS: ACCEPTED** — folded into `repo-docs/nvim-migration-plan.md` (v3). No further action.

The plan must explicitly define how Vue and TypeScript servers cooperate. Running Vue language support and an independent TypeScript server incorrectly can generate duplicate completion results. ([GitHub][11])

# 7. `Tab` needs a formal arbitration chain

> **STATUS: ACCEPTED** — plus an `Esc` dispatcher, which this document correctly identified as missing. Folded into `repo-docs/nvim-migration-plan.md` (v3). No further action.

Your plan currently assigns `Tab` to:

- Completion selection or acceptance
- Snippet expansion/jumping
- Copilot suggestion acceptance
- Sidekick NES
- Normal indentation

Use one dispatcher:

```text
Insert-mode Tab priority
1. Sidekick NES is visible       → accept or advance NES
2. Completion menu is visible    → select/accept completion
3. Snippet jump is available     → jump to next placeholder
4. Copilot ghost text is visible → accept suggestion
5. Otherwise                     → insert indentation
```

`Shift+Tab` should similarly prioritise previous snippet/completion movement before outdenting.

Also preserve `Ctrl+P` contextually:

```text
Completion menu visible → previous completion item
Otherwise               → parameter/signature help
```

Without this dispatcher, completion and AI behaviour will feel random.

Sidekick does support Copilot NES and integrated terminals for several AI CLIs, but this does not mean all three AI plugins should independently own mappings and suggestion state. ([GitHub][12])

# 8. The plugin baseline is too large

> **STATUS: ACCEPTED** — three tiers adopted. Folded into `repo-docs/nvim-migration-plan.md` (v3). No further action.

The plan proposes approximately 30–40 plugins before proving the core editor. That increases failure radius and makes it difficult to identify whether a defect comes from Neovim, an LSP, a parser, or a plugin.

## Tier 1 — mandatory replacement core

| Area                     | Plugin                                |
| ------------------------ | ------------------------------------- |
| Package management       | lazy.nvim                             |
| Discoverability          | which-key.nvim                        |
| Picker/explorer/terminal | snacks.nvim                           |
| LSP configurations       | nvim-lspconfig using `vim.lsp.config` |
| Completion               | blink.cmp                             |
| Syntax                   | nvim-treesitter                       |
| Formatting               | conform.nvim                          |
| Lint integration         | nvim-lint                             |
| Git hunks                | gitsigns.nvim                         |
| Diagnostics UI           | trouble.nvim                          |
| Project replacement      | grug-far.nvim                         |

## Tier 2 — primary engineering workflows

| Area         | Plugin                         |
| ------------ | ------------------------------ |
| Tests        | neotest plus detected adapters |
| Debug        | nvim-dap, dap-ui               |
| Tasks        | overseer.nvim                  |
| Multi-cursor | multicursor.nvim               |
| Refactoring  | refactoring.nvim               |
| Git history  | diffview.nvim                  |
| Outline      | aerial.nvim                    |

## Tier 3 — install only after a demonstrated need

- Oil
- Harpoon
- UFO
- Octo
- Git-conflict
- Obsidian
- Markdown preview
- Todo-comments
- Persistence
- Hardtime
- Precognition
- CopilotChat
- Neovide

Neotest itself still calls the framework early-stage software and requires separate adapters; adapters should be enabled only when their runner and parser are available. ([GitHub][13])

# 9. Tree-sitter ownership is unresolved

> **STATUS: ACCEPTED** — Option A adopted (Nix owns plugin, parsers and the tree-sitter CLI). Folded into `repo-docs/nvim-migration-plan.md` (v3). No further action.

`lazy-lock.json` pins the plugin commit, but it does not by itself define a reproducible parser installation state.

The current `nvim-treesitter` main branch is a full incompatible rewrite for Neovim 0.12, is not intended for lazy loading, and expects parser versions to remain aligned with the plugin’s parser definitions. ([GitHub][14])

Choose one owner:

| Option | Plugin owner                                                   | Parser owner |                      Score |
| ------ | -------------------------------------------------------------- | ------------ | -------------------------: |
| A      | Nix                                                            | Nix          | **92/100 reproducibility** |
| B      | lazy.nvim                                                      | `TSUpdate`   |      **80/100 simplicity** |
| C      | lazy plugin + Nix parsers without explicit compatibility tests | Split        |                 **45/100** |

For your repository rules, choose **A**:

```text
Nix:
  nvim-treesitter plugin
  selected parser grammars
  tree-sitter CLI/compiler requirements

Lua:
  enable highlighting/folding
  configure filetype behaviour
```

Do not run `TSInstall` or `TSUpdate` against Nix-owned parsers.

# 10. Autosave should not use raw `CursorHold`

> **STATUS: ACCEPTED** — folded into `repo-docs/nvim-migration-plan.md` (v3). No further action.

`CursorHold` fires after `updatetime` with no Normal-mode input; `CursorHoldI` is separate for Insert mode. Neotest also uses `CursorHold`, so coupling autosave to it can create unrelated writes and confusing timing. ([Neovim][15])

Defer autosave until formatting is stable. Then use a guarded policy:

```text
Write on:
  FocusLost
  BufLeave
  optional debounced TextChanged

Never write:
  unnamed buffers
  readonly buffers
  terminal/help/prompt buffers
  files above the large-file threshold
  buffers with formatter currently running
```

Format-on-save plus aggressive autosave must not create repeated formatter churn.

# 11. “Zero unresolved extension gaps” is incorrect

> **STATUS: ACCEPTED** — five-status parity classification adopted. Folded into `repo-docs/nvim-migration-plan.md` (v3). No further action.

Use five parity statuses:

| Status     | Meaning                                 |
| ---------- | --------------------------------------- |
| Exact      | Same outcome and comparable interaction |
| Functional | Same core outcome, different workflow   |
| Partial    | Important capabilities missing          |
| Deferred   | Not required for cutover                |
| Gap        | No adequate replacement yet             |

Corrections:

| VS Code capability         | Correct status              | Reason                                                                                       |
| -------------------------- | --------------------------- | -------------------------------------------------------------------------------------------- |
| SonarLint                  | **Partial**                 | Semgrep is not SonarLint connected-mode parity                                               |
| Remote Containers          | **Gap/functional redesign** | `docker exec` alone does not provide remote LSP, debugger, task and filesystem orchestration |
| GitHub Actions extension   | **Partial**                 | `actionlint` validates YAML but does not provide run browsing, logs and dispatch UI          |
| Nuxt extension             | **Partial**                 | “Custom + LSP” is not a defined implementation                                               |
| Copilot agent mode         | **Partial**                 | CLI integration is useful but not identical to VS Code agent workflows                       |
| GitLens                    | **Functional**              | Gitsigns + Diffview + LazyGit cover most, but not every integrated view                      |
| Laravel extra intelligence | **Functional/partial**      | Must be verified feature by feature                                                          |
| Reopen closed editor       | **Approximate**             | Recent file is not restored editor state                                                     |

The official SonarQube MCP server may help AI agents query SonarQube, but it is not an inline replacement for SonarQube for IDE. ([GitHub][16])

# 12. Devcontainer design needs its own decision

> **STATUS: OPEN** — requires a user decision. Tracked in `nvim-migration-plan.md` (v3) "Open decisions".

There are three legitimate models:

| Model                                 | Description                                                      |                 Suitability |
| ------------------------------------- | ---------------------------------------------------------------- | --------------------------: |
| Neovim inside container               | Launch editor, LSPs and tools inside the devcontainer            |             **Best parity** |
| Local Neovim, container tool wrappers | Editor local; formatter/test/LSP commands invoke container tools | Good but more configuration |
| Plain `docker exec` when needed       | Manual commands only                                             |          Not VS Code parity |

Do not mark Remote Containers as solved until one real project passes:

- LSP navigation
- completion
- formatter
- test runner
- debugger
- clipboard
- Git operations
- project terminal

# 13. Use an isolated Neovim application during migration

> **STATUS: ACCEPTED** — `NVIM_APPNAME=nvim-ide`, config at `home/dot_config/nvim-ide/`. Folded into `repo-docs/nvim-migration-plan.md` (v3). No further action.

The rollback section should not instruct you to delete live configuration or data directories.

Neovim’s `NVIM_APPNAME` isolates configuration, data, state and cache directories. ([Neovim][17])

Use:

```bash
NVIM_APPNAME=nvim-ide nvim
```

Layout:

```text
~/.config/nvim/       # current minimal configuration
~/.config/nvim-ide/   # migration candidate
```

Cutover becomes an alias or chezmoi-profile change. Rollback becomes immediate and non-destructive.

# 14. Add security boundaries

> **STATUS: ACCEPTED** — extended to cover this repo's `home/.chezmoidata/personal.yaml` and `personal.local.yaml`. Folded into `repo-docs/nvim-migration-plan.md` (v3). No further action.

The plan currently allows project-local tasks, AI context, LSP commands and potentially `.nvim.lua`, but does not define trust.

Required controls:

| Area                      | Rule                                                                       |
| ------------------------- | -------------------------------------------------------------------------- |
| Project-local `.nvim.lua` | Enable only through Neovim’s trust mechanism                               |
| Shell execution           | Use `vim.system({ "cmd", "arg" })`, not concatenated shell strings         |
| Overseer tasks            | Do not automatically run repository tasks on directory entry               |
| AI context                | Exclude `.env`, secrets, credentials, generated databases and private keys |
| LSP executable            | Resolve from Nix/PATH allowlist                                            |
| Project overrides         | Review before `:trust`                                                     |
| Bruno environments        | Never place secret values in committed mappings/config                     |

Neovim 0.12 executes project-local configuration only after trust approval and recommends viewing the file before trusting it. ([Neovim][18])

# 15. Better configuration architecture

> **STATUS: ACCEPTED** — declarative keymap registry with duplicate `(mode, lhs)` rejection. Folded into `repo-docs/nvim-migration-plan.md` (v3). No further action.

Do not maintain mappings manually in both Lua and Markdown. Create a declarative registry and generate the documentation.

```text
home/dot_config/nvim-ide/
  init.lua

  lua/
    config/
      options.lua
      autocmds.lua
      capabilities.lua
      health.lua

    keymaps/
      registry.lua
      core.lua
      editing.lua
      navigation.lua
      terminal.lua
      plugins.lua
      dispatcher.lua

    lsp/
      init.lua
      ownership.lua
      php.lua
      web.lua
      go.lua
      python.lua
      nix.lua

    plugins/
      core.lua
      editing.lua
      git.lua
      test.lua
      debug.lua
      ai.lua
      extras.lua

    tests/
      startup.lua
      keymaps.lua
      ownership.lua
      formatting.lua
      lsp.lua
```

Each mapping entry:

```lua
{
  id = "format_document",
  modes = { "n", "x" },
  lhs = "<C-A-l>",
  fallback = "<leader>cf",
  group = "code",
  transport = "extended",
  action = function() end,
  requires = { "conform" },
  desc = "Format document or selection",
}
```

The loader should reject duplicate `(mode, lhs)` combinations unless an explicit priority/layer is declared.

# 16. Revised leader hierarchy

> **STATUS: ACCEPTED WITH CHANGE** — duplicate-line uses `<leader>cd`, not `<leader>ed`, because `<leader>e` is the Explorer namespace in this same hierarchy (internal inconsistency in the original). See `nvim-migration-plan.md` (v3). No further action.

| Prefix             | Category          |
| ------------------ | ----------------- |
| `<leader><leader>` | Search Everywhere |
| `<leader>a`        | AI                |
| `<leader>b`        | Buffers           |
| `<leader>c`        | Code/refactor     |
| `<leader>d`        | Debug             |
| `<leader>e`        | Explorer          |
| `<leader>f`        | Files             |
| `<leader>g`        | Git               |
| `<leader>h`        | HTTP/API          |
| `<leader>l`        | LSP               |
| `<leader>n`        | Notes             |
| `<leader>p`        | Projects          |
| `<leader>r`        | Run/tasks         |
| `<leader>s`        | Search/replace    |
| `<leader>t`        | Tests             |
| `<leader>u`        | UI toggles        |
| `<leader>v`        | Selection/Visual  |
| `<leader>w`        | Windows           |
| `<leader>x`        | Diagnostics       |
| `<leader>y`        | Clipboard/path    |
| `<leader>z`        | Folds/Zen         |

Corrections from the current hierarchy:

- Bruno/API moves from `<leader>a` to `<leader>h`.
- Replace moves from `<leader>r` to `<leader>s`.
- Select-all moves from `<leader>a` to `<leader>v`.
- Duplicate line becomes `<leader>ed` or `<leader>cd`.
- Define an actual purpose for local leader: language/project-local operations only.

# 17. Revised rollout

> **STATUS: ACCEPTED** — vertical slices. Folded into `repo-docs/nvim-migration-plan.md` (v3). No further action.

| Phase                                | Deliverable                                                 | Objective exit gate                         |
| ------------------------------------ | ----------------------------------------------------------- | ------------------------------------------- |
| **0. Isolation and transport**       | `NVIM_APPNAME`, key probe, GNOME/Ghostty audit              | Every planned non-leader key classified     |
| **1. Core editor**                   | Options, registry, WhichKey, Snacks, clipboard, buffers     | Zero mapping collisions; clean startup      |
| **2. PHP/Laravel vertical slice**    | Intelephense, Phpactor command mode, Pint, PHPStan, PHPUnit | One Laravel repository works end-to-end     |
| **3. Vue/TypeScript vertical slice** | Vue LS, vtsls, ESLint, Prettier, Vitest                     | One Vue repository works end-to-end         |
| **4. Editing power**                 | Tree-sitter objects, multi-cursor, Grug-far, refactoring    | Selection/editing acceptance suite passes   |
| **5. Git, tests and debug**          | Gitsigns, LazyGit, Neotest, DAP                             | Xdebug and JS/Go debugger smoke tests pass  |
| **6. Secondary languages**           | Go, Bash, Nix, Python, Lua, YAML, Markdown                  | Per-language smoke fixtures pass            |
| **7. Tasks and AI**                  | Overseer, Sidekick, AI dispatcher                           | No Tab/Esc conflicts; secrets excluded      |
| **8. Optional extras**               | Notes, Oil, Octo, UFO, sessions                             | Add only after a recorded need              |
| **9. Cutover**                       | Default alias/profile switched                              | Five working days without critical fallback |

The original “all 12 languages in one session” phase is too broad. Vertical slices expose capability conflicts earlier.

# 18. Required validation gates

> **STATUS: ACCEPTED** — folded into `repo-docs/nvim-migration-plan.md` (v3). No further action.

| Gate               | Test                                                           |
| ------------------ | -------------------------------------------------------------- |
| Lua syntax         | All Lua files parse headlessly                                 |
| Startup            | Clean and warm startup tested                                  |
| Mapping uniqueness | No duplicate global or buffer-local maps after plugin load     |
| Key transport      | Every extended shortcut manually certified                     |
| LSP ownership      | Maximum one primary completion/diagnostic owner per capability |
| Formatting         | Running formatter twice produces no second diff                |
| Diagnostics        | No duplicate messages from ESLint, Ruff, PHP or Vue            |
| Tree-sitter        | Every required parser loads without query errors               |
| Tests              | Nearest/file/suite works in representative repositories        |
| Debug              | Breakpoint, step, inspect and stop pass per primary language   |
| Security           | No secrets enter AI context; project config requires trust     |
| Rollback           | Old profile opens without modifying migration state            |

Suggested internal performance targets:

| Metric                                 |    Target |
| -------------------------------------- | --------: |
| Warm empty startup p50                 |   ≤100 ms |
| Warm empty startup p95                 |   ≤180 ms |
| Picker first result, normal repository |   ≤150 ms |
| Completion UI response                 |   ≤100 ms |
| Non-PHP format-on-save                 |   ≤500 ms |
| PHP Pint format-on-save                | ≤1,500 ms |
| Keymap collisions                      |     **0** |
| Duplicate diagnostic producers         |     **0** |
| Startup errors/warnings                |     **0** |

# Final combined decision

> **STATUS: ACCEPTED** — folded into `repo-docs/nvim-migration-plan.md` (v3). No further action.

Keep these parts of your plan:

- Mode-scoped compatibility
- Leader fallbacks
- WhichKey as mandatory
- Nix ownership of executable tools
- Phased migration
- PHP-first language coverage
- Neotest/DAP/Overseer integration
- Continued VS Code availability during migration
- Explicit learning ramp

Replace these parts:

- “88.2% verbatim” → “88.2% syntactically expressible; transport pending”
- “zero unresolved gaps” → explicit parity classification
- dual full PHP LSPs → one primary plus bounded Phpactor functions
- all plugins in one stack → three plugin tiers
- direct live migration → isolated `NVIM_APPNAME`
- feature-only exit criteria → executable acceptance gates
- manual mapping tables → generated registry and collision checker
- Neovide as a `Shift Shift` solution → leader or OS-level emitted key
- CursorHold autosave → guarded, deferred autosave
- mixed Tree-sitter ownership → one reproducible owner

With these changes, the plan becomes implementable rather than merely comprehensive.

[1]: https://github.com/neovim/neovim/releases?utm_source=chatgpt.com 'Releases · neovim/neovim'
[2]: https://github.com/jake-stewart/multicursor.nvim?utm_source=chatgpt.com 'jake-stewart/multicursor.nvim: multiple cursors in neovim'
[3]: https://neovim.io/doc/user/lsp/?utm_source=chatgpt.com 'Lsp - Neovim docs'
[4]: https://neovim.io/doc/user/tui/?utm_source=chatgpt.com 'Tui - Neovim docs'
[5]: https://help.gnome.org/gnome-help/shell-keyboard-shortcuts.html?utm_source=chatgpt.com 'Useful keyboard shortcuts'
[6]: https://ghostty.org/docs/config/keybind?utm_source=chatgpt.com 'Keybindings - Configuration'
[7]: https://neovim.io/doc/user/insert/?utm_source=chatgpt.com 'Insert - Neovim docs'
[8]: https://neovim.io/doc/user/usr_10/?utm_source=chatgpt.com 'Usr_10 - Neovim docs'
[9]: https://github.com/stevearc/conform.nvim/blob/master/README.md?utm_source=chatgpt.com 'README.md - conform.nvim'
[10]: https://github.com/phpactor/phpactor?utm_source=chatgpt.com 'Phpactor'
[11]: https://github.com/vuejs/language-tools/issues/5105?utm_source=chatgpt.com 'Duplicate completion response using hybridMode = false #5105'
[12]: https://github.com/folke/sidekick.nvim?utm_source=chatgpt.com 'folke/sidekick.nvim: Your Neovim AI sidekick'
[13]: https://github.com/nvim-neotest/neotest?utm_source=chatgpt.com 'nvim-neotest/neotest: An extensible framework for ...'
[14]: https://github.com/nvim-treesitter/nvim-treesitter?utm_source=chatgpt.com 'Nvim Treesitter configurations and abstraction layer'
[15]: https://neovim.io/doc/user/autocmd/?utm_source=chatgpt.com 'Autocmd - Neovim docs'
[16]: https://github.com/SonarSource/sonarqube-mcp-server?utm_source=chatgpt.com 'SonarSource/sonarqube-mcp-server'
[17]: https://neovim.io/doc/user/starting/?utm_source=chatgpt.com 'Starting - Neovim docs'
[18]: https://neovim.io/doc/user/options/?utm_source=chatgpt.com 'Options - Neovim docs'
