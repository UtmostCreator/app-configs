#!/usr/bin/env bats

setup() {
    script="$BATS_TEST_DIRNAME/../../nix/modules/home/scripts/merge-mimeapps.py"
    dir="$BATS_TEST_TMPDIR/home"
    state="$dir/state/home-manager/mimeapps.list"
    cfg="$dir/config/mimeapps.list"
    legacy="$dir/share/applications/mimeapps.list"
    declared="$BATS_TEST_TMPDIR/declared.ini"
    mkdir -p "${state%/*}" "${cfg%/*}" "${legacy%/*}"
    printf '[Default Applications]\ntext/plain=code.desktop\ntext/html=brave-browser.desktop\n' > "$declared"
}

migrate() { python3 "$script" "$state" "$cfg" "$legacy" "$declared"; }

activate_twice() {
    migrate
    rm -f "$cfg" "$legacy"
    ln -s "$state" "$cfg"
    ln -s "$state" "$legacy"
    stamp=$(stat -c '%i:%y' "$state")
    before=$(sha256sum "$state")
    backups=$(find "${state%/*}/mimeapps-backups" -type f | wc -l)
    migrate
    [ "$stamp" = "$(stat -c '%i:%y' "$state")" ]
    [ "$before" = "$(sha256sum "$state")" ]
    [ "$backups" = "$(find "${state%/*}/mimeapps-backups" -type f | wc -l)" ]
}

@test "legacy-only file is saved, including additions/removals and original bytes" {
    printf '# keep raw\n[Added Associations]\na/b=keep.desktop;\n[Removed Associations]\na/b=drop.desktop;\n' > "$legacy"
    cp "$legacy" "$BATS_TEST_TMPDIR/raw"
    activate_twice
    grep -qx 'a/b=keep.desktop;' "$state"
    grep -qx 'a/b=drop.desktop;' "$state"
    cmp "$BATS_TEST_TMPDIR/raw" "${state%/*}"/mimeapps-backups/legacy-*.list
    [ "$(stat -c %a "${state%/*}"/mimeapps-backups/legacy-*.list)" = 600 ]
}

@test "two restored files merge by XDG precedence and keep distinct desktop associations" {
    printf '[Default Applications]\na/b=config.desktop\ntext/plain=editor.desktop\n[Added Associations]\na/b=config.desktop;\n[Removed Associations]\na/b=denied.desktop;\n' > "$cfg"
    printf '[Default Applications]\na/b=legacy.desktop\nx/y=legacy.desktop\n[Added Associations]\na/b=denied.desktop;extra.desktop;\n' > "$legacy"
    activate_twice
    grep -qx 'a/b=config.desktop' "$state"
    grep -qx 'x/y=legacy.desktop' "$state"
    grep -qx 'text/plain=code.desktop' "$state"
    grep -qx 'a/b=config.desktop;extra.desktop;' "$state"
    grep -qx 'a/b=denied.desktop;' "$state"
    [ "$backups" = 2 ]
}

@test "a restored regular file adds decisions over canonical state on subsequent activation" {
    printf '[Default Applications]\na/b=old.desktop\nx/y=keep.desktop\n[Added Associations]\na/b=old.desktop;\n' > "$state"
    ln -s "$state" "$legacy"
    printf '[Default Applications]\na/b=new.desktop\ntext/html=other.desktop\n[Removed Associations]\na/b=old.desktop;\n' > "$cfg"
    activate_twice
    grep -qx 'a/b=new.desktop' "$state"
    grep -qx 'x/y=keep.desktop' "$state"
    grep -qx 'text/html=brave-browser.desktop' "$state"
    grep -A1 '^\[Removed Associations\]' "$state" | grep -qx 'a/b=old.desktop;'
    [ "$backups" = 2 ]
}

@test "an unreadable format or a dangling independent symlink aborts before any replacement" {
    printf 'invalid\n' > "$legacy"
    run migrate
    [ "$status" -ne 0 ]
    [ ! -e "$state" ]
    [ -f "$legacy" ]
    [ ! -e "${state%/*}/mimeapps-backups" ]
    rm "$legacy"
    ln -s "$BATS_TEST_TMPDIR/missing" "$cfg"
    run migrate
    [ "$status" -ne 0 ]
    [ ! -e "$state" ]
    [ -L "$cfg" ]
}

@test "an existing conflicting private backup blocks linking without clobbering either file" {
    cp "$declared" "$cfg"
    digest=$(sha256sum "$cfg")
    backup="${state%/*}/mimeapps-backups/config-${digest%% *}.list"
    mkdir -m 700 "${backup%/*}"
    printf 'sentinel\n' > "$backup"
    run migrate
    [ "$status" -ne 0 ]
    [ "$(cat "$backup")" = sentinel ]
    cmp "$cfg" "$declared"
    [ ! -e "$state" ]
}

@test "an unexpected external link cannot be imported or copied to the private backups" {
    other="$BATS_TEST_TMPDIR/other.ini"
    printf '[Added Associations]\na/b=unrelated.desktop;\n' > "$other"
    ln -s "$other" "$legacy"
    run migrate
    [ "$status" -ne 0 ]
    [ ! -e "$state" ]
    [ ! -e "${state%/*}/mimeapps-backups" ]
    [ "$(readlink "$legacy")" = "$other" ]
    grep -qx 'a/b=unrelated.desktop;' "$other"
}

@test "byte-identical restored regular files still converge on the mutable state" {
    migrate
    cp "$state" "$cfg"
    cp "$state" "$legacy"
    migrate
    [ -L "$cfg" ]
    [ "$cfg" -ef "$state" ]
    [ -L "$legacy" ]
    [ "$legacy" -ef "$state" ]
    cp "$state" "$BATS_TEST_TMPDIR/merged"
    migrate
    cmp "$BATS_TEST_TMPDIR/merged" "$cfg"
    [ "$(find "${state%/*}/mimeapps-backups" -type f | wc -l)" = 2 ]
}
