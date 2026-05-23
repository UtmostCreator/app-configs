# ssh-agent auto-loader for fish (Linux + macOS).
#
# Drop into ~/.config/fish/conf.d/ssh-agent.fish. Fish auto-sources every
# .fish file in conf.d on shell start.
#
# Configure keys with:
#   set -Ux APP_CONFIGS_SSH_KEYS github.uc.ll5 work_ed25519
# (universal variable, persists across sessions). Paths are resolved
# against $HOME/.ssh/.

if not status is-interactive
    exit 0
end

if not set -q APP_CONFIGS_SSH_KEYS
    set -g APP_CONFIGS_SSH_KEYS github.uc.ll5
end

function __app_configs_ssh_key_paths
    for k in $APP_CONFIGS_SSH_KEYS
        if string match -q '/*' -- $k
            test -f $k; and echo $k
        else
            test -f $HOME/.ssh/$k; and echo $HOME/.ssh/$k
        end
    end
end

switch (uname -s)
    case Darwin
        # macOS: launchd's agent is already running. Add keys via the
        # Keychain so the passphrase is asked at most once ever.
        set -l loaded (ssh-add -l 2>/dev/null)
        for path in (__app_configs_ssh_key_paths)
            set -l fp (ssh-keygen -lf $path 2>/dev/null | awk '{print $2}')
            if test -n "$fp"; and string match -q "*$fp*" -- "$loaded"
                continue
            end
            if not ssh-add --apple-use-keychain $path 2>/dev/null
                ssh-add -K $path 2>/dev/null; or ssh-add $path
            end
        end
    case Linux FreeBSD OpenBSD NetBSD '*'
        if type -q keychain
            # Passphrase asked once per boot, reused across every shell.
            keychain --eval --quiet --agents ssh $APP_CONFIGS_SSH_KEYS | source
        else
            # Fallback: persistent agent env file shared across shells.
            set -l env_file $HOME/.ssh/agent.env
            if test -r $env_file
                # The file is POSIX shell syntax: `KEY=val; export KEY;`.
                # Convert to fish setters.
                for line in (cat $env_file)
                    set -l m (string match -r '^(SSH_[A-Z_]+)=([^;]+);' -- $line)
                    if test (count $m) -ge 3
                        set -gx $m[2] $m[3]
                    end
                end
            end
            if not ssh-add -l >/dev/null 2>&1
                umask 077
                ssh-agent -s >$env_file
                for line in (cat $env_file)
                    set -l m (string match -r '^(SSH_[A-Z_]+)=([^;]+);' -- $line)
                    if test (count $m) -ge 3
                        set -gx $m[2] $m[3]
                    end
                end
            end
            set -l loaded (ssh-add -l 2>/dev/null)
            for path in (__app_configs_ssh_key_paths)
                set -l fp (ssh-keygen -lf $path 2>/dev/null | awk '{print $2}')
                if test -n "$fp"; and string match -q "*$fp*" -- "$loaded"
                    continue
                end
                ssh-add $path
            end
        end
end

functions -e __app_configs_ssh_key_paths
