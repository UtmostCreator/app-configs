# Neovim Plan - Defaults-First (Strategy E)

> **Status: PLAN ONLY.** Nothing in this document has been implemented. No
> Neovim, Nix, mise, chezmoi or terminal configuration file has been created or
> modified as a result of this document. Every path, mapping and package name
> below is a proposal awaiting explicit approval.

This document is the **active** Neovim migration plan. It replaces the retired
keymap-parity approach with a defaults-first strategy: learn Neovim as Neovim,
and add only what Neovim has no answer for.

### Relationship to other documents

| Document | Role | Status | Read it for |
|---|---|---|---|
| `repo-docs/nvim-defaults-plan.md` | This file. Active strategy, architecture, rollout. | **Active** | Everything strategic. Start here. |
| `repo-docs/nvim-keymap.md` | Full VS Code -> Neovim translation, grouped by category. | Active, written in parallel | "What replaces the key I used to press?" |
| `repo-docs/nvim-cheatsheet.md` | One-page daily driver reference. | Active, written in parallel | Printing and pinning next to the keyboard. |
The superseded parity plans and triage drafts were removed after their accepted
decisions were incorporated here. This file is the strategy authority.

---

## 2. Why the strategy changed

The previous plan tried to reproduce a PhpStorm/IntelliJ (Windows) keymap on top
of Neovim: 178 unique bindings extracted from
`home/.chezmoitemplates/vscode/keybindings.json`, ported key-for-key. That plan
was internally consistent, but it was solving the wrong problem.

Three findings collapsed it:

1. **A large share of the keymap was not transportable.** 48 of the 178 bindings
   (27%) depend on terminal key-protocol support to be distinguishable at all -
   `Ctrl+Shift+<key>`, `Ctrl+<digit>`, and most `Alt+Shift` combinations are not
   representable in legacy terminal input encoding. Delivering them required
   certifying a Kitty-keyboard-protocol transport across the terminal emulator,
   the multiplexer and the desktop environment before a single line of Lua was
   useful. That is a large, brittle prerequisite for cosmetic gain.
2. **Parity actively destroys Neovim.** Rebinding `Ctrl+V`, `Ctrl+W`, `Ctrl+R`,
   `Ctrl+O`, `Ctrl+I`, `Ctrl+A` and `Ctrl+D` to their Windows-editor meanings
   removes Visual Block, window management, redo, the jumplist and
   increment/decrement. Those are not incidental features; they are the reason
   the editor is worth learning. A parity keymap yields a slow VS Code.
3. **The user has near-zero Vim proficiency.** Parity is a strategy for someone
   with deep muscle memory in *both* editors who needs to switch between them
   daily. Someone learning Neovim from zero has no Neovim muscle memory to
   protect and no reason to preserve a keymap they are leaving. Every hour spent
   maintaining parity is an hour not spent learning motions.

Neovim 0.11 and 0.12 also changed the arithmetic. Modern Neovim ships defaults
that previously required plugins and custom mappings: unconditional LSP mappings
(`grn`, `grr`, `gri`, `gra`, `grt`, `grx`, `gO`), a full vim-unimpaired-style
bracket family, built-in commenting (`gcc`, `gc{motion}`, `gbc`), snippet
navigation on `Tab`/`S-Tab`, `gx` via `vim.ui.open()`, and treesitter-backed
folding in the Lua ftplugin. The gap that a custom keymap used to fill is much
smaller than it was two years ago.

### Re-scoring table

Scores are out of 100 and weight: learnability for a Vim beginner, resilience to
terminal and plugin churn, maintenance cost, and how much of the user's actual
workflow it covers.

| Strategy | Old | New | Why moved |
|---|---:|---:|---|
| A - blind IntelliJ override | 34 | 25 | Dropped. Still destroys Visual Block, window management, redo and the jumplist. The 0.11 defaults it would clobber grew, so the damage is now larger than when first scored. |
| B - mode-scoped hybrid (IntelliJ keys in Insert, Vim keys in Normal) | 89 | 72 | Solves a problem the user no longer has. Mode-scoping exists to protect existing muscle memory during a gradual switch; the user has committed to a full switch, so the complexity buys nothing and the two-keymaps-in-one-head cost is real. |
| C - pure defaults, zero additions | 50 | 78 | Rose sharply. The 0.11/0.12 defaults cover far more than they did. Still not viable alone: Neovim has no default for find-in-files, git UI, test running, debugging, task running or REST. Honest, but incomplete. |
| **E - defaults-first + leader-only additions** | - | **92** | **Recommended, chosen.** Takes C's correctness and closes its real gaps in a namespace (`<leader>`) that Neovim deliberately leaves empty. Nothing native is lost, every tutorial and Stack Overflow answer applies verbatim, and the additions are discoverable through which-key. |

Strategy E was selected. The remainder of this document assumes it.

---

## 3. The governing rule

> **Never remap a Neovim default. Only add mappings on `<leader>`, or extend the
> `g` / `[` / `]` families with keys Neovim leaves unused.**

This rule is absolute and is enforced by an automated acceptance test (see
section 12, no-default-override test). It has four consequences worth stating
explicitly:

- **Every default keeps working.** `Ctrl+V` is Visual Block. `Ctrl+W` is the
  window prefix. `Ctrl+R` is redo. `Ctrl+O` and `Ctrl+I` walk the jumplist.
  `Ctrl+A` and `Ctrl+X` increment and decrement. `Ctrl+D` and `Ctrl+F` scroll.
  `Ctrl+S` is left entirely alone, which matters twice over: it is XOFF in the
  terminal, and in Neovim 0.11 Insert-mode `CTRL-S` is signature help.
- **External knowledge transfers unmodified.** Any Vim tutorial, `:help` page,
  video, cheat sheet or answer from the last twenty years describes the actual
  configuration. There is no translation layer in the user's head.
- **Additions are discoverable, not memorised.** Pressing `<leader>` and waiting
  pops which-key with the full menu. A beginner does not need to recall a
  mapping; they need to recall a category letter.
- **`<leader>` is `<Space>`.** It is unused in Normal mode by default (it is a
  synonym for `l`, which nobody uses), it is reachable by both thumbs, and it is
  the near-universal community convention.

Permitted extension points, in order of preference:

| Namespace | Permitted use | Constraint |
|---|---|---|
| `<leader>` + letter + letter | Primary namespace for all additions. | Two-level hierarchy only. No three-level chords. |
| `<localleader>` | Filetype-scoped additions if ever needed. | Not used in the initial build. Reserved. |
| `g` family | Only unused suffixes. | `gd`, `gr`, `gO`, `gc`, `gb`, `gx`, `gq`, `gv`, `gi`, `gu`, `gU`, `g;`, `g,`, `gf`, `gg` are taken. Do not shadow them. |
| `[` / `]` family | Only unused suffixes, for genuinely paired navigation. | `q Q l L t T a A b B <Space> [ ] d D` are taken as of 0.11. |
| Insert mode | `jk` only. | One exception, granted explicitly in section 5 item 1. |

Anything that does not fit these namespaces is not added. If a plugin ships a
default keymap that violates the rule, its keymaps are disabled at setup and
re-declared under `<leader>`.

---

## 4. What the pivot eliminates

The following work items existed only to serve keymap parity. All are removed
from scope.

| Eliminated item | Size | Why it is gone |
|---|---|---|
| Protocol-dependent bindings | 48 bindings (27% of 178) | `Ctrl+Shift+<key>`, `Ctrl+<digit>` and most `Alt+Shift` combinations cannot be encoded in legacy terminal input. With no parity target, none of them need to exist. |
| tmux extended-keys certification | Blocker | Was a hard prerequisite: tmux had to pass through Kitty keyboard protocol sequences before the keymap could work. Now optional quality-of-life. |
| Ghostty keybind configuration | Blocker | Same. The terminal emulator no longer needs special configuration for the editor to be usable. |
| GNOME owning `Alt+F2` and friends | Conflict class | Desktop-environment keybind arbitration disappears when no binding needs `Alt+F<n>`. |
| Semantic Vim conflicts | 21 conflicts | Every case where an IntelliJ binding collided with a Neovim default (`Ctrl+V`, `Ctrl+W`, `Ctrl+R`, `Ctrl+A`, `Ctrl+D`, `Ctrl+F`, `Ctrl+B`, `Ctrl+O`, `Ctrl+I`, ...). Resolved by not creating the collision. |
| `Shift Shift` (double-shift search-everywhere) | Impossibility | A terminal cannot report a bare modifier press. Was an unresolvable gap in the parity plan; now simply a different key (`<leader><leader>`). |
| Phase 0 transport certification | Whole phase | Was a mandatory gate with its own test matrix across emulator x multiplexer x DE. Downgraded to **optional**, deferrable indefinitely. |
| Keymap registry | 178 entries -> ~30 | Still useful as a single source of truth for generated documentation and the uniqueness test, but it now describes roughly 30 additions instead of 178 ports. Maintenance cost drops by an order of magnitude. |

Net effect: the project no longer has an infrastructure dependency. It can start
today with any terminal, on any of the four supported targets (macOS, Linux
desktop, Linux CLI/headless, WSL2), and produce a working editor in Phase 1.

---

## 5. Problematic keys

Fourteen keys carry strong non-Vim muscle memory, or are actively hazardous in a
terminal. Each is resolved without breaking the governing rule. Severity is the
risk to the migration if the item is left unaddressed.

| # | Key | Why it is a problem | Resolution | Severity |
|---:|---|---|---|---|
| 1 | `Esc` | Physically far from the home row on every modern keyboard. Mode-switching is the single most frequent action in Vim; a long reach for it makes the whole model feel expensive and is the most common reason beginners quit. | **CapsLock -> Esc at the OS level** on every target, plus `jk` in Insert mode as a same-hand fallback. This is the one permitted Insert-mode mapping. Both remain available alongside the real `Esc` key. | Critical |
| 2 | `Ctrl+S` | Sends XOFF under default terminal line discipline: the terminal appears to freeze completely with no error, and the user will believe Neovim crashed. Additionally, in Neovim 0.11 Insert-mode `CTRL-S` is bound to LSP signature help, so binding it would destroy a useful default. | **Do not bind it.** Save with `:w` and `<leader>w`. If the user insists after four weeks, `stty -ixon` in the shell rc disables flow control - but this is a shell-level change with its own consequences and is not part of the default build. | Critical |
| 3 | `Ctrl+C` / `Ctrl+V` / `Ctrl+X` | Twenty years of OS-level copy/paste muscle memory. In Neovim, `Ctrl+C` is a rough `Esc`, `Ctrl+V` is Visual Block (irreplaceable), `Ctrl+X` is decrement/Insert-completion prefix. All three are defaults worth keeping. | `set clipboard=unnamedplus`, which routes the unnamed register through the system clipboard. Then plain `y`, `p`, `d` and `x` *are* copy, paste, cut and delete-to-clipboard, with no modifier at all. This is strictly less typing than the OS shortcuts. | High |
| 4 | `Ctrl+Z` | Undo everywhere else. In a terminal it suspends Neovim to the shell, which looks exactly like the editor vanishing and losing work. Highly alarming the first time. | Undo is `u`; redo is `Ctrl+R`. Document the recovery explicitly: if it happens, type `fg` and press Enter to bring Neovim back with all state intact. Nothing is lost. Do not rebind - job control is genuinely useful. | High |
| 5 | `Ctrl+A` | Select-all everywhere else. In Neovim it is increment-number-under-cursor, which is a genuinely excellent feature (especially with counts, and with a Visual selection plus `g Ctrl+A` for sequences). | Select-all is `ggVG` (go to top, Visual Line, go to bottom). Three keystrokes, no modifier. Usually the better answer is a text object or `:%` on an Ex command instead of selecting everything. | Medium |
| 6 | `Ctrl+F` | Find-in-file everywhere else. In Neovim it is page-forward. | Search is `/` (forward) or `?` (backward), then `n` / `N` to cycle. `*` searches for the word under the cursor. This is faster than the modal find dialog it replaces and needs no dismissal. | Medium |
| 7 | `Ctrl+Shift+F` | Find-in-files across the project. **Neovim has no native equivalent at all** - `:vimgrep` and `:grep` exist but have no result UI worth using for interactive work. This is a genuine gap, not a muscle-memory issue. | Picker-backed live grep on `<leader>fg`. Replace-in-files, which is a separate and even less native operation, goes to `<leader>sr` via grug-far.nvim. | Medium |
| 8 | `Shift Shift` | IntelliJ search-everywhere. **Impossible in a terminal**: terminals report key presses, not bare modifier presses, so a double-tap of Shift alone cannot be detected. | `<leader><leader>` as the smart/everything picker. Same double-tap ergonomics, same "one entry point to everything" role, on a key the terminal can actually see. | Medium |
| 9 | `Alt+J` | IntelliJ add-selection-for-next-occurrence (multi-cursor). No native Neovim equivalent. | **Native Visual Block only, initially.** `Ctrl+V` then `I` or `A` covers roughly 80% of real multi-cursor use (column edits), and `:s` with a range plus `.`-repeat covers most of the rest. Re-evaluate multicursor.nvim after four weeks of daily use - not before. | Medium |
| 10 | `Ctrl+D` | Duplicate line in the VS Code keymap. In Neovim it is scroll-half-page-down, a core navigation key. | `yyp` duplicates the current line (yank line, put). `yyP` duplicates upward. With a count, `3yyp` duplicates three lines. Shorter than the shortcut it replaces. | Low |
| 11 | `Ctrl+B` | Goto-definition in the VS Code keymap. In Neovim it is scroll-page-back. | `gd` for goto-definition (LSP), or `Ctrl+]` which works via the `'tagfunc'` that Neovim's LSP client sets automatically on attach. Return with `Ctrl+O`. | Low |
| 12 | `Ctrl+W` | Expand-selection in the VS Code keymap. In Neovim it is the **window command prefix** - splits, closing, resizing, navigation all live behind it. Losing it would be severe. | Keep the native meaning without exception. Selection expansion is better served by entering Visual with `v` and then using a text object: `an` / `in` for treesitter nodes via mini.ai, `i(`, `a"`, `ip`, `it` for structural selection. More precise than repeated expansion. | Low |
| 13 | `F5`-`F12` | Debug controls (start, step over, step into, step out, continue). Neovim has **no native DAP** - debugging is entirely a plugin concern. | nvim-dap under `<leader>d`. The function keys are deliberately not used: they are inconsistent across terminals and desktop environments, they are a long reach, and `<leader>d` keeps the whole debug surface discoverable in one which-key menu. | Low |
| 14 | `Ctrl+/` | Toggle comment. Most terminals transmit this as `Ctrl+_` (0x1F), and some transmit nothing distinguishable at all - so it is unreliable even if bound. | Native `gcc` (toggle line), `gc{motion}` (toggle over a motion, e.g. `gcap`), `gbc` (block comment). Built into Neovim since 0.10; no plugin, no binding, works everywhere. | Low |

Two cross-cutting notes:

- Items 3, 5, 6, 10, 11 and 14 are all cases where **the Vim answer is shorter
  than the shortcut it replaces**. This should be stated to the user early and
  often; it is the strongest argument for the strategy and it is verifiable in
  under a minute each.
- Only items 7, 9 and 13 are true capability gaps. Everything else is
  re-learning. That ratio - 3 real gaps out of 14 pain points - is the empirical
  case for defaults-first.

---

## 6. The leader mappings

These are the **only** additions permitted. The count is **32 mappings**
(including the `<leader><leader>` picker and `<leader>?` help), organised as a
two-level hierarchy under `<Space>`. which-key renders the whole tree, so the
user memorises 16 category letters, not 32 mappings.

Group prefixes are chosen to be mnemonic in English and to avoid colliding with
each other on the first letter.

| Prefix | Group | Mapping | Action | Backing plugin |
|---|---|---|---|---|
| - | Smart picker | `<leader><leader>` | Smart find: files + buffers + recent, frecency-ranked. The `Shift Shift` replacement. | snacks.nvim picker |
| `f` | Files / find | `<leader>ff` | Find files in project root | snacks.nvim picker |
| `f` | Files / find | `<leader>fg` | Live grep across project (the `Ctrl+Shift+F` replacement) | snacks.nvim picker |
| `f` | Files / find | `<leader>fr` | Recent files | snacks.nvim picker |
| `f` | Files / find | `<leader>fb` | Buffers | snacks.nvim picker |
| `f` | Files / find | `<leader>fc` | Commands / command palette | snacks.nvim picker |
| `f` | Files / find | `<leader>fn` | New file | snacks.nvim / builtin |
| `s` | Search / replace | `<leader>sr` | Structured search-and-replace across files | grug-far.nvim |
| `s` | Search / replace | `<leader>sw` | Search word under cursor across project | grug-far.nvim / picker |
| `g` | Git | `<leader>gg` | Open lazygit (full git TUI) | snacks.nvim lazygit |
| `g` | Git | `<leader>gb` | Toggle line blame | gitsigns.nvim |
| `g` | Git | `<leader>gd` | Diff view / file history | diffview.nvim |
| `g` | Git | `<leader>gh` | Hunk actions menu (stage, reset, preview) | gitsigns.nvim |
| `d` | Debug | `<leader>db` | Toggle breakpoint | nvim-dap |
| `d` | Debug | `<leader>dc` | Continue / start | nvim-dap |
| `d` | Debug | `<leader>du` | Toggle DAP UI | nvim-dap-ui |
| `t` | Tests | `<leader>tt` | Run nearest test | neotest |
| `t` | Tests | `<leader>tf` | Run tests in current file | neotest |
| `t` | Tests | `<leader>ts` | Toggle test summary panel | neotest |
| `x` | Diagnostics | `<leader>xx` | Toggle diagnostics list | trouble.nvim |
| `x` | Diagnostics | `<leader>xq` | Quickfix list | trouble.nvim |
| `c` | Code | `<leader>cf` | Format buffer or selection | conform.nvim |
| `b` | Buffers | `<leader>bd` | Delete buffer, keep window layout | snacks.nvim bufdelete |
| `w` | Write / windows | `<leader>w` | Write buffer (the `Ctrl+S` replacement) | builtin |
| `e` | Explorer | `<leader>e` | Toggle file explorer | snacks.nvim explorer |
| `r` | Run / tasks | `<leader>rr` | Run task / open task list | overseer.nvim |
| `r` | Run / tasks | `<leader>rh` | Run HTTP request under cursor | kulala.nvim (Bruno via CLI) |
| `a` | AI | `<leader>aa` | Open AI chat | CopilotChat / Claude / OpenCode |
| `a` | AI | `<leader>ac` | AI action on selection | CopilotChat |
| `n` | Notes | `<leader>nn` | New / open note (Obsidian vault) | obsidian.nvim |
| `u` | UI toggles | `<leader>u` | UI toggle menu (wrap, spell, diagnostics, line numbers) | snacks.nvim toggle |
| `?` | Help | `<leader>?` | Show all keymaps for current buffer | which-key.nvim |

**Total: 32 mappings across 16 groups.** `<leader>h` is deliberately left unallocated —
see the reservation note below.

Design constraints applied to this table:

- **No third level.** `<leader>gdh` does not exist. Two keys after `<Space>` is
  the hard ceiling; anything needing more depth gets a picker or a menu instead.
- **Group letters do not collide with each other.** `f`, `s`, `g`, `d`, `t`,
  `x`, `c`, `b`, `w`, `e`, `r`, `a`, `n`, `u`, `?` are all distinct first
  characters. `<leader>w` is a leaf, not a group, and is deliberately the only
  single-key leaf besides `<leader>e` and `<leader>u` - all three are
  high-frequency actions that do not deserve a second keystroke.
- **`<leader>h` is reserved for gitsigns hunks.** It previously held HTTP/REST
  (`<leader>hr`, kulala.nvim), which was a poor allocation: kulala is Tier 3,
  arrives no earlier than Phase 9, and is still an open Bruno-vs-kulala decision
  (section 16). `h` is the community-standard hunk prefix, and gitsigns is Tier 1
  and lands in Phase 4. HTTP/REST therefore moved to `<leader>rh` under Run /
  tasks, which costs no budget and removes a group. Phase 4 decides whether hunks
  stay as the single `<leader>gh` menu or expand into an `h` prefix; expanding
  spends budget and must displace mappings to stay at 32.
- **Nothing here shadows a Neovim default**, because `<Space>` in Normal mode is
  a synonym for `l` and is universally treated as free.
- **Growth is capped.** If a new need appears, it must fit an existing group or
  replace an existing mapping. The number 32 is a budget, not a starting point.
  Every proposed addition beyond it requires justification that it cannot be a
  command, a picker entry, or an existing default.
- **Plugin defaults are disabled.** Plugins that ship their own top-level
  keymaps (trouble, neotest, dap, overseer, obsidian) are configured with
  `keys = {}` or equivalent, and their functionality is re-exposed only through
  the table above.

---

## 7. Single-owner responsibility matrix

Carried forward unchanged from the v3 plan. This section remains fully valid and
is independent of the keymap strategy.

The rule: **for any given (filetype, concern) pair there is exactly one owner.**
Two formatters fighting over a buffer, or two tools reporting the same
diagnostic twice, is the most common and most demoralising failure mode in a
from-scratch Neovim configuration. It is prevented by configuration, not by
hoping.

### 7.1 Formatting

| Concern | Owner | Enforcement |
|---|---|---|
| All formatting except Go | **conform.nvim, sole formatter** | `lsp_format = "never"` in conform's setup. Formatting is never routed through the LSP client. |
| LSP formatting capability | **Disabled on every server except gopls** | Set `capabilities.documentFormattingProvider = false` (and `documentRangeFormattingProvider = false`) in the `on_attach` or via `vim.lsp.config` for each server. |
| Go formatting | **gopls** | gopls is the single exception. It owns Go formatting with `gofumpt = true`. **conform.nvim has no `go` entry at all** - not `gofmt`, not `goimports`, not `gofumpt`. The absence is deliberate; adding one creates a double-format. |
| Format on save | conform.nvim `format_on_save` | Non-PHP budget 500ms, PHP (Pint) budget 1500ms. Timeout falls back to no-format rather than blocking the write. |
| Manual format | `<leader>cf` | Calls `conform.format()` directly. Same code path as save. |

### 7.2 Diagnostics

One diagnostic producer per (filetype, concern). Duplicates are a test failure,
not a preference.

| Language | Producer | Explicitly NOT used | Rationale |
|---|---|---|---|
| JS / TS / Vue | **eslint LSP** | nvim-lint eslint | The eslint language server already reports on change. A parallel nvim-lint eslint linter produces every diagnostic twice with slightly different ranges. |
| Bash | **bash-language-server** | nvim-lint shellcheck | bash-language-server **bundles shellcheck** and surfaces its diagnostics through LSP. Adding nvim-lint shellcheck duplicates every finding. |
| Python | **ruff LSP** | nvim-lint ruff, nvim-lint flake8 | ruff's language server covers lint and import sorting. One server, one source. |
| Go | **golangci-lint via nvim-lint** | gopls staticcheck | golangci-lint already runs staticcheck among its analysers. gopls must therefore be configured with `staticcheck = false`, or every staticcheck finding appears twice. |
| PHP | **intelephense (LSP) + phpstan (nvim-lint)** | phpactor diagnostics | Distinct concerns: intelephense provides language-server diagnostics, phpstan provides static analysis at the configured level. phpactor's own diagnostics are disabled - see 7.3. |
| Nix | **nil or nixd (one, not both)** | the other | Choose one at build time. Running both is a duplicate-producer failure. |
| Spelling | **cspell** | Neovim builtin `spell` in code buffers | `spell` is off in code buffers and on in Markdown/text. cspell handles code-aware spelling with a project dictionary. |

### 7.3 PHP language servers

PHP is the primary language and the most delicate configuration in the build.

| Server | Role | Configuration |
|---|---|---|
| **intelephense** | **PRIMARY.** Completion, hover, goto-definition, references, rename, diagnostics, workspace symbols. | Full capabilities. Premium licence key, if used, is read from an environment variable and never committed. |
| **phpactor** | **Restricted.** Explicit refactoring, code generation, and import-class only. | All overlapping LSP capabilities disabled: completion, hover, definition, references, rename, diagnostics, formatting. It attaches as a command surface, not as a language server. |

**`refactoring.nvim` has NO PHP support.** This is stated explicitly because it
is a natural assumption that it would, and building a PHP refactoring workflow
around it fails. PHP refactoring is phpactor's job, exposed through commands
rather than through the refactoring.nvim keymaps.

### 7.4 Vue

| Server | Role | Configuration |
|---|---|---|
| **vue_ls** | Vue SFC language features | Configured as the Vue half of the hybrid setup. |
| **vtsls** | TypeScript language features inside and outside SFCs | Configured with the Vue language plugin. |

This is **the supported hybrid configuration** as documented upstream. Both
servers attach to Vue buffers by design; this is not a duplicate-producer
violation because they own disjoint concerns (`vue_ls` owns template and SFC
structure, `vtsls` owns TypeScript semantics).

### 7.5 Treesitter

**Option A: Nix owns everything.**

| Artifact | Owner |
|---|---|
| `nvim-treesitter` plugin | Nix |
| All grammars / parsers | Nix |
| `tree-sitter` CLI | Nix |

**Never run `:TSInstall` or `:TSUpdate`.** Doing so writes compiled parsers into
`~/.local/share/`, which then shadow the Nix-provided ones and drift out of sync
with the plugin version, producing parser ABI mismatch errors that are very hard
to diagnose. Parser changes are made by editing `nix/modules/home/dev.nix` and
rebuilding. This is checked by an acceptance test.

---

## 8. Plugin tiers

Three tiers, installed in order. A tier is not started until the previous tier's
exit gate passes. Tier 3 is explicitly optional and may be trimmed.

### Tier 1 - Core (required, installed in Phases 1, 3, 4)

| Plugin | Role |
|---|---|
| `lazy.nvim` | Plugin manager. Committed `lazy-lock.json` pins every version. |
| `which-key.nvim` | Renders the `<leader>` hierarchy. Load-bearing for discoverability; this is how the user finds the 32 mappings. |
| `snacks.nvim` | Picker, explorer, lazygit integration, buffer delete, UI toggles, notifier, dashboard. Deliberately one dependency covering several needs. |
| `nvim-lspconfig` | Server configuration data, consumed via `vim.lsp.config()` / `vim.lsp.enable()`. **`require('lspconfig').setup()` is deprecated and is not used.** |
| `blink.cmp` | Completion. Chosen over nvim-cmp for performance and lower configuration surface. |
| `nvim-treesitter` | Syntax, indentation, text objects, folding. Nix-managed per 7.5. |
| `conform.nvim` | Sole formatter per 7.1. |
| `nvim-lint` | Linters that have no language server, per 7.2. |
| `gitsigns.nvim` | Signs, hunk actions, blame. |
| `trouble.nvim` | Diagnostics and quickfix UI. |
| `grug-far.nvim` | Search and replace across files. Closes problematic-key gap 7. |

### Tier 2 - Workflow (installed in Phases 5-8)

| Plugin | Role |
|---|---|
| `neotest` + adapters | Test running. Adapters: `neotest-pest` or `neotest-phpunit` (one, not both), `neotest-vitest`, `neotest-golang`, `neotest-python`. |
| `nvim-dap` + `nvim-dap-ui` | Debugging. Closes problematic-key gap 13. |
| `overseer.nvim` | Task running. **Must not auto-run tasks on directory entry** - see section 11. |
| `refactoring.nvim` | Refactoring for JS/TS/Go/Python/Lua. **Not PHP** (see 7.3). |
| `diffview.nvim` | Git diff and file history UI. |
| `aerial.nvim` | Symbol outline. Complements the native `gO` document-symbol default. |
| `mini.ai` | Extended text objects, including treesitter `an` / `in`. Closes problematic-key gap 12. |
| `mini.surround` | Surround operations. |
| `flash.nvim` | Enhanced motions and search labels. |
| `vim-tmux-navigator` | Seamless split navigation across Neovim and tmux, if tmux is in use. |
| `hardtime.nvim` | Blocks repeated `hjkl` and arrow keys, forces efficient motions. **Enabled from week 2.** |
| `precognition.nvim` | Shows available motions inline. **Enabled from week 2**, paired with hardtime. |

### Tier 3 - Optional (Phase 9, trim freely)

| Plugin | Role | Note |
|---|---|---|
| `multicursor.nvim` | Multi-cursor | **Deferred.** Re-evaluate after 4 weeks of Visual Block. Closes problematic-key gap 9 only if still needed. |
| `oil.nvim` | Buffer-as-directory editing | Alternative to the snacks explorer. |
| `harpoon` | Fast file marks | Overlaps with `<leader>fr`; adopt only if the picker proves too slow. |
| `nvim-ufo` | Advanced folding | Note `vim.lsp.foldexpr()` exists natively and the Lua ftplugin already sets a treesitter `foldexpr`. |
| `octo.nvim` | GitHub PRs and issues in-editor | |
| `git-conflict.nvim` | Merge conflict resolution | |
| `obsidian.nvim` | Obsidian vault integration | Backs `<leader>n`. |
| `todo-comments.nvim` | TODO/FIXME highlighting and search | |
| `persistence.nvim` | Session management | |
| `CopilotChat.nvim` | AI chat | Backs `<leader>a`. Claude and OpenCode integrations added as they stabilise. |
| `Neovide` | GUI frontend | Sidesteps all terminal key-protocol limits if ever wanted. Not required. |
| `kulala.nvim` | HTTP/REST client | Backs `<leader>rh`. Bruno collections run via the Bruno CLI. |

---

## 9. Language support matrix

Owners per language. Blank cells mean no owner is assigned and none is needed.

| Language | LSP | Format | Lint | Debug | Test |
|---|---|---|---|---|---|
| PHP | intelephense (primary), phpactor (refactor only) | conform -> pint | phpstan (nvim-lint) | nvim-dap + Xdebug (`php-debug-adapter`) | neotest-pest or neotest-phpunit |
| Blade | intelephense + `blade` treesitter | conform -> blade-formatter | - | - (via PHP) | - (via PHP) |
| Vue | vue_ls + vtsls (hybrid, 7.4) | conform -> prettier | eslint LSP | nvim-dap + `js-debug-adapter` | neotest-vitest |
| TypeScript / JavaScript | vtsls | conform -> prettier | eslint LSP | nvim-dap + `js-debug-adapter` | neotest-vitest |
| Tailwind | tailwindcss-language-server | (via prettier + `prettier-plugin-tailwindcss`) | - | - | - |
| Go | gopls (`gofumpt = true`, `staticcheck = false`) | **gopls** (conform has no `go` entry) | golangci-lint (nvim-lint) | nvim-dap + delve | neotest-golang |
| Bash | bash-language-server (bundles shellcheck) | conform -> shfmt | (via LSP, no nvim-lint shellcheck) | - | bats via overseer |
| Nix | nil **or** nixd (exactly one) | conform -> nixfmt or alejandra | (via LSP) | - | - |
| Python | ruff LSP (+ optional basedpyright for types) | conform -> ruff_format | (via ruff LSP) | nvim-dap + debugpy | neotest-python |
| Lua | lua_ls | conform -> stylua | (via LSP) | - | - |
| YAML | yaml-language-server | conform -> prettier | (via LSP schema validation) | - | - |
| Markdown | marksman | conform -> prettier | markdownlint (nvim-lint) | - | - |

Notes:

- **Go is the deliberate formatting exception** and appears in bold above to
  make the asymmetry obvious to anyone editing conform's config later.
- **Nix requires a choice** between `nil` and `nixd` before Phase 3. Running
  both violates 7.2.
- Blade has no independent test or debug story; it is exercised through PHP.
- Tailwind has no formatter of its own; class sorting is a prettier plugin.
- This repo is Bash + Nix, so those two rows are the ones that will be exercised
  first when the config is developed inside `app-configs` itself.

---

## 10. Repository integration and file layout

Carried forward from v3. The ownership split follows this repository's existing
architecture: Nix owns binaries, chezmoi owns dotfiles, mise owns tasks, bats
owns tests.

### 10.1 Ownership

| Artifact | Owner | Location |
|---|---|---|
| Neovim binary | Nix / Home Manager | `nix/modules/home/dev.nix` |
| Language servers (~10 additions) | Nix / Home Manager | `nix/modules/home/dev.nix` |
| Formatters and linters | Nix / Home Manager | `nix/modules/home/dev.nix` |
| Treesitter plugin, parsers, CLI | Nix / Home Manager | `nix/modules/home/dev.nix` (per 7.5) |
| Debug adapters (delve, debugpy, js-debug, php-debug) | Nix / Home Manager | `nix/modules/home/dev.nix` |
| Bruno (GUI) | Nix / Home Manager | `nix/modules/home/gui.nix` |
| Neovim Lua configuration | chezmoi | `home/dot_config/nvim-ide/**` |
| Plugin version pins | chezmoi (committed) | `home/dot_config/nvim-ide/lazy-lock.json` |
| Tasks (`nvim:check`, `nvim:test`, ...) | mise | `mise.toml` |
| Acceptance tests | bats | `tests/bash/nvim-*.bats` |

Roughly ten language servers must be added to `nix/modules/home/dev.nix`:
intelephense, phpactor, vue-language-server, vtsls, tailwindcss-language-server,
gopls, bash-language-server, nil (or nixd), ruff, lua-language-server, plus
marksman and yaml-language-server.

### 10.2 Proposed file layout

```text
home/dot_config/nvim-ide/
  init.lua                     -- bootstrap lazy.nvim, load core, load plugins
  lazy-lock.json               -- committed version pins
  lua/
    core/
      options.lua              -- clipboard=unnamedplus, leader, UI options
      keymaps.lua              -- the 32 leader mappings, nothing else
      autocmds.lua             -- yank highlight, trailing whitespace, ft tweaks
      diagnostics.lua          -- virtual_lines config (see 10.3)
    plugins/
      ui.lua                   -- which-key, theme, snacks UI
      editor.lua               -- mini.ai, mini.surround, flash, hardtime, precognition
      lsp.lua                  -- vim.lsp.config / vim.lsp.enable per server
      completion.lua           -- blink.cmp
      treesitter.lua           -- nvim-treesitter (no auto-install)
      format.lua               -- conform.nvim
      lint.lua                 -- nvim-lint
      git.lua                  -- gitsigns, diffview
      test.lua                 -- neotest + adapters
      debug.lua                -- nvim-dap, nvim-dap-ui
      tasks.lua                -- overseer
      ai.lua                   -- CopilotChat / Claude / OpenCode
      extras.lua               -- Tier 3
    lsp/
      php.lua                  -- intelephense + restricted phpactor
      vue.lua                  -- vue_ls + vtsls hybrid
      go.lua                   -- gopls, gofumpt on, staticcheck off
      <one file per language>
tests/bash/
  nvim-keymap-uniqueness.bats
  nvim-no-default-override.bats
  nvim-startup-budget.bats
  nvim-single-formatter.bats
  nvim-single-diagnostic-source.bats
  nvim-security.bats
```

### 10.3 Diagnostics display

`virtual_text` is **disabled by default in Neovim 0.11**. Diagnostics are
therefore invisible inline unless a handler is configured explicitly. This plan
configures `virtual_lines` instead:

- `virtual_lines` renders the full diagnostic on its own line beneath the
  offending code. It does not truncate, which matters for PHPStan and TypeScript
  messages that routinely exceed 200 characters.
- `virtual_text` remains off. Enabling both produces the same message twice.
- `<leader>u` exposes a toggle so the display can be collapsed when it becomes
  noisy.
- `]d` / `[d` (which accept a count) and `]D` / `[D` (first/last in buffer) are
  Neovim defaults and are not remapped.

### 10.4 Isolation

`NVIM_APPNAME=nvim-ide`. Configuration lives at `home/dot_config/nvim-ide/` and
is invoked through a shell alias, for example `nvim-ide`. Consequences:

- An existing `~/.config/nvim` is untouched and keeps working.
- Runtime state lands in `~/.local/share/nvim-ide/` and
  `~/.local/state/nvim-ide/`, separate from any existing installation.
- **Rollback is simply not using the alias.** Nothing is deleted.
- **This plan never instructs deleting `~/.config/nvim` or
  `~/.local/share/nvim`.** Any advice that does is wrong and must be rejected.

### 10.5 Parity statuses

Every entry in `repo-docs/nvim-keymap.md` carries exactly one of five statuses:

| Status | Meaning |
|---|---|
| **Exact** | Identical behaviour is available, via a default or a leader mapping. |
| **Functional** | The outcome is achievable by a different, equally good route. |
| **Partial** | Most of the behaviour is available; a named sub-case is not. |
| **Deferred** | Achievable but intentionally not built yet, with a named trigger for revisiting. |
| **Gap** | No equivalent exists. Documented as such. |

**No "zero gaps" claim is made anywhere.** Gaps are listed honestly; an editor
migration that claims total coverage is lying.

---

## 11. Security boundaries

Carried forward unchanged from v3. These are non-negotiable.

| Boundary | Rule |
|---|---|
| Project-local config | `.nvim.lua` is loaded **only** through Neovim's trust mechanism (`:trust`). `exrc` is never enabled unconditionally. Cloning a hostile repository must not execute its Lua. |
| Subprocess execution | `vim.system({ 'cmd', 'arg' })` with an argument list. **Never** a shell string. No `os.execute`, no `io.popen`, no `vim.fn.system` with interpolated paths. Filenames containing spaces, quotes or `$(...)` must be inert. |
| Task auto-run | **Overseer must not auto-run tasks on directory entry.** Task templates are discovered but never executed without an explicit user action. Opening a repository must never run its build. |
| AI context exclusion | AI plugins must exclude `.env`, `.env.*`, `*.key`, `*.pem`, `id_*`, `*credentials*`, `*secret*`, and specifically this repository's `home/.chezmoidata/personal.yaml` and `home/.chezmoidata/personal.local.yaml`. Verified by an acceptance test. |
| LSP executables | Language server binaries are resolved from a **Nix/PATH allowlist**. No auto-download, no `mason.nvim`, no fetching binaries at runtime. Every executable is a Nix store path or an explicitly allowlisted PATH entry. |
| Bruno secrets | Bruno environment files containing tokens or credentials are **never committed**. Only example environments are tracked, matching this repo's existing `home/personal.yaml.example` convention. |
| Logging | No plugin configuration may log buffer contents, environment variables or clipboard contents to disk. |

This repository already enforces a related rule: `home/.chezmoidata/personal.yaml`
and `personal.local.yaml` are protected paths and must never be committed or
echoed. The AI-context exclusion above extends that protection into the editor.

---

## 12. Acceptance tests and performance targets

### 12.1 Acceptance tests

Implemented as bats tests in `tests/bash/`, runnable via `mise run test:bash`.

| # | Test | Assertion |
|---:|---|---|
| 1 | Mapping uniqueness | Zero duplicate `(mode, lhs)` pairs across the entire resolved keymap. |
| 2 | **No-default-override** | **No Neovim default keymap has been remapped.** Snapshot the default keymap set from a bare `nvim --clean`, diff against the configured keymap set, assert the configured set is a strict superset with no modified entries. This test enforces the governing rule of section 3 and is the single most important test in the suite. |
| 3 | Startup budget | Warm startup stays within the p50/p95 targets in 12.2. |
| 4 | `:checkhealth` clean | No ERROR entries. WARN entries are enumerated in an allowlist with a reason each. |
| 5 | Single formatter | For every filetype, exactly one formatter is resolved. Asserts `lsp_format = "never"` and that no server except gopls advertises `documentFormattingProvider`. |
| 6 | Format idempotency | Formatting a file twice produces a byte-identical result. Catches formatter pairs that fight. |
| 7 | Single diagnostic source | For every (filetype, concern) pair, exactly one producer is registered. Explicitly asserts no nvim-lint eslint, no nvim-lint shellcheck, no gopls staticcheck. |
| 8 | LSP attach set | Opening a fixture file of each language attaches exactly the expected server set - including both `vue_ls` and `vtsls` for Vue, and intelephense-plus-restricted-phpactor for PHP. |
| 9 | Treesitter parser load | Every configured parser loads from the Nix store path. Fails if a parser resolves to `~/.local/share/`, which would indicate `:TSInstall` was run. |
| 10 | Neotest adapter uniqueness | Exactly one adapter claims each test file. Specifically catches pest and phpunit adapters both claiming PHP tests. |
| 11 | DAP adapters | Each configured debug adapter's executable resolves on PATH. |
| 12 | Security | AI context builder, given a fixture directory containing `.env` and a `personal.yaml`, returns neither. |
| 13 | Rollback | Unsetting `NVIM_APPNAME` yields the pre-existing Neovim behaviour, and `~/.config/nvim` is unmodified. |

### 12.2 Performance targets

| Metric | Target |
|---|---|
| Warm startup, p50 | <= 100ms |
| Warm startup, p95 | <= 180ms |
| Picker first result | <= 150ms |
| Completion response | <= 100ms |
| Format on save, non-PHP | <= 500ms |
| Format on save, PHP (Pint) | <= 1500ms |
| Keymap collisions | 0 |
| Duplicate diagnostic producers | 0 |
| Startup errors | 0 |

Measured with `nvim --startuptime` averaged over 10 warm runs, on the primary
Linux desktop target. Targets are checked at every phase gate, not only at the
end - a regression is far cheaper to find in the phase that caused it.

---

## 13. Phased rollout

Eleven phases. Each has an **objective exit gate** - a checkable condition, not
a feeling. A phase is not started until the previous gate passes.

Phase 2 is unusual and is the most important phase in the plan: it adds no
software at all.

| Phase | Name | Work | Exit gate |
|---:|---|---|---|
| 0 | Isolation | Set `NVIM_APPNAME=nvim-ide` and the shell alias. Map CapsLock -> Esc at OS level on every target in use. Set `clipboard=unnamedplus`. Nothing else. | `nvim-ide` launches with an empty config; `~/.config/nvim` demonstrably unmodified; CapsLock produces Esc in a terminal; `y` in Neovim puts text on the system clipboard and `Ctrl+V` pastes it into a browser. |
| 1 | Core | lazy.nvim, options, which-key, nvim-treesitter (Nix-provided parsers), snacks.nvim, colour scheme. The 32 leader mappings are declared here even where their targets do not yet exist. | Startup p50 <= 100ms; `:checkhealth` has zero ERRORs; pressing `<Space>` shows the which-key menu with all 16 groups; test 2 (no-default-override) passes. |
| 2 | **Learn defaults** | **No plugins are added.** Complete `:Tutor` end to end. Daily driving only. Weeks 1-3 of the learning ramp run here. | `:Tutor` completed; the user can, without reference: enter and leave Insert mode three ways, delete a word/line/inner-quotes, yank and put, undo and redo, repeat with `.`, and navigate with `w`/`b`/`e`/`f`/`t`/`0`/`$`/`gg`/`G`. Self-assessed, honestly. |
| 3 | LSP | All servers from section 9 via `vim.lsp.config()` / `vim.lsp.enable()`. blink.cmp. `virtual_lines` diagnostics. | Test 8 (LSP attach set) passes for every language; `grn`, `grr`, `gri`, `gra`, `grt`, `gO` and `K` all work in a PHP and a TS buffer; `:lsp` reports the expected servers; completion p95 <= 100ms. |
| 4 | Format / lint ownership | conform.nvim with `lsp_format = "never"`, `documentFormattingProvider = false` everywhere except gopls, nvim-lint for the four linters that need it. | Tests 5, 6 and 7 pass. Format-on-save meets the 500ms / 1500ms budgets. Saving a Go file formats via gopls; saving a PHP file formats via Pint; neither double-formats. |
| 5 | PHP / Laravel vertical slice | intelephense fully configured, phpactor restricted per 7.3, phpstan via nvim-lint, Pint via conform, Blade treesitter and blade-formatter, neotest-pest or -phpunit, Xdebug via nvim-dap. | Open a real Laravel project: goto-definition into a facade resolves; rename across files works; phpstan diagnostics appear once; a Pest test runs from `<leader>tt`; a breakpoint in a controller is hit from a browser request. |
| 6 | Vue / TS vertical slice | vue_ls + vtsls hybrid, eslint LSP, prettier via conform, tailwindcss-language-server, neotest-vitest, js-debug-adapter. | Open a real Nuxt project: completion works inside `<template>`, `<script setup>` and `<style>`; Tailwind classes complete and sort on save; eslint diagnostics appear once; a Vitest test runs; a breakpoint in a composable is hit. |
| 7 | Git, tests, debug | gitsigns, diffview, lazygit via snacks; neotest summary panel; nvim-dap-ui. | `<leader>g*` and `<leader>t*` and `<leader>d*` groups fully populated in which-key; tests 10 and 11 pass; a merge conflict can be resolved end to end without leaving the editor. |
| 8 | AI and tasks | CopilotChat (Claude and OpenCode when available), overseer.nvim with auto-run disabled. | Test 12 (security) passes; overseer does not execute anything on directory entry; `<leader>aa` opens a chat with project context that provably excludes `.env` and `personal.yaml`. |
| 9 | Extras | Tier 3, selectively. Obsidian, kulala/Bruno, persistence, todo-comments, octo. Multi-cursor decision point falls here. | Startup budget still met after every addition. Any Tier 3 plugin that costs more than 10ms of startup is dropped or lazy-loaded. Keymap count still <= 32. |
| 10 | Cutover | VS Code is closed for a full working week. `nvim-ide` alias becomes `nvim`, or replaces the editor entry in the shell environment. | Five consecutive working days with no VS Code launch. All 13 acceptance tests green. All performance targets met. Rollback path still verified working (test 13). |

Notes on sequencing:

- **Phase 2 cannot be skipped or shortened.** Every subsequent phase adds
  surface area; adding it before the fundamentals are automatic produces a
  configuration the user cannot drive. If the Phase 2 gate is not met, repeat
  the phase. There is no schedule pressure - the existing VS Code setup keeps
  working throughout.
- Phases 5 and 6 are vertical slices deliberately: each is validated against a
  **real project**, not a fixture. A configuration that passes synthetic tests
  and fails on a real Laravel codebase has proved nothing.
- Phase 10's cutover is reversible at any point by not using the alias.

---

## 14. Learning ramp

Six weeks, structured so that each week's material is a prerequisite for the
next. Weeks 1-3 run inside Phase 2 with no plugins installed.

| Week | Focus | Specifics | Self-check |
|---:|---|---|---|
| 1 | Modes and survival | Normal / Insert / Visual / Command. `h` `j` `k` `l`. `i` `a` `o` `O`. `dd`, `yy`, `p`, `P`, `u`, `:w`, `:q`. `<leader>w` to save. | Edit a config file start to finish without touching the arrow keys or the mouse. |
| 2 | Operator + motion | The grammar: `operator{motion}`. `dw`, `d$`, `cw`, `ci"`, `ca(`, `yi{`, `>>`. Counts: `3dd`, `d2w`, `5j`. **Enable hardtime.nvim and precognition.nvim this week.** | Delete a function body with `di{`. Change a string's contents with `ci"`. Never press `x` more than twice in a row. |
| 3 | Text objects and repeat | `iw` `aw` `is` `as` `ip` `ap` `i(` `a(` `i"` `a"` `it` `at`. The `.` command. `f` `F` `t` `T` `;` `,` for intra-line motion. | Rename every occurrence of a variable in a function using `*` then `cgn` then `.` repeatedly. |
| 4 | Visual Block, macros, registers | `Ctrl+V` then `I` / `A` / `c` / `d` for column edits (this is the multi-cursor answer). `q{reg}` to record, `@{reg}` to play, `@@` to repeat. Named registers `"a`, the yank register `"0`, the clipboard behaviour from `unnamedplus`. | Add a trailing comma to 20 consecutive lines with Visual Block. Record a macro that reformats one list item and apply it to 30 items. |
| 5 | Marks, jumps, brackets | `m{a-z}` and `` `{a-z} ``. `Ctrl+O` / `Ctrl+I` jumplist. `` `. `` last edit, `g;` / `g,` change list. The 0.11 bracket family: `[q ]q`, `[b ]b`, `[d ]d`, `[<Space> ]<Space>`, `[[ ]]`. | Navigate a quickfix list of grep results entirely with `]q` and `[q`. Return from a goto-definition three files deep using only `Ctrl+O`. |
| 6 | LSP defaults and polish | `grn` rename, `grr` references, `gri` implementation, `gra` code action (Normal and Visual), `grt` type definition, `grx` codelens, `gO` document symbols, `K` hover, Insert `CTRL-S` signature help, `Ctrl+]` via `'tagfunc'`, `gq` format via `'formatexpr'`. Re-run `:Tutor` to completion. Optionally `vim-be-good`. | Refactor a class across three files using only `grr`, `grn` and `gra`. Complete `:Tutor` without pausing. |

The ramp deliberately teaches **defaults before additions**. By week 6 the user
knows enough Vim that the 32 leader mappings read as a small, obvious supplement
rather than as the interface itself. That inversion is the entire point of
Strategy E.

Reinforcement rules:

- hardtime.nvim stays on permanently after week 2. Turning it off is a decision
  to stop improving.
- `<leader>?` (which-key, buffer-local keymaps) is the answer to "what can I
  press here". Use it instead of grepping the config.
- `:help` is authoritative. Because no default was remapped, every `:help` page
  describes the actual configuration.

---

## 15. Risks and rollback

### 15.1 Risks

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| User abandons in weeks 1-3 due to speed loss | High | High | Phase 2 has no deadline and VS Code remains installed and working the whole time. Speed loss is expected and is stated up front; the ramp's self-checks give objective evidence of progress when it does not feel like progress. |
| Leader mapping count creeps past 32 | High | Medium | The count is a budget enforced in review, and every mapping is listed in section 6. Additions must displace something or justify why no default, command or picker entry suffices. |
| A plugin update remaps a default | Medium | High | Acceptance test 2 catches it deterministically. `lazy-lock.json` is committed, so updates are explicit events, not surprises. |
| Duplicate formatter or diagnostic source appears | Medium | Medium | Tests 5, 6 and 7. The Go/conform asymmetry and the shellcheck-in-bash-language-server case are the two most likely offenders and are called out by name in 7.1 and 7.2. |
| `:TSInstall` run accidentally, shadowing Nix parsers | Medium | Medium | Test 9 asserts parsers resolve from the Nix store. Section 7.5 states the rule; auto-install is disabled in the treesitter config. |
| Multi-cursor gap proves intolerable | Medium | Low | Explicit four-week review point. multicursor.nvim is a Tier 3 plugin that can be added in an afternoon if Visual Block genuinely does not cover the workload. |
| Startup budget regresses as Tier 3 grows | Medium | Low | Budget checked at every phase gate. Phase 9's exit gate drops any plugin costing more than 10ms that cannot be lazy-loaded. |
| PHP refactoring expectations unmet | Low | Medium | Stated explicitly in 7.3: refactoring.nvim has no PHP support and phpactor is the only route. Setting the expectation now prevents the disappointment later. |
| Secrets leak into AI context | Low | Critical | Test 12, plus the exclusion list in section 11, plus this repository's existing protected-path rules for `personal.yaml`. |
| Terminal key-protocol issues resurface | Low | Low | No longer a blocker by construction - the plan uses no key that requires extended encoding. If it ever matters, Neovide sidesteps it entirely. |

### 15.2 Non-destructive rollback

Rollback is designed to be trivial and is verified by acceptance test 13.

| Level | Action | Effect |
|---|---|---|
| Session | Launch `nvim` instead of `nvim-ide` | Immediate return to the pre-existing editor. Nothing changes on disk. |
| Config | `git checkout` the `home/dot_config/nvim-ide/` directory | Returns the config to any previous commit. chezmoi re-applies. |
| Plugins | Restore `lazy-lock.json` from git and run `:Lazy restore` | Returns every plugin to a known-good pinned version. |
| Packages | Revert the `nix/modules/home/dev.nix` change and rebuild | Removes the added language servers and tools. Home Manager generations allow rollback to the exact previous state. |
| Total | Remove the shell alias and the `home/dot_config/nvim-ide/` directory | Complete removal. `~/.config/nvim` and `~/.local/share/nvim` were never touched. |

**Explicit prohibition, restated:** this plan never instructs deleting
`~/.config/nvim` or `~/.local/share/nvim`. `NVIM_APPNAME` isolation exists
precisely so that removal of this experiment cannot damage anything else.

---

## 16. Open decisions

These require a decision before the phase that depends on them. None blocks
Phase 0 or Phase 1.

| # | Decision | Needed by | Options | Default if unanswered |
|---:|---|---|---|---|
| 1 | Nix LSP: `nil` or `nixd` | Phase 3 | `nil` is lighter and simpler; `nixd` is more capable with flakes and NixOS module evaluation but needs more configuration. Running both violates 7.2. | `nil` |
| 2 | PHP test adapter: `neotest-pest` or `neotest-phpunit` | Phase 5 | Determined by what the user's Laravel projects actually use. Only one may be registered (test 10). | Detect from the project; register one. |
| 3 | Python type checker alongside ruff | Phase 3 | ruff LSP alone, or ruff plus `basedpyright` for types. Adding basedpyright must not duplicate ruff's lint diagnostics. | ruff alone |
| 4 | Colour scheme | Phase 1 | Cosmetic. Must have treesitter and LSP-semantic-token support. | Defer to user taste; no impact on any other decision. |
| 5 | Multi-cursor: adopt `multicursor.nvim`? | Week 4 review | Decided by evidence from four weeks of Visual Block use, not in advance. | Do not adopt. |
| 6 | tmux integration depth | Phase 7 | `vim-tmux-navigator` only, or fuller tmux session integration. Optional either way now that key protocol is not a blocker. | `vim-tmux-navigator` only, if tmux is in use. |
| 7 | AI provider mix | Phase 8 | Copilot now; Claude when its Neovim integration stabilises; OpenCode if a usable integration exists. All must satisfy the section 11 exclusion list. | Copilot only, extend later. |
| 8 | Session manager | Phase 9 | `persistence.nvim`, or none. The user asked for sessions, but auto-restore can be disorienting during learning. | `persistence.nvim`, manual restore only. |
| 9 | Bruno vs kulala for REST | Phase 9 | Bruno GUI for collection management plus kulala.nvim for in-editor requests, or one of the two. Bruno collections can be run via its CLI from overseer. | Both, with kulala for in-editor and Bruno for collection authoring. |
| 10 | Docker workflow | Phase 9 | In-editor container management, or leave it to lazydocker in a terminal split. Neovim's docker plugins are weak. | lazydocker in a terminal, no plugin. |
| 11 | Terminal key-protocol work | Never (optional) | Deferred indefinitely per section 4. Revisit only if a future need genuinely requires an extended-key binding. | Do not do it. |

Decisions 1, 2 and 3 have acceptance tests that will fail if left ambiguous, so
they are self-enforcing. The rest are preferences.

---

**End of plan.** This document describes intent only. No implementation has
occurred.
