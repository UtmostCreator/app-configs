# app-configs
all app configs for macos


## Repository configuration files

This repository includes a set of editor, formatter, linter, and tooling configuration files to keep development consistent across machines and contributors.

### Core editor & formatting

- [`.editorconfig`](./.editorconfig)  
  Defines cross-editor defaults (indentation, newline style, charset, trimming, final newline) so different IDEs/editors produce consistent files.

- [`.prettierrc.json`](./.prettierrc.json)  
  Prettier configuration (opinionated code formatting) to ensure consistent formatting for supported file types.

- [`.eslintrc.json`](./.eslintrc.json)  
  ESLint configuration for JavaScript/TypeScript (rules, environments, parser options, plugins). Used to catch bugs and enforce style beyond formatting.

### Documentation

- [`README.md`](./README.md)  
  Entry-point documentation for the project: purpose, setup, usage, scripts, conventions, and contribution notes.

- [`vscode-extensions.md`](./vscode-extensions.md)  
  Recommended VS Code extensions for this repo (typically to align linting, formatting, testing, and language support across the team).

### VS Code workspace configuration

> These files typically live under `.vscode/` in many repos, but are linked here as they exist in this repository’s root.

- [`settings.json`](./settings.json)  
  VS Code workspace settings (format-on-save, default formatter, language-specific overrides, path mappings, etc.) to standardize the editor experience.

- [`keybindings.json`](./keybindings.json)  
  VS Code keyboard shortcut customizations for productivity and consistent workflows.

- [`launch.json`](./launch.json)  
  VS Code debug configurations (how to run/debug the app, attach to processes, environment variables, and debug adapters).

### System / OS-level tooling

- [`karabiner.json`](./karabiner.json)  
  Karabiner-Elements configuration (macOS keyboard remapping and complex modifications). Useful for consistent key behavior across environments.

### Language/runtime configuration

- [`php.ini`](./php.ini)  
  PHP runtime configuration (error reporting, memory limits, extensions, timezone, and other INI directives) for local/dev parity.

### PHP code style tooling

- [`pint.json`](./pint.json)  
  Laravel Pint configuration (PHP code style fixer) to enforce consistent PHP formatting rules.

