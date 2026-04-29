# Env check

- Status: `warning`
- Generated at: `2026-04-29T00:34:18+00:00`
- Commit: `92d5dbc`
- Branch: `main`
- Recommended next action: `Install missing required tools before running full workflow.`

```json
{
    "schema_version": 1,
    "artifact": "env-check.json",
    "generated_at": "2026-04-29T00:34:18+00:00",
    "command": "php tools/ai/ai.php env-check",
    "based_on_commit": "92d5dbc",
    "based_on_branch": "main",
    "input_hashes": {},
    "status": "warning",
    "score": null,
    "stale": false,
    "recommended_next_action": "Install missing required tools before running full workflow.",
    "data": {
        "required": [
            {
                "tool": "bash",
                "found": true,
                "path": "C:\\Program Files\\Git\\usr\\bin\\bash.exe"
            },
            {
                "tool": "git",
                "found": true,
                "path": "C:\\Program Files\\Git\\mingw64\\bin\\git.exe"
            },
            {
                "tool": "php",
                "found": true,
                "path": "C:\\Users\\UC-LL5S\\AppData\\Local\\Microsoft\\WinGet\\Packages\\PHP.PHP.8.5_Microsoft.Winget.Source_8wekyb3d8bbwe\\php.exe"
            },
            {
                "tool": "rg",
                "found": false,
                "path": null
            }
        ],
        "context_required": [
            {
                "tool": "repomix",
                "found": true,
                "path": "C:\\Users\\UC-LL5S\\AppData\\Roaming\\npm\\repomix"
            },
            {
                "tool": "scc",
                "found": true,
                "path": "C:\\Users\\UC-LL5S\\AppData\\Local\\Microsoft\\WinGet\\Packages\\BenBoyter.scc_Microsoft.Winget.Source_8wekyb3d8bbwe\\scc.exe"
            },
            {
                "tool": "jq",
                "found": false,
                "path": null
            }
        ],
        "optional": [
            {
                "tool": "just",
                "found": false,
                "path": null
            },
            {
                "tool": "yq",
                "found": false,
                "path": null
            },
            {
                "tool": "shellcheck",
                "found": false,
                "path": null
            },
            {
                "tool": "shfmt",
                "found": false,
                "path": null
            },
            {
                "tool": "actionlint",
                "found": false,
                "path": null
            },
            {
                "tool": "lychee",
                "found": false,
                "path": null
            },
            {
                "tool": "gitleaks",
                "found": false,
                "path": null
            }
        ],
        "missing_required": [
            "rg"
        ]
    }
}
```
