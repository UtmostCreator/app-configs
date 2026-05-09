<?php

declare(strict_types=1);

require_once __DIR__ . '/session-log-lib.php';

try {
    $args = aiSessionParseArgs($argv);
    $root = aiSessionRepoRoot($args['root']);
    $sessionId = aiSessionId($args['session_id']);
    $task = (string) ($args['options']['task'] ?? 'unknown');
    $agent = (string) ($args['options']['agent'] ?? 'ai-agent');

    $event = aiSessionEvent([
        'event_type' => 'session.start',
        'session_id' => $sessionId,
        'actor_id' => $agent,
        'tool_name' => 'session-start.php',
        'execution_status' => 'success',
        'repository_root' => $root,
        'details' => ['task' => $task, 'cwd' => getcwd()],
    ]);
    $dir = aiSessionAppendEvent($root, $sessionId, $event);
    aiSessionWriteSummary($root, $sessionId, 'started', 'Continue task: ' . $task, []);
    fwrite(STDOUT, "OK: session started {$sessionId} at {$dir}\n");
} catch (Throwable $e) {
    fwrite(STDERR, 'ERROR: ' . $e->getMessage() . PHP_EOL);
    exit(1);
}
