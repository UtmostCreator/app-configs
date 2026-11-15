# ADR-0008: Git editor per host profile
Status: decided (not yet implemented; T-0047 task S3-4) · Date: 2026-11-15 · Sources: T-0047 ticket (Decision) and plan, `home/dot_gitconfig.tmpl`

## Decision
`core.editor` is `nvim` on the wsl and linux-cli profiles and `code --wait` on macOS and linux-desktop, set as a template value in `home/dot_gitconfig.tmpl`. `GIT_EDITOR` still overrides it.

## Why
- `git commit` must work on hosts without VS Code, such as WSL where VS Code is not in Milestone 1.
- A template value is enough; no wrapper to maintain.
- Behaviour on macOS and the desktop does not change (the plan checks `core.editor` stays `code --wait` there).

## Strong alternatives
| Option | Why it lost |
|--------|-------------|
| `code --wait` everywhere (today) | Breaks `git commit` on hosts without VS Code. |
| A wrapper or fallback script | Unneeded: a template value suffices. |

## Discarded
None recorded.

## Consequences
- Answers the earlier rejection in T-0037 (VS Code on WSL); VS Code on Windows is Milestone 2.
- Needs neovim declared on those hosts (it is declared in `nix/modules/home/dev.nix`).
- Revisit when VS Code on WSL or Windows is adopted.
