#!/usr/bin/env bats
# ADR-0043 and ADR-0044: the winget import manifests (ops/windows/winget/*.json), the
# app list (docs/platforms/windows/apps.md) and the taskbar pins
# (docs/platforms/windows/taskbar-pins.yaml) must agree.

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    W="$REPO_ROOT/ops/windows/winget"
    APPS="$REPO_ROOT/docs/platforms/windows/apps.md"
    PINS="$REPO_ROOT/docs/platforms/windows/taskbar-pins.yaml"
}

# ids FILE: the manifest's package ids, sorted.
ids() { jq -r '.Sources[].Packages[].PackageIdentifier' "$1" | sort; }

# table_ids FIELD: ids (backticked, field 4) from apps.md table rows whose awk field FIELD
# (5 = Home, 6 = Corporate; field 1 is empty before the leading "|") is "yes".
table_ids() {
    awk -F'|' -v c="$1" '
        /^\| / && $4 ~ /`[^`]+`/ {
            id = $4; sub(/^[^`]*`/, "", id); sub(/`.*$/, "", id)
            v = $(c); gsub(/^ +| +$/, "", v)
            if (v == "yes") print id
        }' "$APPS" | sort
}

# pin_rows: "winget<TAB>profiles" for every pins row with a winget key.
pin_rows() {
    awk '
        /^  - position:/ { if (w != "") print w "\t" p; w = ""; p = "both" }
        /^    winget:/ { w = $2 }
        /^    profiles:/ { p = $2 }
        /^[a-z_]+:/ && !/^pins:/ { if (w != "") print w "\t" p; w = "" }
        END { if (w != "") print w "\t" p }' "$PINS"
}

@test "manifests are winget export files with unique ids" {
    for f in "$W/home.json" "$W/work.json"; do
        run jq -e '."$schema" == "https://aka.ms/winget-packages.schema.2.0.json"
            and (.Sources | length) == 1
            and .Sources[0].SourceDetails.Name == "winget"
            and (.Sources[0].Packages | length) > 0
            and all(.Sources[0].Packages[]; (keys == ["PackageIdentifier"]))' "$f"
        [ "$status" -eq 0 ] || { echo "bad manifest shape: $f"; return 1; }
        dups="$(ids "$f" | uniq -d)"
        [ -z "$dups" ] || { echo "duplicate ids in $f: $dups"; return 1; }
    done
}

@test "home.json matches the apps.md Home column" {
    diff <(table_ids 5) <(ids "$W/home.json")
}

@test "work.json matches the apps.md Corporate column" {
    diff <(table_ids 6) <(ids "$W/work.json")
}

@test "work.json is a subset of home.json" {
    run comm -23 <(ids "$W/work.json") <(ids "$W/home.json")
    [ -z "$output" ] || { echo "only in work.json: $output"; return 1; }
}

@test "every taskbar pin winget id is in a manifest, and personal pins stay off work.json" {
    local bad="" id prof
    while IFS=$'\t' read -r id prof; do
        ids "$W/home.json" | grep -qxF "$id" || ids "$W/work.json" | grep -qxF "$id" || bad+=" $id(no manifest)"
        if [ "$prof" = "personal" ] && ids "$W/work.json" | grep -qxF "$id"; then bad+=" $id(personal but in work.json)"; fi
    done < <(pin_rows)
    [ -n "$(pin_rows)" ] || { echo "no pins rows with a winget key parsed"; return 1; }
    [ -z "$bad" ] || { echo "taskbar-pins.yaml:$bad"; return 1; }
}

@test "every chosen pin names its winget id" {
    run awk '
        /^  - position:/ { if (s == "chosen" && w == "") print a; s = ""; w = ""; a = "" }
        /^    app:/ { sub(/^    app: */, ""); a = $0 }
        /^    status:/ { sub(/^    status: */, ""); s = $0 }
        /^    winget:/ { w = $2 }
        /^not_pinned:/ { if (s == "chosen" && w == "") print a; s = "" }' "$PINS"
    [ -z "$output" ] || { echo "chosen rows without winget: $output"; return 1; }
}

@test "the parity check catches a manifest that drifts from apps.md" {
    tmp="$BATS_TEST_TMPDIR/home.json"
    jq '.Sources[0].Packages += [{"PackageIdentifier": "Example.NotListed"}]' "$W/home.json" >"$tmp"
    run diff <(table_ids 5) <(ids "$tmp")
    [ "$status" -ne 0 ]
    [[ "$output" == *"Example.NotListed"* ]]
}
