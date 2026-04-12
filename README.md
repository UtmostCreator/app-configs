# app-configs (macOS)

Repository of **opinionated development configuration** for macOS, focused on a consistent experience across editors, formatters, PHP tooling, and keyboard muscle-memory (Windows → macOS).

Opinionated, reusable configuration for a consistent development experience on macOS: editor defaults, formatting/linting, PHP tooling (Herd + Xdebug), VS Code workflow, and Windows-like keyboard ergonomics (Karabiner).

---

## Required folder structure

Place the files in this repository using the following layout (paths are relative to repo root):

Basic requirements:

- ⚠️ with existing config workspace and user settings you would be reuiqred to have some files or you must disable `requireConfig` flag

```
.
├── pint.json
├── .gitattributes
├── .editorconfig
├── .stylelint.config.js
├── .stylelintignore
├── .prettierrc.json
├── .eslintrc.json
├── .stylelintrc.json
└── .vscode
    ├── settings.json
    └── launch.json
```

If pint not install you will see:

```
["INFO" - 11:26:21] Extension Name: open-southeners.laravel-pint.
["INFO" - 11:26:21] Extension Version: 1.3.0.
["ERROR" - 11:26:22] Executable not readable or lacks permissions for Laravel Pint.
```

We need to install it to have executable to format our code:

```
composer require laravel/pint --dev
```

Current repo structure

```text
.
├── .editorconfig
├── .eslintrc.json
├── .gitignore
├── .prettierrc.json
├── .stylelintrc.json
├── README.md
├── php/                          # PHP runtime config + code style
│   ├── php.ini
│   └── pint.json
├── shell/                        # zsh env + Starship prompt (coupled)
│   ├── .zshrc
│   └── starship.toml
├── tools/                        # standalone app configs
│   ├── ghostty/
│   │   └── config
│   ├── karabiner/
│   │   └── karabiner.json
│   └── nvim/
│       ├── init.lua
│       └── lua/
│           └── plugins/
│               └── vim-tmux-navigator.lua
├── vscode/                       # VS Code settings & keybindings
│   ├── keybindings.json
│   ├── launch.json
│   ├── workspace-example.json    # full project-specific example
│   ├── workspace-template.json   # minimal shareable baseline
│   └── user/
│       ├── settings.json         # full user settings
│       └── settings.minimal.json # minimal shareable subset
└── docs/
    ├── keyboard.md               # Karabiner Windows→macOS mapping
    ├── nvim-setup.md
    ├── shell-setup.md
    └── vscode-extensions.md
```

## Copilot workflow (hybrid)

Use VS Code Copilot as the primary interface and Copilot CLI for shell-heavy/background tasks.

- Setup and invocation guide: `docs/copilot-workflow.md`
- Critical gap audit and priorities: `docs/copilot-critical-audit.md`

## Scope

- **Editor defaults** via `.editorconfig`
- **JS/TS/Vue formatting** via Prettier + ESLint
- **PHP code style** via Laravel Pint (custom ruleset)
- **PHP runtime/dev debugging** via Herd PHP 8.3 + Xdebug
- **VS Code setup** (workspace + user settings) + extension list
- **Karabiner-Elements** profile documentation (Windows-like shortcuts)

---

## Repository layout

### Editor / formatting

- [`.editorconfig`](./.editorconfig)
  Cross-editor defaults (LF, whitespace trimming, final newline, per-language indentation).

- [`.prettierrc.json`](./.prettierrc.json)
  Prettier configuration (semi, single quotes, 100 print width, LF).

- [`.eslintrc.json`](./.eslintrc.json)
  ESLint configuration (Vue 3 + TypeScript + Prettier integration).

### PHP

- [`config/pint/pint.json`](./config/pint/pint.json)
  Laravel Pint ruleset:
  - PSR-12 baseline
  - Import ordering (class/function/const), single import per statement
  - Spacing rules, trailing commas for multiline
  - Strict class member ordering (sorted + grouped)

- [`config/php/php.ini`](./config/php/php.ini)
  Herd PHP 8.3 oriented `php.ini` example including:
  - CA bundle paths for curl/openssl
  - memory limits and upload sizes
  - Xdebug settings (port 9003)

  **Note:** This file includes **absolute paths** with `USERNAME`. You must replace `USERNAME` with your macOS username and ensure paths match your Herd installation.

### VS Code

- [`.vscode/settings.json`](./.vscode/settings.json)
  Repo/workspace settings (project-level). Contains SQLTools example connection and editor/UI preferences.

- [`.vscode/launch.json`](./.vscode/launch.json)
  Xdebug launch configurations (Herd PHP 8.3, port 9003).

- [`.vscode/keybindings.json`](./.vscode/keybindings.json)
  Currently empty placeholder (add repo-specific bindings if required).

- [`.vscode/userSettings/settings.json`](./.vscode/userSettings/settings.json)
  **User-level** VS Code settings template intended to be copied to:
  `~/Library/Application Support/Code/User/settings.json`

  This file defines:
  - Stable formatting strategy (Prettier global, Pint for PHP, Blade Formatter for Blade)
  - Explicit lint fixes on save (to avoid random slowdowns)
  - Tailwind/Blade/Vue language associations
  - Performance exclusions (vendor/node_modules/storage/etc.)

### Karabiner

- [`docs/karabiner.md`](./docs/karabiner.md)
  Human-readable explanation of the Windows → macOS “muscle memory” profile (what each mapping does, plus exclusions for terminals/IDEs).

- [`tools/karabiner/karabiner.json`](./tools/karabiner/karabiner.json)
  Placeholder location for the actual Karabiner profile JSON (currently empty in this snapshot).

### Documentation

- [`docs/vscode-extensions.md`](./docs/vscode-extensions.md)
  VS Code extensions list with `code --install-extension ...` commands.

### Utilities

- [`all_in_one.sh`](./all_in_one.sh)
  Utility script to produce a single `combined_output.txt` containing all repo files (pruning common ignored directories). Useful for audits/reviews.

---

## Quick start

### 1) EditorConfig (recommended)

Most editors pick this up automatically. If not, enable EditorConfig support in your IDE and keep `.editorconfig` at repo root.

### 2) VS Code

#### Workspace settings

Open the repository in VS Code. The workspace settings in `.vscode/settings.json` will apply automatically.

#### User settings (optional but recommended)

Copy the template into your user settings file:

1. Open VS Code → Command Palette → **Preferences: Open User Settings (JSON)**
2. Replace or merge content from:
   - `./.vscode/userSettings/settings.json`

**Important:** This template disables some built-in formatters and routes formatting to:

- Prettier for web languages
- Pint for PHP
- Blade Formatter for Blade

#### Install extensions

Use the list in:

- `./docs/vscode-extensions.md`

Example:

```bash
code --install-extension esbenp.prettier-vscode
code --install-extension dbaeumer.vscode-eslint
code --install-extension open-southeners.laravel-pint
code --install-extension xdebug.php-debug
```
