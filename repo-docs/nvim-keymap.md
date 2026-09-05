# Neovim Keymap Reference — VS Code (PhpStorm-style) to Neovim

> **Reference document.** Generated against **Neovim 0.12 defaults** under **Strategy E:
> defaults-first + leader-only additions**. The governing rule is: *never remap a Neovim
> default*. Only add mappings on `<leader>`, or extend the `g`, `[`, and `]` families.
> Every row prefers the NATIVE Neovim default; a `<leader>` mapping is named only where no
> native equivalent exists. This document changes no configuration — it is documentation only.

Source of the VS Code column: `home/.chezmoitemplates/vscode/keybindings.json`
(178 unique positive bindings; all are covered below).

> **The `<leader>` column is illustrative, not binding.** This file names roughly 156
> `<leader>` candidates so that every VS Code key has a documented Neovim counterpart.
> The real keymap is capped at **32 mappings** and is defined solely by section 6 of
> `repo-docs/nvim-defaults-plan.md`.
>
> Two consequences follow. First, where a `<leader>` suggestion here disagrees with that
> table, section 6 wins and this file is the non-authoritative side. Second, where two
> sections of this file suggest the same `<leader>` key for different actions — for
> example `<leader>gb` for both a branch picker and line blame — that is a documentation
> inconsistency, not a configuration conflict, because at most one of them is ever bound.
>
> Treat a row's `<leader>` value as "the shape this would take *if* promoted", never as a
> key that exists. Only mappings promoted into section 6 are bound.

## Legend — the `Type` column

| Type | Meaning |
|---|---|
| `native` | Built-in Neovim default. Zero configuration. Works in a bare `nvim`. |
| `native-opt` | Built in, but requires an option or a one-line config to enable (for example `set clipboard`, `set foldmethod`, an LSP capability, or `vim.diagnostic.config`). |
| `leader` | No native equivalent. A `<leader>`-prefixed mapping is added (Strategy E allows this). |
| `plugin` | Requires a plugin. The plugin is named in the Notes column. |
| `none` | No equivalent exists and none is planned. |

Additional conventions used in this document:

- `<leader>` is assumed to be `<Space>`.
- `->` means "leads to" / "maps to". No Unicode arrows are used.
- `**CONFLICT:**` in the Notes column means the VS Code key collides with a Vim default,
  and the note names what the Vim key natively does.
- A `-` in the VS Code column means there is no VS Code counterpart; the row exists because
  Neovim offers the capability anyway.

## Companion documents

| Document | Role | Status |
|---|---|---|
| `repo-docs/nvim-defaults-plan.md` | Active plan. The authoritative statement of Strategy E, the option set, and the plugin list. | Present in repo. |
| `repo-docs/nvim-keymap.md` | This file. Complete VS Code -> Neovim translation, by category. | This document. |
| `repo-docs/nvim-cheatsheet.md` | One-page daily driver. The ~45 keys used every day. | Active. Print this for week 1-2. |
| `repo-docs/nvim-migration-plan.md` | Superseded v3 migration plan. Historical context only. | Present, superseded. |
| `home/.chezmoitemplates/vscode/keybindings.json` | Source of every VS Code key in this document. | Present in repo. |

## The 21 known conflicts at a glance

These VS Code keys collide with Vim defaults. Under Strategy E none of them are remapped in
Neovim; the native meaning wins and the table rows below name the native replacement.

| Key | Native Vim meaning |
|---|---|
| `Ctrl+V` | Visual Block mode |
| `Ctrl+W` | Window command prefix |
| `Ctrl+R` | Redo |
| `Ctrl+D` | Scroll half page down |
| `Ctrl+U` | Scroll half page up |
| `Ctrl+A` | Increment number under cursor |
| `Ctrl+O` | Jumplist: go back |
| `Ctrl+]` | Go to definition via `tagfunc` |
| `Ctrl+N` | Insert-mode completion: next |
| `Ctrl+B` | Scroll page up |
| `Ctrl+F` | Scroll page down |
| `Ctrl+[` | Equivalent to `Esc` |
| `Ctrl+C` | Cancel / leave Insert mode without abbreviation expansion |
| `Ctrl+E` | Scroll window down one line |
| `Ctrl+G` | Show file info |
| `Ctrl+L` | Redraw screen (and clear search highlight in many configs) |
| `Ctrl+P` | Insert-mode completion: previous |
| `Ctrl+Q` | Visual Block mode (alternative to `Ctrl+V`) |
| `Ctrl+X` | Decrement number under cursor |
| `Ctrl+Y` | Scroll window up one line |
| `Ctrl+Z` | Suspend Neovim to the shell |

---

## A. Code Intelligence (LSP)

Neovim 0.11 and later ship **unconditional global LSP default mappings**. They exist whether
or not a language server is attached; when a server is attached they act on it. The `gr`
family is the modern replacement for the older hand-rolled `gd`/`gr`/`gi` sets.

### A1. Navigation

| VS Code key | Action | Neovim | Type | Notes / alternatives |
|---|---|---|---|---|
| `Ctrl+B` | Go to Definition | `Ctrl+]` | `native` | Works because the LSP client sets `'tagfunc'` on attach. **CONFLICT:** `Ctrl+B` natively scrolls a full page up. Do not remap it. |
| `Ctrl+B` | Go to Definition (second binding, `editorTextFocus`) | `Ctrl+]` | `native` | Same as above; the source file binds `Ctrl+B` twice with different `when` clauses. |
| `Ctrl+Alt+B` | Go to Implementation | `gri` | `native` | Unconditional global default since 0.11. |
| `Ctrl+Alt+B` | Go to Implementation (second binding) | `gri` | `native` | Duplicate binding in the source file. |
| `Ctrl+Shift+B` | Go to Type Definition | `grt` | `native` | Unconditional global default since 0.11. |
| `Alt+F7` | Find Usages (peek references) | `grr` | `native` | Populates the quickfix list; then `]q` / `[q` to walk it. |
| `Ctrl+Alt+F7` | Find Usages (references view panel) | `grr` then `:copen` | `native` | Or `<leader>fr` for a Telescope/fzf-lua reference picker. |
| `Ctrl+Shift+I` | Peek Definition | `<leader>gp` | `plugin` | No native peek window. Options: `glance.nvim`, `goto-preview`, or Telescope's preview pane. Native fallback: `Ctrl+]` then `Ctrl+O` to come back. |
| `Ctrl+Alt+D` | Peek Definition (second binding) | `<leader>gp` | `plugin` | Same as above. |
| `Ctrl+F12` | File structure / Go to Symbol in file | `gO` | `native` | Document symbols into the location list. Then `]l` / `[l`. |
| `Ctrl+Alt+Shift+N` | Go to Symbol (workspace) | `<leader>fs` | `plugin` | `vim.lsp.buf.workspace_symbol()` exists natively but has no default key. Telescope `lsp_workspace_symbols` or fzf-lua. |
| `Ctrl+Alt+F12` | Focus Outline view | `gO` | `native` | Or `<leader>o` for a persistent outline panel (`aerial.nvim`, `outline.nvim`). |
| `Alt+7` | Outline tool window | `gO` | `native` | See H6 for the panel-style alternative. |
| `Ctrl+Down` | Next occurrence of symbol under cursor | `*` | `native` | `*` searches forward for the exact word under the cursor; `n` repeats. |
| `Ctrl+Up` | Previous occurrence of symbol under cursor | `#` | `native` | `#` searches backward for the word under the cursor. |
| `-` | Go to Declaration | `<leader>gD` | `leader` | `vim.lsp.buf.declaration()`. No default key; distinct from definition in C/C++. |
| `-` | Go to Definition, split window first | `Ctrl+W ]` | `native` | Opens the definition in a horizontal split. |
| `-` | Go to Definition in a preview window | `Ctrl+W }` | `native` | Native tag preview; closes with `Ctrl+W z`. |
| `-` | Jump to tag under cursor, older tag stack | `Ctrl+T` | `native` | Pops the tag stack. Pairs with `Ctrl+]`. |
| `-` | Go to file under cursor | `gf` | `native` | `gF` also honours a trailing `:line` number. |
| `-` | Open URL or path under cursor externally | `gx` | `native` | Calls `vim.ui.open()`. New in 0.10. |
| `-` | Incoming / outgoing call hierarchy | `<leader>ci` / `<leader>co` | `leader` | `vim.lsp.buf.incoming_calls()` / `outgoing_calls()`. No default keys. |

### A2. Documentation and signature

| VS Code key | Action | Neovim | Type | Notes / alternatives |
|---|---|---|---|---|
| `Ctrl+Q` | Quick Documentation (hover) | `K` | `native` | Buffer-local default once a server attaches. Falls back to `:help`/`keywordprg` with no server. **CONFLICT:** `Ctrl+Q` is Visual Block mode. |
| `Ctrl+Shift+Space` | Parameter info | Insert `Ctrl+S` | `native` | `vim.lsp.buf.signature_help()` is bound to Insert-mode `Ctrl+S` by default in 0.11+. |
| `Ctrl+P` | Parameter hints (second binding) | Insert `Ctrl+S` | `native` | **CONFLICT:** `Ctrl+P` in Insert mode is the native "previous completion match". **Also see the `Ctrl+S` terminal warning below.** |
| `-` | Hover again to enter the hover window | `K` `K` | `native` | Pressing `K` twice moves focus into the floating window; `q` closes it. |
| `-` | Close all floating windows | `<leader>q` or `Esc` | `native-opt` | `:fclose!` or a small `vim.lsp.buf.hover` wrapper. `Esc` closes focused floats. |
| `-` | Show diagnostic under cursor in a float | `Ctrl+W d` | `native` | `vim.diagnostic.open_float()` is bound to `Ctrl+W d` by default in 0.10+. |
| `-` | Look up the keyword under cursor in help | `K` (no LSP) | `native` | With no server attached `K` uses `'keywordprg'`, which is `:help` in Vim files and `man` elsewhere. |
| `-` | Show character code under cursor | `ga` | `native` | Prints decimal, hex, and octal for the character. Useful for hunting homoglyphs. |
| `-` | Show file info and position | `Ctrl+G` | `native` | `g Ctrl+G` gives byte/word/line counts, and works on a Visual selection. |

**Warning on `Ctrl+S`.** In a terminal, `Ctrl+S` triggers **XOFF software flow control** and
freezes the terminal until `Ctrl+Q` (XON) is pressed. It is also Insert-mode signature help in
Neovim 0.11+. Do not bind `Ctrl+S` to save. Use `:w` or `<leader>w` instead. If a terminal does
freeze, press `Ctrl+Q` to resume it. The flow control can be disabled shell-side with
`stty -ixon`, but the recommendation stands: use `:w`.

### A3. Refactoring

| VS Code key | Action | Neovim | Type | Notes / alternatives |
|---|---|---|---|---|
| `Shift+F6` | Rename symbol | `grn` | `native` | Unconditional global default since 0.11. Prompts for the new name. |
| `Alt+Enter` | Quick Fix | `gra` | `native` | `vim.lsp.buf.code_action()`. Works in Normal AND Visual mode by default. |
| `Ctrl+Alt+Shift+T` | Refactor this (menu) | `gra` | `native` | Same code-action menu; the LSP server decides which refactors it offers. |
| `Ctrl+Alt+N` | Inline variable/method | `gra` then pick "Inline" | `native` | Server-dependent. No dedicated native key for a specific refactor kind. |
| `Ctrl+Alt+V` | Extract variable | `gra` (Visual) then pick | `native` | Select the expression in Visual mode first, then `gra`. |
| `Ctrl+Alt+M` | Extract method/function | `gra` (Visual) then pick | `native` | Select the block in Visual mode first, then `gra`. |
| `Ctrl+Alt+C` | Extract constant | `gra` (Visual) then pick | `native` | Server-dependent code action. |
| `Ctrl+Alt+T` | Surround with | `<leader>s` family or `ys{motion}{char}` | `plugin` | `nvim-surround` or `mini.surround`. `ysiw"` wraps a word in quotes; `cs"'` changes quotes; `ds"` deletes them. Visual mode: `S"`. |
| `Ctrl+Alt+O` | Optimize / organize imports | `<leader>oi` | `leader` | `vim.lsp.buf.code_action({ context = { only = { "source.organizeImports" } }, apply = true })`. No native key. |
| `-` | Run codelens under cursor | `grx` | `native` | New unconditional default in 0.11. Requires the server to publish codelenses. |
| `-` | Refresh codelenses | `<leader>cl` | `leader` | `vim.lsp.codelens.refresh()`. |
| `-` | Rename across the project without LSP | `:argdo %s/old/new/gce` | `native` | Combine with `:args **/*.php`. `c` prompts, `e` skips files with no match. |
| `-` | Rename with a preview of every change | `:%s/old/new/gc` | `native` | The `c` flag prompts per match: `y`, `n`, `a` (all), `q` (quit), `l` (last). |

### A4. Formatting

| VS Code key | Action | Neovim | Type | Notes / alternatives |
|---|---|---|---|---|
| `Ctrl+Alt+L` | Reformat document | `gqq` on a range, or `<leader>f` | `native-opt` | The LSP client sets `'formatexpr'` on attach, so `gq{motion}` formats via the server. Whole file: `gggqG`. A `<leader>f` calling `vim.lsp.buf.format()` is the ergonomic addition. |
| `Ctrl+Alt+L` | Format selection (`editorHasSelection`) | `gq` in Visual mode | `native-opt` | Select, then `gq`. Same `'formatexpr'` mechanism. |
| `Ctrl+Alt+Shift+L` | Format selection | `gq` in Visual mode | `native-opt` | Duplicate of the above in the source file. |
| `Ctrl+Alt+I` | Reindent lines | `==` / `=G` / `=ap` | `native` | `=` is the indent operator. `==` one line, `=ap` a paragraph, `gg=G` the whole file. |
| `-` | Format on save | `native-opt` config | `native-opt` | A `BufWritePre` autocommand calling `vim.lsp.buf.format()`. Or `conform.nvim` for multi-formatter routing. |
| `-` | Reflow a paragraph to `'textwidth'` | `gqap` | `native` | With no `'formatexpr'` this is the classic text reflow. `gw` does the same but keeps the cursor put. |
| `-` | Format the whole buffer keeping cursor | `gwgg` from the bottom, or `gg=G` then `` `` `` | `native` | `gw` is the cursor-preserving twin of `gq`. |

### A5. Completion

| VS Code key | Action | Neovim | Type | Notes / alternatives |
|---|---|---|---|---|
| `Ctrl+Space` | Trigger suggest | Insert `Ctrl+X Ctrl+O` | `native` | Native omni-completion. The LSP client sets `'omnifunc'` on attach. |
| `Alt+Space` | Trigger suggest (second trigger) | Insert `Ctrl+X Ctrl+O` | `native` | Or enable `vim.lsp.completion.enable({ autotrigger = true })` in 0.11+ for automatic popups with no plugin. |
| `-` | Next completion candidate | Insert `Ctrl+N` | `native` | **CONFLICT NOTE:** this is why `Ctrl+N` must not be remapped to "new file". |
| `-` | Previous completion candidate | Insert `Ctrl+P` | `native` | Pairs with `Ctrl+N`. |
| `-` | Complete from current buffer only | Insert `Ctrl+X Ctrl+N` | `native` | Keyword completion, current file. `Ctrl+X Ctrl+P` for backwards. |
| `-` | Complete a whole line | Insert `Ctrl+X Ctrl+L` | `native` | Extremely useful for repeated boilerplate lines. |
| `-` | Complete a file path | Insert `Ctrl+X Ctrl+F` | `native` | Filename completion relative to the current directory. |
| `-` | Complete from the dictionary | Insert `Ctrl+X Ctrl+K` | `native` | Requires `'dictionary'` to be set. |
| `-` | Complete from a thesaurus | Insert `Ctrl+X Ctrl+T` | `native` | Requires `'thesaurus'`. |
| `-` | Complete a Vim command | Insert `Ctrl+X Ctrl+V` | `native` | Command-line completion inside Insert mode. |
| `-` | Spelling suggestions | Insert `Ctrl+X S` | `native-opt` | Requires `set spell`. Normal mode: `z=`. |
| `-` | Accept completion | `Ctrl+Y` | `native` | In the completion popup, `Ctrl+Y` accepts and `Ctrl+E` cancels. Note the overlap with the scroll keys outside the popup. |
| `-` | Jump to next snippet placeholder | `Tab` | `native` | Since 0.11, `Tab` / `Shift+Tab` jump when a snippet is active. Otherwise `Tab` inserts a tab. |
| `-` | Jump to previous snippet placeholder | `Shift+Tab` | `native` | See above. |
| `-` | Richer completion UI | `<leader>` free | `plugin` | `blink.cmp` or `nvim-cmp` if the native popup is not enough. Strategy E does not require either. |

---

## B. Diagnostics and Problems

### B1. Navigation

| VS Code key | Action | Neovim | Type | Notes / alternatives |
|---|---|---|---|---|
| `F2` | Next problem in files | `]d` | `native` | Default since 0.10. Accepts a count: `3]d` jumps three diagnostics forward. |
| `Shift+F2` | Previous problem in files | `[d` | `native` | Accepts a count the same way. |
| `-` | Last diagnostic in the buffer | `]D` | `native` | New in 0.11. Jumps to the last diagnostic, not "next". |
| `-` | First diagnostic in the buffer | `[D` | `native` | New in 0.11. |
| `-` | Next ERROR only, skipping warnings | `<leader>]e` | `leader` | `vim.diagnostic.jump({ count = 1, severity = vim.diagnostic.severity.ERROR })`. No native severity-filtered key. |
| `-` | Previous ERROR only | `<leader>[e` | `leader` | Mirror of the above with `count = -1`. |
| `-` | Next diagnostic across all buffers | `<leader>]D` | `leader` | Requires setting the diagnostics into the quickfix list first; see B3. |
| `-` | Next spelling error | `]s` | `native-opt` | Requires `set spell`. `[s` for the previous one, `z=` for suggestions, `zg` to add to the dictionary. |

### B2. Display

| VS Code key | Action | Neovim | Type | Notes / alternatives |
|---|---|---|---|---|
| `-` | Show the diagnostic under the cursor | `Ctrl+W d` | `native` | Default since 0.10 -> `vim.diagnostic.open_float()`. Repeat to enter the float. |
| `-` | Enable inline diagnostic text | `vim.diagnostic.config({ virtual_text = true })` | `native-opt` | **`virtual_text` is DISABLED by default in Neovim 0.11.** You must opt in. This surprises people migrating from VS Code, where inline squiggle text is always on. |
| `-` | Enable multi-line inline diagnostics | `vim.diagnostic.config({ virtual_lines = true })` | `native-opt` | A `virtual_lines` handler ships in 0.11. It renders the full message below the line instead of truncating at the right margin. Also off by default. |
| `-` | Show only the current line's virtual lines | `virtual_lines = { current_line = true }` | `native-opt` | Reduces the noise of full `virtual_lines`. |
| `-` | Toggle diagnostics off and on | `<leader>td` | `leader` | `vim.diagnostic.enable(not vim.diagnostic.is_enabled())`. |
| `-` | Diagnostic signs in the sign column | `vim.diagnostic.config({ signs = ... })` | `native-opt` | Requires `set signcolumn=yes` to avoid the gutter jumping in and out. |
| `-` | Underline diagnostics | `vim.diagnostic.config({ underline = true })` | `native-opt` | On by default. |
| `-` | Sort diagnostics by severity | `vim.diagnostic.config({ severity_sort = true })` | `native-opt` | Makes the most severe diagnostic win on a line that has several. |

### B3. Lists and panels

| VS Code key | Action | Neovim | Type | Notes / alternatives |
|---|---|---|---|---|
| `Alt+6` | Problems tool window | `<leader>xx` | `plugin` | Native equivalent: `:lua vim.diagnostic.setqflist()` then `:copen`. `trouble.nvim` gives the VS Code-style panel. |
| `Ctrl+Shift+M` | Problems tool window (second binding) | `<leader>xx` | `plugin` | Same as above. |
| `-` | Buffer diagnostics into the location list | `<leader>xl` | `leader` | `vim.diagnostic.setloclist()`. Then `]l` / `[l` to walk them. |
| `-` | All diagnostics into the quickfix list | `<leader>xq` | `leader` | `vim.diagnostic.setqflist()`. Then `]q` / `[q`. |
| `-` | Open the quickfix window | `:copen` | `native` | `:cclose` to close, `:cc N` to jump to entry N. |
| `-` | Open the location list window | `:lopen` | `native` | Location lists are per-window; quickfix is global. |
| `-` | Next quickfix entry | `]q` | `native` | Default since 0.11 — a built-in `vim-unimpaired`-style mapping. |
| `-` | Previous quickfix entry | `[q` | `native` | See C9 for the whole family. |

---

## C. Motion and Navigation

Vim's motions are the foundation of the whole editor: every motion doubles as the object of an
operator (see D2). VS Code has no equivalent to that composability, so this section lists many
more Neovim keys than VS Code bindings.

### C1. Character and word

| VS Code key | Action | Neovim | Type | Notes / alternatives |
|---|---|---|---|---|
| `Ctrl+Left` | Move one word left | `b` | `native` | `b` = back to the start of the previous word. `B` ignores punctuation (WORD). |
| `Ctrl+Right` | Move one word right | `w` | `native` | `w` = forward to the start of the next word. `W` for WORD. |
| `Ctrl+Left` | Move one word left (chat input) | `b` | `native` | The source file repeats this binding for `inChat && inputFocus`. Neovim's Cmdline mode uses `Shift+Left` / `Shift+Right` for word motion. |
| `Ctrl+Right` | Move one word right (chat input) | `w` | `native` | See above. |
| `Ctrl+Left` | Move one word left (other inputs) | `b` | `native` | Third duplicate in the source file, for `inputFocus && !editorTextFocus`. |
| `Ctrl+Right` | Move one word right (other inputs) | `w` | `native` | Third duplicate. |
| `-` | Move to the END of the next word | `e` | `native` | `E` for WORD. There is no VS Code equivalent — this is the key that makes `ce` so useful. |
| `-` | Move to the END of the previous word | `ge` | `native` | `gE` for WORD. |
| `-` | Move one character left / down / up / right | `h` `j` `k` `l` | `native` | Take counts: `12j` moves down 12 lines. |
| `-` | Move down one DISPLAY line (wrapped text) | `gj` | `native` | `gk` for up. Essential in soft-wrapped prose. |
| `-` | Jump to the next occurrence of a character | `f{char}` | `native` | `F{char}` backwards, `t{char}` stops before it, `T{char}` backwards-before. |
| `-` | Repeat the last `f`/`t` search | `;` | `native` | `,` repeats it in the reverse direction. This is the single most underused motion in Vim. |

### C2. Line

| VS Code key | Action | Neovim | Type | Notes / alternatives |
|---|---|---|---|---|
| `Ctrl+G` | Go to line number | `{count}G` or `:{count}` | `native` | `42G` goes to line 42. `:42<CR>` does the same. **CONFLICT:** `Ctrl+G` natively shows file info. |
| `Ctrl+G` | Go to line (second binding, `editorTextFocus`) | `{count}G` | `native` | Duplicate binding in the source file. |
| `-` | Start of line (column 0) | `0` | `native` | Absolute first column, including indentation. |
| `-` | First NON-BLANK character of the line | `^` | `native` | This is what "Home" usually means in VS Code with smart-home enabled. |
| `-` | End of line | `$` | `native` | `g_` goes to the last non-blank character instead. |
| `-` | Go to a percentage of the file | `{count}%` | `native` | `50%` jumps to the middle of the file. |
| `-` | Go to line, first non-blank | `{count}gg` | `native` | `gg` alone goes to line 1. |
| `-` | Go to a specific column | `{count}|` | `native` | `40|` puts the cursor in column 40. |
| `-` | Toggle relative line numbers | `<leader>tn` | `leader` | `set relativenumber!`. Makes `12j` / `7k` trivially countable. |

### C3. Screen and scroll

| VS Code key | Action | Neovim | Type | Notes / alternatives |
|---|---|---|---|---|
| `Ctrl+Alt+E` | Scroll down one line | `Ctrl+E` | `native` | **CONFLICT:** the user rebound this to `Ctrl+Alt+E` in VS Code precisely because `Ctrl+E` was taken. In Neovim use the native `Ctrl+E`. |
| `Ctrl+Alt+Y` | Scroll up one line | `Ctrl+Y` | `native` | Mirror of `Ctrl+E`. **CONFLICT:** `Ctrl+Y` in VS Code is "delete line"; in Vim it scrolls. |
| `-` | Scroll half a page down | `Ctrl+D` | `native` | **CONFLICT:** `Ctrl+D` in VS Code is "duplicate line". |
| `-` | Scroll half a page up | `Ctrl+U` | `native` | **CONFLICT:** `Ctrl+U` in VS Code is "cursor undo". |
| `-` | Scroll a full page down | `Ctrl+F` | `native` | **CONFLICT:** `Ctrl+F` in VS Code is "find". |
| `-` | Scroll a full page up | `Ctrl+B` | `native` | **CONFLICT:** `Ctrl+B` in VS Code is "go to definition". |
| `-` | Centre the current line on screen | `zz` | `native` | The single best quality-of-life key in Vim. `zt` puts the line at the top, `zb` at the bottom. |
| `-` | Redraw and centre, moving to first non-blank | `z.` | `native` | `z<CR>` for top, `z-` for bottom. |
| `-` | Move to the top line on screen | `H` | `native` | "High". `M` = middle, `L` = "Low". Takes a count: `3H` is three lines from the top. |
| `-` | Move to the middle line on screen | `M` | `native` | See above. |
| `-` | Move to the bottom line on screen | `L` | `native` | See above. |
| `-` | Scroll horizontally | `zl` / `zh` | `native` | `zL` / `zH` for half a screen. Only matters with `set nowrap`. |
| `-` | Keep N lines of context when scrolling | `set scrolloff=8` | `native-opt` | Makes `j`/`k` scroll the view before the cursor hits the edge. |
| `-` | Redraw the screen | `Ctrl+L` | `native` | **CONFLICT:** `Ctrl+L` in VS Code is "clear terminal". In Neovim it also clears search highlighting in most configurations. |

### C4. File

| VS Code key | Action | Neovim | Type | Notes / alternatives |
|---|---|---|---|---|
| `Ctrl+Home` | Go to the first line | `gg` | `native` | The canonical Vim first-line key. |
| `Alt+Shift+T` | Go to the first line (alias) | `gg` | `native` | The user added this alias in VS Code; in Neovim `gg` needs no alias. |
| `Ctrl+End` | Go to the last line | `G` | `native` | `G` with no count goes to the last line. |
| `Alt+Shift+B` | Go to the last line (alias) | `G` | `native` | Alias in VS Code; unnecessary in Neovim. |
| `-` | Go to the last edited position in this file | `` `. `` | `native` | Backtick-dot. `'.` goes to the line instead of the exact column. |
| `-` | Go to where you last left Insert mode | `gi` | `native` | Re-enters Insert mode at that exact spot. No VS Code equivalent. |
| `-` | Go to the position when the file was last closed | `` `" `` | `native-opt` | Requires the standard `BufReadPost` autocommand that restores the last cursor position. |
| `-` | Restore the previous cursor position after a jump | `` `` `` | `native` | Two backticks. Toggles between the current and previous jump position. |

### C5. Search motion

| VS Code key | Action | Neovim | Type | Notes / alternatives |
|---|---|---|---|---|
| `Ctrl+F` | Find in file | `/` | `native` | `/pattern<CR>`. **CONFLICT:** `Ctrl+F` scrolls a page forward. |
| `F3` | Find next match | `n` | `native` | Repeats in the original direction. |
| `Shift+F3` | Find previous match | `N` | `native` | Repeats in the opposite direction. |
| `Ctrl+F7` | Highlight usages of the symbol | `*` | `native` | `*` searches forward for the exact word under the cursor and highlights all matches when `hlsearch` is on. |
| `-` | Search backwards | `?` | `native` | `?pattern<CR>`. `n` then goes backwards, `N` forwards. |
| `-` | Search backwards for the word under the cursor | `#` | `native` | Mirror of `*`. |
| `-` | Search for a PARTIAL word under the cursor | `g*` | `native` | Unlike `*`, `g*` does not add word boundaries, so it also finds `myVarName` when on `myVar`. `g#` backwards. |
| `-` | Repeat the last search as a motion in an operator | `d/foo<CR>` | `native` | Deletes from the cursor up to the next `foo`. Search is a motion like any other. |
| `-` | Search with an offset | `/foo/e<CR>` | `native` | Puts the cursor on the END of the match. `/foo/b+2` for two characters past the start. |
| `-` | Recall search history | `/` then `Up` | `native` | Or `q/` to open the search history in a full editable window. |
| `-` | Clear search highlighting | `:noh<CR>` | `native` | Often bound to `<leader>h` or `Esc`. |
| `-` | Case-insensitive search unless you type a capital | `set ignorecase smartcase` | `native-opt` | The standard pairing. `/foo` matches `Foo`; `/Foo` matches only `Foo`. |
| `-` | Show match count in the command line | `set shortmess-=S` | `native-opt` | Displays `[3/17]` next to the search. |
| `-` | Incremental preview of `:s` while typing | `set inccommand=split` | `native-opt` | A Neovim exclusive. Live-previews substitutions in a split. Strongly recommended. |
| `-` | Jump anywhere on screen with two characters | `<leader>s` or `s` | `plugin` | `flash.nvim` or `leap.nvim`. There is no native equivalent; native `f`/`t`/`/` cover most of it. |

### C6. Jump history

| VS Code key | Action | Neovim | Type | Notes / alternatives |
|---|---|---|---|---|
| `Ctrl+Alt+Left` | Navigate back | `Ctrl+O` | `native` | Jumplist backwards. **CONFLICT:** `Ctrl+O` in Insert mode runs one Normal-mode command. |
| `Ctrl+Alt+Right` | Navigate forward | `Ctrl+I` | `native` | Jumplist forwards. Note `Ctrl+I` and `Tab` are the same byte in a terminal. |
| `Alt+Left` | Navigate back (second binding) | `Ctrl+O` | `native` | Duplicate binding in the source file. |
| `Alt+Right` | Navigate forward (second binding) | `Ctrl+I` | `native` | Duplicate binding in the source file. |
| `Ctrl+Shift+Backspace` | Go to the last edit location | `g;` | `native` | Changelist backwards. Distinct from the jumplist: it tracks *edits*, not *jumps*. |
| `Alt+G Shift+;` | Older position in the change list | `g;` | `native` | The user explicitly modelled this VS Code chord on Vim's `g;`. |
| `Alt+G Shift+,` | Newer position in the change list | `g,` | `native` | Mirror of `g;`. |
| `-` | Show the jumplist | `:jumps` | `native` | Then `{count}Ctrl+O` to jump back N entries. |
| `-` | Show the changelist | `:changes` | `native` | Then `{count}g;`. |
| `-` | Switch to the previously edited file | `Ctrl+^` | `native` | Also written `Ctrl+6`. The fastest two-file toggle in the editor. |

### C7. Marks

VS Code has no marks. This entire subcategory is a Neovim capability with no counterpart.

| VS Code key | Action | Neovim | Type | Notes / alternatives |
|---|---|---|---|---|
| `-` | Set a mark in this file | `m{a-z}` | `native` | Lowercase marks are file-local. |
| `-` | Set a GLOBAL mark across files | `m{A-Z}` | `native` | Uppercase marks jump to the file too, and survive restarts via `shada`. |
| `-` | Jump to a mark, exact column | `` `{mark} `` | `native` | Backtick. |
| `-` | Jump to a mark, first non-blank of the line | `'{mark}` | `native` | Single quote. |
| `-` | List all marks | `:marks` | `native` | Shows both local and global marks with their file and line. |
| `-` | Delete marks | `:delmarks a b c` or `:delmarks!` | `native` | `!` clears all lowercase marks in the buffer. |
| `-` | Start / end of the last Visual selection | `` `< `` / `` `> `` | `native` | These are what `:'<,'>` refers to in the command line. |
| `-` | Start / end of the last change or yank | `` `[ `` / `` `] `` | `native` | Lets you re-select or re-indent exactly what you just pasted: `` `[v`] ``. |
| `-` | Position before the latest jump | `` '' `` | `native` | Two single quotes. |
| `-` | Visual marker column for marks | `<leader>m` family | `plugin` | `marks.nvim` adds gutter signs and next/previous mark motions. |

### C8. Brackets and pairs

| VS Code key | Action | Neovim | Type | Notes / alternatives |
|---|---|---|---|---|
| `Ctrl+Shift+]` | Select to the matching bracket | `v%` | `native` | `%` is the matching-pair motion; prefixing `v` makes it a selection. |
| `Ctrl+Shift+[` | Select to the matching bracket (mirror) | `v%` | `native` | Same key in Neovim regardless of direction. |
| `-` | Jump to the matching bracket | `%` | `native` | Works for `()`, `[]`, `{}` and, with `matchit`, for HTML tags and language keywords such as `if`/`endif`. |
| `-` | Jump to the start of the enclosing block | `[{` | `native` | `]}` for the end. Works when the cursor is INSIDE the block. |
| `-` | Jump to the start of the enclosing parenthesis | `[(` | `native` | `])` for the end. |
| `-` | Delete the surrounding brackets | `ds(` | `plugin` | `nvim-surround` / `mini.surround`. Native-ish fallback: `%x` then jump back and `x`. |
| `-` | Change the surrounding brackets | `cs([` | `plugin` | Same plugins. |
| `-` | Auto-close brackets as you type | `-` | `plugin` | `nvim-autopairs` or `mini.pairs`. No native equivalent. |
| `-` | Highlight the matching bracket | `:packadd matchit` / built-in `matchparen` | `native` | `matchparen` ships enabled by default. |

### C9. The `[` and `]` family

Neovim 0.11 promoted a large set of `vim-unimpaired`-style mappings into **core defaults**.
These are `native` — no plugin, no config. Strategy E explicitly permits *extending* this
family, which is why several `leader`-free additions below are legitimate.

| VS Code key | Action | Neovim | Type | Notes / alternatives |
|---|---|---|---|---|
| `F2` / `Shift+F2` | Next / previous diagnostic | `]d` / `[d` | `native` | Accepts a count. See B1. |
| `-` | First / last diagnostic in the buffer | `[D` / `]D` | `native` | New in 0.11. |
| `-` | Next / previous quickfix entry | `]q` / `[q` | `native` | New core default in 0.11. |
| `-` | First / last quickfix entry | `[Q` / `]Q` | `native` | Capital Q jumps to the ends of the list. |
| `-` | Next / previous quickfix FILE | `]Ctrl+Q` / `[Ctrl+Q` | `native` | Skips to the next file in the quickfix list. |
| `-` | Next / previous location list entry | `]l` / `[l` | `native` | New core default in 0.11. |
| `-` | First / last location list entry | `[L` / `]L` | `native` | |
| `-` | Next / previous location list FILE | `]Ctrl+L` / `[Ctrl+L` | `native` | |
| `-` | Next / previous tag | `]t` / `[t` | `native` | New core default in 0.11. |
| `-` | First / last tag | `[T` / `]T` | `native` | |
| `-` | Next / previous tag in a preview window | `]Ctrl+T` / `[Ctrl+T` | `native` | |
| `-` | Next / previous arglist file | `]a` / `[a` | `native` | New core default in 0.11. Pairs with `:args`. |
| `-` | First / last arglist file | `[A` / `]A` | `native` | |
| `Alt+L` | Next buffer | `]b` | `native` | New core default in 0.11. `:bnext` under the hood. |
| `Alt+H` | Previous buffer | `[b` | `native` | `:bprevious` under the hood. |
| `-` | First / last buffer | `[B` / `]B` | `native` | |
| `-` | Add a blank line ABOVE the cursor | `[<Space>` | `native` | New core default in 0.11. Takes a count: `3[<Space>` adds three. Does NOT enter Insert mode. |
| `-` | Add a blank line BELOW the cursor | `]<Space>` | `native` | Mirror of the above. |
| `-` | Next / previous section | `]]` / `[[` | `native` | In 0.11 these also navigate OSC-133 shell prompts in a `:terminal` buffer. |
| `-` | Next / previous section end | `][` / `[]` | `native` | The four-way `[[`, `]]`, `][`, `[]` set. |
| `-` | Next / previous method start (treesitter) | `]m` / `[m` | `plugin` | Native `]m` works for C-like braces; `nvim-treesitter-textobjects` makes it language-aware. |
| `-` | Next / previous unsaved-change hunk | `]c` / `[c` | `native` | In `diff` mode this is the native next/previous-change motion. Git plugins reuse the same keys; see K2. |
| `-` | Next / previous misspelled word | `]s` / `[s` | `native-opt` | Requires `set spell`. |
| `-` | Next / previous comment block | `]/` `[/` or `<leader>]c` | `leader` | No native default. |
| `-` | Next / previous fold | `zj` / `zk` | `native` | Note these are `z`-prefixed, not `]`-prefixed. See section I. |

---

## D. Editing

### D1. Entering Insert mode

| VS Code key | Action | Neovim | Type | Notes / alternatives |
|---|---|---|---|---|
| `Shift+Enter` | Insert a line after and go there | `o` | `native` | Opens a new line below and enters Insert mode. Takes a count: `3o` is rarely useful, but `3O` plus text repeats it. |
| `Ctrl+Enter` | Insert a line after (second binding) | `o` | `native` | The source file binds `Ctrl+Enter` twice; the second is the Git stage-hunk binding, see K2. |
| `Ctrl+Alt+Enter` | Insert a line before | `O` | `native` | Opens a new line above. |
| `-` | Insert before the cursor | `i` | `native` | The base Insert command. |
| `-` | Insert at the first non-blank of the line | `I` | `native` | The correct "Home then type" for indented code. |
| `-` | Append after the cursor | `a` | `native` | |
| `-` | Append at the end of the line | `A` | `native` | This is the key used in the "append `;` to 40 lines" recipe below. |
| `-` | Insert at column 0 regardless of indent | `gI` | `native` | Distinct from `I`. |
| `-` | Insert at the end of a Visual Block | `Ctrl+V` then `$A` | `native` | Appends to every line of the block even when they have different lengths. |
| `-` | Replace mode (overtype) | `R` | `native` | `r{char}` replaces exactly one character without entering Insert mode. |
| `-` | Return to where you last left Insert mode | `gi` | `native` | No VS Code equivalent. |
| `-` | Leave Insert mode | `Esc` | `native` | Also `Ctrl+[` and `Ctrl+C`. **CONFLICT:** both are VS Code bindings for other things. `Ctrl+C` skips abbreviation expansion and `InsertLeave` side effects, so prefer `Esc` or `Ctrl+[`. |
| `-` | Leave Insert mode from the home row | `jk` | `leader` | An Insert-mode `inoremap jk <Esc>`. Strategy E permits this because `jk` is not a Normal-mode default binding being overwritten. Pair it with **CapsLock -> Esc remapped at the OS level** (`keyd`, `xremap`, or Karabiner on macOS) so `Esc` is always under the left pinky. |
| `-` | Run ONE Normal-mode command then return to Insert | Insert `Ctrl+O` | `native` | For example `Ctrl+O zz` to recentre without leaving Insert mode. |
| `-` | Insert the contents of a register while in Insert | Insert `Ctrl+R {reg}` | `native` | `Ctrl+R "` inserts the unnamed register, `Ctrl+R +` the system clipboard, `Ctrl+R =` evaluates an expression. |
| `-` | Insert a literal control character | Insert `Ctrl+V {key}` | `native` | Useful for finding out what byte a key sends, for example `Ctrl+V Ctrl+/`. |
| `-` | Insert a Unicode codepoint | Insert `Ctrl+V u00e9` | `native` | Also `Ctrl+K` for digraphs: `Ctrl+K e'` gives an accented e. |

### D2. Delete, change, yank

Vim's `operator + motion` grammar is the core idea here. Any operator (`d`, `c`, `y`, `>`, `<`,
`=`, `gu`, `gU`, `g~`, `gq`, `gc`) combines with any motion (C1-C5) or text object (E2). The
table lists the operators; the combinations are unbounded.

| VS Code key | Action | Neovim | Type | Notes / alternatives |
|---|---|---|---|---|
| `Ctrl+X` | Cut selection | `d` (Visual) or `dd` | `native` | Vim's delete IS cut — deleted text goes into a register. **CONFLICT:** `Ctrl+X` natively decrements the number under the cursor. |
| `Ctrl+X` | Cut in an input box | `d` | `native` | Duplicate binding in the source file for `inputFocus`. |
| `Ctrl+C` | Copy selection | `y` (Visual) or `yy` | `native` | "Yank". **CONFLICT:** `Ctrl+C` natively cancels / leaves Insert mode. |
| `Ctrl+C` | Copy in an input box | `y` | `native` | Duplicate binding in the source file. |
| `Ctrl+V` | Paste | `p` / `P` | `native` | `p` pastes after the cursor, `P` before. **CONFLICT:** `Ctrl+V` is Visual Block mode — one of the most valuable keys in the editor. Never remap it. |
| `Ctrl+V` | Paste in an input box | `p` | `native` | Duplicate binding in the source file. |
| `Ctrl+Backspace` | Delete the word to the left | `db` (Normal) / `Ctrl+W` (Insert) | `native` | Insert-mode `Ctrl+W` deletes the previous word — a readline convention Neovim shares. |
| `Ctrl+Backspace` | Delete word left in an input box | `Ctrl+W` in Cmdline | `native` | Duplicate binding in the source file. Cmdline mode supports `Ctrl+W` too. |
| `Ctrl+Delete` | Delete the word to the right | `dw` | `native` | `dW` for a WORD. |
| `Ctrl+Delete` | Delete word right in an input box | `dw` | `native` | Duplicate binding in the source file. |
| `-` | Delete a character | `x` | `native` | `X` deletes backwards. `3x` deletes three. |
| `-` | Delete to the end of the line | `D` | `native` | Shorthand for `d$`. |
| `-` | Change to the end of the line | `C` | `native` | Shorthand for `c$`. |
| `-` | Change a whole line | `S` or `cc` | `native` | Keeps the indentation. |
| `-` | Substitute one character | `s` | `native` | Deletes the character and enters Insert mode. |
| `-` | Change the word under the cursor | `ciw` | `native` | Works from anywhere inside the word, unlike `cw`. |
| `-` | Delete but keep the register clean | `"_d` | `native` | The black hole register. `"_dd` deletes a line without clobbering the yank register. |
| `-` | Yank a whole line | `yy` or `Y` | `native` | In Neovim 0.6+, `Y` yanks to the end of the line (`y$`), matching `D` and `C`. |
| `-` | Yank to the end of the file | `yG` | `native` | Any motion works as the object. |
| `-` | Paste over a selection without losing the yank | Visual `P` | `native` | In Neovim, Visual-mode `P` does not overwrite the unnamed register. Visual `p` does. |
| `-` | Re-select the text you just pasted | `` `[v`] `` | `native` | Or `gp` / `gP`, which leave the cursor after the pasted text. |
| `-` | Paste and adjust the indentation | `]p` / `[p` | `native` | Adjusts the indent of the pasted lines to the current line. |
| `-` | Swap two characters | `xp` | `native` | Delete a character, paste it after the next. `ddp` swaps two lines. |

### D3. Line operations

| VS Code key | Action | Neovim | Type | Notes / alternatives |
|---|---|---|---|---|
| `Ctrl+Y` | Delete line | `dd` | `native` | The JetBrains muscle memory maps cleanly. **CONFLICT:** `Ctrl+Y` scrolls up one line in Vim. |
| `Ctrl+D` | Duplicate line down | `yyp` | `native` | Yank the line, paste it below. `yyP` duplicates upwards. **CONFLICT:** `Ctrl+D` scrolls half a page. |
| `Shift+Alt+Down` | Move the line down | `:m +1<CR>==` or `<leader>j` | `leader` | No native single key. A common Strategy-E addition: `vim.keymap.set("n", "<leader>j", ":m .+1<CR>==")`. Visual mode: `:m '>+1<CR>gv=gv`. |
| `Shift+Alt+Up` | Move the line up | `:m -2<CR>==` or `<leader>k` | `leader` | Mirror of the above. |
| `Ctrl+Shift+Down` | Move the line down (second binding) | `:m +1<CR>==` | `leader` | Duplicate binding in the source file. |
| `Ctrl+Shift+Up` | Move the line up (second binding) | `:m -2<CR>==` | `leader` | Duplicate binding in the source file. |
| `-` | Move a RANGE of lines | `:10,20m 50` | `native` | Moves lines 10-20 to after line 50. The Visual-mode form is `:'<,'>m '>+1`. |
| `-` | Copy a range of lines to elsewhere | `:10,20t 50` | `native` | `:t` (also `:copy`) duplicates without deleting. `:t.` duplicates the current line in place. |
| `-` | Delete every line matching a pattern | `:g/pattern/d` | `native` | The global command. See the power extras section. |
| `-` | Delete every line NOT matching a pattern | `:v/pattern/d` | `native` | `:v` is `:g!`. |
| `-` | Sort a range of lines | `:'<,'>sort` | `native` | `sort u` removes duplicates, `sort n` sorts numerically, `sort!` reverses. |
| `-` | Reverse the order of lines | `:g/^/m0` | `native` | A classic global-command idiom. |
| `-` | Filter lines through an external command | `!ap jq .` | `native` | `!{motion}{cmd}` replaces the text with the command output. `:%!jq .` formats a whole JSON file. |

### D4. Indentation

| VS Code key | Action | Neovim | Type | Notes / alternatives |
|---|---|---|---|---|
| `Ctrl+]` | Indent lines | `>>` | `native` | **CONFLICT:** `Ctrl+]` is go-to-definition via `'tagfunc'`. Never remap it. Visual mode: `>`. |
| `Ctrl+[` | Outdent lines | `<<` | `native` | **CONFLICT:** `Ctrl+[` is exactly equivalent to `Esc` at the byte level. Never remap it. Visual mode: `<`. |
| `-` | Indent and keep the selection | Visual `>gv` | `native` | Or map Visual `>` to `>gv` so the selection survives repeated indents. |
| `-` | Indent a motion | `>ap`, `>i{` | `native` | `>` is an operator: `>i{` indents everything inside the enclosing braces. |
| `-` | Auto-indent using the language rules | `==` | `native` | `=` is the equalprg/indentexpr operator. `gg=G` reindents the whole file. |
| `-` | Indent in Insert mode | Insert `Ctrl+T` | `native` | `Ctrl+D` outdents. Both respect `'shiftwidth'`. |
| `-` | Set the indent width | `set shiftwidth=4 tabstop=4 expandtab` | `native-opt` | `set smartindent` or a treesitter indent module for language awareness. |
| `-` | Show indent guides | `-` | `plugin` | `indent-blankline.nvim`. `set list listchars=tab:>-` gets partway there natively. |

### D5. Case conversion

| VS Code key | Action | Neovim | Type | Notes / alternatives |
|---|---|---|---|---|
| `Ctrl+Shift+U` | Transform to uppercase (with a selection) | `gU` (Visual) or `gUiw` | `native` | `gU` is the uppercase operator. `gUU` uppercases the whole line. |
| `Ctrl+Shift+U` | Transform to lowercase (no selection) | `gu` (Visual) or `guiw` | `native` | The source file binds the same key to both, switching on `editorHasSelection`. |
| `Ctrl+Shift+L` | Explicit lowercase | `gu` | `native` | `guu` for the whole line. |
| `-` | Toggle the case of a character | `~` | `native` | Advances the cursor. `3~` toggles three characters. |
| `-` | Toggle the case of a motion | `g~{motion}` | `native` | `g~iw` toggles the case of a word, `g~~` a whole line. |
| `-` | Uppercase the rest of the line | `gU$` | `native` | Any motion works. |
| `-` | Convert snake_case to camelCase | `:s/_\(\l\)/\u\1/g` | `native` | `\u` uppercases the next character in the replacement. `\U` uppercases the rest. |
| `-` | Case coercion helpers | `<leader>c` family | `plugin` | `text-case.nvim` or `abolish.vim` (`crs` snake, `crc` camel, `crm` mixed, `cru` upper). |

### D6. Join and split

| VS Code key | Action | Neovim | Type | Notes / alternatives |
|---|---|---|---|---|
| `Ctrl+Shift+J` | Join lines | `J` | `native` | Joins the next line to this one and inserts one space. `3J` joins three lines. Visual mode: `J` joins the whole selection. |
| `-` | Join lines WITHOUT inserting a space | `gJ` | `native` | Exactly what you want for joining broken string literals. |
| `-` | Split a line at the cursor | `i<CR><Esc>` or `<leader>S` | `leader` | There is no native "split line" key; `r<CR>` replaces the character under the cursor with a newline, which is the closest one-key option. |
| `-` | Split a function argument list onto lines | `-` | `plugin` | `treesj` or `mini.splitjoin`. `gS` / `gJ` in those plugins. No native equivalent. |
| `-` | Join every line in a range | `:1,10join` | `native` | `:%j` joins the whole file into one line. |

### D7. Undo and redo

| VS Code key | Action | Neovim | Type | Notes / alternatives |
|---|---|---|---|---|
| `Ctrl+Z` | Undo | `u` | `native` | **CONFLICT: `Ctrl+Z` SUSPENDS Neovim to the shell.** The editor appears to vanish. It is not lost — type `fg` at the shell prompt to bring it back, or `jobs` to list suspended jobs. Never bind `Ctrl+Z` to undo. |
| `Ctrl+Shift+Z` | Redo | `Ctrl+R` | `native` | **CONFLICT:** `Ctrl+R` in VS Code is "replace". In Vim it is redo, and in Insert/Cmdline mode it inserts a register. |
| `Ctrl+U` | Undo cursor movement | `` `` `` or `Ctrl+O` | `native` | Vim has no "cursor undo"; the jumplist covers the same need. **CONFLICT:** `Ctrl+U` scrolls half a page (and in Insert mode deletes to the start of the line). |
| `-` | Undo all recent changes on one line | `U` | `native` | A line-level undo. Itself undoable with `u`. |
| `-` | Time-travel undo backwards | `:earlier 10m` | `native` | Also `:earlier 5` for five changes, `:earlier 1f` for one file write. |
| `-` | Time-travel undo forwards | `:later 10m` | `native` | Mirror of `:earlier`. |
| `-` | Undo tree branches | `g-` / `g+` | `native` | Moves through undo STATES rather than the linear undo chain, so you can recover a branch `u` would hide. |
| `-` | Visualise the undo tree | `<leader>u` | `plugin` | `undotree` or `mundo`. Native `:undolist` shows the raw data. |
| `-` | Persist undo history across restarts | `set undofile` | `native-opt` | Combined with `set undodir=...`. Then `u` still works tomorrow. |

### D8. Repeat and macros

VS Code has no equivalent to any row in this table. This is the largest single capability gap.

| VS Code key | Action | Neovim | Type | Notes / alternatives |
|---|---|---|---|---|
| `-` | Repeat the last change | `.` | `native` | The "dot command". Repeats the last edit, including its count and its text. `3.` repeats it with a new count. |
| `-` | Repeat the last Ex command | `@:` | `native` | Then `@@` to repeat again. |
| `-` | Record a macro | `q{a-z}` | `native` | `qq` starts recording into register `q`; `q` again stops. |
| `-` | Play a macro | `@{a-z}` | `native` | `@q` plays register `q`. `@@` replays the last one. |
| `-` | Play a macro many times | `100@q` | `native` | Stops early when a motion or search fails, which is usually exactly the right behaviour. |
| `-` | Append to an existing macro | `q{A-Z}` | `native` | `qQ` appends to the `q` register instead of replacing it. |
| `-` | Edit a macro as text | `"qp`, edit, `"qy$` | `native` | Paste the register, fix it by hand, yank it back. |
| `-` | Run a macro over a Visual selection | `:'<,'>normal @q` | `native` | Runs the macro on every selected line. |
| `-` | Run a macro on every matching line | `:g/pattern/normal @q` | `native` | The global command plus a macro is the most powerful bulk-edit tool in the editor. |
| `-` | Make plugin actions dot-repeatable | `-` | `plugin` | `vim-repeat` teaches `.` about plugin operators such as `nvim-surround`. |

### D9. Numbers

| VS Code key | Action | Neovim | Type | Notes / alternatives |
|---|---|---|---|---|
| `-` | Increment the number under the cursor | `Ctrl+A` | `native` | **CONFLICT:** `Ctrl+A` in VS Code is "select all". In Vim it increments. `10Ctrl+A` adds ten. |
| `-` | Decrement the number under the cursor | `Ctrl+X` | `native` | **CONFLICT:** `Ctrl+X` in VS Code is "cut". |
| `-` | Increment each line in a selection by 1, 2, 3... | Visual `g Ctrl+A` | `native` | Turns a column of `0 0 0 0` into `1 2 3 4`. Genuinely magic for building numbered lists. |
| `-` | Decrement progressively in a selection | Visual `g Ctrl+X` | `native` | Mirror of the above. |
| `-` | Control which number formats are recognised | `set nrformats=bin,hex` | `native-opt` | Remove `octal` so that `007` increments to `008` and not `010`. Add `alpha` to make `Ctrl+A` step letters. |
| `-` | Evaluate an expression into the buffer | Insert `Ctrl+R =2*21<CR>` | `native` | The expression register. Also does `Ctrl+R =line('.')`. |

---

## E. Selection

### E1. Visual modes

| VS Code key | Action | Neovim | Type | Notes / alternatives |
|---|---|---|---|---|
| `-` | Character-wise Visual mode | `v` | `native` | The base selection mode. |
| `-` | Line-wise Visual mode | `V` | `native` | Selects whole lines. |
| `-` | Block-wise Visual mode | `Ctrl+V` | `native` | **CONFLICT:** this is exactly the key VS Code uses for paste. Visual Block is a headline Vim feature; do not remap. |
| `-` | Block-wise Visual mode, alternative key | `Ctrl+Q` | `native` | Provided for terminals where `Ctrl+V` is swallowed by flow control or the terminal emulator. **CONFLICT:** `Ctrl+Q` is XON. |
| `-` | Reselect the previous Visual selection | `gv` | `native` | Also works after leaving Visual mode to run a command. |
| `-` | Swap to the other end of the selection | `o` | `native` | In Visual Block, `O` swaps to the other corner horizontally. |
| `-` | Switch between Visual modes without losing the selection | `v` / `V` / `Ctrl+V` | `native` | Pressing another Visual key while selecting changes the mode in place. |
| `-` | Select mode (typing replaces the selection) | `gh` / `gH` / `g Ctrl+H` | `native` | Behaves like a conventional editor selection. Rarely used but it exists. |

### E2. Text objects

Text objects are the second half of Vim's grammar. `i` means "inner" (excluding delimiters),
`a` means "a"/"around" (including delimiters). Every one combines with every operator.

| VS Code key | Action | Neovim | Type | Notes / alternatives |
|---|---|---|---|---|
| `Ctrl+Alt+W` | Select word | `viw` | `native` | `vaw` includes the trailing whitespace. |
| `-` | Change the text inside quotes | `ci"` | `native` | Works from anywhere on the line, not just inside the quotes. `ci'` and ``ci` `` too. |
| `-` | Delete a parenthesised expression including the parens | `da(` | `native` | `di(` keeps the parens. `(`, `)`, and `b` are interchangeable here. |
| `-` | Change the contents of an HTML/XML tag | `cit` | `native` | `cat` includes the tags themselves. |
| `-` | Select a paragraph | `vip` | `native` | `vap` includes the trailing blank line. |
| `-` | Select a `{...}` block | `vi{` | `native` | `va{` includes the braces. `B` is a synonym for `{`. |
| `-` | Select a `[...]` block | `vi[` | `native` | `va[` includes the brackets. |
| `-` | Select an angle-bracket block | `vi<` | `native` | `va<` includes the angle brackets. |
| `-` | Select a sentence | `vis` / `vas` | `native` | Sentence boundaries follow `'cpoptions'`. |
| `-` | Select a WORD (whitespace delimited) | `viW` / `vaW` | `native` | Captures `foo.bar-baz` as one unit. |
| `-` | Select a function body (language aware) | `vif` / `vaf` | `plugin` | `nvim-treesitter-textobjects`. There is no native language-aware function object. |
| `-` | Select a class | `vic` / `vac` | `plugin` | Same plugin. |
| `-` | Select a function argument | `via` / `vaa` | `plugin` | `nvim-treesitter-textobjects` or `mini.ai`. |
| `-` | Select the whole indent block | `vii` | `plugin` | `mini.indentscope` or `vim-indent-object`. Vital in YAML and Python. |
| `-` | Select the entire buffer as a text object | `vae` | `plugin` | `mini.ai`. Native equivalent: `ggVG`. |

### E3. Expand and shrink

| VS Code key | Action | Neovim | Type | Notes / alternatives |
|---|---|---|---|---|
| `Ctrl+W` | Expand selection (smart select) | Visual `an` | `native` | In Visual mode `an` expands the selection. When treesitter is inactive it falls back to `vim.lsp.buf.selection_range()`. **CONFLICT:** `Ctrl+W` is the window command prefix — the single most-used prefix in Neovim. Absolutely do not remap it. |
| `Ctrl+Shift+W` | Shrink selection | Visual `in` | `native` | The shrink counterpart of `an`. Same LSP `selection_range` fallback. |
| `-` | Treesitter incremental selection | `<leader>v` / `<CR>` family | `plugin` | `nvim-treesitter` `incremental_selection` gives node-aware grow/shrink. The native `an`/`in` covers most of it in 0.11+. |
| `-` | Grow the selection by a text object instead | `viw` then `a(` then `a{` | `native` | Repeatedly applying `a{object}` in Visual mode expands outward, which is the manual version of smart-select. |

### E4. Column edit and multi-cursor

Vim does not have multiple cursors. It has **Visual Block**, the **dot command**, **macros**,
and `:normal` over a range — which together cover more ground than multi-cursor does, and
which are all deterministic.

| VS Code key | Action | Neovim | Type | Notes / alternatives |
|---|---|---|---|---|
| `Alt+J` | Add a cursor at the next find match | `*` then `cgn` then `.` | `native` | `gn` is the "next match" text object. `cgn` changes the next match; `.` repeats it on the following match; `n` skips one. This is the idiomatic Vim replacement for multi-cursor and it is strictly more controllable. |
| `Alt+Shift+J` | Add a cursor at the previous find match | `#` then `cgN` then `.` | `native` | `gN` is the backwards counterpart. |
| `Ctrl+Alt+J` | Select all occurrences | `:%s/\<word\>//gc` or `cgn` plus `.` | `native` | `Ctrl+Alt+J` collides with the split-focus binding at the bottom of the source file. |
| `Ctrl+Alt+Shift+Up` | Insert a cursor above | `Ctrl+V k` | `native` | Visual Block extended upwards, then `I` or `A`. |
| `Ctrl+Alt+Shift+Down` | Insert a cursor below | `Ctrl+V j` | `native` | Visual Block extended downwards. Note the source file also binds `Ctrl+Alt+Shift+Down` to "increase view height"; see H3. |
| `-` | Insert the same text at the start of many lines | `Ctrl+V {motion} I text Esc` | `native` | The `Esc` is what broadcasts the insertion to every line in the block. |
| `-` | Append the same text to the end of many lines | `Ctrl+V {motion} $ A text Esc` | `native` | `$` makes the block ragged-right, so it works on lines of differing length. |
| `-` | Delete a rectangular column | `Ctrl+V {motion} d` | `native` | For example stripping a leading comment column. |
| `-` | Replace a rectangular column with one character | `Ctrl+V {motion} r-` | `native` | Fills the block with `-`. |
| `-` | Change a rectangular column | `Ctrl+V {motion} c text Esc` | `native` | |
| `-` | True multiple cursors | `-` | `plugin` | `multicursor.nvim` or `vim-visual-multi` if the native workflow genuinely does not fit. Strategy E does not require either. |

**Worked example — append `;` to 40 lines.** There are three native solutions and no plugin is
needed for any of them.

1. **Visual Block.** `Ctrl+V` then `39j` then `$` then `A;` then `Esc`.
   Note carefully: the cursor starts on line 1, so `39j` selects **40** lines.
   `40j` would select **41** lines. The `$` makes the block ragged-right so the `;`
   lands at the true end of each line regardless of length.
2. **`:normal` over a range.** `:%norm A;`
   Runs the Normal-mode command `A;` on every line in the file. Restrict the range to be
   precise: `:1,40norm A;` or, with a Visual selection active, `:'<,'>norm A;`.
3. **A macro.** `qq` then `A;` then `Esc` then `j` then `q` to record; then `39@q` to replay.
   The recorded macro is one line's worth of work; the count does the rest.

Solution 2 is usually the shortest to type. Solution 1 is the easiest to see while doing it.
Solution 3 generalises to arbitrarily complex per-line work.

### E5. Select all

| VS Code key | Action | Neovim | Type | Notes / alternatives |
|---|---|---|---|---|
| `Ctrl+A` | Select all | `ggVG` | `native` | Go to the top, line-Visual, go to the bottom. **CONFLICT:** `Ctrl+A` increments the number under the cursor. |
| `Ctrl+A` | Select all in an input box | `ggVG` | `native` | Duplicate binding in the source file for `inputFocus`. |
| `-` | Yank the whole file | `:%y+` | `native` | Copies the whole buffer to the system clipboard without moving the cursor. Cleaner than `ggVG"+y`. |
| `-` | Delete the whole file | `:%d` | `native` | Or `ggdG`. |
| `-` | Operate on the whole file with any operator | `gg{op}G` | `native` | `gg=G` reindents everything, `gggqG` reflows everything, `ggyG` yanks everything. |
| `-` | Address the whole file in Ex commands | `%` | `native` | `%` is shorthand for the range `1,$`. |

---

## F. Search and Replace

### F1. In-buffer search

| VS Code key | Action | Neovim | Type | Notes / alternatives |
|---|---|---|---|---|
| `Ctrl+F` | Find | `/` | `native` | **CONFLICT:** `Ctrl+F` scrolls forward a page. |
| `F3` | Find next | `n` | `native` | |
| `Shift+F3` | Find previous | `N` | `native` | |
| `-` | Search backwards | `?` | `native` | |
| `-` | Keep the cursor centred while searching | `nzzzv` | `leader` | A common `<leader>`-free remap is `nnoremap n nzzzv`, but that remaps a default and Strategy E forbids it. Use `n` then `zz`, or accept `set scrolloff=999`. |
| `-` | Open the search history in an editable window | `q/` | `native` | `q?` for backwards, `q:` for the command history. Press `Ctrl+C` to return to the plain command line. |
| `-` | Search only within a range | `:10,50g/pattern/p` | `native` | Or use Visual mode and `/\%V pattern`. |
| `-` | Search for the current Visual selection | `y` then `/Ctrl+R"` | `native` | Yank, then paste the register into the search prompt. |
| `-` | Very-magic regex (PCRE-like) | `/\vpattern` | `native` | `\v` makes `(`, `)`, `+`, `?`, `{` special without backslashes. `\V` is very-nomagic for literal strings. |
| `-` | Fuzzy find within the current buffer | `<leader>/` | `plugin` | Telescope `current_buffer_fuzzy_find` or fzf-lua `blines`. |

### F2. In-buffer replace

| VS Code key | Action | Neovim | Type | Notes / alternatives |
|---|---|---|---|---|
| `Ctrl+R` | Start find and replace | `:%s/old/new/g` | `native` | **CONFLICT:** `Ctrl+R` is redo in Normal mode and "insert register" in Insert and Cmdline mode. |
| `-` | Replace with confirmation on every match | `:%s/old/new/gc` | `native` | The `c` flag prompts: `y` yes, `n` no, `a` all remaining, `q` quit, `l` this one then quit, `Ctrl+E`/`Ctrl+Y` to scroll while deciding. |
| `-` | Replace only in a Visual selection | `:'<,'>s/old/new/g` | `native` | Typing `:` while a selection is active pre-fills `'<,'>`. |
| `-` | Replace only on this line | `:s/old/new/g` | `native` | No range means the current line. |
| `-` | Replace whole words only | `:%s/\<old\>/new/g` | `native` | `\<` and `\>` are word boundaries. |
| `-` | Case-insensitive replace | `:%s/old/new/gi` | `native` | The `i` flag. `I` forces case sensitivity. |
| `-` | Reuse the last search pattern in a replace | `:%s//new/g` | `native` | An empty pattern means "the last search". So `*` then `:%s//new/g` renames the word under the cursor everywhere. |
| `-` | Use capture groups | `:%s/\(\w\+\)_\(\w\+\)/\2_\1/g` | `native` | `\1`, `\2` in the replacement. With `\v` the groups need no backslashes. |
| `-` | Live-preview the substitution while typing | `set inccommand=split` | `native-opt` | A Neovim exclusive. The split shows every affected line as you type the pattern. |
| `-` | Repeat the last substitute on this line | `&` | `native` | `g&` repeats it across the whole file with the same flags. |
| `-` | Increment a number inside a replacement | `:%s/x/\=line('.')/g` | `native` | `\=` evaluates a Vimscript expression per match. |

### F3. Project search

| VS Code key | Action | Neovim | Type | Notes / alternatives |
|---|---|---|---|---|
| `Ctrl+Shift+F` | Find in files | `<leader>fg` | `plugin` | Telescope `live_grep` or fzf-lua `live_grep`. Native equivalent: `:grep pattern` with `set grepprg=rg\ --vimgrep` then `:copen`. |
| `Ctrl+Shift+H` | Open a search editor | `<leader>fG` | `plugin` | Telescope with `--fixed-strings`, or `:copen` after `:grep`. |
| `Alt+2` | Search tool window | `<leader>fg` | `plugin` | Same picker. See H6. |
| `-` | Native project grep | `:grep -n pattern .` | `native-opt` | Requires `set grepprg=rg\ --vimgrep\ --smart-case` and `set grepformat=%f:%l:%c:%m`. Results land in the quickfix list; then `]q` / `[q`. |
| `-` | Grep with the internal engine, no external tool | `:vimgrep /pattern/gj **/*.php` | `native` | Slower than ripgrep but needs nothing installed. The `j` flag stops it from jumping to the first hit. |
| `-` | Grep for the word under the cursor | `:grep -w <cword>` | `native-opt` | Or `<leader>fw` in Telescope `grep_string`. |
| `-` | Search only the files in the arglist | `:vimgrep /pattern/ ##` | `native` | `##` expands to every arglist file. |
| `-` | Persist a quickfix list before running another search | `:colder` / `:cnewer` | `native` | Neovim keeps ten quickfix lists; `:colder` steps back to the previous one. |

### F4. Project replace

| VS Code key | Action | Neovim | Type | Notes / alternatives |
|---|---|---|---|---|
| `Ctrl+Shift+R` | Replace in files | `:cfdo %s/old/new/ge \| update` | `native` | The canonical native workflow: `:grep pattern` -> `:copen` -> review -> `:cfdo`. The `e` flag suppresses "pattern not found" errors; `update` writes only changed buffers. |
| `-` | Replace across the arglist | `:argdo %s/old/new/ge \| update` | `native` | Set the arglist first: `:args **/*.php`. |
| `-` | Replace across all open buffers | `:bufdo %s/old/new/ge \| update` | `native` | Requires `set hidden` (the default in Neovim). |
| `-` | Replace only on the quickfix LINES, not whole files | `:cdo s/old/new/ge \| update` | `native` | `:cdo` runs per quickfix entry; `:cfdo` runs per file. Choose deliberately. |
| `-` | Interactive project-wide find and replace UI | `<leader>sr` | `plugin` | `grug-far.nvim` or `spectre.nvim` give the VS Code panel experience. |
| `-` | LSP-aware rename across the project | `grn` | `native` | For renaming a *symbol* this is correct and safe; text substitution is not. Prefer `grn`. |

### F5. Word and symbol highlight

| VS Code key | Action | Neovim | Type | Notes / alternatives |
|---|---|---|---|---|
| `Ctrl+F7` | Highlight usages of the symbol | `*` | `native` | With `set hlsearch` every occurrence lights up until `:noh`. |
| `Ctrl+Down` | Jump to the next highlighted occurrence | `n` (after `*`) | `native` | `*` already moves to the next one; `n` continues. |
| `Ctrl+Up` | Jump to the previous highlighted occurrence | `N` (after `*`) | `native` | Or press `#` to search backwards from the start. |
| `-` | Automatic highlight of the symbol under the cursor | `vim.lsp.buf.document_highlight()` | `native-opt` | Needs a `CursorHold` autocommand plus `vim.lsp.buf.clear_references()` on `CursorMoved`. No default key. |
| `-` | Enable search highlighting at all | `set hlsearch` | `native-opt` | On by default in Neovim. `set incsearch` (also default) highlights as you type. |
| `-` | Highlight the yanked region briefly | `vim.hl.on_yank()` | `native-opt` | A `TextYankPost` autocommand. Extremely useful for confirming what a `y{motion}` actually grabbed. |
| `-` | Multiple persistent highlight colours | `<leader>hh` | `plugin` | `vim-interestingwords` or `nvim-hlslens`. No native multi-colour highlight. |

---

## G. Files, Buffers, Editors

Terminology: VS Code "editors"/"tabs" are Neovim **buffers**. Neovim **tabpages** are
*window layouts*, not files — this is the single most common point of confusion when
migrating. See H5.

### G1. Open and find

| VS Code key | Action | Neovim | Type | Notes / alternatives |
|---|---|---|---|---|
| `Shift Shift` | Search Everywhere / Quick Open | `<leader><leader>` or `<leader>ff` | `plugin` | Telescope `find_files` or fzf-lua. The source file notes VS Code does not natively support a double-shift chord at all. |
| `Ctrl+Shift+N` | Go to File | `<leader>ff` | `plugin` | Native equivalent: `:find **/name` with `set path+=**`. Genuinely usable, just slower to type. |
| `Ctrl+Shift+A` | Show all commands (command palette) | `:` | `native` | The command line IS the command palette. `Ctrl+D` after a partial command lists completions; `Tab` cycles them; `:help :command` documents them. |
| `Ctrl+N` | New untitled file | `:enew` | `native` | **CONFLICT:** `Ctrl+N` is Insert-mode "next completion". `:enew` opens an empty unnamed buffer; `:w path` names it on save. |
| `-` | Open a specific file | `:e path/to/file` | `native` | `Tab` completes paths. `:e!` discards local changes and rereads from disk. |
| `-` | Open a file relative to the current one | `:e %:h/other.php` | `native` | `%` is the current file, `:h` takes the head (directory). |
| `-` | Native fuzzy-ish file open | `:find name` | `native-opt` | Requires `set path+=**` and `set wildmenu wildmode=longest:full,full`. |
| `-` | Fuzzy find in the git-tracked file set | `<leader>fG` | `plugin` | Telescope `git_files`. Native: `:args \`git ls-files\`` then `]a` / `[a`. |
| `-` | Open the file path under the cursor | `gf` | `native` | `Ctrl+W f` opens it in a split, `Ctrl+W gf` in a new tabpage. |
| `-` | Reopen the current file as read-only | `:view %` | `native` | |

### G2. Save

| VS Code key | Action | Neovim | Type | Notes / alternatives |
|---|---|---|---|---|
| `Ctrl+S` | Save | `:w` | `native` | **DO NOT BIND `Ctrl+S`.** In a terminal `Ctrl+S` sends XOFF and freezes the terminal until `Ctrl+Q` (XON). It is also Insert-mode signature help in Neovim 0.11+. Use `:w`, or add `<leader>w` -> `:w<CR>`. |
| `Ctrl+Shift+S` | Save As | `:saveas path` | `native` | `:w path` writes a copy but keeps editing the original; `:saveas` switches the buffer to the new name. |
| `-` | Save only if modified | `:update` | `native` | The right command inside `:bufdo` and `:cfdo` loops. |
| `-` | Save all modified buffers | `:wa` | `native` | `:wqa` saves everything and quits. |
| `-` | Save and quit | `:x` or `ZZ` | `native` | `ZZ` is the Normal-mode form. `:x` writes only if the buffer changed; `:wq` always writes. |
| `-` | Quit without saving | `:q!` or `ZQ` | `native` | `:qa!` abandons everything. |
| `-` | Save a file that needs root | `:w !sudo tee % > /dev/null` | `native` | Then `:e!` to reload. |
| `-` | Autosave on focus lost | `au FocusLost * silent! wa` | `native-opt` | The closest thing to VS Code's `files.autoSave`. |

### G3. Buffer navigation

| VS Code key | Action | Neovim | Type | Notes / alternatives |
|---|---|---|---|---|
| `Alt+L` | Next editor | `]b` | `native` | Core default since 0.11. Equivalent to `:bnext`. |
| `Alt+H` | Previous editor | `[b` | `native` | Core default since 0.11. Equivalent to `:bprevious`. |
| `-` | First / last buffer | `[B` / `]B` | `native` | |
| `-` | Toggle between the two most recent buffers | `Ctrl+^` | `native` | Also written `Ctrl+6`. Faster than any picker for a two-file edit loop. |
| `-` | List all buffers | `:ls` or `:buffers` | `native` | Then `:b {number}` or `:b partial-name`. |
| `-` | Jump to a buffer by partial name | `:b conf` | `native` | Matches any buffer whose path contains `conf`. `Tab` disambiguates. |
| `-` | Buffer picker | `<leader>fb` | `plugin` | Telescope `buffers` or fzf-lua. |
| `-` | Visible buffer line (tab bar) | `-` | `plugin` | `bufferline.nvim` or `barbar.nvim` if the VS Code tab strip is missed. `set showtabline=2` shows the native tabpage line, which is not the same thing. |
| `Ctrl+0` | Focus the sidebar | `Ctrl+W W` or `<leader>e` | `native` | `Ctrl+W W` cycles windows; a file-explorer toggle is a `<leader>` addition. See G6. |

### G4. Closing

| VS Code key | Action | Neovim | Type | Notes / alternatives |
|---|---|---|---|---|
| `Ctrl+F4` | Close the active editor | `:bd` | `native` | `:bd` unloads the buffer. `:bd!` discards unsaved changes. |
| `Ctrl+Shift+F4` | Close all editors | `:%bd` | `native` | `:%bd` deletes every buffer. `:%bd|e#` closes all but the current one. |
| `Ctrl+K W` | Close all editors (chord) | `:%bd` | `native` | Duplicate intent in the source file. |
| `Ctrl+K O` | Close other editors | `:%bd \| e# \| bd#` | `native` | Keeps the current buffer, drops the rest. Worth a `<leader>bo` alias. |
| `Ctrl+K Ctrl+O` | Close other editor groups | `Ctrl+W o` | `native` | `Ctrl+W o` makes the current WINDOW the only one. That is the closest native concept. |
| `Shift+Escape` | Close the panel | `Ctrl+W c` or `:cclose` | `native` | `Ctrl+W c` closes the current window; `:cclose` / `:lclose` close the quickfix and location lists. |
| `-` | Close a window but keep the buffer loaded | `Ctrl+W c` | `native` | Distinct from `:bd`, which unloads the buffer everywhere. |
| `-` | Delete a buffer but keep the window layout | `<leader>bd` | `plugin` | `mini.bufremove` or `bufdelete.nvim`. Native `:bd` collapses the window that held it. |
| `-` | Wipe a buffer completely including marks | `:bw` | `native` | Stronger than `:bd`. |

### G5. Recent and history

| VS Code key | Action | Neovim | Type | Notes / alternatives |
|---|---|---|---|---|
| `Ctrl+E` | Recent files | `<leader>fo` | `plugin` | Telescope `oldfiles` or fzf-lua. Native: `:browse oldfiles` then pick a number, backed by the shada file. **CONFLICT:** `Ctrl+E` scrolls down one line. |
| `Ctrl+Shift+E` | All editors by most recently used | `<leader>fb` | `plugin` | Telescope `buffers` sorted by recency. Native: `:ls t` sorts by last-used time. |
| `Ctrl+Shift+T` | Reopen the closed editor | `<leader>fo` then pick | `plugin` | No native "reopen last closed". `:browse oldfiles` is the native path. |
| `-` | Native recent-files list | `:oldfiles` | `native` | Reads `v:oldfiles` from the shada file. `:browse oldfiles` makes it selectable. |
| `-` | Command history | `q:` | `native` | Opens the command history as an editable buffer. Edit a line and press `Enter` to run it. |
| `-` | Search history | `q/` | `native` | Same idea for searches. |
| `-` | Cycle the command history matching a prefix | `:` then `Ctrl+P` / `Ctrl+N` | `native` | Or `Up` / `Down`, which filter by what you have typed so far. |
| `Alt+Shift+C` | View recent changes (Git timeline) | `<leader>gh` | `plugin` | `gitsigns.nvim` blame or `diffview.nvim` file history. See K3. |

### G6. Explorer

| VS Code key | Action | Neovim | Type | Notes / alternatives |
|---|---|---|---|---|
| `Alt+1` | Explorer tool window | `<leader>e` | `native-opt` | Neovim ships `netrw` (`:Explore`, `:Sexplore`, `:Vexplore`) and, in 0.11+, `:Oil`-style editing is still a plugin. A `<leader>e` toggle is the standard addition. |
| `Alt+F1` | Reveal the active file in the Explorer | `:Explore` or `<leader>E` | `native` | Plain `:Explore` opens netrw in the current file's directory, which is exactly "reveal". |
| `Ctrl+0` | Focus the sidebar | `Ctrl+W W` | `native` | Cycles to the next window, including a tree window. |
| `-` | Open a directory as a buffer | `:e .` | `native` | netrw renders the directory listing. `-` in `oil.nvim` does the same with editable semantics. |
| `-` | Directory tree panel | `<leader>e` | `plugin` | `nvim-tree`, `neo-tree`, or `oil.nvim`. All are optional; netrw works out of the box. |
| `-` | Change the working directory to the current file | `:cd %:h` | `native` | `:lcd %:h` changes it only for the current window. `:pwd` shows it. |
| `-` | Fuzzy browse from the current file's directory | `<leader>fd` | `plugin` | Telescope `find_files` with `cwd = vim.fn.expand("%:h")`. |

### G7. File operations

| VS Code key | Action | Neovim | Type | Notes / alternatives |
|---|---|---|---|---|
| `Alt+F2` | Rename the file (Finder style) | `:!mv % newname` then `:e newname` | `native` | Or `:saveas newname` followed by `:!rm #`. |
| `Shift+F6` | Rename the file (Explorer focus) | `R` in netrw | `native` | netrw binds `R` to rename and `D` to delete. `oil.nvim` lets you edit the listing like text and `:w` to apply. |
| `Ctrl+Shift+C` | Copy the path of the active file | `:let @+ = expand('%:p')` | `native` | Worth a `<leader>yp` alias. `%:p` absolute, `%` relative, `%:t` tail only, `%:h` directory. |
| `-` | Show the current file name and status | `Ctrl+G` | `native` | `1Ctrl+G` shows the full path; `2Ctrl+G` shows the buffer number too. |
| `-` | Delete the current file | `:call delete(expand('%')) \| bd!` | `native` | Worth a `<leader>bD` alias. |
| `-` | Create the parent directory on save | `au BufWritePre * call mkdir(expand('<afile>:p:h'), 'p')` | `native-opt` | Neovim will not create missing directories by itself. |
| `-` | Reload the file from disk | `:e!` | `native` | `:checktime` reloads every buffer whose file changed externally. |
| `-` | Diff the buffer against the file on disk | `:DiffOrig` | `native-opt` | The command from `:help :DiffOrig`; not defined by default, but the recipe is in the built-in help. |
| `-` | Open a file at a specific line | `nvim +42 file` or `:e +42 file` | `native` | Also `nvim file:42` with a small wrapper. |

---

## H. Windows and Layout

`Ctrl+W` is the window command prefix and is the busiest prefix in Neovim. VS Code binds
`Ctrl+W` to "expand selection" in this configuration. Under Strategy E the Vim meaning wins
unconditionally.

### H1. Splits

| VS Code key | Action | Neovim | Type | Notes / alternatives |
|---|---|---|---|---|
| `Ctrl+\` | Split editor (vertical) | `Ctrl+W v` | `native` | Also `:vsplit` or `:vs`. `Ctrl+W Ctrl+V` works too. |
| `Ctrl+Shift+\` | Split editor down (horizontal) | `Ctrl+W s` | `native` | Also `:split` or `:sp`. |
| `Ctrl+Alt+\` | Split orthogonal (flip the split direction) | `Ctrl+W t Ctrl+W H` | `native` | `Ctrl+W H` / `Ctrl+W J` rotate the layout between vertical and horizontal. `Ctrl+W t` first moves to the top-left window. |
| `-` | Split and open a different file | `:vsp path` | `native` | `:sp path` for horizontal. |
| `-` | Split showing the same buffer twice | `Ctrl+W v` | `native` | Both windows scroll independently over one buffer. Use `:set scrollbind` to link them. |
| `-` | New empty split | `Ctrl+W n` | `native` | Horizontal split containing an empty buffer. |
| `-` | Duplicate the window into a new tabpage | `Ctrl+W T` | `native` | Capital T. Moves the current window out into its own tabpage. |
| `-` | Control where new splits appear | `set splitright splitbelow` | `native-opt` | Without these, vertical splits open to the LEFT and horizontal splits ABOVE, which surprises everyone from VS Code. |
| `-` | Equalise all window sizes | `Ctrl+W =` | `native` | |
| `-` | Rotate windows | `Ctrl+W r` | `native` | `Ctrl+W R` rotates the other way. `Ctrl+W x` exchanges two windows. |

### H2. Focus

| VS Code key | Action | Neovim | Type | Notes / alternatives |
|---|---|---|---|---|
| `Ctrl+Alt+H` | Focus the left group | `Ctrl+W h` | `native` | The whole point of `hjkl` window motion. |
| `Ctrl+Alt+L` | Focus the right group | `Ctrl+W l` | `native` | Note `Ctrl+Alt+L` is bound twice in the source file: format document, and focus right group. |
| `Ctrl+Alt+K` | Focus the group above | `Ctrl+W k` | `native` | |
| `Ctrl+Alt+J` | Focus the group below | `Ctrl+W j` | `native` | Note `Ctrl+Alt+J` is bound twice in the source file: select all occurrences, and focus below group. |
| `Ctrl+1` | Focus the first editor group | `Ctrl+W t` | `native` | `Ctrl+W t` goes to the top-left window. Or `1Ctrl+W w` to go to window 1 by number. |
| `Ctrl+2` | Focus the second editor group | `2Ctrl+W w` | `native` | `{count}Ctrl+W w` jumps to window number `{count}`. |
| `Ctrl+3` | Focus the third editor group | `3Ctrl+W w` | `native` | |
| `-` | Cycle to the next window | `Ctrl+W w` | `native` | `Ctrl+W W` cycles backwards. |
| `-` | Focus the bottom-right window | `Ctrl+W b` | `native` | The counterpart of `Ctrl+W t`. |
| `-` | Return to the previously focused window | `Ctrl+W p` | `native` | The window equivalent of `Ctrl+^`. |
| `-` | Move the current window to the far left | `Ctrl+W H` | `native` | `Ctrl+W J` bottom, `Ctrl+W K` top, `Ctrl+W L` far right. Capital letters MOVE, lowercase FOCUS. |
| `-` | Seamless focus across tmux panes | `-` | `plugin` | `vim-tmux-navigator` if tmux is in use. |

### H3. Resize

| VS Code key | Action | Neovim | Type | Notes / alternatives |
|---|---|---|---|---|
| `Ctrl+Alt+Shift+Left` | Increase the view width | `Ctrl+W >` | `native` | `{count}Ctrl+W >` widens by `{count}` columns. |
| `Ctrl+Alt+Shift+Right` | Decrease the view width | `Ctrl+W <` | `native` | |
| `Ctrl+Alt+Shift+Down` | Increase the view height | `Ctrl+W +` | `native` | |
| `Ctrl+Alt+Shift+Up` | Decrease the view height | `Ctrl+W -` | `native` | |
| `-` | Maximise the height of the current window | `Ctrl+W _` | `native` | Underscore. |
| `-` | Maximise the width of the current window | `Ctrl+W \|` | `native` | Pipe character. |
| `-` | Restore equal sizes | `Ctrl+W =` | `native` | |
| `-` | Set an exact height | `:resize 20` | `native` | `:vertical resize 80` for width. |
| `-` | Keep the focused window large automatically | `set winwidth=100 winminwidth=10` | `native-opt` | Makes the active window expand as you move between splits. |
| `-` | Toggle-maximise the current split | `<leader>z` | `leader` | `Ctrl+W \|` plus `Ctrl+W _`, or a small toggle function. `mini.misc.zoom` also does it. |

### H4. Close

| VS Code key | Action | Neovim | Type | Notes / alternatives |
|---|---|---|---|---|
| `Ctrl+K Ctrl+O` | Close other editor groups | `Ctrl+W o` | `native` | "Only". Closes every window except the current one. |
| `Shift+Escape` | Close the panel | `Ctrl+W c` | `native` | Or `:cclose` / `:lclose` for the quickfix and location lists specifically. |
| `-` | Close the current window | `Ctrl+W c` | `native` | Keeps the buffer loaded. `Ctrl+W q` is `:quit`, which exits Neovim if it is the last window. |
| `-` | Quit all windows | `:qa` | `native` | `:qa!` discards unsaved changes. |
| `-` | Close a preview window | `Ctrl+W z` | `native` | |

### H5. Tabpages

**A Neovim tabpage is not a VS Code tab.** A tabpage is a *named window layout*. The VS Code
notion of a tab maps to a Neovim **buffer** (see G3). Use tabpages for workspaces, not files.

| VS Code key | Action | Neovim | Type | Notes / alternatives |
|---|---|---|---|---|
| `-` | New tabpage | `:tabnew` | `native` | `:tabedit path` opens a file in one. |
| `-` | Next / previous tabpage | `gt` / `gT` | `native` | `{count}gt` jumps to tabpage `{count}`. |
| `-` | Go to the last-used tabpage | `g<Tab>` | `native` | Added as a default in 0.10. |
| `-` | Close a tabpage | `:tabclose` | `native` | `:tabonly` closes all the others. |
| `-` | Move a tabpage | `:tabmove +1` | `native` | `:tabmove 0` sends it to the front. |
| `-` | List tabpages | `:tabs` | `native` | |
| `-` | Run a command in every tabpage | `:tabdo {cmd}` | `native` | Sibling of `:bufdo`, `:argdo`, `:windo`. |
| `-` | Move the current window into a new tabpage | `Ctrl+W T` | `native` | |

### H6. Tool windows

| VS Code key | Action | Neovim | Type | Notes / alternatives |
|---|---|---|---|---|
| `Alt+1` | Explorer | `<leader>e` | `native-opt` | netrw `:Explore` natively; a tree plugin for the panel feel. See G6. |
| `Alt+2` | Search | `<leader>fg` | `plugin` | Telescope / fzf-lua live grep. Native: `:grep` plus `:copen`. See F3. |
| `Alt+3` | Source Control | `<leader>gg` | `plugin` | `neogit` or `vim-fugitive` (`:Git`). See K1. |
| `Alt+4` | Run and Debug | `<leader>dd` | `plugin` | `nvim-dap` plus `nvim-dap-ui`. See L. |
| `Alt+5` | Extensions | `:Lazy` | `plugin` | `lazy.nvim`'s UI. Also `:Mason` for LSP/DAP/linter binaries. |
| `Alt+6` | Problems | `<leader>xx` | `plugin` | `trouble.nvim`. Native: `vim.diagnostic.setqflist()` plus `:copen`. See B3. |
| `Alt+7` | Outline / Structure | `gO` | `native` | Document symbols into the location list. A panel needs `aerial.nvim` or `outline.nvim`. |
| `Alt+0` | Output | `:messages` | `native` | Shows Neovim's message log. `:LspLog` for the language server log. |
| `Alt+F12` | Terminal | `:terminal` or `<leader>t` | `native` | See section N. |
| `Shift+Escape` | Close the panel | `Ctrl+W c` | `native` | See H4. |
| `-` | Command / message history | `:messages` | `native` | `g<` reopens the last page of output that scrolled away. |
| `-` | Health check for the whole config | `:checkhealth` | `native` | The nearest thing to a diagnostics tool window. |

### H7. Zen and fullscreen

| VS Code key | Action | Neovim | Type | Notes / alternatives |
|---|---|---|---|---|
| `Ctrl+Alt+F11` | Toggle fullscreen | terminal / WM level | `none` | Neovim runs inside a terminal, so fullscreen belongs to the terminal emulator or the window manager (`Super+F` in most tiling WMs). Not a Neovim concern. |
| `Ctrl+Shift+F12` | Toggle Zen mode | `<leader>zz` | `plugin` | `zen-mode.nvim`. Native approximation: `Ctrl+W o` to close other windows, plus `set laststatus=0 nonumber norelativenumber signcolumn=no`. |
| `Alt+Z` | Toggle word wrap | `set wrap!` | `native-opt` | Worth a `<leader>tw` toggle. Pair with `set linebreak` so wrapping happens at word boundaries. |
| `-` | Hide the statusline | `set laststatus=0` | `native-opt` | `3` is the global statusline, which is the pleasant default for split-heavy layouts. |
| `-` | Hide line numbers | `set nonumber norelativenumber` | `native-opt` | |
| `-` | Distraction-free prose mode | `<leader>zp` | `plugin` | `zen-mode.nvim` plus `twilight.nvim` dims everything except the current block. |

---

## I. Folding

Neovim's default `'foldmethod'` is `manual` and `'foldenable'` is on, which means nothing is
folded until you create a fold. Most people set `foldmethod=expr` with
`foldexpr=v:lua.vim.treesitter.foldexpr()` and `foldlevel=99` so files open unfolded.

| VS Code key | Action | Neovim | Type | Notes / alternatives |
|---|---|---|---|---|
| `Ctrl+NumPad_Subtract` | Fold (close one level) | `zc` | `native` | Closes the fold under the cursor. |
| `Ctrl+NumPad_Add` | Unfold (open one level) | `zo` | `native` | Opens the fold under the cursor. |
| `Ctrl+Shift+NumPad_Subtract` | Fold all | `zM` | `native` | Closes every fold in the buffer. |
| `Ctrl+Shift+NumPad_Add` | Unfold all | `zR` | `native` | Opens every fold in the buffer. |
| `-` | Toggle the fold under the cursor | `za` | `native` | The most useful single fold key. |
| `-` | Toggle recursively | `zA` | `native` | Capital letters recurse: `zO` opens all nested folds, `zC` closes them. |
| `-` | Close all folds except the one under the cursor | `zx` | `native` | `zX` re-applies `'foldlevel'`. Great for "show me only this function". |
| `-` | Create a fold over a motion | `zf{motion}` | `native-opt` | Requires `foldmethod=manual`. `zfap` folds a paragraph; Visual mode `zf` folds the selection. |
| `-` | Delete a fold | `zd` | `native-opt` | `zD` recursively, `zE` eliminates every manual fold in the buffer. |
| `-` | Move to the next / previous fold | `zj` / `zk` | `native` | `zj` moves to the start of the next fold, `zk` to the end of the previous one. |
| `-` | Move to the start / end of the current fold | `[z` / `]z` | `native` | |
| `-` | Open just enough folds to see the cursor | `zv` | `native` | |
| `-` | Reduce / increase the fold level by one | `zm` / `zr` | `native` | Lowercase steps one level; uppercase (`zM` / `zR`) goes all the way. |
| `-` | Treesitter-based folding | `set foldmethod=expr foldexpr=v:lua.vim.treesitter.foldexpr()` | `native-opt` | Requires a treesitter parser for the language, but the fold engine itself is core. |
| `-` | Indent-based folding with no parser | `set foldmethod=indent` | `native-opt` | Works everywhere, including YAML and plain text. |
| `-` | Persist folds across sessions | `:mkview` / `:loadview` | `native-opt` | Or a `BufWinLeave` / `BufWinEnter` autocommand pair. |
| `-` | Nicer fold text and previews | `<leader>` free | `plugin` | `nvim-ufo` gives VS Code-style fold previews and LSP-driven fold ranges. |

---

## J. Clipboard and Registers

Vim has a *register* model, not a single clipboard. Every delete and yank goes somewhere
addressable. This is a strict superset of what VS Code offers.

### J1. Copy, cut, paste

| VS Code key | Action | Neovim | Type | Notes / alternatives |
|---|---|---|---|---|
| `Ctrl+C` | Copy | `y` | `native` | Yank a motion (`yiw`, `y$`, `yap`) or a Visual selection. **CONFLICT:** `Ctrl+C` cancels. |
| `Ctrl+X` | Cut | `d` | `native` | Delete IS cut: the text goes into the unnamed register. **CONFLICT:** `Ctrl+X` decrements a number. |
| `Ctrl+V` | Paste | `p` / `P` | `native` | **CONFLICT:** `Ctrl+V` is Visual Block. |
| `-` | Paste in Insert mode | Insert `Ctrl+R "` | `native` | `Ctrl+R +` for the system clipboard. `Ctrl+R Ctrl+P` fixes the indentation as it pastes. |
| `-` | Paste in the command line | Cmdline `Ctrl+R "` | `native` | Also `Ctrl+R Ctrl+W` inserts the word under the cursor into the command line. |
| `-` | Paste over a selection without clobbering the register | Visual `P` | `native` | Neovim-specific improvement over classic Vim. |
| `-` | Paste and leave the cursor after the text | `gp` / `gP` | `native` | Useful when pasting several times in a row. |
| `-` | Paste with the indentation adjusted | `]p` / `[p` | `native` | |

### J2. System clipboard

| VS Code key | Action | Neovim | Type | Notes / alternatives |
|---|---|---|---|---|
| `Ctrl+C` | Copy to the system clipboard | `"+y` | `native` | The `+` register is the system CLIPBOARD selection. |
| `Ctrl+V` | Paste from the system clipboard | `"+p` | `native` | |
| `-` | Copy to the X11 PRIMARY selection | `"*y` | `native` | On Linux, `*` is middle-click paste and `+` is `Ctrl+V` paste. On Windows and macOS they are the same register. |
| `-` | Make ALL yanks and pastes use the system clipboard | `set clipboard=unnamedplus` | `native-opt` | This is the one-line setting that makes `y`, `p`, and `d` behave the way a VS Code user expects. **Trade-off:** every `d` and `x` then overwrites the system clipboard, which many people find worse, not better. The alternative is to keep it unset and type `"+y` deliberately. |
| `-` | Yank the whole file to the system clipboard | `:%y+` | `native` | |
| `-` | Yank a range to the clipboard | `:10,20y+` | `native` | |
| `-` | Clipboard over SSH | OSC 52 | `native-opt` | Neovim 0.10+ ships an OSC 52 clipboard provider, so `"+y` works through SSH in a terminal that supports OSC 52 (kitty, wezterm, foot, recent tmux). Set `vim.g.clipboard = 'osc52'` if it is not detected. |
| `-` | Check what clipboard tool Neovim found | `:checkhealth vim.provider` | `native` | Diagnoses a missing `xclip`, `wl-clipboard`, or `pbcopy`. |

### J3. Named registers

| VS Code key | Action | Neovim | Type | Notes / alternatives |
|---|---|---|---|---|
| `-` | Yank into a named register | `"ay` | `native` | 26 lowercase registers, `a` to `z`. |
| `-` | Paste from a named register | `"ap` | `native` | |
| `-` | APPEND to a named register | `"Ay` | `native` | Uppercase appends instead of replacing. Lets you collect scattered lines into one register, then paste them all at once. |
| `-` | List every register with its contents | `:reg` | `native` | `:reg a b` shows only those two. |
| `-` | The unnamed register | `""` | `native` | Where every yank and delete lands by default. |
| `-` | The yank-only register | `"0` | `native` | Holds the LAST YANK, untouched by deletes. The classic fix for "I yanked, then deleted, and lost my yank": paste with `"0p`. |
| `-` | Numbered delete-history registers | `"1` to `"9` | `native` | `"1` is the most recent multi-line delete, shifting down to `"9`. `"1p` then `.` repeatedly walks back through the delete history. |
| `-` | The black hole register | `"_` | `native` | `"_d` deletes without touching any register. |
| `-` | The last inserted text | `".` | `native` | |
| `-` | The current file name | `"%` | `native` | `"%p` pastes the path of the current file. |
| `-` | The last Ex command | `":` | `native` | `@:` re-runs it. |
| `-` | The last search pattern | `"/` | `native` | Insert it into a `:s` with `Ctrl+R /`. |
| `-` | The expression register | `"=` | `native` | `"=2*21<CR>p` pastes `42`. In Insert mode: `Ctrl+R =`. |
| `-` | Registers double as macro storage | `"qp` / `@q` | `native` | A macro IS just a register holding keystrokes. That is why you can paste, edit, and re-yank one. |
| `-` | Visual register picker | `<leader>r` | `plugin` | `registers.nvim` shows a popup. `:reg` is the native answer. |

---

## K. Git

Neovim ships **no Git integration** beyond `:terminal` and `!` shell commands, and a genuinely
good `diff` mode. Everything panel-shaped here is `plugin`. The VS Code source file uses a
`Ctrl+Alt+G` chord prefix; the natural Neovim translation is a `<leader>g` prefix.

### K1. Repository operations

| VS Code key | Action | Neovim | Type | Notes / alternatives |
|---|---|---|---|---|
| `Ctrl+Alt+G S` | Show the Source Control view | `<leader>gg` | `plugin` | `neogit` (magit-style) or `vim-fugitive` `:Git`. Native: `:!git status` or `:terminal lazygit`. |
| `Alt+3` | Source Control tool window | `<leader>gg` | `plugin` | Same as above. |
| `Ctrl+Alt+G C` | Commit | `<leader>gc` | `plugin` | Fugitive `:Git commit`. Native: `:!git commit`, though editing the message needs `:terminal`. |
| `Ctrl+Alt+G Shift+C` | Commit staged | `<leader>gC` | `plugin` | Fugitive `:Git commit` already commits only what is staged. |
| `Ctrl+Alt+G U` | Pull | `<leader>gu` | `plugin` | Native: `:!git pull`. |
| `Ctrl+Alt+G P` | Push | `<leader>gp` | `plugin` | Native: `:!git push`. Fugitive `:Git push` runs it asynchronously. |
| `Ctrl+Alt+G Y` | Sync (pull then push) | `<leader>gy` | `plugin` | No single native command; `:!git pull --rebase && git push`. |
| `Ctrl+Alt+G F` | Fetch | `<leader>gf` | `plugin` | Native: `:!git fetch`. |
| `-` | Full-screen Git TUI | `<leader>gl` | `native` | `:terminal lazygit`. This is `native` because `:terminal` is core; `lazygit` is an external binary, not a Neovim plugin. Many people use only this and no Git plugin at all. |
| `-` | Run any git command | `:!git {args}` | `native` | `:r !git log --oneline -20` reads the output straight into the buffer. |
| `-` | Branch picker | `<leader>gb` | `plugin` | Telescope `git_branches`. |
| `-` | Stash picker | `<leader>gS` | `plugin` | Telescope `git_stash`. |

### K2. Hunks

| VS Code key | Action | Neovim | Type | Notes / alternatives |
|---|---|---|---|---|
| `Alt+Shift+Down` | Next change / hunk | `]c` | `native-opt` | `]c` is the NATIVE next-change motion in `diff` mode. `gitsigns.nvim` reuses the same key outside diff mode, which is why it feels native. |
| `Alt+Shift+Up` | Previous change / hunk | `[c` | `native-opt` | Mirror of `]c`. |
| `Ctrl+Enter` | Stage the selected ranges | `<leader>hs` | `plugin` | `gitsigns.nvim` `stage_hunk`. Works on a Visual selection for partial staging. Native: `git add -p` in a `:terminal`. |
| `Ctrl+Alt+Enter` | Unstage the selected ranges | `<leader>hu` | `plugin` | `gitsigns.nvim` `undo_stage_hunk` / `reset_hunk`. |
| `-` | Preview the hunk under the cursor | `<leader>hp` | `plugin` | `gitsigns.nvim` `preview_hunk`. |
| `-` | Reset (discard) the hunk under the cursor | `<leader>hr` | `plugin` | `gitsigns.nvim` `reset_hunk`. |
| `-` | Reset the whole buffer | `<leader>hR` | `plugin` | `gitsigns.nvim` `reset_buffer`. |
| `-` | Select the hunk as a text object | `ih` / `ah` | `plugin` | `gitsigns.nvim` provides a hunk text object, so `dih` discards a hunk. |
| `-` | Change signs in the gutter | `set signcolumn=yes` | `plugin` | The gutter column is native; the git signs in it come from `gitsigns.nvim`. |
| `-` | Native diff of two files | `:diffthis` in each window | `native` | Or start with `nvim -d file1 file2`. |
| `-` | Pull a change from the other diff window | `do` | `native` | "diff obtain". `dp` is "diff put". Both are core `diff`-mode commands. |

### K3. History and blame

| VS Code key | Action | Neovim | Type | Notes / alternatives |
|---|---|---|---|---|
| `Alt+Shift+C` | View recent changes (Git timeline) | `<leader>gh` | `plugin` | `diffview.nvim` `:DiffviewFileHistory %`, or Fugitive `:0Gclog`. |
| `-` | Blame the current line | `<leader>gb` | `plugin` | `gitsigns.nvim` `blame_line`. Native: `:!git blame -L {line},{line} %`. |
| `-` | Full-file blame in a split | `<leader>gB` | `plugin` | Fugitive `:Git blame` gives a scroll-bound blame column. |
| `-` | Inline virtual-text blame | `current_line_blame = true` | `plugin` | `gitsigns.nvim` option. |
| `-` | Browse commits | `<leader>gc` | `plugin` | Telescope `git_commits`, or `:terminal lazygit`. |
| `-` | Open the current file as it was N commits ago | `:Gedit HEAD~3:%` | `plugin` | Fugitive. Native: `:r !git show HEAD~3:path` into a scratch buffer. |
| `-` | Diff the working tree against HEAD | `:Gdiffsplit` | `plugin` | Native: `nvim -d <(git show HEAD:path) path` from the shell. |

### K4. Conflicts

| VS Code key | Action | Neovim | Type | Notes / alternatives |
|---|---|---|---|---|
| `-` | Three-way merge view | `:Git mergetool` or `<leader>gm` | `plugin` | Fugitive `:Git mergetool`, or `diffview.nvim` `:DiffviewOpen`. Native: `git mergetool` configured to use `nvim -d`. |
| `-` | Native three-way diff | `nvim -d LOCAL BASE REMOTE MERGED` | `native` | This is what `git config merge.tool nvimdiff` sets up. `diff` mode is core Neovim. |
| `-` | Jump between conflict markers | `/^<<<<<<<` then `n` | `native` | Or `]c` / `[c` in diff mode. |
| `-` | Take the change from one side | `do` / `dp` | `native` | Core diff-mode "diff obtain" and "diff put", with a count for which buffer: `2do`. |
| `-` | Conflict-marker keybindings | `<leader>co` `<leader>ct` `<leader>cb` | `plugin` | `git-conflict.nvim` gives choose-ours / choose-theirs / choose-both. |
| `-` | Update the diff highlighting after an edit | `:diffupdate` | `native` | |
| `-` | Turn diff mode off | `:diffoff!` | `native` | |

---

## L. Debugging

Neovim ships **no debugger**. Everything in this section is `nvim-dap` plus adapters
(`nvim-dap-ui`, `nvim-dap-virtual-text`, and a per-language adapter such as `php-debug-adapter`
for Xdebug). The VS Code function-key layout maps naturally onto a `<leader>d` prefix.

### L1. Session control

| VS Code key | Action | Neovim | Type | Notes / alternatives |
|---|---|---|---|---|
| `Shift+F9` | Start debugging | `<leader>dc` | `plugin` | `nvim-dap` `continue()`. With no session running, `continue()` starts one. |
| `Ctrl+Shift+F9` | Start debugging (second binding) | `<leader>dc` | `plugin` | Duplicate binding in the source file. |
| `Shift+F10` | Run without debugging | `<leader>dr` | `plugin` | Or just `:terminal` and run the program directly. |
| `Ctrl+Shift+F10` | Run without debugging (second binding) | `<leader>dr` | `plugin` | Duplicate binding in the source file. |
| `F9` | Continue | `<leader>dc` | `plugin` | `nvim-dap` `continue()`. Same function as start, which is convenient. |
| `Ctrl+F2` | Stop debugging | `<leader>dq` | `plugin` | `nvim-dap` `terminate()`. |
| `Ctrl+Shift+F2` | Restart debugging | `<leader>dR` | `plugin` | `nvim-dap` `restart()`. |
| `Alt+4` | Run and Debug tool window | `<leader>du` | `plugin` | `nvim-dap-ui` `toggle()`. See H6. |
| `-` | Run to the cursor | `<leader>dC` | `plugin` | `nvim-dap` `run_to_cursor()`. |
| `-` | Pick a launch configuration | `<leader>dl` | `plugin` | Reads `.vscode/launch.json` if `nvim-dap` is configured to, so VS Code launch configs carry over. |

### L2. Stepping

| VS Code key | Action | Neovim | Type | Notes / alternatives |
|---|---|---|---|---|
| `F8` | Step over | `<leader>do` | `plugin` | `nvim-dap` `step_over()`. |
| `F7` | Step into | `<leader>di` | `plugin` | `nvim-dap` `step_into()`. |
| `Shift+F8` | Step out | `<leader>dO` | `plugin` | `nvim-dap` `step_out()`. |
| `-` | Step back (time-travel debugging) | `<leader>db` | `plugin` | `nvim-dap` `step_back()`, only if the adapter supports reverse execution. |
| `-` | Go up / down the call stack | `<leader>d[` / `<leader>d]` | `plugin` | `nvim-dap` `up()` / `down()`. |
| `-` | Keep the function keys as-is | `F7` / `F8` / `F9` | `leader` | Function keys are not Vim defaults, so binding `F7`-`F9` directly to DAP is permitted under Strategy E and preserves the muscle memory exactly. |

### L3. Breakpoints

| VS Code key | Action | Neovim | Type | Notes / alternatives |
|---|---|---|---|---|
| `Ctrl+F8` | Toggle a breakpoint | `<leader>dt` | `plugin` | `nvim-dap` `toggle_breakpoint()`. |
| `Ctrl+Shift+F8` | View / toggle breakpoint activation | `<leader>dB` | `plugin` | `nvim-dap` `set_breakpoint()` with a condition prompt; `nvim-dap-ui` has a breakpoints pane. |
| `-` | Conditional breakpoint | `<leader>dc` prompt | `plugin` | `dap.set_breakpoint(vim.fn.input('Condition: '))`. |
| `-` | Log point (print without stopping) | `<leader>dp` | `plugin` | `dap.set_breakpoint(nil, nil, vim.fn.input('Log: '))`. |
| `-` | Clear all breakpoints | `<leader>dx` | `plugin` | `dap.clear_breakpoints()`. |
| `-` | List breakpoints | `<leader>dL` | `plugin` | `dap.list_breakpoints()` fills the quickfix list, so `]q` / `[q` then walk them natively. |

### L4. Inspection

| VS Code key | Action | Neovim | Type | Notes / alternatives |
|---|---|---|---|---|
| `Alt+F8` | Evaluate selection / add to watch | `<leader>de` | `plugin` | `nvim-dap-ui` `eval()`. Works on a Visual selection. |
| `-` | Hover over a variable to see its value | `<leader>dh` | `plugin` | `nvim-dap-ui` `eval()` in a float, or `nvim-dap-virtual-text` to show values inline. |
| `-` | REPL / debug console | `<leader>dr` | `plugin` | `nvim-dap` `repl.toggle()`. |
| `-` | Variables, scopes, watches, call stack panes | `<leader>du` | `plugin` | `nvim-dap-ui` `toggle()`. |
| `-` | Inline variable values as virtual text | `-` | `plugin` | `nvim-dap-virtual-text`. |
| `-` | Print debugging without a debugger | `:g/pattern/normal Ovar_dump($x);` | `native` | Bulk-insert debug statements with the global command, then `:g/var_dump/d` to remove them all. |

---

## M. Testing

The VS Code keybindings file contains **no test bindings**. This section documents the Neovim
capability anyway, since it is part of a working editor setup.

| VS Code key | Action | Neovim | Type | Notes / alternatives |
|---|---|---|---|---|
| `-` | Run the nearest test | `<leader>tn` | `plugin` | `neotest` `run()`. Adapters exist for PHPUnit, Pest, Jest, pytest, Go, and others. |
| `-` | Run all tests in the current file | `<leader>tf` | `plugin` | `neotest` `run(vim.fn.expand("%"))`. |
| `-` | Run the whole suite | `<leader>tA` | `plugin` | `neotest` `run({ suite = true })`. |
| `-` | Re-run the last test | `<leader>tl` | `plugin` | `neotest` `run_last()`. |
| `-` | Debug the nearest test | `<leader>td` | `plugin` | `neotest` `run({ strategy = "dap" })`, which bridges into section L. |
| `-` | Toggle the test summary panel | `<leader>ts` | `plugin` | `neotest` `summary.toggle()`. |
| `-` | Show the output of the last test | `<leader>to` | `plugin` | `neotest` `output_panel.toggle()`. |
| `-` | Jump to the next failed test | `<leader>tj` | `plugin` | `neotest` `jump.next({ status = "failed" })`. |
| `-` | Run tests with no plugin at all | `:!vendor/bin/phpunit %` | `native` | `%` is the current file. `:!` runs any shell command. |
| `-` | Run tests and load failures into the quickfix list | `:make` | `native-opt` | Set `'makeprg'` and `'errorformat'` for the test runner; then `:copen` and `]q` / `[q` walk the failures natively. This is the classic, plugin-free workflow. |
| `-` | Run tests in a persistent split terminal | `:sp \| terminal make test` | `native` | Or `<leader>tt` bound to that. |
| `-` | Watch mode | `-` | `plugin` | `overseer.nvim` or a `:terminal` running the test runner's own watch flag. |

---

## N. Terminal and Tasks

Neovim has a real, full terminal emulator built in: `:terminal`. Terminal buffers are ordinary
buffers, so every buffer command in G3 applies to them.

| VS Code key | Action | Neovim | Type | Notes / alternatives |
|---|---|---|---|---|
| `Alt+F12` | Toggle the terminal | `:terminal` or `<leader>t` | `native` | `:sp \| term` for a horizontal split, `:vs \| term` for vertical, `:tabnew \| term` for a full tabpage. |
| `Ctrl+L` | Clear the terminal | `Ctrl+L` in the shell | `native` | Inside a `:terminal` buffer, keys go to the shell, so the shell's own `Ctrl+L` clears it. **CONFLICT:** in a normal buffer `Ctrl+L` redraws Neovim. |
| `Ctrl+D` | Send EOF to the shell | `Ctrl+D` in Terminal mode | `native` | Passes through to the shell as EOF and ends the session. **CONFLICT:** in a normal buffer `Ctrl+D` scrolls half a page. |
| `Ctrl+Shift+D` | Kill the terminal | `:bd!` on the terminal buffer | `native` | Or exit the shell with `exit`. |
| `Shift+Escape` | Close the panel | `Ctrl+W c` | `native` | Closes the terminal window while leaving the process running in the buffer. |
| `-` | Leave Terminal mode (back to Normal) | `Ctrl+\ Ctrl+N` | `native` | The essential terminal key. Many people alias it to `Esc` with `tnoremap <Esc> <C-\><C-n>`, but that makes `Esc` unusable inside a TUI running in the terminal. |
| `-` | Window commands from inside Terminal mode | Terminal `Ctrl+W` | `native` | Since 0.11, `Ctrl+W` works in Terminal mode as the window prefix, so `Ctrl+W h` moves out of the terminal without leaving Terminal mode first. |
| `-` | Enter Terminal mode (start typing) | `i` or `a` | `native` | From Normal mode in a terminal buffer. |
| `-` | Paste into the terminal | Terminal `Ctrl+\ Ctrl+N` then `"+p` | `native` | Or `Ctrl+W ""` in Terminal mode pastes the unnamed register. |
| `-` | Scroll back through terminal output | `Ctrl+\ Ctrl+N` then `Ctrl+B` | `native` | The scrollback is just buffer text: search it with `/`, yank from it with `y`. |
| `-` | Jump between shell prompts | `]]` / `[[` | `native` | In 0.11 these navigate OSC-133 shell prompt marks in a terminal buffer. Requires a shell that emits OSC 133 (zsh with a prompt hook, fish 3.6+, or starship). |
| `-` | Run a shell command and read the output into the buffer | `:r !command` | `native` | `:r !date` inserts the date. `:%!sort` filters the whole buffer through `sort`. |
| `-` | Run a shell command without leaving Neovim | `:!command` | `native` | `:!` with no command repeats the previous one. |
| `-` | Run a build and capture errors | `:make` | `native-opt` | Set `'makeprg'` and `'errorformat'`; errors land in the quickfix list. This is Neovim's native task runner. |
| `-` | Persistent floating terminal | `<leader>tf` | `plugin` | `toggleterm.nvim` if a floating, toggleable terminal is wanted. |
| `-` | Task runner with a task list UI | `<leader>ot` | `plugin` | `overseer.nvim` reads `.vscode/tasks.json`, so VS Code tasks carry over. |
| `-` | Auto-enter Insert mode in new terminals | `au TermOpen * startinsert` | `native-opt` | Removes one keystroke per terminal. |
| `-` | Hide line numbers in terminals | `au TermOpen * setlocal nonumber norelativenumber` | `native-opt` | |

---

## O. AI

The VS Code keybindings file contains **no AI bindings**, although it does adjust word motion
`when: inChat && inputFocus`, which implies Copilot Chat is in use. Everything here is `plugin`.

| VS Code key | Action | Neovim | Type | Notes / alternatives |
|---|---|---|---|---|
| `-` | Inline completion suggestions | `-` | `plugin` | `copilot.lua` or `copilot.vim`. Accept with `Tab` or `Ctrl+J`; note the `Tab` conflict with snippet jumping described in A5. |
| `-` | Accept the current suggestion | `Ctrl+J` | `plugin` | Prefer `Ctrl+J` over `Tab` to avoid the snippet and completion-popup collision. |
| `-` | Next / previous suggestion | `Alt+]` / `Alt+[` | `plugin` | `copilot.vim` defaults. |
| `-` | Dismiss the suggestion | `Ctrl+]` | `plugin` | **CONFLICT:** `Ctrl+]` is go-to-definition via `'tagfunc'`. Rebind the plugin, not Neovim. |
| `-` | Open a chat panel | `<leader>aa` | `plugin` | `CopilotChat.nvim`, `avante.nvim`, `codecompanion.nvim`, or `gp.nvim`. |
| `-` | Explain the selected code | `<leader>ae` | `plugin` | Visual mode, then the chat plugin's explain action. |
| `-` | Ask about the selection | `<leader>ai` | `plugin` | Most chat plugins accept a Visual range. |
| `-` | Generate or fix tests for the selection | `<leader>at` | `plugin` | Prompt-library feature of `CopilotChat.nvim` and `codecompanion.nvim`. |
| `-` | Inline edit the selection with a prompt | `<leader>ax` | `plugin` | `avante.nvim` or `codecompanion.nvim` inline mode. |
| `-` | Toggle AI completion off | `<leader>ac` | `plugin` | `:Copilot disable` / `:Copilot enable`. |
| `-` | Check AI plugin status | `:Copilot status` | `plugin` | |

---

## P. Settings and Meta

| VS Code key | Action | Neovim | Type | Notes / alternatives |
|---|---|---|---|---|
| `Ctrl+Alt+S` | Open Settings (UI) | `:options` | `native` | `:options` is a browsable, editable list of every option grouped by topic. It is the closest native thing to the Settings UI and almost nobody knows it exists. |
| `Ctrl+Alt+Shift+S` | Open settings.json | `:e $MYVIMRC` | `native` | `$MYVIMRC` points at `~/.config/nvim/init.lua`. Worth a `<leader>vc` alias. |
| `Ctrl+Alt+Shift+K` | Open the keybindings file | `:e $MYVIMRC` then the keymap file | `native` | Neovim has no separate keybindings file; mappings live in the config. Inspect the live state instead with `:map`. |
| `-` | List every mapping | `:map` | `native` | `:nmap`, `:imap`, `:vmap` per mode. `:verbose map <leader>f` shows WHICH FILE defined a mapping and on which line. Indispensable for debugging conflicts. |
| `-` | Check what a specific key is bound to | `:verbose nmap gr` | `native` | The single best debugging command for keymap conflicts. |
| `-` | Check the value and origin of an option | `:verbose set shiftwidth?` | `native` | Shows the value AND the file that last set it. |
| `-` | Search the documentation | `:help {topic}` | `native` | `:helpgrep pattern` searches all help files into the quickfix list; then `]q` / `[q`. |
| `-` | Help for a key in a specific mode | `:help i_CTRL-O` | `native` | Prefixes: `i_` Insert, `v_` Visual, `c_` Cmdline, `t_` Terminal, `g` for `g`-commands, `z` for `z`-commands. |
| `-` | Health check | `:checkhealth` | `native` | `:checkhealth vim.lsp`, `:checkhealth vim.provider`, `:checkhealth vim.treesitter` for specific subsystems. |
| `-` | View recent messages | `:messages` | `native` | `g<` reopens the last page of output that scrolled past. |
| `-` | Show the syntax or treesitter node under the cursor | `:Inspect` | `native` | Neovim 0.9+. `:InspectTree` opens a live treesitter parse tree — invaluable for writing custom text objects and folds. |
| `-` | Edit the treesitter query playground | `:EditQuery` | `native` | Neovim 0.10+. |
| `-` | Reload the configuration | `:source $MYVIMRC` | `native` | Lua module caching means a restart is often cleaner. |
| `-` | Profile startup time | `nvim --startuptime /tmp/nvim.log` | `native` | Or `:Lazy profile` with `lazy.nvim`. |
| `-` | Start with no config at all | `nvim --clean` | `native` | The correct first step when bisecting a broken config or confirming whether a key is a genuine default. |
| `-` | Verify a key really is a Neovim default | `nvim --clean` then `:verbose nmap grn` | `native` | Use this to check any claim in this document independently. |
| `-` | Which-key style popup for prefixes | `<leader>` popup | `plugin` | `which-key.nvim` displays the available continuations after `<leader>`, `g`, `[`, `]`, and `z`. The most useful single plugin while learning. |
| `-` | Show all `g` commands | `:help g` | `native` | Likewise `:help z`, `:help ctrl-w`, `:help text-objects`. |

---

## Q. Power extras — Neovim capabilities with NO VS Code equivalent

Everything in this table is `native`. None of it has a VS Code counterpart, and collectively it
is the reason the migration is worth doing at all. The `VS Code key` column is omitted here
because it would be `-` in every row.

| Capability | Keys / command | Why it has no VS Code equivalent |
|---|---|---|
| **Dot repeat** | `.` | Repeats the last change, including its count and its inserted text. `3.` repeats with a new count. VS Code has "repeat last action" for commands, not for arbitrary composed edits. |
| **Macros** | `qa` ... `q`, then `@a` | Record any sequence of keystrokes into a register and replay it. `100@a` replays it a hundred times and stops cleanly when a motion fails. `@@` repeats the last macro. |
| **Operator plus motion grammar** | `d` `c` `y` `>` `<` `=` `gu` `gU` `g~` `gq` `gc` combined with any motion | `d2}`, `c/foo<CR>`, `y'a`, `>i{`, `gUiw`. The operator set times the motion set is thousands of composed commands from about thirty keys. VS Code has a flat command list. |
| **Registers** | `"ay`, `"ap`, `"Ay` to append, `:reg` to list | 26 named registers plus `"0` (last yank), `"1`-`"9` (delete history), `"_` (black hole), `"%` (filename), `":` (last command), `"/` (last search), `"=` (expression). VS Code has one clipboard. |
| **Marks** | `ma`, `` `a ``, `mA`, `:marks` | File-local lowercase marks and cross-file uppercase marks that survive a restart. Plus automatic marks: `` `. `` last edit, `` `^ `` last insert, `` `< `` `` `> `` the last selection, `` `[ `` `` `] `` the last change or yank. |
| **Text objects** | `ci"`, `da(`, `cit`, `vip`, `yi{`, `dat` | Operate on structure from anywhere inside it. `ci"` changes what is inside the quotes no matter where the cursor sits on the line. VS Code's "expand selection" is a weaker, mouse-adjacent approximation. |
| **`:normal` over a range** | `:%norm A;`, `:'<,'>norm I// `, `:10,20norm @q` | Run any Normal-mode key sequence on every line in a range. This is bulk editing as a first-class primitive. |
| **The global command** | `:g/pattern/cmd`, `:v/pattern/cmd` | `:g/TODO/d` deletes every TODO line. `:g/^$/d` strips blank lines. `:g/function/norm O// ---` annotates every function. `:g/pattern/m0` reverses matching lines to the top. There is no VS Code equivalent at any level. |
| **Substitute with confirmation** | `:%s/old/new/gc` | Per-match `y`/`n`/`a`/`q`/`l` prompting, with `\=` expression replacements, `\1` capture groups, and `set inccommand=split` live preview. |
| **Count prefixes** | `3dd`, `5yy`, `12j`, `2ci(`, `10@q`, `50%` | Almost every command takes a count, and counts compose with operators and motions. `d3w` and `3dw` both delete three words. |
| **Jumplist and changelist** | `Ctrl+O` / `Ctrl+I`, `g;` / `g,`, `:jumps`, `:changes` | Two independent histories: one of *jumps* (searches, `G`, tag jumps) and one of *edits*. VS Code's back/forward conflates them. |
| **`:argdo` / `:bufdo` / `:windo` / `:tabdo` / `:cdo` / `:cfdo`** | `:argdo %s/old/new/ge \| update` | Run any command across a defined set of files. Combined with `:g` and `:normal`, this is a full batch-editing language that happens to live inside your editor. |
| **`gq` reflow** | `gqap`, `gggqG`, `gw` | Reformat text to `'textwidth'`, honouring comment leaders. `gw` does the same but keeps the cursor in place. Essential for prose, commit messages, and comment blocks. |
| **Screen positioning** | `zz`, `zt`, `zb`, `H`, `M`, `L` | Move the *view* relative to the *cursor* without moving the cursor. `zz` after every jump is the single biggest quality-of-life habit in Vim. |
| **`gi`** | `gi` | Return to the exact position where you last left Insert mode, and re-enter Insert mode there. |
| **`gv`** | `gv` | Reselect the previous Visual selection exactly, even after running other commands in between. |
| **`ga`** | `ga` | Show the decimal, hex, and octal value of the character under the cursor. This is how you catch a Cyrillic homoglyph hiding in an identifier. `g8` shows the raw UTF-8 bytes. |
| **`g?` rot13** | `g?`, `g?g?`, `g?ap` | Rot13 as a first-class operator. Mostly a joke, but it demonstrates that operators are extensible and uniform. |
| **Time-travel undo** | `:earlier 10m`, `:later 5`, `g-`, `g+`, `set undofile` | Undo is a TREE, not a stack. Move by time (`10m`, `1h`), by change count, or by file write (`1f`). `g-` / `g+` walk undo states, recovering branches that plain `u` cannot reach. With `undofile` this survives restarts. |
| **Ex ranges** | `:10,20d`, `:.,+5y`, `:%s`, `:'<,'>t$`, `:/start/,/end/d` | Address lines by number, by offset, by pattern, by mark, or by the whole file, then apply any command to that range. |
| **The expression register** | Insert `Ctrl+R =`, `"=` | Evaluate arbitrary Vimscript or Lua and insert the result. `Ctrl+R =line('.')*2` inserts a computed value mid-typing. |
| **Filter through external commands** | `!ap sort`, `:%!jq .`, `:r !date` | Pipe any range through any shell command and replace it with the output. Your editor composes with the entire Unix toolbox. |
| **`gn` as a text object** | `cgn` then `.` | "The next match of the last search" as an operable object. `cgn` plus `.` is the idiomatic multi-cursor replacement, and unlike multi-cursor it lets you skip individual matches with `n`. |
| **Visual Block with ragged right** | `Ctrl+V` motion `$A text Esc` | Append to the true end of every line in a block regardless of their differing lengths. |
| **Progressive increment** | Visual `g Ctrl+A` | Turn a column of identical numbers into a sequence. Building a numbered list becomes one keystroke. |
| **Diff mode** | `nvim -d a b`, `do`, `dp`, `]c`, `[c`, `:diffthis` | A real three-way merge tool built into the editor core, usable as `git mergetool` with no plugin. |
| **`Ctrl+^`** | `Ctrl+^` | Instant toggle between the two most recently used buffers. Faster than any fuzzy finder for a tight edit loop. |
| **`q:` `q/`** | `q:`, `q/` | Open the command or search history as a real, editable buffer. Fix a long command with normal editing keys, then press `Enter` to run it. |
| **`:options`** | `:options` | A browsable, editable, categorised list of every option with its documentation inline. |
| **`:InspectTree`** | `:Inspect`, `:InspectTree`, `:EditQuery` | Live treesitter parse tree and query playground built into core. |

---

## R. Terminal-level caveats

These bite during the first week and are not Neovim's fault.

| Symptom | Cause | Fix |
|---|---|---|
| The terminal freezes completely after `Ctrl+S` | XOFF software flow control. `Ctrl+S` stops terminal output at the tty layer, above Neovim. | Press `Ctrl+Q` (XON) to resume. Prevent it with `stty -ixon` in the shell rc. Do not bind `Ctrl+S` to save; use `:w` or `<leader>w`. |
| Neovim vanishes after `Ctrl+Z` | `Ctrl+Z` sends SIGTSTP and suspends the process to the shell. Nothing is lost. | Type `fg` at the shell prompt. `jobs` lists suspended jobs; `fg %1` picks one. This is a feature: suspend, run a git command, `fg` back. |
| `Ctrl+/` does nothing | Most terminals transmit `Ctrl+/` as `Ctrl+_` (0x1F); some send nothing at all. | Use the native `gcc` (toggle comment on a line) and `gc{motion}` (comment a motion). Both are core defaults since 0.10 and sidestep the problem entirely. `gbc` toggles a block comment. |
| `Ctrl+Shift+{key}` does nothing | Legacy terminal encodings cannot represent Shift with a control character. | Use a terminal that supports the Kitty keyboard protocol (kitty, wezterm, foot, ghostty, alacritty 0.13+) — Neovim 0.10+ negotiates it automatically. Or avoid `Ctrl+Shift` bindings entirely, which Strategy E already does. |
| `Ctrl+I` and `Tab` are indistinguishable | They are the same byte (0x09) in legacy terminal encodings. Likewise `Ctrl+M` and `Enter`, and `Ctrl+[` and `Esc`. | The Kitty keyboard protocol disambiguates them. Otherwise accept it: `Ctrl+I` is jumplist-forward and `Tab` is a tab character, and you cannot have both meanings separately. |
| `Alt+{key}` inserts a strange character | The terminal is sending the key as a Meta-prefixed 8-bit character instead of `Esc` plus the key. | Configure the terminal to send `Esc+` for Alt (`macos_option_as_alt yes` in kitty, `AltSendsEscape` elsewhere). |
| `Esc` feels sluggish | `'ttimeoutlen'` is waiting to see whether `Esc` starts an escape sequence. | `set ttimeoutlen=10`. Keep `'timeoutlen'` (the mapping timeout) at a comfortable 300-500ms. |
| `Esc` is far from the home row | Physical keyboard layout. | Remap **CapsLock to Esc at the OS level** — `keyd` or `xremap` on Linux, Karabiner-Elements on macOS, PowerToys on Windows. Do it at the OS level so it applies everywhere, not just in Neovim. Additionally map Insert-mode `jk` to `<Esc>` as a fallback. |
| True colour looks wrong | The terminal is not advertising 24-bit colour. | `set termguicolors` and ensure `$TERM` and `$COLORTERM` are correct (`COLORTERM=truecolor`). |
| The system clipboard does nothing | No clipboard provider is installed. | Install `wl-clipboard` (Wayland), `xclip` or `xsel` (X11); macOS uses `pbcopy` automatically. Verify with `:checkhealth vim.provider`. Over SSH, Neovim 0.10+ falls back to OSC 52. |

---

## S. Coverage index — the 178 VS Code bindings by section

Every positive binding in `home/.chezmoitemplates/vscode/keybindings.json` appears in exactly
one of the sections below. Use this table to find where a specific key was translated.

| VS Code key | Section |
|---|---|
| `Ctrl+C` (copy, editor / input) | D2, J1 |
| `Ctrl+X` (cut, editor / input) | D2, J1 |
| `Ctrl+V` (paste, editor / input) | D2, J1 |
| `Ctrl+A` (select all, editor / input) | E5 |
| `Ctrl+Z` (undo) | D7 |
| `Ctrl+Shift+Z` (redo) | D7 |
| `Ctrl+Y` (delete line) | D3 |
| `Ctrl+S` (save) | G2 |
| `Ctrl+Shift+S` (save as) | G2 |
| `Ctrl+Alt+F11` (fullscreen) | H7 |
| `Ctrl+Shift+F12` (zen mode) | H7 |
| `Shift Shift` (quick open) | G1 |
| `Ctrl+Shift+A` (command palette) | G1 |
| `Ctrl+Shift+N` (go to file) | G1 |
| `Ctrl+N` (new file) | G1 |
| `Ctrl+Alt+Shift+N` (go to symbol) | A1 |
| `Ctrl+G` (go to line, both bindings) | C2 |
| `Ctrl+E` (recent files) | G5 |
| `Ctrl+Shift+E` (editors by MRU) | G5 |
| `Alt+Shift+C` (timeline) | G5, K3 |
| `Ctrl+Alt+Left` / `Ctrl+Alt+Right` (navigate back / forward) | C6 |
| `Alt+Left` / `Alt+Right` (navigate back / forward) | C6 |
| `Ctrl+Shift+Backspace` (last edit location) | C6 |
| `Alt+G Shift+;` / `Alt+G Shift+,` (change list) | C6 |
| `Ctrl+F4` (close editor) | G4 |
| `Ctrl+Shift+F4` (close all) | G4 |
| `Ctrl+Shift+T` (reopen closed editor) | G5 |
| `Ctrl+F` (find) | C5, F1 |
| `Ctrl+R` (replace) | F2 |
| `F3` / `Shift+F3` (next / previous match) | C5, F1 |
| `Ctrl+Shift+F` (find in files) | F3 |
| `Ctrl+Shift+R` (replace in files) | F4 |
| `Ctrl+Shift+H` (search editor) | F3 |
| `Ctrl+Space` / `Alt+Space` (trigger suggest) | A5 |
| `Ctrl+Shift+Space` (parameter hints) | A2 |
| `Ctrl+P` (parameter hints) | A2 |
| `Ctrl+Q` (hover) | A2 |
| `Alt+Enter` (quick fix) | A3 |
| `Ctrl+B` (go to definition, both bindings) | A1 |
| `Ctrl+Alt+B` (go to implementation, both bindings) | A1 |
| `Ctrl+Shift+B` (go to type definition) | A1 |
| `Ctrl+Shift+I` (peek definition) | A1 |
| `Ctrl+Alt+D` (peek definition) | A1 |
| `Alt+F7` (find usages) | A1 |
| `Ctrl+Alt+F7` (references view) | A1 |
| `Ctrl+F7` (highlight usages) | C5, F5 |
| `Ctrl+F12` (file structure) | A1 |
| `Ctrl+Alt+F12` (outline focus) | A1 |
| `Alt+F1` (reveal in explorer) | G6 |
| `Ctrl+/` (comment line) | S, "Commenting" subsection below |
| `Ctrl+Shift+/` (block comment) | S, "Commenting" subsection below |
| `Ctrl+Alt+W` (select word) | E2 |
| `Ctrl+W` (expand selection) | E3 |
| `Ctrl+Shift+W` (shrink selection) | E3 |
| `Alt+J` / `Alt+Shift+J` (multi-cursor next / previous match) | E4 |
| `Ctrl+Alt+J` (select all occurrences) | E4, H2 |
| `Ctrl+Shift+]` / `Ctrl+Shift+[` (select to bracket) | C8 |
| `Ctrl+U` (cursor undo) | D7 |
| `Ctrl+NumPad_Add` / `Ctrl+NumPad_Subtract` (unfold / fold) | I |
| `Ctrl+Shift+NumPad_Add` / `Ctrl+Shift+NumPad_Subtract` (unfold all / fold all) | I |
| `Ctrl+D` (duplicate line) | D3 |
| `Ctrl+Shift+J` (join lines) | D6 |
| `Shift+Enter` (insert line after) | D1 |
| `Ctrl+Enter` (insert line after / stage hunk) | D1, K2 |
| `Ctrl+Alt+Enter` (insert line before / unstage hunk) | D1, K2 |
| `Shift+Alt+Down` / `Shift+Alt+Up` (move lines / next change) | D3, K2 |
| `Ctrl+Shift+Down` / `Ctrl+Shift+Up` (move lines) | D3 |
| `Ctrl+[` / `Ctrl+]` (outdent / indent) | D4 |
| `Ctrl+Left` / `Ctrl+Right` (word motion, all three contexts) | C1 |
| `Ctrl+Backspace` / `Ctrl+Delete` (word delete, both contexts) | D2 |
| `Ctrl+Shift+U` (upper / lower case) | D5 |
| `Ctrl+Shift+L` (lowercase) | D5 |
| `Ctrl+Alt+L` (format document / selection / focus right group) | A4, H2 |
| `Ctrl+Alt+Shift+L` (format selection) | A4 |
| `Ctrl+Alt+O` (organize imports) | A3 |
| `Ctrl+Alt+I` (reindent) | A4 |
| `Shift+F6` (rename symbol / rename file) | A3, G7 |
| `Ctrl+Alt+Shift+T` (refactor menu) | A3 |
| `Ctrl+Alt+N` (inline) | A3 |
| `Ctrl+Alt+V` / `Ctrl+Alt+M` / `Ctrl+Alt+C` (extract variable / method / constant) | A3 |
| `Ctrl+Alt+T` (surround with) | A3 |
| `Alt+1` to `Alt+7`, `Alt+0` (tool windows) | H6 |
| `Alt+F12` (terminal) | H6, N |
| `Shift+Escape` (close panel) | H4, H6, N |
| `Ctrl+L` (terminal clear) | C3, N |
| `Ctrl+D` (terminal EOF) | N |
| `Ctrl+Shift+D` (kill terminal) | N |
| `Shift+F9` / `Ctrl+Shift+F9` (debug start) | L1 |
| `Shift+F10` / `Ctrl+Shift+F10` (run) | L1 |
| `F8` / `F7` / `Shift+F8` (step over / into / out) | L2 |
| `F9` (continue) | L1 |
| `Alt+F8` (evaluate selection) | L4 |
| `Ctrl+F2` / `Ctrl+Shift+F2` (stop / restart) | L1 |
| `Ctrl+F8` / `Ctrl+Shift+F8` (breakpoints) | L3 |
| `Ctrl+Alt+G S/C/Shift+C/U/P/Y/F` (git chords) | K1 |
| `Ctrl+Alt+S` / `Ctrl+Alt+Shift+S` / `Ctrl+Alt+Shift+K` (settings and keybindings) | P |
| `Alt+F2` (rename file) | G7 |
| `Ctrl+Down` / `Ctrl+Up` (word highlight next / previous) | A1, F5 |
| `Ctrl+Shift+C` (copy file path) | G7 |
| `F2` / `Shift+F2` (next / previous problem) | B1, C9 |
| `Alt+Up` / `Alt+Down` (breadcrumbs) | A1 (use `gO`) |
| `Ctrl+Shift+\` / `Ctrl+Alt+\` / `Ctrl+\` (splits) | H1 |
| `Ctrl+1` / `Ctrl+2` / `Ctrl+3` (focus editor group) | H2 |
| `Ctrl+Alt+H/J/K/L` (focus group by direction) | H2 |
| `Ctrl+Shift+M` (problems panel) | B3 |
| `Ctrl+Alt+Shift+Up` / `Ctrl+Alt+Shift+Down` (insert cursor / resize height) | E4, H3 |
| `Alt+H` / `Alt+L` (previous / next editor) | C9, G3 |
| `Alt+Z` (toggle word wrap) | H7 |
| `Ctrl+K O` / `Ctrl+K W` (close other / all editors) | G4 |
| `Ctrl+K Ctrl+O` (close other groups) | G4, H4 |
| `Ctrl+0` (focus sidebar) | G3, G6 |
| `Ctrl+Alt+E` / `Ctrl+Alt+Y` (scroll by line) | C3 |
| `Ctrl+Home` / `Alt+Shift+T` (go to first line) | C4 |
| `Ctrl+End` / `Alt+Shift+B` (go to last line) | C4 |
| `Ctrl+Alt+Shift+Left` / `Ctrl+Alt+Shift+Right` (resize width) | H3 |

### Commenting — the `Ctrl+/` translation

Commenting is built into Neovim core since 0.10 and needs no plugin and no configuration:

| VS Code key | Action | Neovim | Type | Notes / alternatives |
|---|---|---|---|---|
| `Ctrl+/` | Toggle a line comment | `gcc` | `native` | Core default since 0.10. Uses `'commentstring'`, which treesitter keeps correct even in mixed-language files such as Blade or Vue. |
| `Ctrl+/` | Toggle comments on a selection | `gc` in Visual mode | `native` | |
| `Ctrl+/` | Comment a motion | `gc{motion}` | `native` | `gcap` comments a paragraph, `gcG` comments to the end of the file, `gc3j` comments four lines. `gc` is a real operator. |
| `Ctrl+Shift+/` | Toggle a block comment | `gbc` | `native` | Block-comment line toggle. `gb{motion}` for a motion. |
| `-` | Comment the current line and open a new one below | `gcO` | `native` | Adds a commented line above; `gco` below. Both enter Insert mode. |
| `-` | Comment every line matching a pattern | `:g/pattern/norm gcc` | `native` | The global command applied to the comment operator. |

`Ctrl+/` frequently does not reach the application at all: most terminals transmit it as
`Ctrl+_` (0x1F) and some send nothing. The native `gcc` avoids the transmission problem
completely, which is the strongest single argument for the defaults-first approach.

---

## T. Summary — what Strategy E actually costs

| Category | Outcome |
|---|---|
| Keys that translate to a Neovim default with no configuration at all | The large majority. Everything in A1-A5, B1, C1-C9, D1-D9, E1-E5, F1, F2, G1-G5, H1-H5, I, J1, J3, N, and P. |
| Keys that need a single option or config line | Formatting (`'formatexpr'` is automatic), diagnostics display (`virtual_text` is off by default), folding method, `set clipboard`, `set grepprg`, `set splitright splitbelow`. |
| Keys that get a new `<leader>` mapping | Move-line up/down, organize imports, format explicitly, diagnostic list helpers, git operations, debug operations, test operations, file explorer toggle, AI actions. |
| Keys that genuinely need a plugin | Fuzzy finding, git panels and hunks, debugging (DAP), testing (neotest), treesitter text objects, surround, AI, zen mode, peek definition. |
| Keys with no equivalent and none planned | Editor fullscreen (`Ctrl+Alt+F11`) — that belongs to the terminal emulator or window manager, not to Neovim. |
| Keys deliberately NOT remapped | All 21 conflicts listed at the top of this document. Each one is a Vim default that is more valuable than the VS Code binding it would replace. |

The trade being made is explicit: about two weeks of relearning roughly twenty finger habits,
in exchange for the entire section Q capability set, a configuration that survives Neovim
upgrades untouched because it fights nothing, and keybindings that work identically over SSH,
in a tmux session, and on a machine you have never logged into before.
