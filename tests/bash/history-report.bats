#!/usr/bin/env bats
# ops/history-report.py: aggregate-only shell-history report. The output must
# never contain raw arguments, hosts, emails, IPs, URLs or private tool names.

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    SCRIPT="$REPO_ROOT/ops/history-report.py"
    OUT="$BATS_TEST_TMPDIR/out"
    FISH="$BATS_TEST_TMPDIR/fish_history"
    cat >"$FISH" <<'H'
- cmd: git st
  when: 1760000000
- cmd: git st
  when: 1760000010
- cmd: git commit -m "fix acmecorp login for jane.doe@acmecorp.example"
  when: 1760000020
- cmd: ssh deploy@db1.acmecorp.internal
  when: 1760000030
- cmd: curl -H "@AUTH@" https://api.acmecorp.example/v1/orders
  when: 1760000040
- cmd: ping 203.0.113.77
  when: 1760000050
- cmd: acmecorp-deploy --env prod
  when: 1760000060
- cmd: just acmecorp-purge-cache
  when: 1760000070
- cmd: cd ~/work/acmecorp-api && npm run dev
  when: 1760000080
- cmd: php artisan acmecorp:sync-orders
  when: 1760000090
- cmd: res refactor priority
  when: 1760000095
- cmd: echo one\\necho two
  when: 1760000100
H
    # Assemble the fake credential at runtime so this file never contains a
    # literal that secret scanners (rightly) block.
    local tok="sk_""live_51Hx""SECRETSECRET"
    sed -i "s|@AUTH@|Authori""zation: Bearer $tok|" "$FISH"
}

@test "report is written and counts every entry" {
    run python3 -I "$SCRIPT" --fish "fish=$FISH" --out "$OUT"
    [ "$status" -eq 0 ]
    [ -s "$OUT/report.md" ]
    [ -s "$OUT/report.json" ]
    run python3 -I -c "import json,sys; r=json.load(open('$OUT/report.json')); print(r['sources'][0]['entries'])"
    [ "$output" = "12" ]
}

@test "no private data reaches the report" {
    python3 -I "$SCRIPT" --fish "fish=$FISH" --out "$OUT" >/dev/null
    for f in "$OUT/report.md" "$OUT/report.json"; do
        run grep -inE 'acmecorp|jane|doe@|sk_live|203\.0\.113|https?://|db1\.|deploy@|orders|purge' "$f"
        [ "$status" -eq 1 ] || { echo "leak in $f: $output"; return 1; }
        # case-sensitive: the repo alias "git secrets" is fine, the token is not
        run grep -nE 'SECRET' "$f"
        [ "$status" -eq 1 ] || { echo "leak in $f: $output"; return 1; }
    done
}

@test "known tools and repo git aliases stay readable" {
    python3 -I "$SCRIPT" --fish "fish=$FISH" --out "$OUT" >/dev/null
    grep -q 'git st' "$OUT/report.md"
    grep -q 'php artisan <artisan-cmd>' "$OUT/report.md"
    grep -q 'just' "$OUT/report.md"
    grep -q '| res |' "$OUT/report.md"     # the user's own public CLI is named
}

@test "atuin jsonl: failures exclude Ctrl-C and SIGPIPE" {
    j="$BATS_TEST_TMPDIR/h.jsonl"
    python3 -I - "$j" <<'PY'
import json,sys
rows=[("git push",1),("git push",0),("git push",130),("git log",141),("git push",1)]
with open(sys.argv[1],"w") as f:
    for i,(c,e) in enumerate(rows):
        f.write(json.dumps(dict(timestamp=(1760000000+i)*10**9,duration=10**9,exit=e,command=c,session="s"))+"\n")
PY
    python3 -I "$SCRIPT" --atuin-jsonl "a=$j" --out "$OUT" >/dev/null
    run python3 -I -c "import json; print(json.dumps(json.load(open('$OUT/report.json'))['sources'][0]['workflows']['git push']))"
    [ "$status" -eq 0 ]
    [[ "$output" == *'"n": 4'* ]]               # every run is counted
    [[ "$output" == *'"fail_rate": 0.667'* ]]   # 2 of 3: the Ctrl-C run is not a failure
}

@test "--auto with no history fails clearly" {
    run env HOME="$BATS_TEST_TMPDIR/empty" XDG_DATA_HOME="$BATS_TEST_TMPDIR/empty/d" \
        XDG_STATE_HOME="$BATS_TEST_TMPDIR/empty/s" python3 -I "$SCRIPT" --auto --out "$OUT"
    [ "$status" -ne 0 ]
    [[ "$output" == *"no history found"* ]]
}
