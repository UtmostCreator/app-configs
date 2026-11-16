#!/usr/bin/env bats
# ADR frontmatter and index contract (docs/architecture/decisions/index.md).
#
# Required, machine-checked: adr (= filename number), status and platforms
# (closed sets), amends/supersedes/superseded_by (positive integers naming
# existing ADRs; a superseded ADR needs superseded_by; an amended ADR's body
# must mention the amender), exactly one index row per ADR whose status column
# equals the frontmatter status, and a human "Status:" line that does not
# contradict it. areas, permits, forbids and related are optional: their
# format is checked only when present. For ADRs numbered above 19 a windows
# platform needs ADR-0019 in amends or related; earlier ADRs are exempt.
#
# It checks the ADRs that exist in the tree; an ADR that lands from another
# branch must bring frontmatter and an index row. Seeded tests copy the
# repository, inject one defect and assert it is caught.

load ../lib/contract

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
}

STATUSES="decided decided-unverified partly-decided proposed trial superseded rejected"
PLATFORMS="linux nixos macos wsl windows cross"

# fm FILE KEY: raw value of a frontmatter key (first block only).
fm() {
    awk -v k="$2" 'NR==1&&$0!="---"{exit} NR>1&&$0=="---"{exit}
        index($0,k":")==1{sub("^"k":[ ]*","");print;exit}' "$1"
}

# list_items VALUE: "[a, b]" -> one item per line.
list_items() { tr -d '[]' <<<"$1" | tr ',' '\n' | sed 's/^ *//;s/ *$//' | grep -v '^$' || true; }

in_set() { local x="$1"; shift; local s; for s in "$@"; do [ "$s" = "$x" ] && return 0; done; return 1; }

# seed FILE SED-EXPR: apply a sed edit and fail the test if nothing changed.
seed() {
    local before after
    before="$(cksum <"$1")"; sed -i "$2" "$1"; after="$(cksum <"$1")"
    [ "$before" != "$after" ] || { echo "seed did not change $1 ($2)"; return 1; }
}

# check ROOT: one line per violation on stdout.
check() {
    local root="$1" dir idx f base n num s p v a k word rows col body
    dir="$root/docs/architecture/decisions"; idx="$dir/index.md"
    for f in "$dir"/[0-9]*.md; do
        base="$(basename "$f")"; n="${base:0:4}"; num=$((10#$n))
        [ "$(head -n1 "$f")" = "---" ] || { echo "$base: no frontmatter"; continue; }
        [ "$(fm "$f" adr)" = "$num" ] || echo "$base: adr key is not $num"
        s="$(fm "$f" status)"
        in_set "$s" $STATUSES || echo "$base: status '$s' not allowed"
        p="$(list_items "$(fm "$f" platforms)")"
        [ -n "$p" ] || echo "$base: platforms empty"
        for v in $p; do in_set "$v" $PLATFORMS || echo "$base: platform '$v' not allowed"; done
        for k in amends supersedes superseded_by; do
            [ -n "$(fm "$f" $k)" ] || echo "$base: $k missing"
            for v in $(list_items "$(fm "$f" $k)"); do
                if ! [[ "$v" =~ ^[1-9][0-9]*$ ]]; then echo "$base: $k item '$v' is not a plain ADR number"; continue; fi
                ls "$dir"/"$(printf '%04d' "$v")"-*.md >/dev/null 2>&1 || { echo "$base: $k names missing ADR $v"; continue; }
                if [ "$k" = amends ]; then
                    body="$(cat "$dir"/"$(printf '%04d' "$v")"-*.md)"
                    grep -qF "ADR-$n" <<<"$body" || echo "$base: amends $v but ADR $v never mentions ADR-$n"
                fi
            done
        done
        if [ "$s" = superseded ] && [ -z "$(list_items "$(fm "$f" superseded_by)")" ]; then
            echo "$base: superseded without superseded_by"
        fi
        for k in areas permits forbids; do
            while IFS= read -r v; do
                [[ "$v" =~ ^[A-Za-z0-9._-]+$ ]] || echo "$base: $k item '$v' has a bad format"
            done < <(list_items "$(fm "$f" $k)")
        done
        while IFS= read -r v; do
            [[ "$v" =~ ^(T-[0-9]+|[1-9][0-9]*)$ ]] || echo "$base: related item '$v' has a bad format"
        done < <(list_items "$(fm "$f" related)")
        rows="$(grep -F "[$n]($base)" "$idx" | grep '^| \[' || true)"
        if [ -z "$rows" ]; then echo "$base: no index row"
        elif [ "$(wc -l <<<"$rows")" -ne 1 ]; then echo "$base: more than one index row"
        else
            col="$(awk -F'|' '{gsub(/^ +| +$/,"",$4);print $4}' <<<"$rows")"
            [ "$col" = "$s" ] || echo "$base: index status '$col' differs from '$s'"
        fi
        word="$(sed -n '/^# ADR-/{n;p;q}' "$f" | sed -nE 's/^Status: ([A-Za-z-]+).*/\1/p')"
        case "$s" in
            proposed|trial|rejected|superseded) [ "$word" = "$s" ] || echo "$base: Status line starts '$word', frontmatter says $s" ;;
            decided|decided-unverified) [[ "$word" == decided* ]] || echo "$base: Status line starts '$word', frontmatter says $s" ;;
            partly-decided) case "$word" in proposed|trial|rejected|superseded) echo "$base: Status line starts '$word', frontmatter says partly-decided" ;; esac ;;
        esac
        if [ "$num" -gt 19 ] && grep -qx windows <<<"$p"; then
            a="$(list_items "$(fm "$f" amends)"; list_items "$(fm "$f" related)")"
            grep -qx 19 <<<"$a" || echo "$base: windows tag without ADR-0019 in amends/related"
        fi
    done
}

dir_of() { printf '%s/docs/architecture/decisions' "$1"; }

@test "every ADR has valid frontmatter, one index row and existing references" {
    run check "$REPO_ROOT"
    [ -z "$output" ] || { echo "$output"; return 1; }
}

@test "the checker sees the ADRs (an empty glob would pass)" {
    [ "$(ls "$REPO_ROOT"/docs/architecture/decisions/[0-9]*.md | wc -l)" -ge 18 ]
}

@test "seeded: an ADR without frontmatter is caught" {
    local c="$BATS_TEST_TMPDIR/repo"; repo_copy "$c"
    seed "$(ls "$(dir_of "$c")"/0004-*.md)" '1,/^---$/d'
    run check "$c"
    [[ "$output" == *"0004-tailscale-on-windows-only.md: no frontmatter"* ]] || { echo "$output"; return 1; }
}

@test "seeded: wrong adr number, bad status and bad platform are caught" {
    local c="$BATS_TEST_TMPDIR/repo"; repo_copy "$c"; local f
    f="$(ls "$(dir_of "$c")"/0003-*.md)"
    seed "$f" 's/^adr: 3$/adr: 4/; s/^status: .*/status: maybe/; s/^platforms: .*/platforms: [beos]/'
    run check "$c"
    [[ "$output" == *"adr key is not 3"* ]]
    [[ "$output" == *"status 'maybe' not allowed"* ]]
    [[ "$output" == *"platform 'beos' not allowed"* ]]
}

@test "seeded: a missing index row, a stale index status and a duplicate row are caught" {
    local c="$BATS_TEST_TMPDIR/repo"; repo_copy "$c"; local i="$(dir_of "$c")/index.md"
    seed "$i" '/\[0009\](/d'
    seed "$i" 's/^\(| \[0014\].*\)| decided |/\1| trial |/'
    grep '^| \[0001\]' "$i" >>"$i.dup"; sed -i '/^## Layers/e cat '"$i.dup" "$i"
    run check "$c"
    [[ "$output" == *"0009-two-machines-one-history.md: no index row"* ]]
    [[ "$output" == *"0014-tool-stack-recap.md: index status 'trial' differs"* ]]
    [[ "$output" == *"0001-wsl2-base-nixos-wsl.md: more than one index row"* ]]
}

@test "seeded: a Status line that contradicts the frontmatter is caught" {
    local c="$BATS_TEST_TMPDIR/repo"; repo_copy "$c"
    seed "$(ls "$(dir_of "$c")"/0018-*.md)" 's/^Status: proposed/Status: decided/'
    run check "$c"
    [[ "$output" == *"0018-interactive-config-manager-frontend.md: Status line starts 'decided'"* ]]
}

@test "seeded: dangling amends, octal item and an unmentioned amender are caught" {
    local c="$BATS_TEST_TMPDIR/repo"; repo_copy "$c"; local d; d="$(dir_of "$c")"
    seed "$(ls "$d"/0016-*.md)" 's/^amends: .*/amends: [9999]/'
    seed "$(ls "$d"/0018-*.md)" 's/^amends: .*/amends: [010]/'
    seed "$(ls "$d"/0015-*.md)" 's/^amends: .*/amends: [3]/'
    run check "$c"
    [[ "$output" == *"0016-native-windows-claude-status-line.md: amends names missing ADR 9999"* ]]
    [[ "$output" == *"amends item '010' is not a plain ADR number"* ]]
    [[ "$output" == *"0015-wsl-distro-selection-nixos-or-ubuntu.md: amends 3 but ADR 3 never mentions ADR-0015"* ]]
}

@test "seeded: superseded without superseded_by and a bad optional tag are caught" {
    local c="$BATS_TEST_TMPDIR/repo"; repo_copy "$c"; local f
    f="$(ls "$(dir_of "$c")"/0013-*.md)"
    seed "$f" 's/^status: trial/status: superseded/; s/^forbids: .*/forbids: [bad tag]/'
    run check "$c"
    [[ "$output" == *"superseded without superseded_by"* ]]
    [[ "$output" == *"forbids item 'bad tag' has a bad format"* ]]
}

@test "optional fields may be absent" {
    local c="$BATS_TEST_TMPDIR/repo"; repo_copy "$c"; local f
    f="$(ls "$(dir_of "$c")"/0004-*.md)"
    seed "$f" '/^\(areas\|permits\|forbids\|related\|title\|date\):/d'
    run check "$c"
    [ -z "$output" ] || { echo "$output"; return 1; }
}

@test "seeded: a new windows-tagged ADR without ADR-0019 is caught, with it passes" {
    local c="$BATS_TEST_TMPDIR/repo" d f
    repo_copy "$c"; d="$(dir_of "$c")"; f="$d/9999-seed.md"
    printf -- '---\nadr: 9999\nstatus: proposed\nplatforms: [windows]\namends: []\nsupersedes: []\nsuperseded_by: []\n---\n# ADR-9999: Seed\nStatus: proposed\n' >"$f"
    sed -i 's/^## Layers/| [9999](9999-seed.md) | seed | proposed | 2026-11-17 |\n\n## Layers/' "$d/index.md"
    run check "$c"
    [[ "$output" == *"9999-seed.md: windows tag without ADR-0019"* ]] || { echo "$output"; return 1; }
    seed "$f" 's/^amends: .*/amends: []\nrelated: [19]/'
    run check "$c"
    [ -z "$output" ] || { echo "$output"; return 1; }
}
