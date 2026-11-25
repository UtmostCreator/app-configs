#!/usr/bin/env bats
# Exercise the staged update against a temporary profile and modeled boot
# entries. No command may touch systemd-boot, EFI variables or a real profile.
setup() {
    project="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    script="$project/nix/hosts/linux-niri/maintenance.sh"
    source "$script"
    fixture="$BATS_TEST_TMPDIR/profiles"
    mkdir -p "$fixture"
    old="$fixture/base-old"
    candidate="$fixture/base-new"
    profile="$fixture/system"
    history="$fixture/history"
    default="$fixture/default"
    printf 'nixos-old.conf\n' >"$default"
    touch "$history"
    for path in "$old" "$candidate"; do
        mkdir -p "$path/specialisation" "$path-nv"
        touch "$path/init" "$path-nv/init"
        chmod +x "$path/init" "$path-nv/init"
        ln -s "$path-nv" "$path/specialisation/nvidia-open"
    done
    ln -s "$old" "$profile-1-link"
    ln -s system-1-link "$profile"
    clean_revision() { echo 1111111111111111111111111111111111111111; }
    app-configs-verify-first-boot() {
        [[ "$1" == --storage-only && ${unhealthy:-0} == 0 ]]
    }
    nix() {
        [[ "$*" == *"--no-update-lock-file"* && "$*" == *"rev=111111"* ]] || return 2
        echo "$candidate"
    }
    nixos-rebuild() {
        [[ "$(cat "$default")" == nixos-old.conf && "$1" == boot && "$*" == *"--sudo"* ]] || return 2
        echo staged >> "$history"
        ln -s "$candidate" "$profile-2-link"
        ln -sfn system-2-link "$profile"
    }
    entries() {
        jq -nc --arg old "$old-nv/init" --arg new "$candidate-nv/init" --arg base "$candidate/init" \
          --arg default "$(cat "$default")" --arg failure "${failed_lookup:-0}" '
          [{id:"nixos-old.conf", options:("init="+$old), version:"Generation 1 details", isSelected:true},
           {id:"nixos-new-base.conf", options:("init="+$base), version:"Generation 2 details"}] +
          (if $failure == "1" then [] else
           [{id:"nixos-new-nv.conf", options:("init="+$new), version:"Generation 2 details"}] end)
          | map(.isDefault = (.id == $default))'
    }
    sudo() {
        [[ "$1 $2 $3" == "bootctl --esp-path=/boot set-default" ]] || return 2
        printf '%s\n' "$4" >>"$history"
        printf '%s\n' "$4" >"$default"
    }
}

@test "an integrated update builds the pinned revision and retains its GPU variant across generation IDs" {
    [[ "$(variant_of "$old" "$old-nv")" == nvidia-open ]]
    run stage_update "$fixture" "$old" nvidia-open "$old-nv" 1 "$profile"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Staged generation 2 (nvidia-open)"* ]]
    [ "$(cat "$history")" = $'nixos-old.conf\nstaged\nnixos-new-nv.conf' ]
}

@test "missing the desired GPU variant refuses staging before any EFI mutation" {
    unlink "$candidate/specialisation/nvidia-open"
    run stage_update "$fixture" "$old" nvidia-open "$old-nv" 1 "$profile"
    [ "$status" -ne 0 ]
    [ ! -s "$history" ]
}

@test "staging refuses an unverified old default and a post-stage lookup failure keeps the old default" {
    echo other.conf >"$default"
    run stage_update "$fixture" "$old" nvidia-open "$old-nv" 1 "$profile"
    [ "$status" -ne 0 ]
    [ ! -s "$history" ]
    echo nixos-old.conf >"$default"
    failed_lookup=1
    run stage_update "$fixture" "$old" nvidia-open "$old-nv" 1 "$profile"
    [ "$status" -ne 0 ]
    [ "$(cat "$default")" = nixos-old.conf ]
    [ "$(cat "$history")" = $'nixos-old.conf\nstaged' ]
}

@test "base and rollback variants resolve by exact generation and init, and reject ambiguity" {
    [ -z "$(variant_of "$old" "$old")" ]
    [ "$(variant_system "$profile-1-link" nvidia-open)" = "$old-nv" ]
    run variant_of "$old" "$candidate"
    [ "$status" -ne 0 ]
    run entry_id /store/foo 3 <<< '[{"id":"nixos-a.conf","version":"Generation 30 test","options":"init=/store/foo/init"},{"id":"nixos-b.conf","version":"Generation 3 test","options":"init=/store/foobar/init"}]'
    [ "$status" -ne 0 ]
    run entry_id /store/foo 3 <<< '[{"id":"nixos-a.conf","version":"Generation 3 test","options":"init=/store/foo/init"},{"id":"nixos-b.conf","version":"Generation 3 test","options":"init=/store/foo/init"}]'
    [ "$status" -ne 0 ]
}

@test "a dirty checkout is refused before staging" {
    repo="$BATS_TEST_TMPDIR/checkout"
    git init -q "$repo"
    git -C "$repo" -c user.email=test@example.invalid -c user.name=Test commit -qm init --allow-empty
    touch "$repo/unreviewed"
    unset -f clean_revision
    source "$script"
    run clean_revision "$repo"
    [ "$status" -ne 0 ]
    [[ "$output" == *"Review and commit"* ]]
}

@test "a failed storage gate stops the update before building or changing the boot entry" {
    unhealthy=1
    run stage_update "$fixture" "$old" nvidia-open "$old-nv" 1 "$profile"
    [ "$status" -ne 0 ]
    [[ "$output" == *"Storage verification failed"* ]]
    [ ! -s "$history" ]
}

@test "retry after incomplete entry selection resumes the exact staged build without replacing its generation" {
    failed_lookup=1
    run stage_update "$fixture" "$old" nvidia-open "$old-nv" 1 "$profile"
    [ "$status" -ne 0 ]
    failed_lookup=0
    run stage_update "$fixture" "$old" nvidia-open "$old-nv" 1 "$profile"
    [ "$status" -eq 0 ]
    [ "$(cat "$history")" = $'nixos-old.conf\nstaged\nnixos-new-nv.conf' ]
}

@test "a different pending generation blocks staging another update" {
    mkdir "$fixture/unrelated"
    ln -s "$fixture/unrelated" "$profile-2-link"
    ln -sfn system-2-link "$profile"
    run stage_update "$fixture" "$old" nvidia-open "$old-nv" 1 "$profile"
    [ "$status" -ne 0 ]
    [ ! -s "$history" ]
}
