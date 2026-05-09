<?php

declare(strict_types=1);

require_once __DIR__ . '/session-log-lib.php';

try {
    $args = aiSessionParseArgs($argv);
    $root = aiSessionRepoRoot($args['root']);
    $sessionId = aiSessionId($args['session_id']);

    if (isset($args['options']['event-json']) && is_string($args['options']['event-json'])) {
        $decoded = json_decode($args['options']['event-json'], true);
        if (!is_array($decoded)) {
            throw new RuntimeException('event-json must decode to an object');
        }
        $decoded['session_id'] = aiSessionId((string) ($decoded['session_id'] ?? $sessionId));
        $dir = aiSessionAppendEvent($root, $decoded['session_id'], $decoded);
        fwrite(STDOUT, "OK: logged {$decoded['event_type']} to {$dir}\n");
        exit(0);
    }

    $details = [];
    if (isset($args['options']['details-json']) && is_string($args['options']['details-json'])) {
        $decoded = json_decode($args['options']['details-json'], true);
        if (!is_array($decoded)) {
            throw new RuntimeException('details-json must decode to an object or array');
        }
        $details = $decoded;
    }

    foreach (['summary', 'path', 'command', 'reason'] as $key) {
        if (isset($args['options'][$key]) && is_string($args['options'][$key])) {
            $details[$key] = $args['options'][$key];
        }
    }

    $event = aiSessionEvent([
        'event_type' => (string) ($args['options']['type'] ?? 'event'),
        'session_id' => $sessionId,
        'actor_id' => (string) ($args['options']['agent'] ?? 'ai-agent'),
        'tool_name' => (string) ($args['options']['tool'] ?? 'agent-log.php'),
        'tool_category' => $args['options']['category'] ?? null,
        'mutates_state' => isset($args['options']['mutates-state']),
        'authorization_decision' => (string) ($args['options']['authorization'] ?? 'unknown'),
        'execution_status' => (string) ($args['options']['status'] ?? 'unknown'),
        'exit_code' => isset($args['options']['exit-code']) ? (int) $args['options']['exit-code'] : null,
        'output_preview' => $args['options']['output-summary'] ?? null,
        'repository_root' => $root,
        'details' => $details,
    ]);

    $dir = aiSessionAppendEvent($root, $sessionId, $event);
    fwrite(STDOUT, "OK: logged {$event['event_type']} to {$dir}\n");
} catch (Throwable $e) {
    fwrite(STDERR, 'ERROR: ' . $e->getMessage() . PHP_EOL);
    exit(1);
}
