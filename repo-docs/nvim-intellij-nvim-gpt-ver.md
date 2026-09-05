# Neovim keybinding architecture

> **TRIAGE COMPLETE — REFERENCE ONLY.**
> Every item in this document has been adjudicated and folded into
> `repo-docs/nvim-migration-plan.md` (v3), which is the single source of truth.
> Do not implement from this file. Status markers below record each decision.
> Triaged: 2026-07-25.

> **STATUS: ACCEPTED WITH CHANGE** — the scores predate the transport analysis; terminal portability is lower than stated. See `nvim-migration-plan.md` (v3). No further action.

**Target:** Neovim 0.12+, currently the stable release. Neovim supports descriptive Lua mappings through `vim.keymap.set()`, separate terminal-mode mappings, built-in LSP operations, and syntax-tree selection through `vim.treesitter.select()`. ([Neovim][1])

| Metric                                 |      Score | Benchmark                   |
| -------------------------------------- | ---------: | --------------------------- |
| VS Code/JetBrains muscle-memory parity | **91/100** | 90+ = nearly complete       |
| Vim-native usability retained          | **84/100** | 80+ = good dual workflow    |
| Terminal portability                   | **72/100** | 70+ = usable with fallbacks |
| Discoverability                        | **95/100** | 90+ = easy with WhichKey    |
| Plugin dependency control              | **86/100** | 80+ = modular               |

## Mapping layers

> **STATUS: ACCEPTED** — folded into `repo-docs/nvim-migration-plan.md` (v3). No further action.

| Layer            | Purpose                                          | Convention                      |
| ---------------- | ------------------------------------------------ | ------------------------------- |
| Direct IDE layer | Preserve your existing shortcuts                 | `Ctrl`, `Alt`, function keys    |
| Leader layer     | Reliable terminal-safe fallback                  | `Space`                         |
| Native Vim layer | Learn standard Vim motions gradually             | `gd`, `g;`, `]d`, text objects  |
| Terminal layer   | Never intercept shell control keys unnecessarily | Terminal-specific mappings only |

## Mode legend

> **STATUS: ACCEPTED** — folded into `repo-docs/nvim-migration-plan.md` (v3). No further action.

| Symbol   | Neovim mode       |
| ------ | ----------------- |
| `N`    | Normal            |
| `I`    | Insert            |
| `V`    | Visual            |
| `C`    | Command line      |
| `T`    | Terminal          |
| `N/V`  | Normal and Visual |

# Important terminal limitation

> **STATUS: ACCEPTED** — the `:lua print(vim.fn.keytrans(vim.fn.getcharstr()))` probe is adopted as the Phase 0 key-transport test. Folded into `repo-docs/nvim-migration-plan.md` (v3). No further action.

Many terminals cannot distinguish `Ctrl+Shift+A` from `Ctrl+A`, or `Ctrl+Shift+N` from `Ctrl+N`. Modern terminals with an extended keyboard protocol may distinguish them, but the configuration should always include a leader fallback.

Test any chord with:

```vim
:lua print(vim.fn.keytrans(vim.fn.getcharstr()))
```

Then press the chord. Use:

```lua
vim.g.ide_extended_keys = true
```

only when the reported key differs from its non-Shift equivalent.

`Shift Shift` is not a real terminal key sequence, so use `Space Space` for Search Everywhere. Alt mappings also depend on terminal transmission, although mapped Alt keys generally work correctly. ([Neovim][2])

# Conflict resolution

> **STATUS: ACCEPTED WITH CHANGE** — most rows adopted, but four rows are REJECTED: `Ctrl+W` (expand selection) because Normal-mode `Ctrl+W` stays the native window prefix; `Ctrl+V` (paste) because Normal-mode `Ctrl+V` stays native Visual Block; `Ctrl+D` (duplicate) because `Ctrl+Alt+D` is peek-definition and duplicate-line moves to `<leader>cd`; `Ctrl+Alt+Shift+Up/Down` (resize) because multi-cursor wins and resize moves to `<leader>w`. See `nvim-migration-plan.md` (v3). No further action.

Your VS Code file contains several duplicate shortcuts whose behaviour is separated using VS Code context expressions. Neovim does not have identical contexts, so these require explicit decisions.

| Shortcut                 | Conflicting actions                        | Neovim decision                                               |
| ------------------------ | ------------------------------------------ | ------------------------------------------------------------- |
| `Ctrl+Alt+L`             | Format document / focus right group        | **Format**; use `Space w l` for right window                  |
| `Ctrl+Alt+J`             | Select all occurrences / focus lower group | **Select occurrences**; use `Space w j` for lower window      |
| `Alt+Shift+Up/Down`      | Move lines / previous-next Git change      | **Git change navigation**                                     |
| `Ctrl+Shift+Up/Down`     | Move lines                                 | Retained for line movement                                    |
| `Ctrl+Alt+Shift+Up/Down` | Add cursors / resize view                  | Resize in Normal mode; cursors inside multi-cursor mode       |
| `Shift+F6`               | Symbol rename / Explorer file rename       | Symbol rename globally; `Alt+F2` or `r` in Explorer for files |
| `Ctrl+Enter`             | Insert line / stage selected ranges        | Insert line in Normal/Insert; stage hunk in Visual            |
| `Ctrl+Alt+Enter`         | Insert line above / unstage ranges         | Mode-specific                                                 |
| `Ctrl+W`                 | Vim window prefix / expand selection       | Expand selection; window actions move to `Space w…`           |
| `Ctrl+R`                 | Vim redo / replace                         | Replace; redo moves to `Ctrl+Shift+Z` and `Space u r`         |
| `Ctrl+V`                 | Visual block / paste                       | Paste; Visual Block moves to `Space v b`                      |
| `Ctrl+D`                 | Half-page down / duplicate line            | Duplicate; page movement remains on `PageDown`                |
| `Ctrl+U`                 | Half-page up / cursor-only undo            | Keep native half-page movement; no exact cursor-only undo     |

# Plugin stack

> **STATUS: ACCEPTED WITH CHANGE** — `mg979/vim-visual-multi` replaced by `multicursor.nvim` (cursor-state-conditional mappings are required), `nvim-pack/nvim-spectre` replaced by `grug-far.nvim`, and the plugins reorganised into three tiers. See `nvim-migration-plan.md` (v3). No further action.

`Snacks.nvim` can provide pickers, Explorer, terminal, recent files, buffer deletion, Git status, LazyGit, Zen mode and LSP reference navigation in one dependency. WhichKey provides discoverable key descriptions. ([GitHub][3])

| Tier       | Plugin                    | Responsibility                                |
| ---------- | ------------------------- | --------------------------------------------- |
| Core       | `folke/snacks.nvim`       | Picker, Explorer, terminal, Git, buffers, Zen |
| Core       | `folke/which-key.nvim`    | Shortcut discovery                            |
| Core       | `stevearc/conform.nvim`   | Document and range formatting                 |
| Core       | `lewis6991/gitsigns.nvim` | Hunk navigation and staging                   |
| IDE parity | `folke/trouble.nvim`      | Problems/diagnostics panel                    |
| IDE parity | `nvim-pack/nvim-spectre`  | Project-wide replacement                      |
| IDE parity | `stevearc/aerial.nvim`    | Persistent symbol outline                     |
| Editing    | `mg979/vim-visual-multi`  | Multi-cursor                                  |
| Editing    | `kylechui/nvim-surround`  | Surround selection                            |
| Debug      | `mfussenegger/nvim-dap`   | Debug protocol                                |
| Debug      | `rcarriga/nvim-dap-ui`    | Debug tool windows                            |
| Run        | `stevearc/overseer.nvim`  | Run/task configurations                       |
| Testing    | `nvim-neotest/neotest`    | Test execution                                |
| AI         | `folke/sidekick.nvim`     | Claude/OpenCode terminal integration          |

Conform supports both full-buffer and range formatting and applies minimal changes rather than replacing the whole buffer. `nvim-dap` supplies the debugger actions but adapters still need language-specific configuration. ([GitHub][4])

---

# 1. Core editing

> **STATUS: ACCEPTED WITH CHANGE** — `Ctrl+V` paste is Insert/Visual only, and `Space v b` for Visual Block is rejected because Normal-mode `Ctrl+V` is retained. See `nvim-migration-plan.md` (v3). No further action.

## 1.1 Clipboard

| Shortcut    | Modes | Action                  | Native fallback |
| ----------- | ----- | ----------------------- | --------------- |
| `Ctrl+C`    | N     | Copy current line       | `yy`            |
| `Ctrl+C`    | V     | Copy selection          | `y`             |
| `Ctrl+X`    | N     | Cut current line        | `dd`            |
| `Ctrl+X`    | V     | Cut selection           | `d`             |
| `Ctrl+V`    | N     | Paste system clipboard  | `"+p`           |
| `Ctrl+V`    | I     | Paste system clipboard  | `Ctrl+R +`      |
| `Space v b` | N     | Enter Visual Block mode | `Ctrl+V`        |
| `Ctrl+A`    | N/I   | Select entire buffer    | `ggVG`          |

Recommended option:

```lua
vim.opt.clipboard = "unnamedplus"
```

## 1.2 Undo, save and files

> **STATUS: ACCEPTED WITH CHANGE** — Insert-mode `Ctrl+S` displaces native LSP signature help, which relocates to `<leader>lh`. See `nvim-migration-plan.md` (v3). No further action.

| Shortcut        | Action                               | Fallback    |
| --------------- | ------------------------------------ | ----------- |
| `Ctrl+Z`        | Undo                                 | `u`         |
| `Ctrl+Shift+Z`  | Redo                                 | `Space u r` |
| `Ctrl+Y`        | Delete line                          | `dd`        |
| `Ctrl+S`        | Save current file                    | `:update`   |
| `Ctrl+Shift+S`  | Save as                              | `Space f S` |
| `Ctrl+N`        | New empty buffer                     | `:enew`     |
| `Ctrl+F4`       | Close buffer without breaking layout | `Space b d` |
| `Ctrl+Shift+F4` | Close all unmodified buffers         | `Space b A` |
| `Ctrl+Shift+T`  | Open recent/closed file picker       | `Space f r` |

---

# 2. Search, files and command palette

> **STATUS: ACCEPTED** — folded into `repo-docs/nvim-migration-plan.md` (v3). No further action.

## 2.1 Search everywhere

| Shortcut           | Action                        | Reliable fallback | Backend             |
| ------------------ | ----------------------------- | ----------------- | ------------------- |
| `Shift Shift`      | Not representable in terminal | `Space Space`     | Snacks smart picker |
| `Ctrl+Shift+A`     | Command palette               | `Space s c`       | Snacks commands     |
| `Ctrl+Shift+N`     | Find file                     | `Space f f`       | Snacks files        |
| `Ctrl+Alt+Shift+N` | Workspace symbol              | `Space s S`       | Snacks LSP symbols  |
| `Ctrl+E`           | Recent files                  | `Space f r`       | Snacks recent       |
| `Ctrl+Shift+E`     | Recent/open buffers           | `Space f b`       | Snacks buffers      |
| `Alt+Shift+C`      | History of current file       | `Space g f`       | Git log file        |
| `Ctrl+G`           | Go to line                    | `:<line>`         | Core                |

## 2.2 Navigation history

| Shortcut               | Action                | Native equivalent |
| ---------------------- | --------------------- | ----------------- |
| `Ctrl+Alt+Left`        | Navigate backward     | `Ctrl+O`          |
| `Ctrl+Alt+Right`       | Navigate forward      | `Ctrl+I`          |
| `Alt+Left`             | Navigate backward     | `Ctrl+O`          |
| `Alt+Right`            | Navigate forward      | `Ctrl+I`          |
| `Ctrl+Shift+Backspace` | Last edit location    | `g;`              |
| `g;`                   | Older change location | Native            |
| `g,`                   | Newer change location | Native            |

---

# 3. Find and replace

> **STATUS: ACCEPTED WITH CHANGE** — the replacement backend is `grug-far.nvim`, not Spectre. See `nvim-migration-plan.md` (v3). No further action.

## 3.1 Current buffer

| Shortcut   | Modes | Action                            |
| ---------- | ----- | --------------------------------- |
| `Ctrl+F`   | N/I/V | Find in current buffer            |
| `Ctrl+R`   | N     | Replace throughout current buffer |
| `Ctrl+R`   | V     | Replace within selection          |
| `F3`       | N     | Next match                        |
| `Shift+F3` | N     | Previous match                    |

Native equivalents remain:

| Action            | Native key          |
| ----------------- | ------------------- |
| Search forward    | `/`                 |
| Search backward   | `?`                 |
| Next result       | `n`                 |
| Previous result   | `N`                 |
| Replace buffer    | `:%s/old/new/g`     |
| Replace selection | `:'<,'>s/old/new/g` |

## 3.2 Project-wide search

| Shortcut       | Action                            | Fallback    | Backend             |
| -------------- | --------------------------------- | ----------- | ------------------- |
| `Ctrl+Shift+F` | Find in files                     | `Space s g` | Snacks grep         |
| `Ctrl+Shift+R` | Replace in files                  | `Space s r` | Spectre             |
| `Ctrl+Shift+H` | Replace in current file UI        | `Space s R` | Spectre             |
| `Space s w`    | Search selected text/current word | —           | Snacks grep-word    |
| `Space s b`    | Search current buffer lines       | —           | Snacks lines        |
| `Space s B`    | Search open buffers               | —           | Snacks grep-buffers |

---

# 4. Completion and code intelligence

> **STATUS: ACCEPTED WITH CHANGE** — native LSP maps corrected to `gra`/`gri`/`grn`/`grr`/`grt`/`gO`. See `nvim-migration-plan.md` (v3). No further action.

## 4.1 Completion and documentation

| Shortcut           | Modes | Action                | Fallback        |
| ------------------ | ----- | --------------------- | --------------- |
| `Ctrl+Space`       | I     | Trigger completion    | `Ctrl+X Ctrl+O` |
| `Alt+Space`        | I     | Trigger completion    | `Ctrl+X Ctrl+O` |
| `Ctrl+Shift+Space` | N/I   | Parameter hints       | `Space l h`     |
| `Ctrl+P`           | N/I   | Parameter hints       | `Space l h`     |
| `Ctrl+Q`           | N     | Documentation/hover   | `K`             |
| `Alt+Enter`        | N/V   | Quick fix/code action | `gra`           |

Neovim’s LSP layer provides definition, implementation, references, hover, rename, formatting and code-action APIs directly. ([Neovim][5])

## 4.2 Definition and usage navigation

| Shortcut       | Action                          | Native/leader fallback |
| -------------- | ------------------------------- | ---------------------- |
| `Ctrl+B`       | Go to definition                | `gd`                   |
| `Ctrl+Alt+B`   | Go to implementation            | `gri` or `Space l i`   |
| `Ctrl+Shift+B` | Go to type definition           | `Space l t`            |
| `Ctrl+Shift+I` | Preview definitions in picker   | `Space l d`            |
| `Ctrl+Alt+D`   | Preview definitions in picker   | `Space l d`            |
| `Alt+F7`       | Find usages                     | `grr` / `Space l r`    |
| `Ctrl+Alt+F7`  | Find usages                     | `Space l r`            |
| `Ctrl+F7`      | Highlight usages                | `Space l H`            |
| `Ctrl+F12`     | File structure picker           | `Space s s`            |
| `Ctrl+Alt+F12` | Toggle persistent Outline       | `Space o`              |
| `Alt+F1`       | Reveal current file in Explorer | `Space e r`            |
| `Ctrl+Down`    | Next occurrence/reference       | `]]`                   |
| `Ctrl+Up`      | Previous occurrence/reference   | `[[`                   |

## 4.3 Diagnostics

| Shortcut       | Action                     | Native equivalent |
| -------------- | -------------------------- | ----------------- |
| `F2`           | Next diagnostic            | `]d`              |
| `Shift+F2`     | Previous diagnostic        | `[d`              |
| `Ctrl+Shift+M` | Problems panel             | `Space x x`       |
| `Alt+6`        | Problems panel             | `Space x x`       |
| `Space x b`    | Current-buffer diagnostics | —                 |
| `Space x q`    | Quickfix diagnostics       | —                 |

Neovim already defines `]d` as next diagnostic and `[d` as previous diagnostic. ([Neovim][6])

---

# 5. Comments, selection and multi-cursor

## 5.1 Comments

> **STATUS: ACCEPTED** — mapping both `<C-/>` and `<C-_>` is adopted. Folded into `repo-docs/nvim-migration-plan.md` (v3). No further action.

| Shortcut       | Modes | Action                               |
| -------------- | ----- | ------------------------------------ |
| `Ctrl+/`       | N     | Toggle current line comment          |
| `Ctrl+/`       | V     | Toggle selected lines                |
| `Ctrl+Shift+/` | V     | Toggle selected block/comment region |
| `gcc`          | N     | Native line comment                  |
| `gc` + motion  | N     | Native comment operator              |

Map both `<C-/>` and `<C-_>` because many terminals report `Ctrl+/` as `Ctrl+_`.

## 5.2 Syntax-aware selection

> **STATUS: ACCEPTED WITH CHANGE** — `Ctrl+W` expand applies in Visual mode only, and `Space v b` is rejected. See `nvim-migration-plan.md` (v3). No further action.

Neovim 0.12 exposes `vim.treesitter.select()` for parent/child syntax-node selection. ([Neovim][7])

| Shortcut       | Action                       | Fallback                    |
| -------------- | ---------------------------- | --------------------------- |
| `Ctrl+Alt+W`   | Select current word          | `viw`                       |
| `Ctrl+W`       | Expand to parent syntax node | `Space v e`                 |
| `Ctrl+Shift+W` | Shrink to child syntax node  | `Space v s`                 |
| `Ctrl+Shift+]` | Select to matching bracket   | `Space v ]`                 |
| `Ctrl+Shift+[` | Select to matching bracket   | `Space v ]`                 |
| `Space v b`    | Visual Block mode            | Native `Ctrl+V` replacement |

## 5.3 Multi-cursor

> **STATUS: ACCEPTED WITH CHANGE** — the backend is `multicursor.nvim`. See `nvim-migration-plan.md` (v3). No further action.

| Shortcut              | Action                                             | Backend          |
| --------------------- | -------------------------------------------------- | ---------------- |
| `Alt+J`               | Add next occurrence                                | vim-visual-multi |
| `Alt+Shift+J`         | Add previous occurrence                            | vim-visual-multi |
| `Ctrl+Alt+J`          | Select all occurrences                             | vim-visual-multi |
| `Ctrl+Alt+Shift+Up`   | Add cursor above while multi-cursor mode is active | vim-visual-multi |
| `Ctrl+Alt+Shift+Down` | Add cursor below while multi-cursor mode is active | vim-visual-multi |

## 5.4 Folding

> **STATUS: ACCEPTED WITH CHANGE** — folding uses native `vim.treesitter.foldexpr()` / `vim.lsp.foldexpr()`, with nvim-ufo deferred to Tier 3. See `nvim-migration-plan.md` (v3). No further action.

| Shortcut              | Action          | Native |
| --------------------- | --------------- | ------ |
| `Ctrl+Numpad +`       | Open fold       | `zo`   |
| `Ctrl+Numpad -`       | Close fold      | `zc`   |
| `Ctrl+Shift+Numpad +` | Open all folds  | `zR`   |
| `Ctrl+Shift+Numpad -` | Close all folds | `zM`   |

---

# 6. Line and word editing

> **STATUS: ACCEPTED WITH CHANGE** — `Ctrl+]` / `Ctrl+[` must NOT be remapped in Normal mode (`Ctrl+]` is native goto-definition via `tagfunc`); indent is `>>` in Normal and `Tab` in Visual. See `nvim-migration-plan.md` (v3). No further action.

## 6.1 Line operations

| Shortcut          | Action                   | Native equivalent |
| ----------------- | ------------------------ | ----------------- |
| `Ctrl+D`          | Duplicate line/selection | `:copy .`         |
| `Ctrl+Shift+J`    | Join lines               | `J`               |
| `Shift+Enter`     | Insert line below        | `o`               |
| `Ctrl+Enter`      | Insert line below        | `o`               |
| `Ctrl+Alt+Enter`  | Insert line above        | `O`               |
| `Ctrl+Shift+Down` | Move line/selection down | `:move`           |
| `Ctrl+Shift+Up`   | Move line/selection up   | `:move`           |
| `Ctrl+[`          | Outdent                  | `<<` / `<`        |
| `Ctrl+]`          | Indent                   | `>>` / `>`        |

`Alt+Shift+Up/Down` is reserved for Git hunk navigation because that later binding overrides line movement in your VS Code source.

## 6.2 Word movement and deletion

| Shortcut         | Modes | Action               | Native          |
| ---------------- | ----- | -------------------- | --------------- |
| `Ctrl+Left`      | N/I   | Previous word        | `b`             |
| `Ctrl+Right`     | N/I   | Next word            | `w`             |
| `Ctrl+Backspace` | N/I   | Delete previous word | `db` / `Ctrl+W` |
| `Ctrl+Delete`    | N/I   | Delete next word     | `dw`            |
| `Ctrl+Home`      | N     | First line           | `gg`            |
| `Ctrl+End`       | N     | Last line            | `G`             |
| `Alt+Shift+T`    | N     | First line           | `gg`            |
| `Alt+Shift+B`    | N     | Last line            | `G`             |

## 6.3 Case conversion

| Shortcut       | Context      | Action                 | Fallback    |
| -------------- | ------------ | ---------------------- | ----------- |
| `Ctrl+Shift+U` | Selection    | Uppercase              | `Space c u` |
| `Ctrl+Shift+U` | No selection | Lowercase current word | `guiw`      |
| `Ctrl+Shift+L` | Selection    | Lowercase              | `Space c l` |
| `Space c t`    | N/V          | Toggle case            | `g~`        |

---

# 7. Formatting and refactoring

> **STATUS: ACCEPTED WITH CHANGE** — the formatting owner is conform.nvim only, never "Conform/LSP", and PHP extracts route to phpactor because refactoring.nvim has no PHP support. See `nvim-migration-plan.md` (v3). No further action.

## 7.1 Formatting

| Shortcut           | Context      | Action             | Backend         |
| ------------------ | ------------ | ------------------ | --------------- |
| `Ctrl+Alt+L`       | No selection | Format document    | Conform/LSP     |
| `Ctrl+Alt+L`       | Selection    | Format selection   | Conform         |
| `Ctrl+Alt+Shift+L` | Selection    | Format selection   | Conform         |
| `Ctrl+Alt+O`       | N            | Organize imports   | LSP code action |
| `Ctrl+Alt+I`       | N            | Reindent document  | `gg=G`          |
| `Ctrl+Alt+I`       | V            | Reindent selection | `=`             |

## 7.2 Refactoring

| Shortcut           | Action                    | Notes                     |
| ------------------ | ------------------------- | ------------------------- |
| `Shift+F6`         | Rename symbol             | LSP                       |
| `Ctrl+Alt+Shift+T` | Refactor menu             | `Space c r` fallback      |
| `Ctrl+Alt+N`       | Inline refactor           | Language-server dependent |
| `Ctrl+Alt+V`       | Extract variable          | Language-server dependent |
| `Ctrl+Alt+M`       | Extract function/method   | Language-server dependent |
| `Ctrl+Alt+C`       | Extract constant          | Language-server dependent |
| `Ctrl+Alt+T`       | Surround visual selection | nvim-surround             |

The exact extraction action kinds are not standardized consistently across every language server. The generic refactor menu is therefore more dependable than separate extraction shortcuts.

---

# 8. Buffers, windows and layout

> **STATUS: ACCEPTED WITH CHANGE** — window focus is `Ctrl+H/J/K/L`, and the "because `Ctrl+W` is used for syntax selection" rationale is rejected. See `nvim-migration-plan.md` (v3). No further action.

## 8.1 Splits

| Shortcut       | Action                 | Native                 |
| -------------- | ---------------------- | ---------------------- |
| `Ctrl+\`       | Vertical split         | `:vsplit`              |
| `Ctrl+Shift+\` | Horizontal split       | `:split`               |
| `Ctrl+Alt+\`   | Smart orthogonal split | Width-dependent helper |
| `Ctrl+1`       | Focus first window     | `1 Ctrl+W w`           |
| `Ctrl+2`       | Focus second window    | `2 Ctrl+W w`           |
| `Ctrl+3`       | Focus third window     | `3 Ctrl+W w`           |

## 8.2 Window navigation

Because `Ctrl+W` is used for syntax selection, window navigation moves into a leader namespace.

| Shortcut        | Action              |
| --------------- | ------------------- |
| `Space w h`     | Focus left window   |
| `Space w j`     | Focus lower window  |
| `Space w k`     | Focus upper window  |
| `Space w l`     | Focus right window  |
| `Space w s`     | Horizontal split    |
| `Space w v`     | Vertical split      |
| `Space w o`     | Close other windows |
| `Ctrl+K Ctrl+O` | Close other windows |

## 8.3 Buffers

| Shortcut   | Action                       | Fallback     |
| ---------- | ---------------------------- | ------------ |
| `Alt+H`    | Previous buffer              | `:bprevious` |
| `Alt+L`    | Next buffer                  | `:bnext`     |
| `Ctrl+K O` | Close other buffers          | `Space b o`  |
| `Ctrl+K W` | Close all buffers            | `Space b A`  |
| `Ctrl+0`   | Open/focus Explorer          | `Space e`    |
| `Ctrl+F4`  | Delete current buffer safely | `Space b d`  |

## 8.4 Resizing and scrolling

| Shortcut               | Action                 |
| ---------------------- | ---------------------- |
| `Ctrl+Alt+Shift+Left`  | Increase window width  |
| `Ctrl+Alt+Shift+Right` | Decrease window width  |
| `Ctrl+Alt+Shift+Up`    | Decrease window height |
| `Ctrl+Alt+Shift+Down`  | Increase window height |
| `Ctrl+Alt+E`           | Scroll down one line   |
| `Ctrl+Alt+Y`           | Scroll up one line     |
| `Alt+Z`                | Toggle word wrapping   |

---

# 9. Tool windows

> **STATUS: ACCEPTED** — folded into `repo-docs/nvim-migration-plan.md` (v3). No further action.

Snacks supplies most of these surfaces, reducing the number of separate UI plugins. ([GitHub][3])

| Shortcut         | Tool window                         | Backend           |
| ---------------- | ----------------------------------- | ----------------- |
| `Alt+1`          | File Explorer                       | Snacks Explorer   |
| `Alt+2`          | Project search                      | Snacks grep       |
| `Alt+3`          | Source control                      | Snacks Git status |
| `Alt+4`          | Debugger UI                         | nvim-dap-ui       |
| `Alt+5`          | Plugin manager                      | Lazy              |
| `Alt+6`          | Problems                            | Trouble           |
| `Alt+7`          | Outline                             | Aerial            |
| `Alt+0`          | Output/notification history         | Snacks notifier   |
| `Alt+F12`        | Terminal                            | Snacks terminal   |
| `Shift+Escape`   | Close focused panel/floating window | Context helper    |
| `Ctrl+Shift+F12` | Zen mode                            | Snacks Zen        |
| `Ctrl+Alt+F11`   | Fullscreen                          | GUI-dependent     |

Terminal Neovim cannot toggle the containing desktop terminal’s fullscreen state. A GUI such as Neovide can expose its own fullscreen variable.

---

# 10. Terminal mappings

> **STATUS: ACCEPTED** — the warning against mapping plain `Escape` in terminal mode is adopted. Folded into `repo-docs/nvim-migration-plan.md` (v3). No further action.

Neovim terminal mode normally sends all keys except the `Ctrl+\` control sequence to the underlying process. Consequently, shell controls should not be unnecessarily remapped. ([Neovim][8])

| Shortcut        | Action                                               |
| --------------- | ---------------------------------------------------- |
| `Ctrl+L`        | Shell clears screen naturally                        |
| `Ctrl+D`        | Shell receives EOF naturally                         |
| `Ctrl+\ Ctrl+N` | Exit Terminal mode                                   |
| `Ctrl+Shift+D`  | Kill terminal buffer, only with extended-key support |
| `Alt+H`         | Leave terminal and focus left window                 |
| `Alt+J`         | Leave terminal and focus lower window                |
| `Alt+K`         | Leave terminal and focus upper window                |
| `Alt+L`         | Leave terminal and focus right window                |

Do not map plain `Escape` to leave terminal mode because it would interfere with LazyGit, interactive shells, debuggers and terminal applications.

---

# 11. Debugging and execution

> **STATUS: ACCEPTED** — folded into `repo-docs/nvim-migration-plan.md` (v3). No further action.

## 11.1 Debug controls

| Shortcut        | Action                        | Backend     |
| --------------- | ----------------------------- | ----------- |
| `Shift+F9`      | Start/continue debugging      | nvim-dap    |
| `Ctrl+Shift+F9` | Start/continue debugging      | nvim-dap    |
| `F8`            | Step over                     | nvim-dap    |
| `F7`            | Step into                     | nvim-dap    |
| `Shift+F8`      | Step out                      | nvim-dap    |
| `F9`            | Continue                      | nvim-dap    |
| `Alt+F8`        | Evaluate expression/selection | nvim-dap-ui |
| `Ctrl+F2`       | Stop debugger                 | nvim-dap    |
| `Ctrl+Shift+F2` | Restart debugger              | nvim-dap    |
| `Ctrl+F8`       | Toggle breakpoint             | nvim-dap    |
| `Ctrl+Shift+F8` | Open debug/breakpoint UI      | nvim-dap-ui |

## 11.2 Run controls

| Shortcut         | Action               | Backend  |
| ---------------- | -------------------- | -------- |
| `Shift+F10`      | Select and run task  | Overseer |
| `Ctrl+Shift+F10` | Select and run task  | Overseer |
| `Space r r`      | Run last task        | Overseer |
| `Space r o`      | Open task list       | Overseer |
| `Space r t`      | Toggle task terminal | Overseer |

---

# 12. Git

> **STATUS: ACCEPTED WITH CHANGE** — `Ctrl+Alt+G C` is plain commit and `Ctrl+Alt+G Shift+C` is commit-staged, matching the VS Code source (this document swapped them). See `nvim-migration-plan.md` (v3). No further action.

## 12.1 IDE-compatible chord

| Shortcut             | Action                             |
| -------------------- | ---------------------------------- |
| `Ctrl+Alt+G S`       | Git status                         |
| `Ctrl+Alt+G C`       | Commit staged files                |
| `Ctrl+Alt+G Shift+C` | Interactive commit through LazyGit |
| `Ctrl+Alt+G U`       | Pull with rebase                   |
| `Ctrl+Alt+G P`       | Push                               |
| `Ctrl+Alt+G Y`       | Pull/rebase then push              |
| `Ctrl+Alt+G F`       | Fetch all and prune                |

## 12.2 Hunk operations

| Shortcut         | Context       | Action                            |
| ---------------- | ------------- | --------------------------------- |
| `Ctrl+Enter`     | Visual        | Stage selected hunk/range         |
| `Ctrl+Alt+Enter` | Visual        | Undo latest staged hunk           |
| `Alt+Shift+Down` | Normal        | Next Git hunk                     |
| `Alt+Shift+Up`   | Normal        | Previous Git hunk                 |
| `Space g h s`    | Normal/Visual | Stage hunk                        |
| `Space g h r`    | Normal/Visual | Reset hunk                        |
| `Space g h p`    | Normal        | Preview hunk                      |
| `Space g h b`    | Normal        | Full blame information            |
| `Space g g`      | Normal        | LazyGit                           |
| `Space g B`      | Normal/Visual | Open file/selection on Git remote |

---

# 13. Settings and metadata

> **STATUS: ACCEPTED WITH CHANGE** — `Alt+F2` is claimed by GNOME as Run Command and must be unbound at GNOME level or relocated. See `nvim-migration-plan.md` (v3). No further action.

| Shortcut           | Action                                   | Fallback    |
| ------------------ | ---------------------------------------- | ----------- |
| `Ctrl+Alt+S`       | Open `init.lua`                          | `Space f c` |
| `Ctrl+Alt+Shift+S` | Find Neovim config file                  | `Space f C` |
| `Ctrl+Alt+Shift+K` | Search active mappings                   | `Space s k` |
| `Alt+F2`           | Rename current file with LSP integration | `Space c R` |
| `Ctrl+Shift+C`     | Copy absolute current-file path          | `Space y p` |
| `Space s k`        | Search all keymaps                       | —           |
| `Space s h`        | Search Neovim help                       | —           |
| `Space s u`        | Browse undo history                      | —           |
| `Space s q`        | Browse quickfix list                     | —           |

---

# 14. High-value extras

> **STATUS: ACCEPTED WITH CHANGE** — the Bruno/HTTP namespace moves to `<leader>h`. See `nvim-migration-plan.md` (v3). No further action.

## 14.1 Projects

| Shortcut    | Action                | Backend         |
| ----------- | --------------------- | --------------- |
| `Space p p` | Select recent project | Snacks projects |
| `Space p f` | Find file in project  | Snacks files    |
| `Space p g` | Grep project          | Snacks grep     |

## 14.2 Tests

| Shortcut    | Action                  | Backend       |
| ----------- | ----------------------- | ------------- |
| `Space t n` | Run nearest test        | Neotest       |
| `Space t f` | Run current test file   | Neotest       |
| `Space t a` | Run complete test suite | Neotest       |
| `Space t d` | Debug nearest test      | Neotest + DAP |
| `Space t o` | Open test output        | Neotest       |
| `Space t s` | Toggle test summary     | Neotest       |

## 14.3 AI terminals

| Shortcut    | Action                           |
| ----------- | -------------------------------- |
| `Space a c` | Toggle focused Claude CLI        |
| `Space a o` | Toggle focused OpenCode CLI      |
| `Space a s` | Select available AI terminal     |
| `Space a d` | Send current diagnostics context |
| `Space a v` | Send visual selection            |
| `Space a f` | Send current file                |

Sidekick currently exposes CLI toggling and supports named AI clients such as Claude. ([GitHub][9])

## 14.4 Native Vim skills worth retaining

| Native key          | Purpose                              |
| ------------------- | ------------------------------------ |
| `.`                 | Repeat the previous edit             |
| `ciw`               | Change current word                  |
| `ci"`               | Change inside quotes                 |
| `di(`               | Delete inside parentheses            |
| `va{`               | Select around braces                 |
| `*` / `#`           | Search current word forward/backward |
| `%`                 | Jump between matching brackets       |
| `zz`                | Centre current line                  |
| `gi`                | Return to last Insert position       |
| `g;` / `g,`         | Traverse edit locations              |
| `Ctrl+O` / `Ctrl+I` | Traverse jump history                |
| `q{register}`       | Record a macro                       |
| `@{register}`       | Execute a macro                      |

# Recommended leader hierarchy

> **STATUS: REJECTED** — superseded by the 21-prefix hierarchy in the addition document section 16. Superseded by `nvim-migration-plan.md` (v3). No further action.

| Prefix    | Category           |
| --------- | ------------------ |
| `Space a` | AI                 |
| `Space b` | Buffers            |
| `Space c` | Code/refactoring   |
| `Space d` | Debug              |
| `Space e` | Explorer           |
| `Space f` | Files              |
| `Space g` | Git                |
| `Space l` | LSP                |
| `Space p` | Projects           |
| `Space r` | Run/tasks          |
| `Space s` | Search             |
| `Space t` | Tests              |
| `Space u` | UI toggles         |
| `Space v` | Visual/selection   |
| `Space w` | Windows            |
| `Space x` | Diagnostics        |
| `Space y` | Yank/copy metadata |
| `Space z` | Zen/folding        |

This design gives you the original IDE shortcuts where technically reliable, terminal-safe leader equivalents for every critical operation, and enough native Vim functionality to avoid turning Neovim into a less capable VS Code imitation.

[1]: https://neovim.io/ 'https://neovim.io/'
[2]: https://neovim.io/doc/user/intro/ 'https://neovim.io/doc/user/intro/'
[3]: https://github.com/folke/snacks.nvim 'https://github.com/folke/snacks.nvim'
[4]: https://github.com/stevearc/conform.nvim/blob/master/README.md 'https://github.com/stevearc/conform.nvim/blob/master/README.md'
[5]: https://neovim.io/doc/user/lsp/ 'https://neovim.io/doc/user/lsp/'
[6]: https://neovim.io/doc/user/diagnostic/ 'https://neovim.io/doc/user/diagnostic/'
[7]: https://neovim.io/doc/user/treesitter/ 'https://neovim.io/doc/user/treesitter/'
[8]: https://neovim.io/doc/user/terminal/ 'https://neovim.io/doc/user/terminal/'
[9]: https://github.com/folke/sidekick.nvim 'https://github.com/folke/sidekick.nvim'
