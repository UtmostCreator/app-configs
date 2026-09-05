# Neovim Cheatsheet — Week 1-2 Daily Driver

Leader is `Space`. CapsLock is remapped to `Esc`. Print this; do not memorise it.

## 1. Survival
| Key | Does |
|---|---|
| `Esc` or `jk` | back to Normal mode (CapsLock is `Esc`) |
| `i` | enter Insert mode before cursor |
| `:w` `:wq` `:q` `:q!` | save, save+quit, quit, quit discarding changes |
| `u` / `Ctrl+R` | undo / redo |
| `.` | repeat last change |

## 2. Modes
| Mode | Enter with | Leave with |
|---|---|---|
| Normal | `Esc` (default mode) | n/a |
| Insert | `i` `a` `o` `A` `I` `O` | `Esc` or `jk` |
| Visual | `v` | `Esc` |
| Visual Line | `V` | `Esc` |
| Visual Block | `Ctrl+V` | `Esc` |
| Command | `:` | `Esc` or `Enter` |

## 3. Move
| Key | Does |
|---|---|
| `h` `j` `k` `l` | left, down, up, right |
| `w` `b` `e` | next word, back word, end of word |
| `0` `^` `$` | line start, first non-blank, line end |
| `gg` `G` `{` `}` | file top, file bottom, paragraph back, paragraph forward |
| `Ctrl+D` `Ctrl+U` `%` `zz` | half page down, half page up, matching bracket, centre line |
| `f{char}` `;` `,` | jump to char on line, repeat, repeat reversed |

## 4. Edit
| Key | Does |
|---|---|
| `x` `J` `~` | delete char, join line below, toggle case of char |
| `dd` `yy` `p` `P` | delete line, yank line, paste after, paste before |
| `o` `O` `A` `I` | open line below, open line above, append at line end, insert at first non-blank |
| `cw` `ciw` | change to word end, change inner word |
| `ci"` `ci(` | change inside quotes, change inside parens |
| `>>` `<<` | indent line, outdent line |

## 5. The grammar
Verbs combine with nouns: `operator` + `motion-or-text-object`. Learn 4 verbs and 5 nouns, get 20 commands.

| Combo | Result |
|---|---|
| `dw` | delete forward to next word |
| `c}` | change to end of paragraph |
| `yip` | yank inner paragraph |
| `vi"` | select text inside the quotes |
| `da(` | delete around parens, brackets included |

## 6. Search and replace
| Key | Does |
|---|---|
| `/` `?` `n` `N` `*` | search fwd, search back, next match, prev match, word under cursor |
| `:%s/old/new/g` | replace all in file |
| `:%s/old/new/gc` | replace all in file, confirm each |

## 7. Code (LSP)
| Key | Does |
|---|---|
| `gd` or `Ctrl+]` | go to definition |
| `grn` | rename symbol — your PhpStorm `Shift+F6` |
| `grr` `gri` | references, implementation |
| `gra` `grt` | code action (quick fix), type definition |
| `K` | hover documentation |
| `gO` | document symbols (outline) |
| `]d` `[d` | next diagnostic, previous diagnostic |

## 8. Files and buffers
| Key | Does |
|---|---|
| `<leader>ff` `<leader>fg` | find file, grep in project |
| `<leader>fr` `<leader><leader>` | recent files, smart find |
| `[b` `]b` `<leader>bd` | previous buffer, next buffer, close buffer |
| `<leader>e` | toggle file explorer |

## 9. Windows
| Key | Does |
|---|---|
| `Ctrl+W v` | split vertically |
| `Ctrl+W s` | split horizontally |
| `Ctrl+W h/j/k/l` | move focus left/down/up/right |
| `Ctrl+W o` `Ctrl+W q` | keep only this window, close this window |

## 10. Multi-line superpower
```
Ctrl+V  39j  $  A;  Esc      -> Visual Block down 40 lines, append ; to each
:%norm A;                    -> run normal-mode `A;` on every line in the file
qq A; Esc j q  then  39@q    -> record macro into q, replay it 39 more times
```

Three ways to append `;` to 40 lines. Counts are off-by-one traps: `39j` selects 40 lines, `40j` would select 41.

## 11. Leader map
| Key | Group | Key | Group |
|---|---|---|---|
| `<leader><leader>` | smart find | `<leader>c` | code |
| `<leader>f` | files | `<leader>b` | buffers |
| `<leader>s` | search/replace | `<leader>e` | explorer |
| `<leader>g` | git | `<leader>r` | run/tasks |
| `<leader>d` | debug | `<leader>h` | HTTP |
| `<leader>t` | tests | `<leader>a` | AI |
| `<leader>x` | diagnostics | `<leader>n` | notes |
| `<leader>u` | UI toggles | `<leader>w` | write |
| `<leader>?` | all keymaps | | |

## 12. Do NOT press
| Key | Why not |
|---|---|
| `Ctrl+S` | freezes the terminal (XOFF). Use `:w`. Press `Ctrl+Q` to unfreeze. |
| `Ctrl+Z` | suspends Neovim to the shell. Type `fg` to return. |
| `Ctrl+C` | does not copy. Use `y` to yank. |
| `Ctrl+V` | does not paste in Normal mode; it is Visual Block. Use `p`. |

## 13. Week-by-week focus
| Week | Focus |
|---|---|
| W1 | Modes and basic edits. Stop using arrow keys. |
| W2 | Operator + motion. Turn hardtime on. |
| W3 | Text objects (`iw` `i"` `ip` `a(`) and the `.` repeat. |
| W4 | Visual Block, macros (`q`), and registers (`"ay`). |
| W5 | Marks (`ma` `'a`), jumplist (`Ctrl+O` `Ctrl+I`), the `[` / `]` family. |
| W6 | LSP defaults end to end, then run `:Tutor` once more. |

## 14. See also
Full reference: `repo-docs/nvim-keymap.md`. Active plan: `repo-docs/nvim-defaults-plan.md`.
