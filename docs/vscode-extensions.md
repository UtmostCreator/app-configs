# VS Code Extensions

Workflow:

1. VS Code user settings + keybindings are chezmoi-managed at:
   - Linux / WSL: `~/.config/Code/User/`
   - macOS: `~/Library/Application Support/Code/User/`

   Sources live under `home/dot_config/Code/User/` and
   `home/Library/Application Support/Code/User/` in the repo. Both
   `settings.json.tmpl` wrappers fold full vs minimal via the `.minimal`
   key in `home/.chezmoidata/personal.yaml`.

2. Extensions themselves are installed via `code --install-extension`.
   The bootstrap does **not** auto-install them; pick what you want from
   the list below.

## Export your current list

```bash
code --list-extensions > /tmp/vscode-extensions.txt
```

## Install the curated list

```bash
xargs -L1 code --install-extension <<'EOF'
alefragnani.bookmarks
amiralizadeh9480.laravel-extra-intellisense
anan.jetbrains-darcula-theme
astro-build.astro-vscode
austenc.tailwind-docs
bmewburn.vscode-intelephense-client
bradlc.vscode-tailwindcss
christian-kohler.npm-intellisense
christian-kohler.path-intellisense
codingyu.laravel-goto-view
damms005.devdb
davidanson.vscode-markdownlint
dbaeumer.vscode-eslint
devsense.phptools-vscode
docker.docker
dotenv.dotenv-vscode
eamodio.gitlens
ecmel.vscode-html-css
editorconfig.editorconfig
esbenp.prettier-vscode
formulahendry.auto-close-tag
github.vscode-github-actions
github.vscode-pull-request-github
gruntfuggly.todo-tree
hbenl.vscode-test-explorer
htmlhint.vscode-htmlhint
humao.rest-client
k--kato.intellij-idea-keybindings
mechatroner.rainbow-csv
mehedidracula.php-namespace-resolver
mhutchie.git-graph
ms-azuretools.vscode-containers
ms-azuretools.vscode-docker
ms-playwright.playwright
ms-vscode-remote.remote-containers
ms-vscode-remote.remote-wsl
ms-vscode.powershell
ms-vscode.test-adapter-converter
ms-vscode.vscode-typescript-next
mtxr.sqltools
mtxr.sqltools-driver-mysql
naumovs.color-highlight
neilbrayfield.php-docblocker
nuxtr.nuxtr-vscode
open-southeners.laravel-pint
pkief.material-icon-theme
pranaygp.vscode-css-peek
recca0120.vscode-phpunit
redhat.vscode-yaml
ryannaddy.laravel-artisan
shufo.vscode-blade-formatter
sonarsource.sonarlint-vscode
streetsidesoftware.code-spell-checker
stylelint.vscode-stylelint
tyriar.lorem-ipsum
unifiedjs.vscode-mdx
usernamehw.errorlens
vue.volar
xdebug.php-debug
EOF
```

> The list intentionally omits `github.copilot*` because this repo uses
> OpenCode as the AI runtime. Install Copilot separately if you want it.
