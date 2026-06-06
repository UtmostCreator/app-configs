#!/usr/bin/env python3
"""Build the exhaustive docs/ -> repo-docs/ move manifest.

For each repo-owned docs/ file, list every referrer (repo vs AI-kit), and the
exact line locations, so the move slice can rewrite all repo-owned referrers
and know which AI-kit referrers will go stale (and must NOT be edited).
"""
import subprocess, json

def list_docs():
    r = subprocess.run(["rg", "--files", "docs",
        "--glob", "!docs/ai/**", "--glob", "!docs/generated/**"],
        capture_output=True, text=True)
    return sorted(l for l in r.stdout.splitlines() if l.strip())

def refs(path):
    # full-path literal references (the only ones that need rewriting on move)
    r = subprocess.run(["rg", "-n", "--no-heading", "-F", path,
        "--glob", "!scc-by-file.csv", "--glob", "!repo-docs/**",
        "--glob", "!.git/**", "--glob", "!.ai-install-manifest.json"],
        capture_output=True, text=True)
    out = []
    for l in r.stdout.splitlines():
        if not l.strip():
            continue
        parts = l.split(":", 2)
        if len(parts) < 3:
            continue
        f, ln, txt = parts[0], parts[1], parts[2]
        if f == path:
            continue
        out.append((f, ln))
    return out

def is_kit(f):
    return (f.startswith(("docs/ai/", ".opencode/", "tools/ai/", "ops/ai/",
            ".schemas/", ".github/")) or f in ("AGENTS.md", "PLACEHOLDERS.md", "llms.txt"))

docs = list_docs()
manifest = []
for d in docs:
    rs = refs(d)
    repo = sorted({f for f, _ in rs if not is_kit(f)})
    kit = sorted({f for f, _ in rs if is_kit(f)})
    manifest.append({"path": d, "repo_referrers": repo, "kit_referrers": kit})

# Summary buckets
tier1 = [m for m in manifest if not m["repo_referrers"] and not m["kit_referrers"]]
tier2 = [m for m in manifest if m["repo_referrers"] and not m["kit_referrers"]]
tier3 = [m for m in manifest if m["kit_referrers"]]

print(f"docs files: {len(manifest)}")
print(f"Tier 1 (no refs):        {len(tier1)}")
print(f"Tier 2 (repo refs only): {len(tier2)}")
print(f"Tier 3 (has kit refs):   {len(tier3)}")
print()
print("=== TIER 3 (kit referrers — go stale, do NOT edit kit) ===")
for m in tier3:
    print(f"  {m['path']}")
    print(f"      kit:  {m['kit_referrers']}")
    print(f"      repo: {m['repo_referrers']}")
print()
print("=== Unique repo-owned files that need rewriting (across all tiers) ===")
allrepo = sorted({f for m in manifest for f in m["repo_referrers"]})
for f in allrepo:
    print(f"  {f}")

json.dump(manifest, open("/tmp/opencode/move-manifest.json", "w"), indent=2)
print("\nDetail -> /tmp/opencode/move-manifest.json")
