# File context

- Status: `ok`
- Generated at: `2026-04-29T00:30:45+00:00`
- Commit: `92d5dbc`
- Branch: `main`
- Recommended next action: `Read this file first, then open top related references if needed.`

```json
{
    "schema_version": 1,
    "artifact": "file-context.json",
    "generated_at": "2026-04-29T00:30:45+00:00",
    "command": "php tools/ai/ai.php file-context tools/ai/ai.php",
    "based_on_commit": "92d5dbc",
    "based_on_branch": "main",
    "input_hashes": {},
    "status": "ok",
    "score": null,
    "stale": false,
    "recommended_next_action": "Read this file first, then open top related references if needed.",
    "data": {
        "target": "tools/ai/ai.php",
        "bytes": 53236,
        "lines": 1433,
        "estimated_tokens": 13309,
        "related_references_preview": [
            "tests/php/CliToolsTest.php:171:    // ---- ai.php foundational workflow commands ----",
            "tests/php/CliToolsTest.php:175:        $result = $this->runTool('php tools/ai/ai.php list');",
            "tests/php/CliToolsTest.php:176:        $this->assertSame(0, $result['exit'], \"ai.php list exited non-zero:\\n\" . $result['stderr']);",
            "tests/php/CliToolsTest.php:181:        $result = $this->runTool('php tools/ai/ai.php snapshot');",
            "tests/php/CliToolsTest.php:182:        $this->assertSame(0, $result['exit'], \"ai.php snapshot exited non-zero:\\n\" . $result['stderr']);",
            "tests/php/CliToolsTest.php:187:        $result = $this->runTool('php tools/ai/ai.php freshness');",
            "tests/php/CliToolsTest.php:188:        $this->assertSame(0, $result['exit'], \"ai.php freshness exited non-zero:\\n\" . $result['stderr']);",
            "tests/php/CliToolsTest.php:193:        $result = $this->runTool('php tools/ai/ai.php diff-summary --base main');",
            "tests/php/CliToolsTest.php:194:        $this->assertSame(0, $result['exit'], \"ai.php diff-summary exited non-zero:\\n\" . $result['stderr']);",
            "tests/php/CliToolsTest.php:199:        $result = $this->runTool('php tools/ai/ai.php risk --base main');",
            "tests/php/CliToolsTest.php:200:        $this->assertSame(0, $result['exit'], \"ai.php risk exited non-zero:\\n\" . $result['stderr']);",
            "tests/php/CliToolsTest.php:205:        $result = $this->runTool('php tools/ai/ai.php verify --changed');",
            "tests/php/CliToolsTest.php:209:            \"ai.php verify exited with unexpected code:\\n\" . $result['stderr']",
            "tests/php/CliToolsTest.php:215:        $result = $this->runTool('php tools/ai/ai.php next');",
            "tests/php/CliToolsTest.php:219:            \"ai.php next exited with unexpected code:\\n\" . $result['stderr']",
            "tests/php/CliToolsTest.php:225:        $result = $this->runTool('php tools/ai/ai.php env-check');",
            "tests/php/CliToolsTest.php:226:        $this->assertSame(0, $result['exit'], \"ai.php env-check exited non-zero:\\n\" . $result['stderr']);",
            "tests/php/CliToolsTest.php:231:        $result = $this->runTool('php tools/ai/ai.php impact --base main');",
            "tests/php/CliToolsTest.php:232:        $this->assertSame(0, $result['exit'], \"ai.php impact exited non-zero:\\n\" . $result['stderr']);"
        ],
        "content_preview": "<?php\n\ndeclare(strict_types=1);\n\nrequire_once __DIR__ . '/ai_output_lib.php';\n\nfunction aiUsage(): void\n{\n    $usage = <<<'TXT'\nUsage:\n  php tools/ai/ai.php <command> [options]\n\nCommands:\n  list           List available AI workflow commands\n  diff-summary   Summarize current branch diff and changed files\n  risk           Score changed-slice risk using deterministic rules\n  verify         Run repository AI verification digest\n  next           Recommend the next required action\n  rebase-state   Run snapshot->diff->risk->verify->freshness->budget->next\n  decision       Add architecture/workflow decision records\n  why            Show decision rationale history\n  session-resume Build concise continuation summary from artifacts\n  commit-msg     Generate commit message suggestion from artifacts\n  pr-summary     Generate PR summary from artifacts\n  logs           List or read generated verify logs\n  env-check      Report environment/tooling readiness for AI workflow scripts\n  file-context   Build focused context artifact for one file\n  orphans        Detect possibly unreferenced/orphan workflow files\n  auto-fix       Preview deterministic safe fixes (dry-run only)\n  impact         Generate deterministic change impact map\n  ask            Record structured blocking clarification questions\n  estimate       Estimate task complexity/risk with deterministic heuristics\n  conflicts      Summarize merge conflict state and suggested resolution posture\n  freshness      Evaluate generated artifact freshness\n  budget         Estimate context token budget from generated artifacts\n  workflow       Show workflow dependency graph summary\n  snapshot       Generate current repository snapshot\n  help           Show this help\n\nExamples:\n  php tools/ai/ai.php list\n  php tools/ai/ai.php freshness\n  php tools/ai/ai.php budget --context-window 32000\n  php tools/ai/ai.php workflow\n  php tools/ai/ai.php snapshot\n  php tools/ai/ai.php diff-summary --base main\n  php tools/ai/ai.php risk --base main\n  php tools/ai/ai.php verify --changed\n  php tools/ai/ai.php next\n  php tools/ai/ai.php rebase-state\n  php tools/ai/ai.php decision add --file tools/ai/ai.php --reason \"added workflow dispatcher\"\n  php tools/ai/ai.php why\n  php tools/ai/ai.php session-resume\n  php tools/ai/ai.php commit-msg\n  php tools/ai/ai.php pr-summary\n  php tools/ai/ai.php logs\n  php tools/ai/ai.php env-check\n  php tools/ai/ai.php file-context tools/ai/ai.php\n  php tools/ai/ai.php orphans\n  php tools/ai/ai.php auto-fix --dry-run\n  php tools/ai/ai.php impact --base main\n  php tools/ai/ai.php ask \"Which runtime adapter is in scope?\" --options \"copilot,opencode,both\" --default both\n  php tools/ai/ai.php estimate \"add workflow-control command\"\n  php tools/ai/ai.php conflicts\nTXT;\n\n    fwrite(STDOUT, $usage . PHP_EOL);\n}\n\nfunction aiRunList(string $root): int\n{\n    $data = [\n        'commands' => [\n            'list',\n            'freshness',\n            'budget',\n            'workflow',\n            'snapshot',\n            'diff-summary',\n            'risk',\n            'verify',\n            'next',\n            'rebase-state',\n            'decision',\n            'why',\n            'session-resume',\n            'commit-msg',\n            'pr-summary',\n            'logs',\n            'env-check',\n            'file-context',\n            'orphans',\n            'auto-fix',\n            'impact',\n            'ask',\n            'estimate',\n            'conflicts',\n        ],\n    ];\n\n    $written = aiCliWriteArtifact($root, 'ai-commands', 'php tools/ai/ai.php list', $data, 'ok');\n    fwrite(STDOUT, \"OK: wrote {$written['json']} and {$written['markdown']}\" . PHP_EOL);\n    return 0;\n}\n\nfunction aiRunCommand(string $root, string $command): array\n{\n    $descriptors = [\n        0 => ['pipe', 'r'],\n        1 => ['pipe', 'w'],\n        2 => ['pipe', 'w'],\n    ];\n\n    $env = [\n        'HOME' => sys_get_temp_dir(),\n        'XDG_CONFIG_HOME' => sys_get_temp_dir(),\n        'GIT_CONFIG_GLOBAL' => '/dev/null',\n        'PATH'"
    }
}
```
