#!/usr/bin/env bash
# Seed absent client loader files from the installation kit's recorded commit.
# Existing shell customisations and SSH identities belong to the user.
set -euo pipefail
umask 077

fail() { printf 'FAIL  %s\n' "$1" >&2; exit 1; }

(( EUID != 0 )) || fail 'Run in the ordinary user session'
[[ $# == 2 ]] || fail 'Usage: app-configs-seed-shell INSTALL_BUNDLE INSTALL_COMMIT'
bundle=$1
revision=$2
[[ $revision =~ ^[a-f0-9]{40}$ && $bundle == /* && -f $bundle && ! -L $bundle ]] ||
  fail 'Expected a local installation bundle and full deployment revision'
[[ $(realpath -e -- "$bundle") == "$bundle" ]] || fail 'Installation bundle path contains a link'
for protected in "$bundle" "${bundle%/*}"; do
  read -r owner mode < <(stat -c '%u %a' -- "$protected")
  if [[ $owner != 0 ]] || (( (8#$mode & 0022) != 0 )); then
    fail 'Installation bundle and directory must be root-owned and protected from other writers'
  fi
done
[[ -n ${HOME:-} && $HOME == /* && $HOME != / && -O $HOME && -d $HOME && ! -L $HOME ]] ||
  fail 'Expected an owned home directory'

targets=(.config/app-configs/ssh-agent.sh .config/fish/conf.d/ssh-agent.fish .bashrc)
sources=(home/dot_config/app-configs/ssh-agent.sh home/dot_config/fish/conf.d/ssh-agent.fish home/dot_bashrc.tmpl)
dirs=(.config .config/app-configs .config/fish .config/fish/conf.d)
for dir in "${dirs[@]}"; do
  path="$HOME/$dir"
  [[ ! -L $path && ( ! -e $path || ( -d $path && -O $path ) ) ]] ||
    fail 'A shell configuration directory requires owner review'
done
missing=()
for i in "${!targets[@]}"; do
  path="$HOME/${targets[i]}"
  if [[ -e $path || -L $path ]]; then
    printf 'INFO  Keeping existing %s\n' "${targets[i]}"
  else
    missing+=("$i")
  fi
done
(( ${#missing[@]} )) || exit 0

scratch=$(mktemp -d)
trap 'rm -rf -- "$scratch"' EXIT
mkdir -m 0700 "$scratch/empty"
touch "$scratch/empty.toml"
# Do not load checkout hooks, global filters, user templates, or external remotes.
export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null GIT_ALLOW_PROTOCOL=file
git -c init.templateDir="$scratch/empty" init --bare --quiet "$scratch/repo"
ref=
heads=$(git bundle list-heads "$bundle" refs/heads/main HEAD) || fail 'Invalid installation bundle'
while read -r hash name; do
  if [[ $hash == "$revision" && ( $name == refs/heads/main || $name == HEAD ) ]]; then
    ref=$name
    break
  fi
done <<< "$heads"
[[ -n $ref ]] || fail 'Installation bundle and deployment revision differ'
git --git-dir="$scratch/repo" -c core.hooksPath=/dev/null fetch --quiet --no-tags "$bundle" "$ref" ||
  fail 'Unable to read the installation bundle'
[[ $(git --git-dir="$scratch/repo" rev-parse FETCH_HEAD) == "$revision" ]] ||
  fail 'Installation bundle and deployment revision differ'

# Finish rendering every missing file before touching the home. These three
# sources contain no personal data. Personal Fish integrations are opt-in.
for i in "${missing[@]}"; do
  git --git-dir="$scratch/repo" cat-file blob "$revision:${sources[i]}" > "$scratch/$i" ||
    fail 'Installation bundle lacks a required shell source'
  if [[ ${sources[i]} == *.tmpl ]]; then
    HOME="$scratch/empty" chezmoi --config "$scratch/empty.toml" --source "$scratch/empty" \
      execute-template < "$scratch/$i" > "$scratch/rendered"
    mv -- "$scratch/rendered" "$scratch/$i"
  fi
done

for i in "${missing[@]}"; do
  (
    cd -P -- "$HOME"
    target=${targets[i]}
    # Keep each directory open as the working directory while descending.
    while [[ $target == */* ]]; do
      part=${target%%/*}
      [[ ! -L $part ]] || fail 'Refusing a symlinked shell configuration directory'
      if [[ ! -d $part ]]; then mkdir -m 0700 -- "$part"; fi
      previous=$PWD
      cd -P -- "$part"
      [[ $PWD == "$previous/$part" && -O . ]] || fail 'Shell configuration directory changed'
      target=${target#*/}
    done
    # Link in the completed file without overwriting a concurrent user edit.
    tmp=$(mktemp .app-configs-shell.XXXXXXXX)
    trap 'rm -f -- "$tmp"' EXIT
    cat "$scratch/$i" > "$tmp"
    if ln -T -- "$tmp" "$target"; then
      printf 'PASS  Seeded %s\n' "${targets[i]}"
    elif [[ -e $target || -L $target ]]; then
      printf 'INFO  Keeping existing %s\n' "${targets[i]}"
    else
      fail 'Could not publish a shell configuration file'
    fi
  )
done
