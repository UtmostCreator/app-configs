# Neovim Migration Plan — PhpStorm-keymap Power User (v3)

> **SUPERSEDED — REFERENCE ONLY.**
> The user has moved to a defaults-first keymap strategy. The active plan is
> `repo-docs/nvim-defaults-plan.md`. This v3 document is retained because its
> ownership matrix, security boundaries, treesitter ownership, NVIM_APPNAME
> isolation and acceptance tests remain valid; its keymap-parity sections
> (7, 8, 10, 11, 12) do not. Superseded: 2026-07-25.

> **Status: PLAN ONLY.** Nothing in this document has been implemented. No
> Neovim, Nix, mise, chezmoi or terminal configuration file has been created or
> modified as a result of this document.

## 1. Scope and Supersession

**v3 supersedes v1 and v2 entirely.** v1 was the original
`repo-docs/nvim-migration-plan.md` (833 lines, defective), now replaced by this
v3 file. v2 was `repo-docs/nvim-correction-plan-v1.md`, a saved correction round
that identified the duplicate-ownership and key-transport defects.
`repo-docs/nvim-correction-plan-v1-addition.md` is the consolidated review of v1,
v2 and the alternative. `repo-docs/nvim-intellij-nvim-gpt-ver.md` is not v2; it
is a parallel alternative keymap architecture, partially superseded. All three
supporting documents are now **triaged and reference-only**:

| Document | Role now | Binding? |
| --- | --- | --- |
| `repo-docs/nvim-migration-plan.md` (this file, v3) | Single source of truth | **Yes** |
| `repo-docs/nvim-correction-plan-v1.md` | v2 correction round; fully folded into v3 | No - reference only |
| `repo-docs/nvim-correction-plan-v1-addition.md` | Consolidated review; STATUS markers record every verdict | No - reference only |
| `repo-docs/nvim-intellij-nvim-gpt-ver.md` | Parallel alternative architecture; partially superseded; STATUS markers record every verdict | No - reference only |

Goal: replace VS Code with Neovim as the primary IDE, preserving PhpStorm
(Windows) keymap muscle memory, then exceeding VS Code capability.

Author context: near-zero Vim proficiency, strong Linux CLI fluency, wants
minimum keystrokes per outcome and power-user depth.

---

## 2. Correction Log

Every defect found in v1 or v2, its severity, where v3 fixes it, and which
review-document section raised it.

| # | Defect in v1/v2 | Severity | Fixed in v3 | Raised by |
| --- | --- | --- | --- | --- |
| 1 | `gI` claimed as goto-implementation | **Critical** | S12.2 — correct map is `gri`; `gI` is insert-at-column-1 | addition S2 |
| 2 | `gr` claimed as references | **Critical** | S12.2 — correct map is `grr` | addition S2 |
| 3 | `gy` claimed as type definition | **Critical** | S12.2 — correct map is `grt` | addition S2 |
| 4 | Code action / rename / doc-symbol maps absent | High | S12.2 — `gra`, `grn`, `gO`, `grx` | addition S2 |
| 5 | `Ctrl+]` proposed as Indent in Normal mode | **Critical** | S12.3 — `Ctrl+]` is native goto-definition via `'tagfunc'`; never remapped in Normal | addition S2 + Neovim 0.12 docs |
| 6 | `g-` described as cursor undo | High | S12.2 — `g-` walks undo-tree text states; no exact equivalent; use `g;`/`g,` and `Ctrl+O`/`Ctrl+I` | addition S2 |
| 7 | `` `. `` described as global last-edit | Medium | S12.2 — buffer-local only | addition S2 |
| 8 | `Ctrl+Shift+T` marked exact reopen-closed-editor | Medium | S14 — status **Approximate** | addition S2, S11 |
| 9 | `Alt+Up`/`Alt+Down` described as prev/next breadcrumb | Medium | S12.2 — both VS Code bindings call the same command; described as "focus breadcrumbs" | addition S2 |
| 10 | `Ctrl+Shift+U` described as generic toggle-case | Medium | S12.4 — selection uppercases, no selection lowercases the current word | addition S2 |
| 11 | Visual Block example used `40j` for 40 lines | Medium | S12.5 — `Ctrl+V`, `39j`, `$`, `A;`, `Esc`; "one short command sequence", not "six keystrokes" | addition S5 |
| 12 | "88.2% verbatim" published as parity | **Critical** | S5 — 88.2% is *semantic* expressibility; transport is a separate axis; deliverable today is 73.0% | addition S3 |
| 13 | "Zero unresolved extension gaps" | **Critical** | S14 — five parity statuses; several Partial and one Gap | addition S11 |
| 14 | Rollback said delete `~/.config/nvim` and `~/.local/share/nvim` | **Critical** | S22 — `NVIM_APPNAME=nvim-ide` isolation; rollback is stopping use of the alias | addition S13 |
| 15 | `Ctrl+Alt+B` bound to both definition and implementation | **Critical** | S10 — implementation only | addition S1 |
| 16 | `Ctrl+Alt+D` bound to both duplicate-line and peek-definition | **Critical** | S10 — peek only; duplicate moves to `<leader>cd` | addition S1 |
| 17 | `Ctrl+Alt+W` bound to both select-word and expand-selection | **Critical** | S10 — select word only | addition S1 |
| 18 | `Ctrl+Alt+L` bound to both format and focus-right-window | **Critical** | S10 — format only; window focus is `Ctrl+H/J/K/L` | addition S1 |
| 19 | `Ctrl+Alt+J` bound to both select-all-occurrences and focus-lower-window | **Critical** | S10 — multi-cursor only | addition S1 |
| 20 | `Alt+Shift+Up/Down` bound to both move-line and hunk-nav | **Critical** | S10 — hunk nav; line move is `Ctrl+Shift+Up/Down` | addition S1 |
| 21 | `Ctrl+Alt+Shift+Arrows` bound to both resize and add-cursor | **Critical** | S10 — add cursor, inside multicursor cursor-state layer; resize is `<leader>wH/J/K/L` | addition S1 |
| 22 | `Ctrl+Enter` / `Ctrl+Alt+Enter` ambiguous across modes | High | S10 — insert line in Normal+Insert; stage/unstage in Visual only | addition S1 |
| 23 | `<leader>r` used for both Replace and Run | High | S11 — Run keeps `<leader>r`; replace-in-files is `<leader>sr` | addition S1 |
| 24 | `<leader>a` used for both Select-all and AI | High | S11 — AI keeps `<leader>a`; select-all is `<leader>va` | addition S1 |
| 25 | `Tab` assigned five owners with no arbitration | High | S13 — single dispatcher, five-step priority | addition S7 |
| 26 | `Esc` dispatcher missing entirely | High | S13 — single dispatcher | addition S7 |
| 27 | "Ctrl+C/V/X/A/S/Z barely used in Insert/Visual" | High | S8 — displaced-key ledger; six real native duties are displaced | addition S4 |
| 28 | Insert-mode undo granularity unaddressed | Medium | S8 — explicit `Ctrl+G u` boundaries | addition S4 |
| 29 | Intelephense + phpactor both full LSP clients | **Critical** | S9 — intelephense primary; phpactor restricted | addition S6 |
| 30 | Vue/TS server cooperation undefined | **Critical** | S9 — `vue_ls` + `vtsls` supported hybrid; never two TS completion providers | addition S6 |
| 31 | Formatting owner listed as "Conform/LSP" | High | S9 — conform sole owner, `lsp_format = "never"`, provider disabled per server except gopls | addition S6, gpt-ver S7.1 |
| 32 | ESLint/Ruff/shellcheck duplicated across LSP and nvim-lint | High | S9 — one producer per (filetype, concern) | addition S6 |
| 33 | Tree-sitter parser ownership unresolved | High | S15 — Option A: Nix owns plugin, parsers and CLI | addition S9 |
| 34 | Autosave on `CursorHold` | High | S17 — deferred; then FocusLost/BufLeave; never raw `CursorHold` (neotest uses it) | addition S10 |
| 35 | ~30-40 plugins in one baseline | High | S15 — three tiers | addition S8 |
| 36 | `mg979/vim-visual-multi` chosen for multi-cursor | Medium | S15 — `multicursor.nvim`, which supports cursor-state-conditional mappings | gpt-ver S5.3 |
| 37 | `nvim-spectre` chosen for project replace | Medium | S15 — `grug-far.nvim` | gpt-ver S3.2 |
| 38 | `nvim-ufo` in baseline | Low | S15 — native `vim.treesitter.foldexpr()` / `vim.lsp.foldexpr()`; ufo is Tier 3 | gpt-ver S5.4 |
| 39 | `glance.nvim` used for peek | Low | S15 — dropped; Snacks picker covers it | v3 consolidation |
| 40 | Two explorers (snacks + oil) at Tier 1 | Medium | S9, S15 — Snacks Explorer is sole Tier-1 explorer and file-mutation owner; oil is Tier 3 | addition S6 |
| 41 | `Ctrl+W` reassigned to expand-selection (v2) | **Critical** | S10 — Normal `Ctrl+W` stays the native window prefix; expand is Visual `Ctrl+W` + `<leader>ve` | addition S1 (overrides gpt-ver S5.2/S8.2) |
| 42 | `Ctrl+V` reassigned to paste in Normal (v2) | **Critical** | S10 — Normal `Ctrl+V` stays native Visual Block; paste is Insert+Visual only | addition S4 (overrides gpt-ver S1.1) |
| 43 | `Ctrl+Alt+H/J/K/L` bound to window focus | High | S10 — single owner is `Ctrl+H/J/K/L` via vim-tmux-navigator | addition S1 |
| 44 | `Shift Shift` "solved by Neovide" | Medium | S6 — bare modifiers do not emit key events; canonical is `<leader><leader>`; only exact option is an OS remapper emitting `F13` | addition S3 |
| 45 | `Alt+F2` assumed available | High | S6 — GNOME owns `Alt+F2` (Run Command); must be unbound at GNOME level or relocated | addition S3 |
| 46 | Ghostty/tmux treated as out of scope | High | S6, S17 — Ghostty `unbind`/`unconsumed` and a tmux passthrough config are in scope; neither exists in this repo yet | addition S3 |
| 47 | Keymap tables hand-maintained in Lua and Markdown | High | S17 — declarative `lua/keymaps/registry.lua`; doc generated | addition S15 |
| 48 | No security boundary for `.nvim.lua`, AI context, tasks, LSP binaries | High | S18 | addition S14 |
| 49 | Leader hierarchy internally inconsistent (`<leader>ed` under Explorer namespace) | Medium | S11 — duplicate line is `<leader>cd` | addition S16 (accepted with change) |
| 50 | Feature-only exit criteria, no executable gates | High | S19, S20 — objective acceptance tests and per-phase gates | addition S18 |
| 51 | "All 12 languages in one phase" | Medium | S20 — vertical slices | addition S17 |
| 52 | `Ctrl+Alt+G C` / `Shift+C` semantics swapped (v2) | Low | S12.9 — `C` is plain commit, `Shift+C` is commit-staged, matching the VS Code source | gpt-ver S12.1 |
| 53 | refactoring.nvim assumed to cover PHP extracts | High | S9 — refactoring.nvim has **no PHP support**; PHP extracts route to phpactor | v3 verification |
| 54 | Devcontainer model undecided but marked solved | Medium | S24 — open decision | addition S12 |

---

## 3. Executive Verdict

| Question | Answer |
| --- | --- |
| Can the PhpStorm keymap be reproduced in Neovim? | **157 of 178 bindings (88.2%) are semantically expressible as Neovim mappings.** That is not the same as delivered. |
| How much is deliverable in a terminal today? | **130 / 178 = 73.0%.** The remaining 48 bindings (27%) require the Kitty keyboard protocol end-to-end. |
| Should Vim defaults be blindly overridden for IntelliJ parity? | **No. Blind override scores 34/100. Mode-scoped layering scores 89/100 and is the recommendation.** |
| Can Neovim fully replace the VS Code setup? | **Mostly.** Under the five-status parity model there is one **Gap** (Remote Containers) and several **Partial** entries. There is no "zero gaps" claim. |
| Biggest single risk | Key transport, not keymap design. Until Phase 0 certifies GNOME -> Ghostty -> tmux -> Neovim for each chord, no parity number can be published. |
| Second biggest risk | Capability co-ownership: two formatters, two diagnostic producers, two TypeScript providers, or two completion menus. |
| Third biggest risk | Learning-curve abandonment during weeks 1-3 at near-zero Vim proficiency. |

**Governing constraint:** every protocol-dependent key MUST ship a `<leader>`
fallback. This is a hard requirement, not a preference.

---

## 4. Evidence Base

All figures measured from the actual configuration in this repository. Use them
verbatim; do not recompute.

| Fact | Value |
| --- | --- |
| Unique positive VS Code bindings | **178** |
| Semantically non-conflicting with Vim | **157 (88.2%)** |
| Semantically conflicting with Vim | **21** — 11 critical, 10 high |
| Bindings requiring the Kitty keyboard protocol | **48 (27%)** |
| Breakdown of the 48 | 35 `ctrl+shift+*`, 5 enter-variants, 4 `ctrl+backspace`/`ctrl+delete`, 4 numpad, `ctrl+[`, `ctrl+/` |
| Deliverable in a terminal today | **130 / 178 = 73.0%** |
| Keys double-bound in the VS Code config | **11** (resolved there by `when` clauses, which Neovim lacks) |
| Existing Neovim config | `home/dot_config/nvim/` — **81-line stub** |
| Existing neotest config | `home/dot_config/nvim/lua/plugins/neotest.lua` declares neotest with **zero adapters**; cannot run a single test |
| tmux configuration in this repo | **None** |
| Ghostty / terminal configuration in this repo | **None** |
| Only tmux-adjacent file present | `home/dot_config/nvim/lua/plugins/vim-tmux-navigator.lua` |
| Neovim installed | **v0.12.4** |

### 4.1 Available in nixpkgs (not yet added to this repo)

`intelephense`, `phpactor`, `vue-language-server`, `vtsls`,
`tailwindcss-language-server`, `bash-language-server`, `nixd`, `basedpyright`,
`ruff`, `lua-language-server`, `delve`, `bruno 3.4.2`.

### 4.2 Already present in `nix/modules/home/dev.nix`

`gopls`, `delve`, `golangci-lint`, `gofumpt`, `gotools`, `govulncheck`,
`gotestsum`, `php84`, `composer`, `nodejs_22`, `pnpm`, `lazygit`, `gh`, `delta`,
`difftastic`, `ast-grep`, `semgrep`, `shellcheck`, `shfmt`, `actionlint`,
`bats`, `nixfmt-rfc-style`, `statix`, `deadnix`, `opencode`, `claude-code`.

### 4.3 Verified from official Neovim 0.12 documentation

These are ground truth and override any contradicting statement in v1 or v2.

| Surface | Fact |
| --- | --- |
| `gra` | Code action. Unconditional global default, Normal **and** Visual. |
| `gri` | Goto implementation. Unconditional global default. |
| `grn` | Rename. Unconditional global default. |
| `grr` | References. Unconditional global default. |
| `grt` | Type definition. Unconditional global default. |
| `grx` | `codelens.run`. Unconditional global default. |
| `gO` | Document symbol. Unconditional global default. |
| Insert `CTRL-S` | Signature help. Unconditional global default. |
| `K` | Hover. Buffer-local on LSP attach. |
| `'tagfunc'` | Set to `vim.lsp.tagfunc`, so **`CTRL-]` is native goto-definition**. Buffer-local. |
| `'formatexpr'` | Set to `vim.lsp.formatexpr`. Buffer-local. |
| `v_an` / `v_in` | Fall back to `vim.lsp.buf.selection_range()` when treesitter is inactive. |
| Folding | `vim.lsp.foldexpr()` and `vim.treesitter.foldexpr()` are built in. |
| LSP API | `vim.lsp.config()` / `vim.lsp.enable()`. `require('lspconfig').setup()` is **deprecated**. |
| LSP commands | `:lsp enable`, `:lsp disable`, `:lsp restart`, `:lsp stop` exist. |
| Inline completion | Native `lsp-inline_completion` exists, **off by default**. |

---

## 5. Two-Axis Feasibility

v1's single parity number conflated two independent axes. They must be reported
separately.

| Axis | Question | Measured |
| --- | --- | --- |
| **Semantic** | Can the binding be expressed as a Neovim mapping without destroying a Vim core function? | **157 / 178 = 88.2%** |
| **Transport** | Does the physical chord actually reach the Neovim input decoder through GNOME, Ghostty and tmux? | **130 / 178 = 73.0%** today; 48 bindings need the Kitty keyboard protocol end-to-end |

Correct headline wording:

> **88.2% of the PhpStorm keymap is syntactically expressible as Neovim
> mappings. Reliable transport is a separate, lower number: 130 of 178 (73.0%)
> are deliverable in a terminal today. The remaining 48 depend on the Kitty
> keyboard protocol being negotiated end-to-end and must each carry a `<leader>`
> fallback.**

No parity percentage may be published before the Phase 0 key probe in Section 6
has certified each non-leader chord.

### 5.1 The 48 protocol-dependent bindings

| Group | Count | Examples |
| --- | ---: | --- |
| `ctrl+shift+*` | 35 | `Ctrl+Shift+N`, `Ctrl+Shift+A`, `Ctrl+Shift+F`, `Ctrl+Shift+U`, `Ctrl+Shift+Up/Down` |
| Enter variants | 5 | `Shift+Enter`, `Ctrl+Enter`, `Ctrl+Alt+Enter`, `Alt+Enter` family |
| `ctrl+backspace` / `ctrl+delete` | 4 | Insert-mode word deletion |
| Numpad | 4 | `Ctrl+NumPad +/-`, `Ctrl+Shift+NumPad +/-` |
| `ctrl+[` | 1 | Outdent (also the ESC alias in legacy terminals) |
| `ctrl+/` | 1 | Toggle comment (many terminals report `Ctrl+_`) |

---

## 6. Key Transport Prerequisites (Phase 0)

Key transport is the gating constraint for this entire migration. It is not
"unrelated terminal configuration". A chord must survive the full chain:

```text
Physical keyboard
  -> GNOME (global shortcuts)
  -> Ghostty (terminal keybinds, keyboard protocol negotiation)
  -> tmux, if active (extended-keys passthrough)
  -> Neovim input decoder
  -> final mapping
```

### 6.1 Transport classes

| Class | Meaning | Examples | Policy |
| --- | --- | --- | --- |
| **A** | Reliable everywhere | Leader sequences, plain function keys, ordinary letters, `Alt+letter` | May be a primary binding with no fallback |
| **B** | Capability-dependent | `Ctrl+Shift+N`, `Shift+Enter`, `Ctrl+Shift+\`, numpad chords, `Ctrl+Backspace`, `Ctrl+/` | Must have a `<leader>` fallback; requires the Kitty keyboard protocol end-to-end |
| **C** | Host-intercepted | `Alt+F2`, terminal new-tab / copy / paste bindings | Must be unbound at GNOME or Ghostty level, or relocated |
| **D** | Impossible directly | `Shift Shift` | Canonical replacement is `<leader><leader>`; the only exact option is an OS-level remapper emitting `F13` |

All 48 protocol-dependent bindings from Section 5.1 are Class B.

### 6.2 Known host interception

| Host | Issue | Required action |
| --- | --- | --- |
| GNOME | **`Alt+F2` is already the global Run Command shortcut.** It will not reach Neovim. | Unbind at GNOME level, or relocate the Neovim action (rename-file) to `<leader>cR`. Decision required. |
| Ghostty | Ghostty can consume bindings before the PTY sees them. | Ghostty `unbind` and `unconsumed` are **in scope for this migration**. A Ghostty config must be authored; **none exists in this repo today.** |
| tmux | tmux must pass extended keys through. | A tmux config must be authored; **none exists in this repo today.** Only `home/dot_config/nvim/lua/plugins/vim-tmux-navigator.lua` exists. |
| Neovide / GUI | Does **not** solve `Shift Shift`. Bare modifiers do not produce an editor key event. | Do not list Neovide as the `Shift Shift` solution. |

### 6.3 The key probe

Phase 0 ships a `:KeyProbe` command wrapping the native test:

```vim
:lua print(vim.fn.keytrans(vim.fn.getcharstr()))
```

Press the chord; if the reported key is identical to its non-Shift equivalent,
the chord is **not** transported and the binding falls back to `<leader>`.

Each registry entry (Section 17.2) carries transport metadata:

```text
transport = reliable | extended | host_reserved | unavailable
fallback  = <leader>...
verified  = linux_ghostty | macos_ghostty | neovide
```

### 6.4 The leader-fallback rule

> **Every protocol-dependent key MUST ship a `<leader>` fallback. No exceptions.**

The registry loader rejects any Class B, C or D entry that declares no
`fallback`. This is an executable gate, not documentation.

---

## 7. The 11 Ambiguous `when`-clause Keys

The VS Code configuration double-binds 11 keys and disambiguates them with
`when` clauses. Neovim has modes, buffer-local maps and plugin state layers, but
no equivalent general `when` expression. Each requires an explicit ruling.

| # | Key | VS Code action A | VS Code action B | v3 ruling | Discarded action goes to |
| --- | --- | --- | --- | --- | --- |
| 1 | `Ctrl+Alt+L` | Format document/selection | Focus right editor group | **Format only** | Window focus -> `Ctrl+L` (vim-tmux-navigator) |
| 2 | `Ctrl+Alt+J` | Select all occurrences | Focus lower editor group | **Select all occurrences only** | Window focus -> `Ctrl+J` |
| 3 | `Ctrl+Enter` | Insert line below | Stage selected range | **Insert line below in Normal + Insert; stage hunk in Visual only** | Mode-scoped, both retained |
| 4 | `Ctrl+Alt+Enter` | Insert line above | Unstage selected range | **Insert line above in Normal + Insert; unstage hunk in Visual only** | Mode-scoped, both retained |
| 5 | `Ctrl+D` | Duplicate line | (Vim half-page down) | **Native half-page down retained in Normal** | Duplicate line -> `<leader>cd` |
| 6 | `Ctrl+Shift+U` | Uppercase selection | Lowercase current word (no selection) | **Both, context-preserved: selection uppercases, no selection lowercases the word under the cursor** | Exact VS Code semantics preserved |
| 7 | `Shift+F6` | Rename symbol | Rename file in Explorer | **Rename symbol globally; buffer-local `r` inside the Snacks Explorer for file rename** | File rename also on `<leader>cR` |
| 8 | `Ctrl+Alt+Shift+Up` | Add cursor above | Decrease window height | **Add cursor above**, registered only in multicursor.nvim's cursor-state layer | Resize -> `<leader>wK` |
| 9 | `Ctrl+Alt+Shift+Down` | Add cursor below | Increase window height | **Add cursor below**, cursor-state layer only | Resize -> `<leader>wJ` |
| 10 | `Alt+Shift+Up` | Move line up | Previous Git change | **Previous Git hunk** | Move line up -> `Ctrl+Shift+Up` |
| 11 | `Alt+Shift+Down` | Move line down | Next Git change | **Next Git hunk** | Move line down -> `Ctrl+Shift+Down` |

`multicursor.nvim` is chosen specifically because it supports mappings that are
active only while multiple cursors exist. Entries 8 and 9 depend on that layer;
`vim-visual-multi` cannot express them safely.

---

## 8. Keymap Strategy Scoring

| # | Strategy | Score | Rationale |
| --- | --- | ---: | --- |
| A | Blind 90% IntelliJ override across all modes | **34 / 100** | Destroys Visual Block, the window prefix, redo and the jumplist. Every `:help` page, tutorial and plugin default becomes wrong. Fatal at near-zero Vim proficiency. |
| B | **Mode-scoped layering** | **89 / 100** | Keep the 157 semantically safe bindings. Put `Ctrl+C/V/X/A/Z` in Insert and Visual modes only. Leave Normal mode Vim-pure. Relocate the 11 critical keys. Requires the displaced-key ledger in S8.2. |
| C | Pure Vim / LazyVim defaults, full retrain | **50 / 100** | Highest long-term ceiling but discards 178 bindings of working muscle memory while modal editing is still being learned. High abandonment risk; contradicts the stated requirement to match the current profile first. |
| D | `vscode-neovim` / IdeaVim-style hybrid | **28 / 100** | Keeps the workflow dependent on VS Code. Directly contradicts the full-replacement goal. |

**Recommendation: Strategy B, 89/100.**

### 8.1 Mode-scoping table

Vim has modes; VS Code does not. That is the entire mechanism that makes
Strategy B work.

| Key | Normal mode | Insert mode | Visual mode |
| --- | --- | --- | --- |
| `Ctrl+V` | **Visual Block — native, never remapped** | Paste (PhpStorm) | Paste (PhpStorm) |
| `Ctrl+C` | Cancel — native | (unmapped) | **Copy** (PhpStorm) |
| `Ctrl+X` | Decrement number — native | (unmapped) | **Cut** (PhpStorm) |
| `Ctrl+A` | Increment number — native | Select all | Select all |
| `Ctrl+Z` | Suspend — native | **Undo** (PhpStorm) | (unmapped) |
| `Ctrl+S` | Save | **Save** (displaces native signature help) | Save |
| `Ctrl+W` | **Window prefix — native, never remapped** | (unmapped) | **Expand selection** (PhpStorm) |
| `Ctrl+]` | **Goto definition via `'tagfunc'` — native, never remapped** | (unmapped) | (unmapped) |
| `Ctrl+R` | Redo — native | (unmapped) | (unmapped) |
| `Ctrl+D` | Half-page down — native | (unmapped) | (unmapped) |
| `Ctrl+U` | Half-page up — native | (unmapped) | (unmapped) |

Indentation is `>>` / `<<` in Normal and `Tab` / `Shift+Tab` in Visual. `Ctrl+]`
and `Ctrl+[` are **not** used for indentation.

### 8.2 Displaced-key ledger

v1 claimed Vim "barely uses" these keys in Insert and Visual mode. That is
false. Six real native duties are displaced and each needs a documented
relocation.

| Mode | Key | Native duty displaced | Relocation / mitigation |
| --- | --- | --- | --- |
| Insert | `Ctrl+V` | Insert the next character literally | Use `Ctrl+Q` where the terminal transports it |
| Insert | `Ctrl+X` | Completion-family prefix (`Ctrl+X Ctrl+O`, `Ctrl+X Ctrl+F`, ...) | Intentionally displaced; blink.cmp owns completion. Native family reachable via `<leader>l` menu entries |
| Insert | `Ctrl+A` | Reinsert previously inserted text | Rarely used; no relocation. Documented loss |
| Insert | `Ctrl+Z` | Suspend the editor | Suspend remains available from Normal mode `Ctrl+Z` |
| Insert | `Ctrl+S` | **Native LSP signature help (Neovim 0.12 default)** | Signature help relocates to `<leader>lh` |
| Visual | `Ctrl+V` | Switch to blockwise Visual mode | Block selection always starts from **Normal** `Ctrl+V`, which is never remapped |

Additional Strategy B obligations:

| Concern | Requirement |
| --- | --- |
| Insert-mode undo granularity | Neovim treats an Insert session as one undo block. Cursor-movement and paste mappings must emit explicit `Ctrl+G u` boundaries so `Ctrl+Z` behaves like VS Code |
| Normal-mode purity | `Ctrl+V`, `Ctrl+W`, `Ctrl+]`, `Ctrl+R`, `Ctrl+D`, `Ctrl+U`, `Ctrl+O`, `Ctrl+I` keep native behaviour in Normal mode |
| Accepted overrides | `Ctrl+E` (scroll one line) and `Ctrl+G` (file info) are low value and may be overridden in Normal mode |
| Terminal mode | Do **not** map plain `Esc` in terminal mode; it breaks LazyGit, interactive shells and debuggers. Exit terminal mode with `Ctrl+\ Ctrl+N` |

---

## 9. Single-Owner Responsibility Matrix

The single largest architectural defect in v1 was assigning one responsibility
to multiple systems. Every capability below has exactly one primary owner.

| Capability | Primary owner | Secondary policy |
| --- | --- | --- |
| Completion UI | `blink.cmp` | No second completion menu, ever |
| PHP intelligence | **intelephense** | Completion, hover, goto, references, rename, diagnostics |
| PHP refactoring | **phpactor** | Explicit refactoring, code generation, import-class, project transforms only. Overlapping LSP capabilities disabled |
| Vue + TypeScript | `vue_ls` + `vtsls` in the **supported hybrid configuration** | Never two independent TypeScript completion providers |
| Formatting | **conform.nvim, sole owner** | `lsp_format = "never"` |
| Go formatting | **gopls** (`gofumpt = true`) | conform has **no** `go` entry |
| Diagnostics | One producer per `(filetype, concern)` — see 9.2 | Duplicate producers are an acceptance-test failure |
| Git hunks | `gitsigns.nvim` | Stage / reset / preview / blame |
| Repository Git UI | `lazygit` | Diffview only for history and diff review |
| Explorer **and file mutation** | **Snacks Explorer** | Sole Tier-1 explorer. `oil.nvim` is Tier 3 and, if adopted, does not become a second mutation owner |
| Search | Snacks picker | grug-far only for replacement |
| Project replacement | `grug-far.nvim` | Not Spectre |
| Multi-cursor | `multicursor.nvim` | Not `vim-visual-multi`; cursor-state layer required |
| Folding | Native `vim.treesitter.foldexpr()` / `vim.lsp.foldexpr()` | `nvim-ufo` is Tier 3, only after a demonstrated missing feature |
| Peek definition | Snacks picker | `glance.nvim` is dropped |
| AI next-edit-suggestion (NES) | `sidekick.nvim` | No competing NES engine |
| AI inline ghost text | `copilot.lua` | Native `lsp-inline_completion` stays off |
| AI CLI terminal | `sidekick.nvim` terminal | `CopilotChat.nvim` is Tier 3, not baseline |
| Tests | `neotest` with per-project detected adapters | Overseer is the fallback for unsupported runners |
| Tasks | `overseer.nvim` | Must not auto-run repository tasks on directory entry (see S18) |
| Treesitter plugin + parsers + CLI | **Nix** | Lua only enables highlight/fold/filetype |
| LSP/formatter/linter/debugger binaries | **Nix / Home Manager** | `mason.nvim` is forbidden; it would duplicate `nix/modules/home/dev.nix` |

### 9.1 Formatting ownership rule

```text
conform.nvim is the sole formatting owner.

On LspAttach:
  set client.server_capabilities.documentFormattingProvider = false
  for EVERY server EXCEPT gopls.

gopls keeps documentFormattingProvider = true and owns Go formatting
with gofumpt = true. conform has no "go" formatter entry.

conform.setup{ ..., lsp_format = "never" }
```

Rationale: `'formatexpr'` is set to `vim.lsp.formatexpr` by Neovim 0.12 on
attach. Without disabling the provider, `gq` and any LSP format path can race
conform and produce a second diff on save.

### 9.2 Diagnostics: one producer per (filetype, concern)

| Filetype | Concern | Sole producer | Explicitly disabled |
| --- | --- | --- | --- |
| JS / TS / Vue | Lint | **eslint LSP** | No `eslint` entry in nvim-lint |
| Bash / sh | Lint | **bash-language-server** (bundles shellcheck) | No `shellcheck` entry in nvim-lint |
| Python | Lint | **ruff LSP** | No `ruff` entry in nvim-lint |
| Go | Lint | **golangci-lint via nvim-lint** | `gopls` configured with `staticcheck = false` |
| PHP | Intelligence | **intelephense** | phpactor diagnostics disabled |
| PHP | Static analysis | **phpstan via nvim-lint** | Kept separate from LSP diagnostics |
| All code buffers | Spelling | **cspell via nvim-lint** | Builtin `spell` off in code buffers |
| Nix | Lint | `statix` + `deadnix` via nvim-lint | nixd diagnostics kept, non-overlapping |
| YAML / GitHub Actions | Lint | `actionlint` via nvim-lint | yaml-language-server schema diagnostics only |

### 9.3 PHP ownership detail

```text
intelephense (PRIMARY LSP):
  completion, hover, goto definition, references, rename, diagnostics, symbols

phpactor (BOUNDED):
  explicit refactoring commands
  code generation (constructor, getters/setters, docblocks)
  import class
  project transforms
  -> overlapping LSP capabilities disabled on the client
```

**refactoring.nvim has no PHP support.** All PHP extract-variable /
extract-method / extract-constant / inline operations route to phpactor, not to
refactoring.nvim. refactoring.nvim serves JS/TS, Go, Python and Lua.

---

## 10. Conflict Register

Every ruling where v1 and the two review documents disagreed. These are binding.

| # | Contested key | v1 said | v2 said | **v3 ruling** | Reason |
| --- | --- | --- | --- | --- | --- |
| 1 | Normal `Ctrl+W` | Expand selection | Expand selection | **Native window prefix, unchanged.** Expand selection is Visual `Ctrl+W` plus `<leader>ve` | The window prefix is load-bearing for every split, resize and navigation; losing it at near-zero Vim proficiency is fatal |
| 2 | Normal `Ctrl+V` | Paste | Paste | **Native Visual Block, unchanged.** Paste is Insert and Visual only | Visual Block is the exact column-edit superpower the user asked for |
| 3 | Window focus | `Ctrl+Alt+H/J/K/L` | `<leader>wh/j/k/l` | **`Ctrl+H/J/K/L`, single owner (vim-tmux-navigator).** Do **not** bind `Ctrl+Alt+H/J/K/L` | One owner; also gives seamless tmux pane traversal |
| 4 | `Ctrl+Alt+L` | Format + focus right | Format | **Format only** | Window focus already owned by rule 3 |
| 5 | `Ctrl+Alt+J` | Occurrences + focus lower | Select occurrences | **Select all occurrences only** | Same |
| 6 | `Ctrl+Alt+B` | Definition + implementation | Implementation | **Implementation only.** Definition is `gd` / `Ctrl+]` plus `<leader>ld` | `Ctrl+]` is native goto-definition via `'tagfunc'` |
| 7 | `Ctrl+Alt+D` | Duplicate + peek | Peek | **Peek definition only.** Duplicate line moves to `<leader>cd` | `<leader>e` is the Explorer namespace, so `<leader>ed` is unavailable |
| 8 | `Ctrl+Alt+W` | Select word + expand | Select word | **Select word only** | Expand is Visual `Ctrl+W` / `<leader>ve` |
| 9 | `Alt+Shift+Up/Down` | Move line | Git hunk nav | **Git hunk navigation.** Line movement is `Ctrl+Shift+Up/Down` | The later VS Code binding wins in the user's own source |
| 10 | `Ctrl+Alt+Shift+Up/Down` | Resize | Resize | **Add cursor above/below**, registered **only** in multicursor.nvim's cursor-state layer. Resize moves to `<leader>wH/J/K/L` | Multi-cursor is higher value and mode-gated |
| 11 | `Ctrl+Enter` | Stage hunk (all modes) | Insert line / stage | **Insert line below in Normal + Insert; stage hunk in Visual only** | Mode scoping resolves it losslessly |
| 12 | `Ctrl+Alt+Enter` | Unstage hunk (all modes) | Insert above / unstage | **Insert line above in Normal + Insert; unstage hunk in Visual only** | Same |
| 13 | `<leader>r` | Replace | Run | **Run / tasks.** Replace-in-files is `<leader>sr` | Run namespace is larger |
| 14 | `<leader>a` | Select all + AI + Bruno | AI | **AI.** Select-all is `<leader>va`; Bruno/HTTP is `<leader>h` | Three-way collision in v1 |
| 15 | New file | `<leader>n` | `Ctrl+N` | **`<leader>fn`** | `<leader>n` is the Notes namespace |
| 16 | Multi-cursor plugin | multicursor.nvim | vim-visual-multi | **multicursor.nvim** | Cursor-state-conditional mappings are required by rule 10 |
| 17 | Project replace plugin | grug-far | Spectre | **grug-far.nvim** | Live preview, actively maintained |
| 18 | Folding | nvim-ufo (Tier 1) | nvim-ufo | **Native treesitter/LSP foldexpr.** nvim-ufo is Tier 3 | Both foldexpr functions are built into 0.12 |
| 19 | Explorer | snacks + oil | snacks | **Snacks Explorer, sole Tier-1 explorer and file-mutation owner.** oil is Tier 3 | Two mutation owners is a data-loss risk |
| 20 | Peek plugin | glance.nvim | Snacks picker | **Snacks picker; glance.nvim dropped** | Removes a dependency with no unique capability |
| 21 | `Ctrl+]` / `Ctrl+[` | Indent / outdent | Indent / outdent | **Not remapped in Normal.** Indent is `>>` Normal, `Tab` Visual | `Ctrl+]` is native goto-definition |
| 22 | `Ctrl+Alt+G C` / `Shift+C` | Commit / commit-staged | Commit-staged / interactive | **`C` = plain commit, `Shift+C` = commit staged** | Matches the VS Code source; v2 swapped them |
| 23 | Leader hierarchy | 18 prefixes | 18 prefixes | **21-prefix table from addition S16**, with duplicate-line at `<leader>cd` | v2's hierarchy is explicitly REJECTED as superseded |

---

## 11. Leader Hierarchy

Leader: `Space`. Local leader: `\`, reserved strictly for language- and
project-local operations.

| Prefix | Category |
| --- | --- |
| `<leader><leader>` | Search Everywhere |
| `<leader>a` | AI |
| `<leader>b` | Buffers |
| `<leader>c` | Code / refactor |
| `<leader>d` | Debug |
| `<leader>e` | Explorer |
| `<leader>f` | Files |
| `<leader>g` | Git |
| `<leader>h` | HTTP / API (Bruno) |
| `<leader>l` | LSP |
| `<leader>n` | Notes |
| `<leader>p` | Projects |
| `<leader>r` | Run / tasks |
| `<leader>s` | Search / replace |
| `<leader>t` | Tests |
| `<leader>u` | UI toggles |
| `<leader>v` | Selection / Visual |
| `<leader>w` | Windows |
| `<leader>x` | Diagnostics |
| `<leader>y` | Clipboard / path |
| `<leader>z` | Folds / Zen |

Relocations forced by this hierarchy:

| Action | Old | New | Reason |
| --- | --- | --- | --- |
| Bruno / API | `<leader>a` | `<leader>h` | `<leader>a` is AI |
| Replace in files | `<leader>r` | `<leader>sr` | `<leader>r` is Run |
| Select all | `<leader>a` | `<leader>va` | `<leader>a` is AI |
| Duplicate line | `<leader>ed` (proposed) | `<leader>cd` | `<leader>e` is Explorer |
| New file | `<leader>n` | `<leader>fn` | `<leader>n` is Notes |
| Signature help | Insert `Ctrl+S` | `<leader>lh` | Insert `Ctrl+S` is displaced by Save |

---

## 12. Keymap Tables

**Status legend:** `=` identical to PhpStorm | `~` relocated | `+` new capability
**Mode legend:** N Normal | I Insert | V Visual | T Terminal | C Command-line
**Tr legend (transport class, Section 6.1):** A reliable | B protocol-dependent |
C host-intercepted | D impossible directly

Every row with `Tr` = B, C or D carries a mandatory `<leader>` fallback. Rows
with `Tr` = A may have a fallback for discoverability but do not require one.

### 12.1 Search and global navigation

| Status | PhpStorm key | Action | Neovim | Mode | Owner | Tr | Fallback |
| :-: | --- | --- | --- | :-: | --- | :-: | --- |
| ~ | `Shift Shift` | Search Everywhere | `<leader><leader>` | N | snacks.picker.smart | D | canonical; exact only via OS remap to `F13` |
| = | `Ctrl+Shift+N` | Go to file | `Ctrl+Shift+N` | N | snacks.picker.files | B | `<leader>ff` |
| = | `Ctrl+Shift+A` | Find action / command palette | `Ctrl+Shift+A` | N | snacks.picker.commands | B | `<leader>sc` |
| = | `Ctrl+Alt+Shift+N` | Go to symbol (workspace) | `Ctrl+Alt+Shift+N` | N | snacks.picker.lsp_workspace_symbols | B | `<leader>sS` |
| = | `Ctrl+E` | Recent files | `Ctrl+E` | N | snacks.picker.recent | A | `<leader>fr` |
| = | `Ctrl+Shift+E` | Recent editors (MRU) | `Ctrl+Shift+E` | N | snacks.picker.buffers | B | `<leader>fb` |
| = | `Ctrl+G` | Go to line | `Ctrl+G` | N | builtin `:<line>` | A | `<leader>sl` |
| = | `Ctrl+F12` | File structure | `Ctrl+F12` | N | snacks.picker.lsp_symbols / `gO` | A | `<leader>ss` |
| = | `Ctrl+Alt+F12` | Toggle persistent outline | `Ctrl+Alt+F12` | N | aerial.nvim | A | `<leader>uo` |
| = | `Alt+Shift+C` | History of current file | `Alt+Shift+C` | N | diffview file history | A | `<leader>gh` |
| + | — | Resume last picker | `<leader>'` | N | snacks.picker.resume | A | — |
| + | — | Jumplist picker | `<leader>sj` | N | snacks.picker.jumps | A | — |
| + | — | Grep word under cursor | `<leader>sw` | N,V | snacks.picker.grep_word | A | — |
| + | — | Search all keymaps | `<leader>sk` | N | snacks.picker.keymaps | A | — |
| + | — | Search Neovim help | `<leader>sh` | N | snacks.picker.help | A | — |
| + | — | Browse undo history | `<leader>su` | N | snacks.picker.undo | A | — |
| + | — | Browse quickfix list | `<leader>sq` | N | snacks.picker.qflist | A | — |

### 12.2 Code navigation and LSP

Neovim 0.12 ships unconditional global LSP defaults. They are retained and
taught alongside the PhpStorm keys.

| Status | PhpStorm key | Action | Neovim | Mode | Owner | Tr | Fallback |
| :-: | --- | --- | --- | :-: | --- | :-: | --- |
| ~ | `Ctrl+B` | Go to definition | `gd` and `Ctrl+]` | N | LSP `'tagfunc'` | A | `<leader>ld` |
| = | `Ctrl+Alt+B` | Go to implementation | `Ctrl+Alt+B` and **`gri`** | N | LSP builtin | A | `<leader>li` |
| = | `Ctrl+Shift+B` | Go to type definition | `Ctrl+Shift+B` and **`grt`** | N | LSP builtin | B | `<leader>lt` |
| = | `Alt+F7` | Find usages | `Alt+F7` and **`grr`** | N | LSP builtin + snacks.picker | A | `<leader>lr` |
| = | `Ctrl+Alt+F7` | Show usages popup | `Ctrl+Alt+F7` | N | snacks.picker.lsp_references | A | `<leader>lr` |
| = | `Ctrl+F7` | Highlight usages in file | `Ctrl+F7` | N | LSP document highlight | A | `<leader>lH` |
| = | `Ctrl+Shift+I` | Peek definition | `Ctrl+Shift+I` | N | snacks.picker (preview) | B | `<leader>lp` |
| = | `Ctrl+Alt+D` | Peek definition (alt) | `Ctrl+Alt+D` | N | snacks.picker (preview) | A | `<leader>lp` |
| + | — | Document symbol | **`gO`** | N | LSP builtin | A | `<leader>ss` |
| + | — | Run code lens | **`grx`** | N | LSP builtin | A | `<leader>lx` |
| = | `Alt+Left` / `Alt+Right` | Navigate back / forward | `Alt+Left` / `Alt+Right` and `Ctrl+O` / `Ctrl+I` | N | builtin jumplist | A | `<leader>lb` / `<leader>lf` |
| = | `Ctrl+Alt+Left` / `Ctrl+Alt+Right` | Navigate back / forward | same | N | builtin jumplist | A | `Ctrl+O` / `Ctrl+I` |
| ~ | `Ctrl+Shift+Backspace` | Last edit location | `Ctrl+Shift+Backspace` -> `g;` | N | builtin change list | B | `g;` (native) |
| = | `Alt+Up` / `Alt+Down` | **Focus breadcrumbs** | `Alt+Up` / `Alt+Down` | N | aerial.nvim focus | A | `<leader>uo` |
| = | `Ctrl+Down` / `Ctrl+Up` | Next / previous occurrence | same | N | LSP document highlight | A | `]r` / `[r` |
| = | `Alt+F1` | Reveal current file in explorer | `Alt+F1` | N | snacks.explorer | C | `<leader>er` — GNOME may claim `Alt+F1` |
| + | — | Jump to any visible char | `s` | N,V | flash.nvim | A | — |
| + | — | Treesitter node jump | `S` | N | flash.nvim | A | — |
| + | — | Matching bracket | `%` | N,V | builtin | A | — |
| + | — | Older / newer change location | `g;` / `g,` | N | builtin | A | — |

**Corrections carried from the review documents.** `gI` is insert-at-column-1,
not implementation; the correct map is `gri`. References is `grr`, not `gr`.
Type definition is `grt`, not `gy`. `g-` walks older undo-tree **text states**
and is **not** cursor undo; there is no exact native cursor-undo equivalent, so
use `g;` / `g,` for edit locations and `Ctrl+O` / `Ctrl+I` for jumps. `` `. `` is
**buffer-local** and is not a cross-file last-edit history.

### 12.3 Editing and line operations

| Status | PhpStorm key | Action | Neovim | Mode | Owner | Tr | Fallback |
| :-: | --- | --- | --- | :-: | --- | :-: | --- |
| ~ | `Ctrl+D` | Duplicate line / selection | `<leader>cd` | N,V | builtin `:copy .` | A | canonical |
| = | `Ctrl+Y` | Delete line | `Ctrl+Y` | N | builtin `dd` | A | `dd` |
| = | `Ctrl+Shift+J` | Join lines | `Ctrl+Shift+J` | N,V | builtin `J` | B | `J` |
| = | `Shift+Enter` | Insert line below | `Shift+Enter` | N,I | builtin `o` | B | `o` |
| = | `Ctrl+Enter` | Insert line below | `Ctrl+Enter` | **N,I only** | builtin `o` | B | `o` |
| = | `Ctrl+Alt+Enter` | Insert line above | `Ctrl+Alt+Enter` | **N,I only** | builtin `O` | B | `O` |
| ~ | `Ctrl+Shift+Up` | Move line / selection up | `Ctrl+Shift+Up` | N,V | mini.move | B | `<leader>ck` |
| ~ | `Ctrl+Shift+Down` | Move line / selection down | `Ctrl+Shift+Down` | N,V | mini.move | B | `<leader>cj` |
| ~ | `Ctrl+]` | Indent | `>>` (N) / `Tab` (V) | N,V | builtin | A | canonical — **`Ctrl+]` is NOT remapped in Normal** |
| ~ | `Ctrl+[` | Outdent | `<<` (N) / `Shift+Tab` (V) | N,V | builtin | A | canonical |
| = | `Ctrl+Alt+I` | Auto-indent | `Ctrl+Alt+I` -> `gg=G` (N) / `=` (V) | N,V | builtin | A | `<leader>ci` |
| = | `Alt+Z` | Toggle word wrap | `Alt+Z` | N | builtin `'wrap'` | A | `<leader>uw` |
| + | — | **Repeat last change** | `.` | N | builtin | A | — |
| + | — | Surround add / delete / replace | `gsa` / `gsd` / `gsr` | N,V | mini.surround | A | — |
| + | — | Increment / decrement number | `Ctrl+A` / `Ctrl+X` | **N** | builtin | A | — |
| + | — | Split / join code block | `gS` | N | mini.splitjoin (Tier 3) | A | — |

### 12.4 Comments, case and word operations

| Status | PhpStorm key | Action | Neovim | Mode | Owner | Tr | Fallback |
| :-: | --- | --- | --- | :-: | --- | :-: | --- |
| = | `Ctrl+/` | Toggle line comment | `Ctrl+/` **and** `Ctrl+_` | N,V,I | builtin `gcc` / `gc` | B | `gcc` |
| = | `Ctrl+Shift+/` | Toggle block comment | `Ctrl+Shift+/` | V | builtin `gb` | B | `gb` |
| = | `Ctrl+Shift+U` | **Selection: uppercase** | `Ctrl+Shift+U` | V | builtin `gU` | B | `<leader>cu` |
| = | `Ctrl+Shift+U` | **No selection: lowercase current word** | `Ctrl+Shift+U` | N | builtin `guiw` | B | `<leader>cl` |
| = | `Ctrl+Shift+L` | Lowercase selection | `Ctrl+Shift+L` | V | builtin `gu` | B | `<leader>cl` |
| + | — | Toggle case | `<leader>ct` | N,V | builtin `g~` | A | — |
| = | `Ctrl+Left` / `Ctrl+Right` | Previous / next word | same | N,I | builtin `b` / `w` | A | `b` / `w` |
| = | `Ctrl+Backspace` | Delete previous word | `Ctrl+Backspace` | I | builtin | B | `Ctrl+W` (Insert) |
| = | `Ctrl+Delete` | Delete next word | `Ctrl+Delete` | I | builtin | B | `<leader>` n/a — Normal `dw` |
| = | `Ctrl+Home` / `Ctrl+End` | First / last line | same | N | builtin `gg` / `G` | A | `gg` / `G` |
| = | `Alt+Shift+T` / `Alt+Shift+B` | First / last line | same | N | builtin `gg` / `G` | A | `gg` / `G` |

**`Ctrl+Shift+U` must preserve exact VS Code semantics:** with a selection it
uppercases; with no selection it lowercases the word under the cursor. It is not
a generic toggle-case.

### 12.5 Multi-cursor and selection

| Status | PhpStorm key | Action | Neovim | Mode | Owner | Tr | Fallback |
| :-: | --- | --- | --- | :-: | --- | :-: | --- |
| = | `Alt+J` | Add cursor at next match | `Alt+J` | N,V | multicursor.nvim | A | `<leader>vn` |
| = | `Alt+Shift+J` | Add cursor at previous match | `Alt+Shift+J` | N,V | multicursor.nvim | A | `<leader>vp` |
| = | `Ctrl+Alt+J` | Select all occurrences | `Ctrl+Alt+J` | N,V | multicursor.nvim | A | `<leader>vA` |
| = | `Ctrl+Alt+Shift+Up` | Add cursor above | `Ctrl+Alt+Shift+Up` | N | multicursor.nvim **cursor-state layer only** | B | `<leader>vK` |
| = | `Ctrl+Alt+Shift+Down` | Add cursor below | `Ctrl+Alt+Shift+Down` | N | multicursor.nvim **cursor-state layer only** | B | `<leader>vJ` |
| ~ | `Ctrl+W` | Expand selection | `Ctrl+W` | **V only** | `vim.treesitter.select()` / `v_an` | A | `<leader>ve` |
| = | `Ctrl+Shift+W` | Shrink selection | `Ctrl+Shift+W` | V | `vim.treesitter.select()` / `v_in` | B | `<leader>vs` |
| = | `Ctrl+Alt+W` | Select word | `Ctrl+Alt+W` | N | builtin `viw` | A | `viw` |
| = | `Ctrl+Shift+]` / `Ctrl+Shift+[` | Select to matching bracket | same | N,V | builtin `va{` / `%` | B | `<leader>v]` |
| ~ | `Ctrl+A` | Select all | `Ctrl+A` (I,V) and `<leader>va` | I,V | builtin `ggVG` | A | `<leader>va` |
| + | — | **Visual Block (column edit)** | `Ctrl+V` | **N** | builtin | A | — |
| + | — | Select inside function / class / argument | `vif` / `vic` / `via` | N,V | mini.ai | A | — |
| + | — | Select inside quotes / brackets | `vi"` `vi(` `vi{` | N,V | builtin | A | — |

**Worked example — append `;` to exactly 40 lines, starting on the first line:**

```text
Ctrl+V   enter Visual Block
39j      extend down to line 40 (current line + 39 more)
$        extend to end of each line
A;       append ";"
Esc      apply to all 40 lines
```

`40j` would select 41 lines. This is **one short command sequence**, not a
measured six-keystroke operation; individual count digits and commands each
count. The `$ A ... Esc` mechanism is the correct way to append to ragged line
endings.

### 12.6 Find and replace

| Status | PhpStorm key | Action | Neovim | Mode | Owner | Tr | Fallback |
| :-: | --- | --- | --- | :-: | --- | :-: | --- |
| = | `Ctrl+F` | Find in current buffer | `Ctrl+F` -> `/` | N,I,V | builtin | A | `/` |
| = | `F3` / `Shift+F3` | Next / previous match | `F3` / `Shift+F3` | N | builtin `n` / `N` | A | `n` / `N` |
| ~ | `Ctrl+R` | Replace in current buffer | `<leader>sR` | N,V | builtin `:%s///g`, `:'<,'>s///g` | A | canonical — **`Ctrl+R` stays redo in Normal** |
| = | `Ctrl+Shift+F` | Find in files | `Ctrl+Shift+F` | N | snacks.picker.grep | B | `<leader>sg` |
| = | `Ctrl+Shift+R` | Replace in files | `Ctrl+Shift+R` | N | grug-far.nvim | B | `<leader>sr` |
| = | `Ctrl+Shift+H` | Replace in current file (UI) | `Ctrl+Shift+H` | N | grug-far.nvim | B | `<leader>sR` |
| + | — | Search open buffers | `<leader>sB` | N | snacks.picker.grep_buffers | A | — |
| + | — | Search current buffer lines | `<leader>sb` | N | snacks.picker.lines | A | — |
| + | — | Structural find and replace (AST) | `<leader>sa` | N | `ast-grep` (already in Nix) | A | — |
| + | — | Clear search highlight | `Esc` | N | Esc dispatcher (S13.2) | A | — |

### 12.7 Files, buffers and editors

| Status | PhpStorm key | Action | Neovim | Mode | Owner | Tr | Fallback |
| :-: | --- | --- | --- | :-: | --- | :-: | --- |
| = | `Ctrl+S` | Save | `Ctrl+S` | N,I,V | builtin `:update` | A | `<leader>fs` |
| = | `Ctrl+Shift+S` | Save as | `Ctrl+Shift+S` | N | builtin `:saveas` | B | `<leader>fS` |
| ~ | `Ctrl+N` | New file | `<leader>fn` | N | builtin `:enew` | A | canonical |
| = | `Ctrl+F4` | Close buffer, keep layout | `Ctrl+F4` | N | snacks.bufdelete | A | `<leader>bd` |
| = | `Ctrl+Shift+F4` | Close all unmodified buffers | `Ctrl+Shift+F4` | N | snacks.bufdelete | B | `<leader>bA` |
| = | `Ctrl+K` `W` | Close all editors | `Ctrl+K W` | N | snacks.bufdelete | A | `<leader>bA` |
| = | `Ctrl+K` `O` | Close other editors | `Ctrl+K O` | N | snacks.bufdelete | A | `<leader>bo` |
| ~ | `Ctrl+Shift+T` | Reopen closed editor (**Approximate**) | `Ctrl+Shift+T` | N | snacks.picker.recent | B | `<leader>fr` |
| = | `Alt+H` / `Alt+L` | Previous / next editor | `Alt+H` / `Alt+L` | N | builtin `:bprevious` / `:bnext` | A | `<leader>bp` / `<leader>bn` |
| = | `Ctrl+Shift+C` | Copy absolute file path | `Ctrl+Shift+C` | N | custom | B | `<leader>yp` |
| = | `Alt+1` | Toggle project explorer | `Alt+1` | N | snacks.explorer | A | `<leader>e` |
| = | `Ctrl+0` | Focus explorer | `Ctrl+0` | N | snacks.explorer | A | `<leader>e` |
| = | `Alt+F2` | Rename current file | **relocated** | N | snacks.rename + LSP | **C** | `<leader>cR` — **GNOME owns `Alt+F2`** |
| = | `Shift+F6` | Rename symbol | `Shift+F6` and **`grn`** | N | LSP builtin | B | `<leader>lR` |
| + | — | Persistent undo across restarts | `u` / `Ctrl+R` | N | builtin `'undofile'` | A | — |
| + | — | Undo history browser | `<leader>su` | N | snacks.picker.undo | A | — |

`Ctrl+Shift+T` is **Approximate**, not Exact: a recent-file picker does not
restore an unsaved deleted buffer or full editor state.

### 12.8 Windows, splits and tool windows

| Status | PhpStorm key | Action | Neovim | Mode | Owner | Tr | Fallback |
| :-: | --- | --- | --- | :-: | --- | :-: | --- |
| = | `Ctrl+\` | Split vertically | `Ctrl+\` | N | builtin `:vsplit` | A | `<leader>wv` |
| = | `Ctrl+Shift+\` | Split horizontally | `Ctrl+Shift+\` | N | builtin `:split` | B | `<leader>ws` |
| ~ | `Ctrl+Alt+H/J/K/L` | Focus left/down/up/right | **`Ctrl+H/J/K/L`** | N,T | vim-tmux-navigator | A | `<leader>wh/wj/wk/wl` |
| = | `Ctrl+1` / `Ctrl+2` / `Ctrl+3` | Focus window N | same | N | builtin `N Ctrl+W w` | A | `<leader>w1..3` |
| ~ | `Ctrl+Alt+Shift+Left/Right/Up/Down` | Resize window | **`<leader>wH/wL/wK/wJ`** | N | builtin | A | canonical — the chords belong to multi-cursor |
| = | `Ctrl+K` `Ctrl+O` | Close other windows | `Ctrl+K Ctrl+O` | N | builtin `:only` | A | `<leader>wo` |
| = | `Shift+Escape` | Close focused panel / float | `Shift+Escape` | N | custom + Esc dispatcher | B | `<leader>uq` |
| = | `Ctrl+Shift+F12` | Zen / distraction-free | `Ctrl+Shift+F12` | N | snacks.zen | B | `<leader>zz` |
| = | `Ctrl+Alt+F11` | Fullscreen | — | N | GUI only | D | Not available in terminal Neovim; Neovide exposes its own variable |
| = | `Ctrl+Alt+E` / `Ctrl+Alt+Y` | Scroll one line down / up | same | N | builtin `Ctrl+E` / `Ctrl+Y` | A | — |
| + | — | Maximise current split | `<leader>wm` | N | snacks.zen | A | — |
| + | — | Seamless tmux pane traversal | `Ctrl+H/J/K/L` | N,T | vim-tmux-navigator | A | — |

**Tool windows.**

| Status | PhpStorm key | Tool window | Neovim | Mode | Owner | Tr | Fallback |
| :-: | --- | --- | --- | :-: | --- | :-: | --- |
| = | `Alt+1` | File explorer | `Alt+1` | N | snacks.explorer | A | `<leader>e` |
| = | `Alt+2` | Project search | `Alt+2` | N | snacks.picker.grep | A | `<leader>sg` |
| = | `Alt+3` | Source control | `Alt+3` | N | lazygit (snacks.lazygit) | A | `<leader>gg` |
| = | `Alt+4` | Debugger UI | `Alt+4` | N | nvim-dap-ui | A | `<leader>du` |
| = | `Alt+5` | Plugin manager | `Alt+5` | N | `:Lazy` | A | `<leader>up` |
| = | `Alt+6` | Problems | `Alt+6` | N | trouble.nvim | A | `<leader>xx` |
| = | `Alt+7` | Outline | `Alt+7` | N | aerial.nvim | A | `<leader>uo` |
| = | `Alt+0` | Output / notification history | `Alt+0` | N | snacks.notifier | A | `<leader>un` |
| = | `Alt+F12` | Terminal | `Alt+F12` | N,T | snacks.terminal | A | `<leader>rt` |

### 12.9 Git

| Status | PhpStorm key | Action | Neovim | Mode | Owner | Tr | Fallback |
| :-: | --- | --- | --- | :-: | --- | :-: | --- |
| = | `Ctrl+Alt+G` `S` | Git status | `Ctrl+Alt+G S` | N | lazygit | A | `<leader>gs` |
| = | `Ctrl+Alt+G` `C` | **Commit** | `Ctrl+Alt+G C` | N | lazygit | A | `<leader>gc` |
| = | `Ctrl+Alt+G` `Shift+C` | **Commit staged** | `Ctrl+Alt+G Shift+C` | N | lazygit | A | `<leader>gC` |
| = | `Ctrl+Alt+G` `U` | Pull with rebase | `Ctrl+Alt+G U` | N | lazygit | A | `<leader>gu` |
| = | `Ctrl+Alt+G` `P` | Push | `Ctrl+Alt+G P` | N | lazygit | A | `<leader>gp` |
| = | `Ctrl+Alt+G` `Y` | Pull/rebase then push | `Ctrl+Alt+G Y` | N | lazygit | A | `<leader>gy` |
| = | `Ctrl+Alt+G` `F` | Fetch all and prune | `Ctrl+Alt+G F` | N | lazygit | A | `<leader>gf` |
| = | `Ctrl+Enter` | Stage selected range | `Ctrl+Enter` | **V only** | gitsigns | B | `<leader>ghs` |
| = | `Ctrl+Alt+Enter` | Unstage selected range | `Ctrl+Alt+Enter` | **V only** | gitsigns | B | `<leader>ghr` |
| = | `Alt+Shift+Up` | Previous Git hunk | `Alt+Shift+Up` and `[c` | N | gitsigns | A | `[c` |
| = | `Alt+Shift+Down` | Next Git hunk | `Alt+Shift+Down` and `]c` | N | gitsigns | A | `]c` |
| = | `Alt+Shift+C` | History / timeline | `Alt+Shift+C` | N | diffview | A | `<leader>gh` |
| + | — | Preview hunk | `<leader>ghp` | N | gitsigns | A | — |
| + | — | Inline blame (GitLens parity) | `<leader>ghb` | N | gitsigns | A | — |
| + | — | Full-repo diff view | `<leader>gd` | N | diffview.nvim | A | — |
| + | — | Open file / selection on remote | `<leader>gB` | N,V | snacks.gitbrowse | A | — |
| + | — | Browse PRs / issues | `<leader>gP` | N | octo.nvim (**Tier 3**) | A | — |
| + | — | Resolve merge conflicts | `<leader>gx` | N | git-conflict.nvim (**Tier 3**) | A | — |

### 12.10 Debugging

All PhpStorm debug keys are F-keys and are Class A. This is the highest-parity
category in the plan.

| Status | PhpStorm key | Action | Neovim | Mode | Owner | Tr | Fallback |
| :-: | --- | --- | --- | :-: | --- | :-: | --- |
| = | `Shift+F9` | Start / continue debugging | `Shift+F9` | N | nvim-dap | A | `<leader>dc` |
| = | `Ctrl+Shift+F9` | Start / continue debugging | `Ctrl+Shift+F9` | N | nvim-dap | B | `<leader>dc` |
| = | `F9` | Continue | `F9` | N | nvim-dap | A | `<leader>dc` |
| = | `F8` | Step over | `F8` | N | nvim-dap | A | `<leader>dO` |
| = | `F7` | Step into | `F7` | N | nvim-dap | A | `<leader>di` |
| = | `Shift+F8` | Step out | `Shift+F8` | N | nvim-dap | A | `<leader>do` |
| = | `Ctrl+F8` | Toggle breakpoint | `Ctrl+F8` | N | nvim-dap | A | `<leader>db` |
| = | `Ctrl+Shift+F8` | Breakpoint manager | `Ctrl+Shift+F8` | N | nvim-dap-ui | B | `<leader>dB` |
| = | `Ctrl+F2` | Stop debugger | `Ctrl+F2` | N | nvim-dap | A | `<leader>dq` |
| = | `Ctrl+Shift+F2` | Restart debugger | `Ctrl+Shift+F2` | N | nvim-dap | B | `<leader>dR` |
| = | `Alt+F8` | Evaluate expression / selection | `Alt+F8` | N,V | nvim-dap-ui | A | `<leader>de` |
| = | `Alt+4` | Debug panel | `Alt+4` | N | nvim-dap-ui | A | `<leader>du` |
| + | — | Conditional breakpoint | `<leader>dB` | N | nvim-dap | A | — |
| + | — | Debug REPL | `<leader>dr` | N | nvim-dap | A | — |
| + | — | Run last debug configuration | `<leader>dl` | N | nvim-dap | A | — |

**Adapters:** PHP -> `vscode-php-debug` (Xdebug) | JS/TS/Vue ->
`js-debug-adapter` | Go -> `delve` (already in `dev.nix`) | Python -> `debugpy` |
Bash -> `bashdb`.

### 12.11 Tests, run, tasks and terminal

| Status | PhpStorm key | Action | Neovim | Mode | Owner | Tr | Fallback |
| :-: | --- | --- | --- | :-: | --- | :-: | --- |
| = | `Shift+F10` | Select and run task | `Shift+F10` | N | overseer | A | `<leader>rr` |
| = | `Ctrl+Shift+F10` | Select and run task | `Ctrl+Shift+F10` | N | overseer | B | `<leader>rr` |
| + | — | Run last task | `<leader>rl` | N | overseer | A | — |
| + | — | Open task list | `<leader>ro` | N | overseer | A | — |
| + | — | Toggle task terminal | `<leader>rt` | N | overseer / snacks.terminal | A | — |
| + | — | mise task picker | `<leader>rm` | N | overseer + `mise.toml` | A | — |
| + | — | `mise run repo:check` | `<leader>rc` | N | overseer | A | — |
| + | — | `mise run test:bash` | `<leader>rb` | N | overseer | A | — |
| + | — | `bash ops/validate-config.sh` | `<leader>rv` | N | overseer | A | — |
| + | — | Lazydocker | `<leader>rD` | N | snacks.terminal | A | — |
| + | — | Floating scratch shell | `<leader>rs` | N | snacks.terminal | A | — |
| + | — | Run nearest test | `<leader>tn` | N | neotest | A | — |
| + | — | Run current test file | `<leader>tf` | N | neotest | A | — |
| + | — | Run whole suite | `<leader>ta` | N | neotest | A | — |
| + | — | Debug nearest test | `<leader>td` | N | neotest + nvim-dap | A | — |
| + | — | Toggle test summary | `<leader>ts` | N | neotest | A | — |
| + | — | Show test output | `<leader>to` | N | neotest | A | — |
| + | — | Re-run last test | `<leader>tl` | N | neotest | A | — |
| + | — | Watch mode | `<leader>tw` | N | neotest | A | — |
| = | `Ctrl+L` | Clear terminal | `Ctrl+L` passes through | T | shell | A | — |
| = | `Ctrl+D` | Terminal EOF | `Ctrl+D` passes through | T | shell | A | — |
| = | `Ctrl+Shift+D` | Kill terminal buffer | `Ctrl+Shift+D` | T | snacks.terminal | B | `<leader>rk` |
| + | — | Exit terminal mode | `Ctrl+\ Ctrl+N` | T | builtin | A | — |

Do **not** map plain `Esc` in terminal mode.

### 12.12 Diagnostics

| Status | PhpStorm key | Action | Neovim | Mode | Owner | Tr | Fallback |
| :-: | --- | --- | --- | :-: | --- | :-: | --- |
| = | `F2` | Next diagnostic | `F2` and `]d` | N | builtin | A | `]d` |
| = | `Shift+F2` | Previous diagnostic | `Shift+F2` and `[d` | N | builtin | A | `[d` |
| = | `Ctrl+Shift+M` | Problems panel | `Ctrl+Shift+M` | N | trouble.nvim | B | `<leader>xx` |
| = | `Alt+6` | Problems panel | `Alt+6` | N | trouble.nvim | A | `<leader>xx` |
| + | — | Buffer diagnostics | `<leader>xb` | N | trouble.nvim | A | — |
| + | — | Quickfix diagnostics | `<leader>xq` | N | trouble.nvim | A | — |
| + | — | Diagnostic float | `<leader>xd` | N | builtin | A | — |
| + | — | Inline diagnostics (ErrorLens parity) | automatic | — | builtin `virtual_text` | A | — |
| + | — | TODO / FIXME list | `<leader>xt` | N | todo-comments.nvim (**Tier 3**) | A | — |

### 12.13 Completion and code intelligence

| Status | PhpStorm key | Action | Neovim | Mode | Owner | Tr | Fallback |
| :-: | --- | --- | --- | :-: | --- | :-: | --- |
| = | `Ctrl+Space` | Trigger completion | `Ctrl+Space` | I | blink.cmp | A | `<leader>l<Space>` |
| = | `Alt+Space` | Trigger completion (alt) | `Alt+Space` | I | blink.cmp | A | `<leader>l<Space>` |
| = | `Ctrl+Shift+Space` | Parameter hints | `Ctrl+Shift+Space` | N,I | blink.cmp signature | B | `<leader>lh` |
| = | `Ctrl+P` | Parameter info | `Ctrl+P` (**dispatcher, S13.3**) | N,I | blink.cmp signature | A | `<leader>lh` |
| = | `Ctrl+Q` | Quick documentation | `Ctrl+Q` and `K` | N | LSP hover | A | `K` |
| = | `Alt+Enter` | Quick fix / intention | `Alt+Enter` and **`gra`** | N,V | LSP builtin | B | `<leader>la` |
| = | `Ctrl+Alt+O` | Optimize imports | `Ctrl+Alt+O` | N | LSP code action / phpactor | A | `<leader>lo` |
| + | — | Snippet expand / jump | `Tab` / `Shift+Tab` | I | Tab dispatcher (S13.1) | A | — |
| + | — | Toggle inlay hints | `<leader>uh` | N | builtin LSP | A | — |
| + | — | Signature help (relocated) | `<leader>lh` | N,I | LSP builtin | A | canonical, since Insert `Ctrl+S` is displaced by Save |

### 12.14 Refactoring

| Status | PhpStorm key | Action | Neovim | Mode | Owner | Tr | Fallback |
| :-: | --- | --- | --- | :-: | --- | :-: | --- |
| = | `Shift+F6` | Rename symbol | `Shift+F6` and `grn` | N | LSP builtin | B | `<leader>lR` |
| = | `Ctrl+Alt+Shift+T` | Refactor this (menu) | `Ctrl+Alt+Shift+T` | N,V | LSP code actions | B | `<leader>cr` |
| = | `Ctrl+Alt+V` | Extract variable | `Ctrl+Alt+V` | N,V | refactoring.nvim; **phpactor for PHP** | A | `<leader>cv` |
| = | `Ctrl+Alt+M` | Extract method | `Ctrl+Alt+M` | N,V | refactoring.nvim; **phpactor for PHP** | A | `<leader>cm` |
| = | `Ctrl+Alt+C` | Extract constant | `Ctrl+Alt+C` | N,V | refactoring.nvim; **phpactor for PHP** | A | `<leader>cc` |
| = | `Ctrl+Alt+N` | Inline | `Ctrl+Alt+N` | N,V | refactoring.nvim; **phpactor for PHP** | A | `<leader>cn` |
| = | `Ctrl+Alt+T` | Surround with | `Ctrl+Alt+T` | V | mini.surround | A | `gsa` |
| = | `Ctrl+Alt+L` | Format document / selection | `Ctrl+Alt+L` | N,V | **conform.nvim only** | A | `<leader>cf` |
| = | `Ctrl+Alt+Shift+L` | Format selection | `Ctrl+Alt+Shift+L` | V | conform.nvim | B | `<leader>cf` |
| + | — | PHP generate constructor / accessors | `<leader>cP` | N | phpactor | A | — |
| + | — | PHP import class | `<leader>cI` | N | phpactor | A | — |

Extraction action kinds are not standardised across language servers. The
generic refactor menu (`<leader>cr`) is more dependable than per-kind shortcuts;
both are provided.

### 12.15 Folding

| Status | PhpStorm key | Action | Neovim | Mode | Owner | Tr | Fallback |
| :-: | --- | --- | --- | :-: | --- | :-: | --- |
| = | `Ctrl+NumPad +` | Open fold | `Ctrl+NumPad +` and `zo` | N | native foldexpr | B | `zo` |
| = | `Ctrl+NumPad -` | Close fold | `Ctrl+NumPad -` and `zc` | N | native foldexpr | B | `zc` |
| = | `Ctrl+Shift+NumPad +` | Open all folds | same and `zR` | N | native foldexpr | B | `zR` |
| = | `Ctrl+Shift+NumPad -` | Close all folds | same and `zM` | N | native foldexpr | B | `zM` |
| + | — | Toggle fold under cursor | `za` | N | builtin | A | — |
| + | — | Fold provider | `vim.treesitter.foldexpr()` / `vim.lsp.foldexpr()` | — | builtin 0.12 | A | — |

### 12.16 Clipboard and undo

| Status | PhpStorm key | Action | Neovim | Mode | Owner | Tr | Fallback |
| :-: | --- | --- | --- | :-: | --- | :-: | --- |
| = | `Ctrl+C` | Copy | `Ctrl+C` | **V only** | builtin `y` | A | `y` |
| = | `Ctrl+X` | Cut | `Ctrl+X` | **V only** | builtin `d` | A | `d` |
| = | `Ctrl+V` | Paste | `Ctrl+V` | **I, V only** | builtin `"+p` / `Ctrl+R +` | A | `p` |
| = | `Ctrl+Z` | Undo | `Ctrl+Z` | **I only** | builtin `u` | A | `u` |
| = | `Ctrl+Shift+Z` | Redo | `Ctrl+Shift+Z` | **I only** | builtin `Ctrl+R` | B | `Ctrl+R` |
| = | `Ctrl+A` | Select all | `Ctrl+A` | **I, V only** | builtin `ggVG` | A | `<leader>va` |
| + | — | Named registers | `"ay` / `"ap` | N,V | builtin | A | — |
| + | — | Yank to system clipboard | `<leader>y` | N,V | builtin | A | — |
| + | — | Copy relative / absolute path | `<leader>yp` / `<leader>yP` | N | custom | A | — |

`vim.opt.clipboard = "unnamedplus"` is the baseline. Insert-mode paste and
cursor-movement mappings emit `Ctrl+G u` undo boundaries.

### 12.17 REST / API (Bruno) and notes

| Status | Action | Neovim | Mode | Owner | Tr | Fallback |
| :-: | --- | --- | :-: | --- | :-: | --- |
| + | Run `.bru` file under cursor | `<leader>hr` | N | overseer -> `bru run` | A | — |
| + | Run Bruno collection with env | `<leader>hc` | N | overseer -> `bru run --env` | A | — |
| + | Open Bruno GUI at current collection | `<leader>hg` | N | `vim.system({...})` | A | — |
| + | Scratch HTTP request | `<leader>hs` | N | kulala.nvim (**Tier 3**) | A | — |
| + | Open Obsidian vault note | `<leader>nn` | N | obsidian.nvim (**Tier 3**) | A | — |
| + | Search vault | `<leader>ns` | N | obsidian.nvim (**Tier 3**) | A | — |
| + | Follow / create wiki link | `<leader>nf` | N | obsidian.nvim (**Tier 3**) | A | — |
| + | Daily note | `<leader>nd` | N | obsidian.nvim (**Tier 3**) | A | — |
| + | Toggle checkbox | `<leader>nx` | N | obsidian.nvim (**Tier 3**) | A | — |
| + | Markdown preview in browser | `<leader>np` | N | markdown-preview.nvim (**Tier 3**) | A | — |

Bruno stays the canonical API client: GUI plus version-controlled `.bru` files.
kulala.nvim is for throwaway requests only. The Obsidian vault is already
Syncthing-managed by `ops/syncthing-obsidian-stignore.sh`; no new sync layer.

### 12.18 AI, sessions, projects and meta

| Status | PhpStorm key | Action | Neovim | Mode | Owner | Tr | Fallback |
| :-: | --- | --- | --- | :-: | --- | :-: | --- |
| + | — | Accept inline suggestion | `Tab` | I | Tab dispatcher (S13.1) | A | — |
| + | — | Next / previous suggestion | `Alt+]` / `Alt+[` | I | copilot.lua | A | `<leader>a]` / `<leader>a[` |
| + | — | Dismiss suggestion | `Esc` | I | Esc dispatcher (S13.2) | A | — |
| + | — | Accept next edit suggestion (NES) | `Tab` | I,N | sidekick.nvim | A | `<leader>ae` |
| + | — | Toggle AI CLI pane | `<leader>aa` | N | sidekick.nvim | A | — |
| + | — | Toggle Claude CLI | `<leader>ac` | N | sidekick.nvim | A | — |
| + | — | Toggle OpenCode CLI | `<leader>ao` | N | sidekick.nvim | A | — |
| + | — | Select AI terminal | `<leader>as` | N | sidekick.nvim | A | — |
| + | — | Send visual selection to AI | `<leader>av` | V | sidekick.nvim | A | — |
| + | — | Send current file to AI | `<leader>af` | N | sidekick.nvim | A | — |
| + | — | Send diagnostics context to AI | `<leader>ad` | N | sidekick.nvim | A | — |
| + | — | Select recent project | `<leader>pp` | N | snacks.picker.projects | A | — |
| + | — | Find file in project | `<leader>pf` | N | snacks.picker.files | A | — |
| + | — | Grep project | `<leader>pg` | N | snacks.picker.grep | A | — |
| + | — | Restore last session | `<leader>pr` | N | persistence.nvim (**Tier 3**) | A | — |
| = | `Ctrl+Alt+S` | Open Neovim config | `Ctrl+Alt+S` | N | snacks.picker.files | A | `<leader>fc` |
| = | `Ctrl+Alt+Shift+S` | Find config file | `Ctrl+Alt+Shift+S` | N | snacks.picker.files | B | `<leader>fC` |
| = | `Ctrl+Alt+Shift+K` | Search active mappings | `Ctrl+Alt+Shift+K` | N | snacks.picker.keymaps | B | `<leader>sk` |
| + | — | Show all keymaps (which-key) | `<leader>?` | N | which-key.nvim | A | — |
| + | — | Plugin manager | `:Lazy` | N | lazy.nvim | A | `<leader>up` |
| + | — | Health check | `:checkhealth` | N | builtin | A | — |
| + | — | Startup profiling | `:Lazy profile` | N | lazy.nvim | A | — |

---

## 13. Tab and Esc Dispatchers

Five subsystems want `Tab` and four want `Esc`. Each key has exactly one
registry entry pointing at one dispatcher function. Without this, completion and
AI behaviour feel random.

### 13.1 Insert-mode `Tab` dispatcher

| Priority | Condition | Action |
| ---: | --- | --- |
| 1 | Sidekick NES suggestion visible | Accept or advance the next edit suggestion |
| 2 | Completion menu visible | Select / accept the completion |
| 3 | Snippet jump available | Jump to the next placeholder |
| 4 | Copilot ghost text visible | Accept the suggestion |
| 5 | Otherwise | Insert indentation |

`Shift+Tab` mirrors the chain: previous NES -> previous completion item ->
previous snippet placeholder -> outdent.

In Visual mode `Tab` / `Shift+Tab` indent and outdent the selection. In Normal
mode indentation is `>>` / `<<`; `Tab` remains the native jumplist-forward key.

### 13.2 `Esc` dispatcher

Missing entirely from v1. Four subsystems compete.

| Priority | Condition | Action |
| ---: | --- | --- |
| 1 | Multiple cursors active | Clear multi-cursors |
| 2 | Popup / floating window open | Close the popup |
| 3 | AI suggestion visible | Dismiss the suggestion |
| 4 | Search highlight active | Clear the highlight (`:nohlsearch`) |
| 5 | Otherwise | Native `Esc` behaviour |

`Esc` is **never** mapped in Terminal mode.

### 13.3 `Ctrl+P` dispatcher

| Priority | Condition | Action |
| ---: | --- | --- |
| 1 | Completion menu visible | Previous completion item |
| 2 | Otherwise | Signature / parameter help |

---

## 14. Extension Parity Matrix

Five statuses, per Section 11 of the addition document. **There is no "zero
unresolved gaps" claim in v3.**

| Status | Meaning |
| --- | --- |
| **Exact** | Same outcome and comparable interaction |
| **Functional** | Same core outcome, different workflow |
| **Partial** | Important capabilities missing |
| **Deferred** | Not required for cutover |
| **Gap** | No adequate replacement yet |

| VS Code extension | Neovim replacement | Status |
| --- | --- | --- |
| `bmewburn.vscode-intelephense-client` | intelephense (Nix) | Exact |
| `devsense.phptools-vscode` | phpactor (bounded refactoring role) | Functional |
| `open-southeners.laravel-pint` | conform.nvim -> pint | Exact |
| `shufo.vscode-blade-formatter` | conform.nvim -> blade-formatter | Exact |
| `mehedidracula.php-namespace-resolver` | phpactor import class | Exact |
| `neilbrayfield.php-docblocker` | neogen | Functional |
| `recca0120.vscode-phpunit` | neotest-phpunit / neotest-pest | Functional |
| `xdebug.php-debug` | nvim-dap + vscode-php-debug | Exact |
| `amiralizadeh9480.laravel-extra-intellisense` | laravel.nvim | **Functional/Partial** — verify feature by feature |
| `codingyu.laravel-goto-view` | laravel.nvim | Functional |
| `ryannaddy.laravel-artisan` | laravel.nvim (`:Artisan`) | Functional |
| `vue.volar` | vue-language-server (Nix), hybrid with vtsls | Exact |
| `nuxtr.nuxtr-vscode` | no defined implementation yet | **Partial** |
| `ms-vscode.vscode-typescript-next` | vtsls (Nix) | Exact |
| `dbaeumer.vscode-eslint` | eslint LSP (sole producer) | Exact |
| `esbenp.prettier-vscode` | conform.nvim -> prettier | Exact |
| `stylelint.vscode-stylelint` | nvim-lint -> stylelint | Exact |
| `bradlc.vscode-tailwindcss` | tailwindcss-language-server (Nix) | Exact |
| `austenc.tailwind-docs` | tailwind LSP hover | Functional |
| `ecmel.vscode-html-css` | LSP + treesitter | Functional |
| `pranaygp.vscode-css-peek` | LSP definition | Functional |
| `htmlhint.vscode-htmlhint` | nvim-lint | Exact |
| `naumovs.color-highlight` | nvim-colorizer | Exact |
| `formulahendry.auto-close-tag` | nvim-ts-autotag | Exact |
| `christian-kohler.path-intellisense` | blink.cmp path source | Exact |
| `christian-kohler.npm-intellisense` | blink.cmp source | Functional |
| `eamodio.gitlens` | gitsigns + diffview + lazygit | **Functional** — not every integrated view |
| `mhutchie.git-graph` | diffview / lazygit | Functional |
| `github.vscode-pull-request-github` | octo.nvim (Tier 3) | Functional |
| `github.vscode-github-actions` | actionlint + nvim-lint | **Partial** — no run browsing, logs or dispatch UI |
| `usernamehw.errorlens` | builtin `virtual_text` | Exact |
| `gruntfuggly.todo-tree` | todo-comments.nvim (Tier 3) | Exact |
| `alefragnani.bookmarks` | marks + harpoon (Tier 3) | Functional |
| `sonarsource.sonarlint-vscode` | semgrep + nvim-lint | **Partial** — no connected-mode parity |
| `streetsidesoftware.code-spell-checker` | cspell via nvim-lint (builtin `spell` off in code) | Exact |
| `davidanson.vscode-markdownlint` | nvim-lint -> markdownlint | Exact |
| `redhat.vscode-yaml` | yaml-language-server | Exact |
| `mechatroner.rainbow-csv` | csvview.nvim | Functional |
| `dotenv.dotenv-vscode` | treesitter | Functional |
| `editorconfig.editorconfig` | builtin | Exact |
| `humao.rest-client` | Bruno + kulala.nvim | Functional |
| `docker.docker`, `ms-azuretools.*` | lazydocker + dockerfile LSP | Functional |
| `ms-playwright.playwright` | neotest-playwright | Functional |
| `ms-vscode-remote.remote-wsl` | native — Neovim runs in WSL | Exact |
| `ms-vscode-remote.remote-containers` | undecided (see S24) | **Gap** |
| `pkief.material-icon-theme` | mini.icons / nvim-web-devicons | Exact |
| `anan.jetbrains-darcula-theme` | darcula-solid.nvim | Exact |
| `k--kato.intellij-idea-keybindings` | this plan's keymap registry | Functional |
| `hbenl.*`, `ms-vscode.test-adapter-*` | neotest | Functional |
| Copilot agent mode | sidekick.nvim CLI integration | **Partial** |
| Reopen closed editor | snacks.picker.recent | **Approximate** |

**Remote Containers is a Gap, not a workflow preference.** `docker exec` alone
does not provide remote LSP, debugger, task and filesystem orchestration. It
must not be marked solved until one real project passes LSP navigation,
completion, formatter, test runner, debugger, clipboard, Git operations and
project terminal inside the container.

---

## 15. Plugin Stack — Three Tiers

Ownership rule: **binaries via Nix, Lua plugins via lazy.nvim.** `mason.nvim` is
forbidden; it would duplicate `nix/modules/home/dev.nix` and break
reproducibility.

### 15.1 Tier 1 — mandatory replacement core

| Area | Plugin | Note |
| --- | --- | --- |
| Package manager | `folke/lazy.nvim` | Committed `lazy-lock.json` |
| Discoverability | `folke/which-key.nvim` | **Mandatory at near-zero Vim proficiency** |
| Picker / explorer / terminal / zen / notifier | `folke/snacks.nvim` | Sole explorer and file-mutation owner |
| LSP configuration | `neovim/nvim-lspconfig` via `vim.lsp.config()` | `require('lspconfig').setup()` is deprecated |
| Completion | `saghen/blink.cmp` | Sole completion UI |
| Syntax | `nvim-treesitter/nvim-treesitter` | Nix-owned; see 15.4 |
| Formatting | `stevearc/conform.nvim` | Sole formatting owner |
| Linting | `mfussenegger/nvim-lint` | Only where an LSP does not already produce it |
| Git hunks | `lewis6991/gitsigns.nvim` | |
| Diagnostics UI | `folke/trouble.nvim` | |
| Project replacement | `MagicDuck/grug-far.nvim` | Not Spectre |

### 15.2 Tier 2 — primary engineering workflows

| Area | Plugin | Note |
| --- | --- | --- |
| Tests | `nvim-neotest/neotest` + per-project adapters | Adapters enabled only when runner and parser exist |
| Debug | `mfussenegger/nvim-dap`, `rcarriga/nvim-dap-ui` | |
| Tasks | `stevearc/overseer.nvim` | Must not auto-run on directory entry |
| Multi-cursor | `jake-stewart/multicursor.nvim` | Cursor-state layer required |
| Refactoring | `ThePrimeagen/refactoring.nvim` | **No PHP support**; PHP routes to phpactor |
| Git history | `sindrets/diffview.nvim` | |
| Outline | `stevearc/aerial.nvim` | |
| Text objects | `echasnovski/mini.ai` | |
| Surround | `echasnovski/mini.surround` | |
| Line movement | `echasnovski/mini.move` | |
| Motions | `folke/flash.nvim` | |
| Pane traversal | `christoomey/vim-tmux-navigator` | Already present in the stub |

### 15.3 Tier 3 — only after a demonstrated need

`oil.nvim`, `harpoon`, `nvim-ufo`, `octo.nvim`, `git-conflict.nvim`,
`obsidian.nvim`, `markdown-preview.nvim`, `todo-comments.nvim`,
`persistence.nvim`, `hardtime.nvim`, `precognition.nvim`, `CopilotChat.nvim`,
`Neovide`, `kulala.nvim`.

Each Tier 3 adoption requires a recorded need: the specific workflow that Tier 1
and Tier 2 could not serve.

### 15.4 Tree-sitter ownership — Option A

```text
Nix owns:
  the nvim-treesitter plugin
  the selected parser grammars
  the tree-sitter CLI and compiler requirements

Lua owns:
  enabling highlight
  enabling folding
  filetype behaviour
```

**Never run `:TSInstall` or `:TSUpdate` against Nix-owned parsers.** The
`nvim-treesitter` main branch is a full rewrite for Neovim 0.12, is **not
intended for lazy-loading**, and expects parser versions to stay aligned with the
plugin's parser definitions. `lazy-lock.json` pins the plugin commit but does not
by itself define a reproducible parser state; Nix does.

---

## 16. Language Support Matrix

`[nix]` = already in `nix/modules/home/dev.nix`. `[add]` = present in nixpkgs,
must be added.

| Language | LSP | Formatter (conform) | Linter | Debugger | Tests |
| --- | --- | --- | --- | --- | --- |
| PHP / Laravel | `intelephense` [add] primary + `phpactor` [add] bounded | `pint` | `phpstan` (nvim-lint) | Xdebug via `vscode-php-debug` | phpunit / pest (neotest) |
| Blade | `intelephense` | `blade-formatter` | — | — | — |
| Vue / Nuxt | `vue-language-server` [add] + `vtsls` [add] hybrid | `prettier` | `eslint` LSP | `js-debug-adapter` | vitest (neotest) |
| TypeScript / JS | `vtsls` [add] | `prettier` | `eslint` LSP | `js-debug-adapter` | vitest / jest (neotest) |
| Tailwind | `tailwindcss-language-server` [add] | `prettier` | — | — | — |
| Go | `gopls` [nix] | **gopls itself** (`gofumpt = true`) — conform has no `go` entry | `golangci-lint` [nix] via nvim-lint; `gopls staticcheck = false` | `delve` [nix] | `gotestsum` [nix] (neotest-golang) |
| Bash | `bash-language-server` [add] (bundles shellcheck) | `shfmt` [nix] | bash-language-server only | `bashdb` | `bats` [nix] (neotest-bats) |
| Nix | `nixd` [add] | `nixfmt-rfc-style` [nix] | `statix` [nix], `deadnix` [nix] | — | — |
| Python | `basedpyright` [add] | `ruff` [add] | `ruff` LSP only | `debugpy` | pytest (neotest-python) |
| Lua | `lua-language-server` [add] | `stylua` | — | — | — |
| YAML / JSON | `yaml-language-server` | `prettier` | `actionlint` [nix] | — | — |
| Markdown | `marksman` | `prettier` | `markdownlint`, `cspell` | — | — |

The entire Go and shell toolchain is already installed. Roughly ten language
servers plus `ruff` and `bruno` need adding to Nix.

---

## 17. Repository Integration

### 17.1 Ownership

| Concern | Owner | Path | State |
| --- | --- | --- | --- |
| Neovim binary | Nix / Home Manager | `nix/modules/home/dev.nix` | present |
| LSP servers, formatters, linters, debug adapters | Nix / Home Manager | `nix/modules/home/dev.nix` | **add ~12** |
| Tree-sitter plugin, parsers, CLI | Nix / Home Manager | `nix/modules/home/dev.nix` | **add** |
| Bruno GUI | Nix / Home Manager | `nix/modules/home/gui.nix` | **add** |
| Lua configuration | chezmoi | `home/dot_config/nvim-ide/**` -> `~/.config/nvim-ide/` | **new** |
| Plugin lockfile | committed | `home/dot_config/nvim-ide/lazy-lock.json` | **new** |
| Machine-specific overrides | chezmoi template | `.tmpl` + `personal.yaml` (mirrors the VS Code full/minimal split) | **new** |
| **tmux configuration** | chezmoi | `home/dot_config/tmux/tmux.conf` | **new — none exists in this repo** |
| **Ghostty configuration** | chezmoi | `home/dot_config/ghostty/config` | **new — none exists in this repo** |
| Generated keymap reference | repo-docs | `repo-docs/nvim-keymap.md` | **generated from the registry, never hand-written** |
| Tasks | mise | `mise.toml` -> `nvim:check`, `nvim:sync`, `nvim:health`, `nvim:keymap-doc` | **add** |
| Validation | ops | extend `ops/validate-config.sh` with a headless Neovim lint | **extend** |
| Config tests | bats | `tests/bash/nvim-ide-*.bats` | **new** |
| Existing `~/.config/nvim` | untouched | `home/dot_config/nvim/**` | **not modified by this plan** |

### 17.2 NVIM_APPNAME isolation

```bash
NVIM_APPNAME=nvim-ide nvim
```

```text
~/.config/nvim/       current 81-line stub, untouched
~/.config/nvim-ide/   migration candidate
```

`NVIM_APPNAME` isolates configuration, data, state and cache directories.
Cutover is an alias or chezmoi-profile change. **Rollback is stopping use of the
alias.** This plan never instructs deleting `~/.config/nvim` or
`~/.local/share/nvim`.

### 17.3 Proposed file layout

```text
home/dot_config/nvim-ide/
  init.lua
  lazy-lock.json                 # committed

  lua/
    config/
      options.lua                # ported from settings.full.json
      autocmds.lua
      capabilities.lua           # single-owner enforcement (S9)
      health.lua                 # :checkhealth extension

    keymaps/
      registry.lua               # declarative source of truth
      core.lua
      editing.lua
      navigation.lua
      terminal.lua
      plugins.lua
      dispatcher.lua             # Tab / Esc / Ctrl+P (S13)

    lsp/
      init.lua                   # vim.lsp.config() / vim.lsp.enable()
      ownership.lua              # LspAttach provider disabling
      php.lua  web.lua  go.lua  python.lua  nix.lua

    plugins/
      core.lua  editing.lua  git.lua  test.lua
      debug.lua  ai.lua  extras.lua

    tests/
      startup.lua  keymaps.lua  ownership.lua
      formatting.lua  lsp.lua
```

### 17.4 Declarative keymap registry

`lua/keymaps/registry.lua` is the single source of truth. Mappings are never
maintained by hand in both Lua and Markdown.

```lua
{
  id       = "format_document",
  modes    = { "n", "x" },
  lhs      = "<C-A-l>",
  fallback = "<leader>cf",
  group    = "code",
  transport= "extended",
  action   = function() end,
  requires = { "conform" },
  desc     = "Format document or selection",
}
```

Loader contract:

| Rule | Behaviour |
| --- | --- |
| Duplicate `(mode, lhs)` | **Rejected** at load, unless an explicit priority/layer is declared (for example the multicursor cursor-state layer) |
| Class B/C/D entry with no `fallback` | Rejected |
| `requires` plugin absent | Entry skipped, warning recorded |
| Documentation | `repo-docs/nvim-keymap.md` is **generated** from the registry by `mise run nvim:keymap-doc` |

### 17.5 Settings ported from `settings.full.json`

| VS Code setting | Neovim target |
| --- | --- |
| `editor.fontSize: 18` | Terminal / Ghostty owns the font; GUI clients only |
| `editor.fontLigatures: true` | Ghostty / Neovide |
| `editor.tabSize` + 18 language overrides | Per-filetype `vim.bo.tabstop` / `shiftwidth` plus conform |
| `editor.formatOnSave: true` | conform `format_on_save` (sole owner) |
| `files.autoSave: afterDelay` | **Deferred.** See 17.6 |
| `editor.minimap.enabled: true` | Drop, or `satellite.nvim` at Tier 3 |
| `workbench.colorTheme: Dark+` | `darcula-solid.nvim` (open decision S24) |
| `editor.cursorBlinking: smooth` | `guicursor` |
| `editor.rulers` | `colorcolumn` |
| `files.trimTrailingWhitespace` | conform, not a separate autocmd |

### 17.6 Autosave policy

Autosave is **deferred until formatting is proven stable**. Then:

```text
Write on:
  FocusLost
  BufLeave
  optional debounced TextChanged

NEVER use raw CursorHold  (neotest uses CursorHold; coupling autosave to it
                           causes unrelated writes and confusing timing)

Never write:
  unnamed buffers
  readonly buffers
  terminal / help / prompt buffers
  files above the large-file threshold
  buffers with a formatter currently running
```

Format-on-save plus aggressive autosave must not create formatter churn.

---

## 18. Security Boundaries

| Area | Rule |
| --- | --- |
| Project-local `.nvim.lua` | Enabled **only** through Neovim's trust mechanism. View the file before `:trust` |
| Shell execution | Always `vim.system({ "cmd", "arg" })`. **Never** concatenated shell strings |
| Overseer tasks | **Must not auto-run repository tasks on directory entry.** Explicit invocation only |
| AI context exclusions | `.env`, secrets, credentials, private keys, generated databases, and specifically **`home/.chezmoidata/personal.yaml`** and **`home/.chezmoidata/personal.local.yaml`** |
| LSP executables | Resolved from a Nix / PATH allowlist. No auto-download, no `mason.nvim` |
| Project overrides | Reviewed before trusting |
| Bruno environments | Secret values never committed to mappings or config; only `.bru` files without secrets are version-controlled |
| Repo secret policy | Never commit or echo `personal.yaml` / `personal.local.yaml`; only `home/personal.yaml.example` is tracked |
| Clipboard | Do not add clipboard providers that shell out to unvetted binaries |

---

## 19. Acceptance Tests and Performance Targets

### 19.1 Objective gates

Feature-only exit criteria are replaced with executable checks.

| Gate | Test | Pass condition |
| --- | --- | --- |
| Lua syntax | All Lua files parse headlessly | Exit 0 |
| Startup | Cold and warm start with `NVIM_APPNAME=nvim-ide` | No errors, no warnings |
| Mapping uniqueness | Registry loader plus post-plugin map dump | **0** duplicate global or buffer-local `(mode, lhs)` |
| Leader fallback | Every Class B/C/D registry entry | `fallback` present |
| Key transport | `:KeyProbe` for every non-leader chord | Each classified `reliable`/`extended`/`host_reserved`/`unavailable` |
| Capability ownership | `capabilities.lua` assertion on `LspAttach` | Max one primary completion and one diagnostic owner per capability |
| Formatting idempotence | Run the formatter twice | Second run produces no diff |
| Formatting provider | Dump `documentFormattingProvider` per client | `false` for all servers except `gopls` |
| Diagnostics uniqueness | Open fixtures for PHP, Vue, TS, Go, Bash, Python | **0** duplicate messages |
| Tree-sitter | Load every required parser | No query errors; no `:TSInstall` invoked |
| Tests | Nearest / file / suite in representative repositories | All three succeed |
| Debug | Breakpoint, step, inspect, stop | Passes per primary language |
| Security | AI context scan | No `.env`, no `personal*.yaml`, no credentials |
| Trust | Project-local config | Requires explicit `:trust` |
| Rollback | Open `~/.config/nvim` profile | Opens cleanly, migration state unmodified |

### 19.2 Performance targets

| Metric | Target |
| --- | ---: |
| Warm empty startup p50 | <= 100 ms |
| Warm empty startup p95 | <= 180 ms |
| Picker first result, normal repository | <= 150 ms |
| Completion UI response | <= 100 ms |
| Non-PHP format-on-save | <= 500 ms |
| PHP Pint format-on-save | <= 1500 ms |
| Keymap collisions | **0** |
| Duplicate diagnostic producers | **0** |
| Startup errors / warnings | **0** |

---

## 20. Phased Rollout

Vertical slices, not horizontal layers. The v1 "all 12 languages in one phase"
approach is rejected: it hides capability conflicts until the end.

| Phase | Deliverable | Objective exit gate |
| --- | --- | --- |
| **0. Isolation and transport** | `NVIM_APPNAME=nvim-ide`, `:KeyProbe`, GNOME audit, first Ghostty config, first tmux config | Every planned non-leader chord classified A/B/C/D; every B/C/D has a `<leader>` fallback |
| **1. Core editor** | options, registry + loader, which-key, snacks, clipboard, buffers, Esc/Tab dispatchers | **0** mapping collisions; clean startup; `<leader>?` lists everything |
| **2. PHP / Laravel slice** | intelephense, phpactor bounded mode, Pint via conform, PHPStan via nvim-lint, PHPUnit via neotest | One Laravel repository works end to end; no duplicate diagnostics; formatter idempotent |
| **3. Vue / TypeScript slice** | `vue_ls` + `vtsls` hybrid, eslint LSP, Prettier, Vitest | One Vue repository works end to end; **no duplicate completion entries** |
| **4. Editing power** | treesitter text objects, mini.ai/surround/move, multicursor, grug-far, refactoring.nvim | Selection and editing acceptance suite passes, including the 40-line `39j` block edit |
| **5. Git, tests, debug** | gitsigns, lazygit, diffview, neotest adapters, nvim-dap | Xdebug and JS/Go debugger smoke tests pass; hunk stage/unstage in Visual only |
| **6. Secondary languages** | Go, Bash, Nix, Python, Lua, YAML, Markdown | Per-language smoke fixture passes; single diagnostic producer verified per filetype |
| **7. Tasks and AI** | overseer, copilot.lua, sidekick | No `Tab`/`Esc` conflicts; secrets excluded from AI context; no task auto-run |
| **8. Optional extras** | Tier 3 items, notes, sessions, Bruno workflows | Each added only against a recorded need |
| **9. Cutover** | Default alias / chezmoi profile switched | Five working days with no critical fallback to VS Code |

**Do not skip Phase 1's which-key.** At near-zero Vim proficiency it is the
difference between a usable editor and an unusable one.

Keep VS Code installed and working until Phase 9 completes.

---

## 21. Learning Ramp (near-zero -> power user, 6 weeks)

| Week | Focus | Target |
| --- | --- | --- |
| 1 | Modes, `hjkl`, `i/a/o`, `:w`, `dd`, `yy`, `p`, `u` | Survive without arrow keys |
| 2 | Operators + motions: `dw`, `ci"`, `ca(`, `d}`, counts `3dd` | Think in verb + noun |
| 3 | Text objects (mini.ai), `.` repeat, `f`/`t`/`;`/`,` | Stop using Visual mode for everything |
| 4 | **Visual Block** `Ctrl+V`, the `39j $ A; Esc` pattern, macros `qq...q` `@q`, registers | The column-edit superpower |
| 5 | Marks, jumplist `Ctrl+O`/`Ctrl+I`, change list `g;`/`g,`, flash.nvim `s` | Navigate at speed |
| 6 | Native LSP maps `gd`, `Ctrl+]`, `gra`, `gri`, `grn`, `grr`, `grt`, `gO`; optionally enable hardtime.nvim | Use Neovim's own vocabulary, not only the PhpStorm layer |

Practice: built-in `:Tutor`, then `vim-be-good`.

**Anti-pattern guard.** The behaviour described as disliked — appending `;` to
lines one at a time — is exactly what Visual Block and, later, `hardtime.nvim`
and `precognition.nvim` train out. Those two are Tier 3 and are introduced in
week 6, not on day one.

---

## 22. Risks and Rollback

| Risk | Severity | Mitigation |
| --- | --- | --- |
| Key transport not certified before parity is claimed | **High** | Phase 0 `:KeyProbe` gate; no percentage published before it |
| GNOME intercepts `Alt+F2` and possibly `Alt+F1` | **High** | Unbind at GNOME level or relocate to `<leader>cR` / `<leader>er` |
| Ghostty consumes chords before the PTY | **High** | Author a Ghostty config with `unbind` / `unconsumed`; none exists yet |
| tmux drops extended keys | **High** | Author a tmux config with extended-keys passthrough; none exists yet |
| Two formatters or two diagnostic producers | **High** | S9 single-owner matrix enforced by `capabilities.lua` and acceptance tests |
| Two TypeScript completion providers for Vue | **High** | Supported `vue_ls` + `vtsls` hybrid only |
| Tree-sitter parser/plugin skew | Medium | Option A: Nix owns both; no `:TSInstall`/`:TSUpdate` |
| Productivity dip in weeks 1-3 | **High** | Keep VS Code until Phase 9; vertical slices |
| `Shift Shift` not reproducible | Low | `<leader><leader>` canonical; OS remapper emitting `F13` is the only exact option |
| Over-plugging slows startup | Medium | Three tiers; `:Lazy profile`; startup budget in S19.2 |
| Config drift across macOS / Linux / WSL | Medium | chezmoi templates + committed `lazy-lock.json` + `flake.lock` |
| Copilot in Neovim weaker than VS Code agent mode | Medium | Marked **Partial**; sidekick NES plus retained VS Code for large agent refactors |
| Autosave churn against format-on-save | Medium | Autosave deferred; guarded policy in S17.6 |
| Secrets leaking into AI context | **High** | S18 exclusion list including `personal.yaml` / `personal.local.yaml` |
| Devcontainer parity assumed but absent | Medium | Marked **Gap**; open decision in S24 |

### 22.1 Non-destructive rollback

```text
Rollback = stop using the `NVIM_APPNAME=nvim-ide` alias.
```

| Step | Action |
| --- | --- |
| 1 | Remove or stop invoking the shell alias / chezmoi profile that sets `NVIM_APPNAME=nvim-ide` |
| 2 | `nvim` continues to use the untouched `~/.config/nvim` stub |
| 3 | VS Code configuration is untouched throughout; this plan removes nothing |
| 4 | Optionally delete `~/.config/nvim-ide` and `~/.local/share/nvim-ide` — **only** those `-ide` paths |

**Never delete `~/.config/nvim` or `~/.local/share/nvim`.** v1 instructed this;
it is wrong and destructive.

---

## 23. Disposition of `nvim-intellij-nvim-gpt-ver.md`

That document is triaged and reference-only. Its STATUS markers are the binding
record; this section restates them.

### 23.1 Accepted

| Item | Reason |
| --- | --- |
| Four mapping layers (direct IDE / leader / native Vim / terminal) | Clean conceptual model, retained |
| Mode legend | Retained |
| `:lua print(vim.fn.keytrans(vim.fn.getcharstr()))` probe | Adopted as the Phase 0 key-transport test |
| Leader fallback for every capability-dependent chord | Adopted as a hard rule |
| `Shift Shift` -> `<leader><leader>` | Correct; terminals do not emit bare modifiers |
| Mapping both `<C-/>` and `<C-_>` | Many terminals report `Ctrl+/` as `Ctrl+_` |
| Warning against mapping plain `Escape` in terminal mode | Adopted; it breaks LazyGit, shells and debuggers |
| Snacks as the consolidated UI surface | Adopted at Tier 1 |
| Debug and run F-key tables | Adopted essentially verbatim; all Class A |
| Tool-window `Alt+1..7` mapping | Adopted |
| Native-Vim skills list | Adopted into the learning ramp |
| Git hunk operations table | Adopted |
| Projects, tests and AI leader tables | Adopted, with the namespace corrections in S11 |

### 23.2 Accepted with change

| Item | Change |
| --- | --- |
| Headline scores (91/84/72/95/86) | Predate the transport analysis; terminal portability is lower than 72 until Phase 0 certifies it |
| `Ctrl+Alt+Shift+Up/Down` -> resize | Multi-cursor wins; resize moves to `<leader>wH/J/K/L` |
| `Ctrl+D` -> duplicate line | Native half-page down retained; duplicate moves to `<leader>cd` |
| `Ctrl+Alt+G C` / `Shift+C` | Swapped back: `C` = commit, `Shift+C` = commit staged, matching the VS Code source |
| Native LSP maps in section 4 | Corrected to `gra` / `gri` / `grn` / `grr` / `grt` / `gO` |
| `Ctrl+]` / `Ctrl+[` as indent/outdent | Rejected in Normal mode; indent is `>>` (N) and `Tab` (V) |
| Multi-cursor backend | `vim-visual-multi` -> `multicursor.nvim` |
| Replace backend | `nvim-spectre` -> `grug-far.nvim` |
| Folding | `nvim-ufo` -> native `vim.treesitter.foldexpr()` / `vim.lsp.foldexpr()`; ufo to Tier 3 |
| Plugin table | Reorganised into three tiers |
| Formatting backend "Conform/LSP" | conform.nvim only |
| Refactoring backends | PHP extracts route to phpactor; refactoring.nvim has no PHP support |
| `Alt+F2` rename file | GNOME owns it; unbind or relocate to `<leader>cR` |
| Bruno / HTTP namespace | Moved from `<leader>a` to `<leader>h` |
| Insert `Ctrl+S` save | Displaces native signature help; signature help relocates to `<leader>lh` |
| Window focus rationale | The "because `Ctrl+W` is used for syntax selection" justification is rejected; `Ctrl+W` stays the native prefix and focus is `Ctrl+H/J/K/L` |

### 23.3 Rejected

| Item | Reason |
| --- | --- |
| `Ctrl+W` reassigned to expand-selection in Normal mode | The window prefix is load-bearing; expand-selection is Visual `Ctrl+W` plus `<leader>ve` |
| `Ctrl+V` reassigned to paste in Normal mode | Visual Block is the column-edit superpower; paste is Insert and Visual only |
| `<leader>vb` as the Visual Block entry point | Unnecessary; Normal `Ctrl+V` is never remapped |
| `Ctrl+R` reassigned to replace in Normal mode | Redo is load-bearing; replace-in-buffer is `<leader>sR` |
| Window navigation moved wholesale into `<leader>w` as the primary | `Ctrl+H/J/K/L` is the primary; `<leader>w*` is the fallback |
| Its 18-prefix leader hierarchy | Superseded by the 21-prefix hierarchy in S11 |

---

## 24. Open Decisions

| # | Decision | Options | Recommendation |
| --- | --- | --- | --- |
| 1 | Keymap strategy | A (34) / **B (89)** / C (50) / D (28) | **B — mode-scoped layering** |
| 2 | GNOME `Alt+F2` | Unbind at GNOME / relocate rename-file to `<leader>cR` | Relocate; do not fight the desktop |
| 3 | GNOME `Alt+F1` | Verify whether it is claimed; unbind or relocate | Probe in Phase 0 |
| 4 | Terminal | Ghostty only / Ghostty + tmux | Decide before Phase 0; both configs are new files in this repo |
| 5 | `Shift Shift` | `<leader><leader>` only / add an OS remapper emitting `F13` | `<leader><leader>`; add `F13` only if muscle memory demands exactness |
| 6 | Theme | darcula-solid / tokyonight / catppuccin | darcula-solid, matching JetBrains Darcula |
| 7 | Minimap | drop / `satellite.nvim` at Tier 3 | Drop |
| 8 | GUI client | terminal-only / add Neovide at Tier 3 | Terminal-only initially; Neovide does **not** unlock `Shift Shift` |
| 9 | **Devcontainers** | (a) Neovim inside the container — best parity; (b) local Neovim with container tool wrappers — good, more configuration; (c) plain `docker exec` — not parity | **User decision required.** Currently classified **Gap** |
| 10 | Autosave | keep VS Code `afterDelay` behaviour / drop autosave | Defer until formatting is stable, then FocusLost + BufLeave |
| 11 | Insert `Ctrl+V` literal insert | relocate to `Ctrl+Q` / accept the loss | Relocate to `Ctrl+Q` where transported |
| 12 | Keep VS Code | until Phase 7 / until Phase 9 | **Until Phase 9 cutover completes** |
| 13 | Tier 3 promotion policy | ad hoc / recorded need required | Recorded need required |
| 14 | `nvim-ide` cutover mechanism | shell alias / chezmoi profile switch / rename directory | Alias first, chezmoi profile at cutover; never rename over `~/.config/nvim` |

---

## 25. Next Step

Approve Sections 8 (Strategy B), 9 (single-owner matrix), 10 (conflict register)
and 24 (open decisions). The next implementation slice is then **Phase 0:
isolation and transport** — `NVIM_APPNAME=nvim-ide` scaffolding, the `:KeyProbe`
command, the GNOME shortcut audit, and the first Ghostty and tmux configurations.

Nothing will be implemented until that approval is given.
