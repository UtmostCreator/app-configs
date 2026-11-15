# ssh-agent auto-loader for fish (Linux + macOS).
#
# Drop into ~/.config/fish/conf.d/ssh-agent.fish. Fish auto-sources every
# .fish file in conf.d on shell start.
#
# Configure keys with:
#   set -Ux APP_CONFIGS_SSH_KEYS <github-key> <work-key>
# (universal variable, persists across sessions). Paths are resolved
# against $HOME/.ssh/.
#
# Keys are forgotten by the agent after APP_CONFIGS_SSH_KEY_LIFETIME hours
# (default 8):
#   set -Ux APP_CONFIGS_SSH_KEY_LIFETIME 24
# 0 or empty keeps keys until the agent dies; anything that is not a
# non-negative integer is ignored (default kept). Not used on macOS. Keys
# already in a running agent keep their old lifetime until it restarts
# (`keychain --clear`, or log out).

if not status is-interactive
    exit 0
end

if not set -q APP_CONFIGS_SSH_KEYS
    set -g APP_CONFIGS_SSH_KEYS id_ed25519
end

# Key lifetime in whole hours; empty means no limit (see header).
set -l __hours 8
if set -q APP_CONFIGS_SSH_KEY_LIFETIME
    if test (count $APP_CONFIGS_SSH_KEY_LIFETIME) -eq 0; or test -z "$APP_CONFIGS_SSH_KEY_LIFETIME[1]"
        set __hours
    else if string match -qr '^[0-9]{1,6}$' -- $APP_CONFIGS_SSH_KEY_LIFETIME[1]
        set __hours (math $APP_CONFIGS_SSH_KEY_LIFETIME[1])
        test "$__hours" = 0; and set __hours
    end
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
        # Keychain so the passphrase is asked at most once ever (the key
        # lifetime does not apply here).
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
            # Passphrase asked about once per key lifetime (default 8 h),
            # reused across every shell.
            # Pass only keys that exist (the bash twin filters the same way);
            # keychain resolves bare names under ~/.ssh.
            set -l keys
            for k in $APP_CONFIGS_SSH_KEYS
                if string match -q '/*' -- $k
                    test -f $k; and set -a keys $k
                else
                    test -f $HOME/.ssh/$k; and set -a keys $k
                end
            end
            # No --agents: keychain 3 deprecates it (prints a warning on every
            # shell). Without it, ssh key names mean ssh-only in both keychain
            # 2.8+ (default) and 3.x (`add`, via legacy parsing).
            # --timeout is in minutes (keychain 2.8+ and 3.x), before the keys.
            set -l timeout_args
            test -n "$__hours"; and set timeout_args --timeout (math $__hours \* 60)
            keychain --eval --quiet $timeout_args $keys | source
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
            # 2 = agent unreachable; 1 = reachable but no identities, which
            # the key loading below handles. Only a dead agent is replaced.
            ssh-add -l >/dev/null 2>&1
            if test $status -eq 2
                # Private env file, without leaving the whole interactive
                # shell at umask 077 (the bash twin uses a subshell).
                set -l old_umask (umask)
                umask 077
                ssh-agent -s >$env_file
                umask $old_umask
                # A pre-existing file keeps its old mode through `>`.
                chmod 600 $env_file
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
                # ssh-add -t is in seconds.
                if test -n "$__hours"
                    ssh-add -t (math $__hours \* 3600) $path
                else
                    ssh-add $path
                end
            end
        end
end

functions -e __app_configs_ssh_key_paths
