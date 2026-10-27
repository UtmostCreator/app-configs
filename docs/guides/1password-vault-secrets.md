# 1Password CLI secret references

How this repo's shell setup pulls tokens from 1Password (`op`) at runtime. This page
contains references and placeholders only. No secret values belong in this file.

## What it is

- `op` is the 1Password CLI.
- A secret reference has the form `op://<vault>/<item>/<field>`. It points to a field
  in a 1Password item and is safe to store in files.
- `op read '<reference>'` resolves one reference and prints the value to stdout.
- `op run --env-file=<file> -- <command>` resolves every reference in an env file and
  injects the results as environment variables into the child process only. Values are
  not written to disk.
- `op whoami` checks whether the CLI has an active session. `op signin` starts one.

## Placeholders

| Placeholder | Meaning |
|-------------|---------|
| `<user>` | Local macOS username |
| `<vault>` | 1Password vault that holds work and employee tokens |
| `<ITEM>` | Item name, for example the GitHub token item |
| `value` | Field name for the token in that item |

## Read one secret

```bash
op read 'op://<vault>/<ITEM>/value'
```

Do not paste the output into shared logs or chat.

## Env file for composer

`~/.config/1password/composer.env`:

```dotenv
GITHUB_COMPOSER_TOKEN="op://<vault>/<ITEM>/value"
```

Each line maps an environment variable name to a reference. The env file is read by
`op run`, so it can be committed to dotfiles without exposing the token.

## Composer wrapper

Both shells wrap `composer` so the Herd composer receives a GitHub OAuth token from
1Password:

- zsh: `composer()` in [`home/dot_zshrc.tmpl`](../../home/dot_zshrc.tmpl)
- fish: `composer` function in [`home/dot_config/fish/config.fish.tmpl`](../../home/dot_config/fish/config.fish.tmpl)

The wrapper runs `op run --env-file=~/.config/1password/composer.env`, builds
`COMPOSER_AUTH` from `GITHUB_COMPOSER_TOKEN`, and then execs Herd's composer with the
original arguments.

## Alternative: token from the gh CLI

```bash
export MY_GITHUB_TOKEN="$(gh auth token)"

echo "MY_GITHUB_TOKEN preview: ${MY_GITHUB_TOKEN:0:4}********${MY_GITHUB_TOKEN: -4}"
```

`gh auth token` prints the token stored by `gh auth login`. The preview line shows only
the first and last four characters, so you can confirm the variable is set without
exposing the full value.

## Other 1Password usage

- The fish config loads a token from a 1Password item when `op` is signed in. It skips
  the lookup otherwise, so shell startup does not prompt.
- `op-refresh` (fish) runs `op signin` and then reloads the fish config.

## Rotating a token

Update the field in the 1Password item. References resolve at runtime, so no repo or
dotfile change is needed.
