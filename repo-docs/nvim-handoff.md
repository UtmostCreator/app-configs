# Neovim Migration — Session Handoff

Session entry point. Read this file first. It is self-contained: you can start Phase 0 from this
document alone. Cross-reference the other documents only for depth.

---

## 1. TL;DR

1. Goal: migrate the user from VS Code to a from-scratch, kickstart-style Neovim IDE config.
2. State: **nothing is implemented.** Every artifact so far is a planning document.
3. Approach is locked: **Strategy E** — defaults-first, additions only on `<leader>`, `g`, `[`, `]`.
4. Isolation is locked: `NVIM_APPNAME=nvim-ide`, source `home/dot_config/nvim-ide/`. Existing config untouched.
5. Next action: execute **Phase 0** (section 11) — isolation scaffolding only, nothing else.

---

## 2. Session Re-Entry Checklist

Do these in order before you edit anything.

1. Read this file end to end.
2. Run `git status --short` and note the dirty worktree. Unrelated in-flight changes exist; do not fold them into your slice.
3. Confirm whether `home/dot_config/nvim-ide/` exists. If it does, read every file in it and determine how far Phase 0 got before assuming a clean start.
4. Read the sections of `repo-docs/nvim-defaults-plan.md` that cover the current phase. Do not read the whole file.
5. Consult `repo-docs/nvim-keymap.md` only to answer a specific key question. It is 1438 lines; never read it wholesale.
6. Confirm the phase and scope with the user before making the first edit.
7. Respect the approval boundaries in section 9. Ask before any listed action.

---

## 3. Current State Of The World

Verified by direct inspection. Treat as fact; do not re-derive.

| Fact | Detail |
|---|---|
| Implementation status | Nothing implemented. Planning documents only. |
| Existing Neovim config | `home/dot_config/nvim/` — 81 lines total across 4 files |
| `init.lua` | 25 lines, lazy.nvim bootstrap only |
| `lua/plugins/copilot.lua` | 23 lines |
| `lua/plugins/vim-tmux-navigator.lua` | 21 lines |
| `lua/plugins/neotest.lua` | 12 lines, declares neotest with **zero adapters** — cannot run a single test |
| Neovim version | v0.12.4 (LuaJIT 2.1), installed by Nix via `nix/modules/home/dev.nix` |
| tmux | Installed via Nix at `nix/modules/home/cli.nix:34` |
| tmux config | **No chezmoi-managed tmux config file exists** |
| Terminal emulator config | None managed in this repo (no Ghostty, kitty, or wezterm config) |
| Bash test surface | `tests/bash/` contains exactly one test: `detect-os-disks.bats` |
| VS Code config | chezmoi-managed, **must remain untouched** |

### tmux hazard — read this before proposing any tmux change

tmux is actively consumed by repository automation:

| Consumer | Path |
|---|---|
| Project session manager | `ops/projects/tmux-master.sh` |
| Log pane driver | `ops/projects/tmux-logs.sh` |
| SSH session driver | `ops/projects/tmux-ssh.sh` |
| Shared library | `ops/projects/lib.sh` |
| Health check | `ops/projects/health/checks.d/10-tmux.sh` |
| Readiness gate | `ops/readiness.sh` |

Because these scripts depend on the current tmux behavior, adding
`home/dot_config/tmux/tmux.conf` is **not greenfield**. It could break the projects workflow.
Adding a chezmoi-managed tmux config requires explicit user approval (section 9).

### VS Code files that must not be modified

| File | Content |
|---|---|
| `home/.chezmoitemplates/vscode/keybindings.json` | 178 unique positive bindings |
| `home/.chezmoitemplates/vscode/settings.full.json` | 275 keys, 18 language overrides |
| `home/.chezmoitemplates/vscode/settings.minimal.json` | minimal profile |

---

## 4. Document Map And Authority Order

| File | Lines | Role | Authority |
|---|---:|---|---|
| `repo-docs/nvim-handoff.md` | this file | Session entry point | Read first; routes you to the rest |
| `repo-docs/nvim-defaults-plan.md` | 715 | **ACTIVE PLAN**, Strategy E | Authoritative for architecture, phases, ownership, security, tests |
| `repo-docs/nvim-keymap.md` | 1438 | Full VS Code -> Neovim translation, 693 typed rows, groups A-T | Authoritative for keymaps |
| `repo-docs/nvim-cheatsheet.md` | 130 | Printable week 1-2 daily driver | For the human, not the agent |
| `repo-docs/nvim-setup.md` | small | Describes the 81-line stub | **Stale** — update at cutover |

The superseded parity plans and triage drafts were removed after their accepted
decisions were folded into the active plan and keymap reference.

### Conflict rule

Resolve disagreements in this order:

1. Current code and git state
2. `repo-docs/nvim-defaults-plan.md`
3. `repo-docs/nvim-keymap.md`
4. Current repository documentation

---

## 5. Locked Decisions

The user has decided these. Do not re-open them. Do not propose alternatives.

| # | Decision | Detail |
|---|---|---|
| 1 | **Strategy E** — defaults-first plus leader-only additions, scored 92/100 | GOVERNING RULE: never remap a Neovim default. Only add mappings on `<leader>`, or extend the `g` / `[` / `]` families. 32 leader mappings across 16 groups. Leader is `Space`. |
| 2 | Escape ergonomics | CapsLock -> Esc at the OS level, plus `jk` in Insert mode |
| 3 | Clipboard | `set clipboard=unnamedplus` |
| 4 | Save | `:w` or `<leader>w`. **Never bind `Ctrl+S`** — it triggers terminal XOFF freeze |
| 5 | Config origin | Built from scratch, kickstart-style. **NOT LazyVim** |
| 6 | Diagnostics | Use `virtual_lines`. Note `virtual_text` is OFF by default in 0.11 |
| 7 | Multi-cursor | Native Visual Block only at first. Re-evaluate `multicursor.nvim` after 4 weeks |
| 8 | Habit enforcement | `hardtime.nvim` plus `precognition.nvim`, starting week 2 |
| 9 | v3 plan | Kept as reference, marked superseded |
| 10 | Terminal key-protocol, tmux, Ghostty, GNOME work | **DEFERRED** — not a blocker under Strategy E |
| 11 | Isolation | `NVIM_APPNAME=nvim-ide`; config at `home/dot_config/nvim-ide/` -> `~/.config/nvim-ide/`. Existing `~/.config/nvim` untouched. **Rollback = stop using the alias. NEVER delete `~/.config/nvim` or `~/.local/share/nvim`** |
| 12 | Binary management | **No `mason.nvim`** — Nix owns all binaries |

---

## 6. Neovim 0.11 / 0.12 Ground Truth

Verified against the official documentation. **Do not re-verify.** These defaults are the
foundation of Strategy E: they already exist, so you must not shadow them.

### LSP mappings that exist unconditionally

| Key | Action |
|---|---|
| `grn` | Rename |
| `grr` | References |
| `gri` | Implementation |
| `gra` | Code action (Normal and Visual) |
| `grt` | Type definition |
| `grx` | Run codelens |
| `gO` | Document symbol |
| `CTRL-S` (Insert) | Signature help |

### LSP mappings that are buffer-local when a server attaches

| Key | Mechanism |
|---|---|
| `K` | Hover |
| `CTRL-]` | Goto definition, via `'tagfunc'` |
| `gq` | Format, via `'formatexpr'` |
| `v_an` / `v_in` (Visual) | `vim.lsp.buf.selection_range()` fallback — expand and shrink selection |

### Diagnostics

| Item | Behavior |
|---|---|
| `]d` / `[d` | Next and previous diagnostic; accept a count |
| `]D` / `[D` | First and last diagnostic in buffer |
| `virtual_text` | **DISABLED by default in 0.11** |
| `virtual_lines` | Handler exists; this is what the config enables |

### unimpaired-style defaults new in 0.11

`[q` `]q` `[Q` `]Q` — quickfix
`[l` `]l` `[L` `]L` — location list
`[t` `]t` `[T` `]T` — tags
`[a` `]a` `[A` `]A` — args
`[b` `]b` `[B` `]B` — buffers
`[<Space>` `]<Space>` — blank lines
`[[` `]]` — sections

### Other built-ins

| Feature | Detail |
|---|---|
| Snippets | `Tab` and `S-Tab` jump when a snippet is active |
| Commenting | Built in since 0.10: `gcc`, `gc{motion}`, `gbc` |
| `gx` | `vim.ui.open()` |
| Folding | Lua ftplugin sets `foldexpr` to treesitter; `vim.lsp.foldexpr()` exists |
| LSP API | **`vim.lsp.config()` / `vim.lsp.enable()`**. `require('lspconfig').setup()` is DEPRECATED |
| LSP commands | `:lsp enable`, `:lsp disable`, `:lsp restart`, `:lsp stop` |
| Terminal | Experimental Kitty keyboard protocol support (disambiguate-escape-codes only) |

---

## 7. Measured Facts

Measured from the user's actual VS Code keymap. **Do not recompute.**

| Metric | Value |
|---|---|
| Unique positive bindings | 178 |
| Semantically non-conflicting with Vim | 157 (88.2%) |
| Conflicting with Vim | 21 |
| — of which critical | 11 |
| — of which high | 10 |
| Bindings needing the Kitty keyboard protocol | 48 (27%) — **irrelevant under Strategy E** |
| Keys double-bound in source | 11, disambiguated by VS Code `when` clauses |

### Strategy E translation outcome

| Target | Count |
|---|---:|
| Native | 487 |
| Native-opt | 53 |
| Leader | 22 |
| Plugin | 129 |
| None | 2 |

---

## 8. Repository Ownership Rules

Each tool owns exactly one layer. Never cross the boundary.

| Owner | Scope | Location |
|---|---|---|
| Nix | All binaries | `nix/modules/home/dev.nix`, `nix/modules/home/cli.nix`, `nix/modules/home/gui.nix` |
| Nix | Treesitter — plugin, parser grammars, and the tree-sitter CLI | `nix/modules/home/dev.nix` |
| chezmoi | Dotfiles | `home/dot_config/nvim-ide/` -> `~/.config/nvim-ide/` |
| mise | Tasks | `mise.toml` |
| `ops/*.sh` | Install, update, cleanup, validation | `ops/` |

### Currently in Nix

`nix/modules/home/dev.nix` — neovim, gopls, delve, golangci-lint, gofumpt, gotools, govulncheck,
gotestsum, php84, composer, nodejs_22, pnpm, lazygit, gh, delta, difftastic, ast-grep, semgrep,
shellcheck, shfmt, actionlint, bats, nixfmt-rfc-style, statix, deadnix, opencode, claude-code.

`nix/modules/home/cli.nix` — tmux and other CLI tools.

`nix/modules/home/gui.nix` — GUI applications. Bruno goes here.

### LSPs still to ADD to Nix

All confirmed present in nixpkgs.

| Package | Purpose |
|---|---|
| `intelephense` | PHP — primary |
| `phpactor` | PHP — code actions only |
| `vue-language-server` | Vue |
| `vtsls` | TypeScript and JavaScript |
| `tailwindcss-language-server` | Tailwind |
| `bash-language-server` | Bash |
| `nixd` | Nix |
| `basedpyright` | Python |
| `ruff` | Python lint and format |
| `lua-language-server` | Lua |
| `marksman` | Markdown |
| `yaml-language-server` | YAML |
| `bruno` 3.4.2 | API client -> `nix/modules/home/gui.nix` |

### Hard rules

1. **Never run `:TSInstall` or `:TSUpdate`.** Nix owns treesitter parsers.
2. **Never add `mason.nvim`.** Nix owns all binaries.
3. Never edit dotfiles in `~/` directly; edit the chezmoi source under `home/`.

### Protected — never commit or echo

| Path |
|---|
| `home/.chezmoidata/personal.yaml` |
| `home/.chezmoidata/personal.local.yaml` |
| `nix/flake.lock` |

---

## 9. Approval Boundaries

Stop and ask the user before doing any of the following. No exceptions.

| Action | Why |
|---|---|
| Anything touching secrets | Security boundary |
| Any destructive change | Irreversible |
| `ops/install.sh --apply` | Mutates the live system |
| `ops/system-setup.sh --apply` | Mutates the live system |
| `ops/uninstall.sh --apply` | Removes installed state |
| NixOS system layer changes | System-wide blast radius |
| Deleting `~/.config/nvim` | Destroys the rollback path |
| Deleting `~/.local/share/nvim` | Destroys the rollback path |
| Adding a chezmoi-managed tmux config | Would affect `ops/projects/tmux-*.sh` and the projects workflow |

---

## 10. Known Hazards

| Hazard | Symptom | Fix |
|---|---|---|
| `Ctrl+S` pressed in a terminal | Terminal freezes; Neovim appears hung | Press `Ctrl+Q` to recover. Use `:w` or `<leader>w`. Never bind `Ctrl+S` |
| `Ctrl+Z` pressed | Neovim vanishes to the shell; looks like a crash | Type `fg` and press Enter |
| `virtual_text` off by default in 0.11 | LSP looks broken — no inline errors | Enable the `virtual_lines` handler |
| Remapping `Ctrl+]` | Breaks native goto-definition provided by `'tagfunc'` | Never remap it |
| Using `refactoring.nvim` for PHP | No PHP support at all; extracts silently unavailable | Route PHP extracts to phpactor |
| intelephense and phpactor as co-equal LSPs | Duplicate hover, goto, and rename results | intelephense is primary; bound phpactor to code actions only |
| eslint LSP plus nvim-lint eslint | Every JS error reported twice | Pick one. Use the eslint LSP |
| nvim-lint shellcheck alongside bash-language-server | Duplicate shell diagnostics — bash-language-server bundles shellcheck | Do not register nvim-lint shellcheck |
| conform with a `go` entry | Fights gopls, which owns Go formatting via `gofumpt=true` | conform must have NO `go` entry |
| Autosave on raw `CursorHold` | Collides with neotest, which also uses `CursorHold` | Trigger autosave on `FocusLost` and `BufLeave` |
| Adding a tmux config | Breaks `ops/projects/tmux-*.sh` session and log automation | Requires user approval; deferred under decision 10 |

---

## 11. Phase 0 — The Next Slice

This is exactly what the next session should do. Nothing more.

**Scope: isolation scaffolding only.** No LSP. No plugins beyond the plugin manager. No keymaps
beyond declaring the leader key.

### Steps

**Step 1 — Create `home/dot_config/nvim-ide/init.lua`.**

Set, at minimum:

| Setting | Value |
|---|---|
| `mapleader` / `maplocalleader` | `Space` — set before lazy.nvim bootstrap |
| `clipboard` | `unnamedplus` |
| `jk` in Insert mode | Maps to `Esc` |
| `number` | on |
| `relativenumber` | on |
| `expandtab` | on |
| `shiftwidth` | Match the repository `.editorconfig` |
| `undofile` | on |
| `ignorecase` + `smartcase` | on |
| `signcolumn` | `yes` |
| `updatetime` | lowered from the 4000ms default |
| `termguicolors` | on |
| `splitright` + `splitbelow` | on |
| `scrolloff` | non-zero |

**Step 2 — Bootstrap lazy.nvim.** Copy the pattern already proven in
`home/dot_config/nvim/init.lua`. Do not invent a new bootstrap.

**Step 3 — Add `which-key.nvim` and nothing else.** No other plugin in Phase 0.

**Step 4 — Add a shell alias or function** for `NVIM_APPNAME=nvim-ide nvim`. Suggested name: `nv`.
Note that fish is the login shell on this repository's hosts, so the alias belongs in the fish
configuration, not `.bashrc`.

**Step 5 — CapsLock -> Esc at the OS level.** This is a **user action** and requires their
confirmation before you run it. On GNOME:

`gsettings set org.gnome.desktop.input-sources xkb-options "['caps:escape']"`

**Step 6 — Add two mise tasks** to `mise.toml`: `nvim:health` and `nvim:keymap-audit`.

### Exit gate — objective, all must pass

| Gate | Check |
|---|---|
| Health is clean | `NVIM_APPNAME=nvim-ide nvim --headless "+checkhealth" +qa` produces zero ERROR lines |
| which-key works | `<leader>?` lists keymaps |
| Startup is fast | p50 startup under 100ms |
| Isolation holds | `~/.config/nvim` provably untouched |
| Repo stays green | `mise run repo:check` passes |

### Explicitly NOT in Phase 0

LSP. Treesitter. Completion. Formatters. Git integration. Test runners. Debug adapters. AI plugins.
If you find yourself adding any of these, you have left the slice.

---

## 12. Full Phase Roadmap

Summary only. Read the matching section of `repo-docs/nvim-defaults-plan.md` for detail, gates,
and per-plugin decisions before starting any phase.

| Phase | Name | Scope summary | Detail |
|---|---|---|---|
| 0 | Isolation scaffolding | `NVIM_APPNAME=nvim-ide`, options, leader, lazy.nvim, which-key, alias, mise tasks | Section 11 of this file |
| 1 | Navigation and editing core | Fuzzy find, file tree, treesitter (Nix-provided), core leader groups | `nvim-defaults-plan.md` |
| 2 | LSP foundation | `vim.lsp.config()` / `vim.lsp.enable()`, diagnostics via `virtual_lines`, completion | `nvim-defaults-plan.md` |
| 3 | Formatting and linting | conform and nvim-lint, with the duplication rules from section 10 | `nvim-defaults-plan.md` |
| 4 | Git integration | gitsigns, lazygit, diffview | `nvim-defaults-plan.md` |
| 5 | PHP and Laravel | intelephense primary, phpactor for code actions, neotest adapter | `nvim-defaults-plan.md` |
| 6 | JS, TS, Vue, Nuxt | vtsls, vue-language-server, tailwindcss-language-server | `nvim-defaults-plan.md` |
| 7 | Testing | neotest with real adapters — replaces the zero-adapter stub | `nvim-defaults-plan.md` |
| 8 | Debugging | nvim-dap, delve for Go, xdebug for PHP | `nvim-defaults-plan.md` |
| 9 | AI and habit tooling | copilot, opencode, `hardtime.nvim`, `precognition.nvim` | `nvim-defaults-plan.md` |
| 10 | Cutover | Update `repo-docs/nvim-setup.md`, retire the stub, decide VS Code removal | `nvim-defaults-plan.md` |

Do not start a phase before the previous phase's exit gate has objectively passed.

---

## 13. Verification Commands

Repository-standard checks. One per line, copy-paste ready.

bash ops/validate-config.sh
mise run repo:check
mise run test:bash
mise run lint:shell
mise run nix:check
mise run sync
mise run sync:apply
chezmoi diff

Notes:

1. `mise run sync` is a **preview**. It does not modify the home directory.
2. `mise run sync:apply` snapshots `~` before applying.
3. `chezmoi diff` shows exactly what would change in `~`. Run it before any apply.
4. `tests/bash/` currently contains only `detect-os-disks.bats`. Any Neovim test is new surface.
5. Start with the narrowest check and escalate only if it fails.

---

## 14. Open Questions For The User

Unresolved. Raise these when the relevant phase approaches; do not decide them unilaterally.

| # | Question | Options | Blocks |
|---|---|---|---|
| 1 | Devcontainers and Remote Containers | (a) Neovim inside the container; (b) local Neovim with container tool wrappers; (c) plain `docker exec` | Classified as a Gap; needs its own decision |
| 2 | Validation targets for Phases 5 and 6 | Confirm which real Laravel repository and which real Nuxt repository to validate against | Phase 5 and Phase 6 exit gates |
| 3 | Self-assessed gates | Four Phase 2 and learning-ramp gates have no automated enforcement. Accept as self-assessed, or reformulate objectively? | Phase 2 sign-off |
| 4 | Theme | `darcula-solid` to match JetBrains Darcula, vs `tokyonight`, vs `catppuccin` | Cosmetic; decide by Phase 1 |
| 5 | chezmoi-managed tmux and Ghostty config | Would unlock the remaining IDE-style chords, but risks the `ops/projects/tmux-*.sh` workflow | Deferred by locked decision 10 |
| 6 | Cutover timing | How long to keep VS Code installed in parallel | Phase 10 |

---

## 15. Change Log

| Date | Change | Implementation status |
|---|---|---|
| 2026-07-25 | Planning documents authored; Strategy E locked; this handoff created | Nothing implemented |
