# Neovim Plan - v2 Correction Round

> **TRIAGE COMPLETE - REFERENCE ONLY.**
> Every item in this document has been adjudicated and folded into
> `repo-docs/nvim-migration-plan.md` (v3), which is the single source of truth.
> Do not implement from this file. Superseded by v3.
> Triaged: 2026-07-25.

I could not write the corrected plan to disk — I have to report that as a failure and deliver the correction here instead. Details at the end.

Your criticism is correct. Checking it also surfaced a **second defect of equal severity that I had missed entirely**.

## Defect 1 — Duplicate ownership (yours, confirmed)

I audited my own v1 and found **28** instances. The worst are not stylistic, they're behavioral:

| ID  | Duplicate                                                                                | Symptom                                                         |
| --- | ---------------------------------------------------------------------------------------- | --------------------------------------------------------------- |
| D6  | eslint LSP **+** `nvim-lint` eslint                                                      | **every JS error rendered twice**                               |
| D7  | `bash-language-server` (bundles shellcheck) **+** `nvim-lint` shellcheck                 | **every shell warning twice**                                   |
| D8  | ruff LSP **+** `nvim-lint` ruff                                                          | duplicate Python diagnostics                                    |
| D1  | `conform.nvim` **+** LSP `documentFormattingProvider`                                    | competing edits on save, cursor jumps                           |
| D2  | prettier **+** `eslint --fix`                                                            | file formatted twice, oscillating diffs                         |
| D3  | conform `gofumpt` **+** gopls `gofumpt:true`                                             | double format                                                   |
| D10 | intelephense **+** phpactor **co-equal** (my v1 Decision 5 literally recommended "both") | duplicate hover/goto/rename, ambiguous rename                   |
| D11 | vue-ls **+** vtsls both doing TS in `.vue`                                               | duplicate diagnostics                                           |
| D12 | `Tab` bound to blink.cmp **+** copilot.lua **+** sidekick NES                            | key does the wrong thing unpredictably                          |
| D14 | `snacks.explorer` **+** `oil.nvim` **+** `snacks.rename`                                 | LSP `willRenameFiles` fires twice or not at all → stale imports |
| D21 | `files.autoSave: afterDelay` **+** `format_on_save`                                      | **reformats mid-typing, moves your cursor every few seconds**   |
| D22 | tmux-navigator `Ctrl+hjkl` **+** my `Ctrl+Alt+hjkl`                                      | two pane-focus owners                                           |

Two of these I should flag as outright errors, not just duplication:

- **`refactoring.nvim` does not support PHP.** My v1 assigned `Ctrl+Alt+V/M/C/N` (extract variable/method/constant/inline) to it generically. In PHP those keys would have silently done nothing. PHP extracts must route to `phpactor`.
- **D21 is a productivity bug, not a config wart.** Autosave-on-delay plus format-on-save means the formatter runs while you're mid-expression.

## Defect 2 — Key transport was never measured (I missed this)

My v1 headline — _"88.2% of your keymap ports over untouched"_ — was measured on **one axis only**: semantic collision with Vim. I never checked whether the terminal can physically deliver the keys.

Measured now:

| Class                                               |              Count |
| --------------------------------------------------- | -----------------: |
| `ctrl+shift+<key>`                                  |             **35** |
| `ctrl+enter`, `ctrl+alt+enter`, `shift+enter`       |                  5 |
| `ctrl+backspace`, `ctrl+delete`                     |                  4 |
| `ctrl+numpad±` (+shift)                             |                  4 |
| `ctrl+[` — **is literally Escape**                  |                  1 |
| `ctrl+/` — terminals send `Ctrl+_`                  |                  1 |
| **Total requiring Kitty keyboard protocol (CSI-u)** | **48 / 178 = 27%** |

And the enabling infrastructure **does not exist in your repo**:

```
tmux config in repo:      NONE
ghostty config in repo:   NONE
```

The only tmux-related file is `home/dot_config/nvim/lua/plugins/vim-tmux-navigator.lua` — configured on the Neovim side while tmux itself is unmanaged. Without `set -s extended-keys on`, all 48 collapse onto their unshifted equivalents.

**Corrected headline:**

| Axis                                  | Result              |
| ------------------------------------- | ------------------- |
| Semantically non-conflicting with Vim | 157/178 = 88.2%     |
| **Actually deliverable today**        | **130/178 = 73.0%** |
| Blocked on terminal protocol work     | 48/178 = 27.0%      |

This adds a **Phase 0** that v1 didn't have. v1 would have failed on 27% of bindings at first keystroke.

## Defect 3 — I propagated 11 collisions from your own config

Your `keybindings.json` double-binds these, resolved by VS Code `when` clauses. Neovim has no `when`:

| Key                      | Competing commands                                     | Resolution                                          |
| ------------------------ | ------------------------------------------------------ | --------------------------------------------------- |
| `ctrl+alt+l`             | formatDocument · formatSelection · **focusRightGroup** | format wins; pane focus owned solely by `Ctrl+hjkl` |
| `ctrl+alt+j`             | selectHighlights · **focusBelowGroup**                 | selectHighlights wins                               |
| `ctrl+enter`             | insertLineAfter · **git.stageSelectedRanges**          | insertLineAfter; stage → `<leader>gs`               |
| `ctrl+alt+enter`         | insertLineBefore · **git.unstageSelectedRanges**       | insertLineBefore; unstage → `<leader>gu`            |
| `ctrl+d`                 | copyLinesDown · **terminal.sendSequence**              | Terminal mode = EOF passthrough                     |
| `ctrl+shift+u`           | transformToLowercase · **transformToUppercase**        | single `g~` toggle (yours was already redundant)    |
| `shift+f6`               | LSP rename · **renameFile**                            | symbol rename; file rename = `Alt+F2` only          |
| `ctrl+alt+shift+up/down` | insertCursorAbove/Below · **resize view**              | multi-cursor wins; resize → `<leader>w`             |
| `alt+shift+up/down`      | moveLines · **prev/nextChange**                        | moveLines wins; hunks → `[c` `]c`                   |

## The fix — Single-Owner Responsibility Matrix

Exactly one owner per concern; column 3 is **mandatory config**, not advice.

**Formatting — sole owner `conform.nvim`:**

| Filetype                   | Formatter             | Must be disabled                                                            |
| -------------------------- | --------------------- | --------------------------------------------------------------------------- |
| php                        | `pint`                | `intelephense.format.enable=false`; phpactor format off                     |
| js/ts/vue/css/json/yaml/md | `prettier`            | **eslint `format=false`, never `--fix` on save**; vtsls + vue-ls format off |
| **go**                     | **`gopls` (gofumpt)** | **conform has NO go entry** — the one LSP exception                         |
| nix                        | `nixfmt-rfc-style`    | nixd format off                                                             |
| python                     | `ruff_format`         | basedpyright never formats                                                  |

Global rule: on `LspAttach`, set `documentFormattingProvider = false` for every server **except gopls**; conform `lsp_format = "never"`.

**Diagnostics — one source per (filetype, concern):**

| Filetype           | Sole owner                        | Must NOT also run                       |
| ------------------ | --------------------------------- | --------------------------------------- |
| js/ts/vue lint     | eslint LSP                        | nvim-lint eslint **removed**            |
| sh/bash            | bash-language-server              | nvim-lint shellcheck **removed**        |
| python lint+format | ruff LSP (one server, both roles) | nvim-lint ruff **removed**              |
| go lint            | golangci-lint                     | `gopls staticcheck=false`               |
| php intel          | intelephense                      | phpactor diagnostics off                |
| php static         | phpstan                           | intelephense deep analysis off          |
| spelling           | cspell                            | **builtin `spell` off in code buffers** |

**PHP — primary/secondary, never co-equal:** intelephense owns completion/hover/goto/refs/rename/diagnostics. phpactor is stripped to **code actions only**, and owns all extract refactors.

**`Tab` — one `expr` dispatcher:** `sidekick NES pending` → `blink menu visible` → `snippet jump` → literal Tab. copilot.lua becomes a **blink source** (`suggestion.enabled=false`, `panel.enabled=false`).

**Dropped from v1 as redundant:** `glance.nvim` (picker already does peek), `snacks.rename` (oil owns file mutation), any `Comment.nvim` (builtin `gc`).

## The fix — objective acceptance tests

Replacing my v1 feature checklists. Your repo already uses bats + `mise run test:bash`:

| ID  | Assertion                                                                    | Gates phase |
| --- | ---------------------------------------------------------------------------- | ----------- |
| T1  | **zero duplicate `(mode, lhs)` keymap pairs**                                | 1           |
| T2  | every protocol-dependent binding has a working `<leader>` alias              | 1           |
| T3  | `--startuptime` median **< 150 ms** over 10 runs                             | 1           |
| T4  | `:checkhealth` yields **zero ERROR** lines                                   | 1           |
| T5  | **CSI-u active inside AND outside tmux, per host**                           | **0**       |
| T6  | every attached LSP has `documentFormattingProvider == false` except gopls    | 4           |
| T7  | format fixture twice → **byte-identical**                                    | 4           |
| T8  | conform output **== `pint`/`prettier` CLI** output on same fixture           | 4           |
| T9  | fixture with one eslint error → **exactly 1 diagnostic**, `source=="eslint"` | 3           |
| T10 | per-filetype fixture → **exact** expected LSP client set, no extras          | 3           |
| T11 | `mason` absent from `lazy-lock.json`                                         | 1           |
| T13 | fixture test file claimed by **exactly one** neotest adapter                 | 7           |

T1, T6, T9, T13 are the automated guards against the duplicate-ownership class. T5 guards the transport blocker.

**Revised phase order:** Phase 0 (terminal + tmux, gated on T5) now precedes Phase 1 — the keymap is unverifiable until transport is proven.

## Failures to flag

- `python3 - <<'PY'` → **denied by policy** (python3 not in allowlist). Worked around using `mcp_Grep`; the double-bound-key analysis is therefore derived from the earlier full 178-binding dump rather than freshly recomputed. Counts for `ctrl+shift+*` (35) and the 15 others **are** freshly measured.
- Multi-command bash (`for` loops, `&&` chains, `>` redirect) → **denied**.
- `tee … <<'EOF'` heredoc → **denied**. Confirmed with a minimal probe.
- `write` and `edit` tools → **no longer available** in my toolset.
- **Net result: `repo-docs/nvim-migration-plan.md` still contains v1, which is now known-defective.** The v2 correction exists only in this message.

Two ways forward — your call:

1. Restore write access (or paste the corrections in yourself) and I'll rewrite the file as v2.
2. I keep iterating in chat and you apply it at the end.

Either way, I'd flag that **Decision 2 is now the important one**: do you accept the Phase 0 tmux + Ghostty prerequisite? If you don't, 27% of your PhpStorm keymap can never fire, and the plan should be rebuilt `<leader>`-first instead of parity-first.
