# Daily-loop abbreviations, mined from ~27k commands of real shell history
# (git status/add/commit/push loop, php artisan, npm). Abbreviations expand in
# place, so the full command is what lands in history. zsh twins live in the
# "cli shortcuts" block of ~/.zshrc; tests/bash/cli-abbr.bats keeps them equal.
# Reference: docs/reference/cli-shortcuts.md

# git (oh-my-zsh git-plugin names; the expansions use the repo's git aliases)
abbr -a gst 'git st'
abbr -a gco 'git co'
abbr -a gl 'git pull'
abbr -a gp 'git push'
abbr -a gd 'git diff'
abbr -a gau 'git add -u'
abbr -a gaa 'git add .'
abbr -a gai 'git add -i'
abbr -a gcmsg 'git commit -m'
# typo catchers seen in history (exit 127)
abbr -a gti git
abbr -a it git

# PHP / Laravel
abbr -a pa 'php artisan'
abbr -a pat 'php artisan test'
abbr -a punit ./vendor/bin/phpunit
abbr -a pint ./vendor/bin/pint

# Node
abbr -a nr 'npm run'
abbr -a ni 'npm install'

# Listing
abbr -a ll 'eza -lah --git'
abbr -a lt 'eza --tree -L 2'

# Reload the shell after config edits (replaces `source ~/.zshrc`)
abbr -a reload 'exec fish'

# `gi tst` / `gi tpull`: the space landed one letter late. Move the t back
# when that turns an unknown word into a git command or alias.
function gi --description 'git, fixing the "gi tst" slip'
    set -l a $argv
    if set -q a[1]; and string match -q 't*' -- $a[1]
        set -l known (git --list-cmds=main,others,alias 2>/dev/null)
        set -l rest (string sub -s 2 -- $a[1])
        if not contains -- $a[1] $known; and contains -- $rest $known
            set a[1] $rest
        end
    end
    git $a
end

# Fresh node_modules (and Nuxt/Next caches), then a clean install.
function nreset --description 'rm node_modules .nuxt .next, then npm ci'
    rm -rf node_modules .nuxt .next; and npm ci
end
