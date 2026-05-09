<?php

declare(strict_types=1);

require_once __DIR__ . '/session-log-lib.php';

try {
    $args = aiSessionParseArgs($argv);
    $root = aiSessionRepoRoot($args['root']);
    $target = $args['args'][0] ?? null;
    $sessions = [];

    if ($target !== null) {
        $path = is_dir($target) ? $target : aiSessionDir($root, (string) $target);
        $sessions[] = $path;
    } else {
        $base = $root . DIRECTORY_SEPARATOR . 'docs' . DIRECTORY_SEPARATOR . 'ai' . DIRECTORY_SEPARATOR . 'generated' . DIRECTORY_SEPARATOR . 'sessions';
        $sessions = is_dir($base) ? array_values(array_filter(glob($base . DIRECTORY_SEPARATOR . '*') ?: [], 'is_dir')) : [];
    }

    $errors = [];
    foreach ($sessions as $sessionDir) {
        $events = $sessionDir . DIRECTORY_SEPARATOR . 'events.jsonl';
        $summary = $sessionDir . DIRECTORY_SEPARATOR . 'summary.md';
        if (!is_file($events)) {
            $errors[] = "missing events.jsonl in {$sessionDir}";
            continue;
        }
        if (!is_file($summary)) {
            $errors[] = "missing summary.md in {$sessionDir}";
        }

        $lines = file($events, FILE_IGNORE_NEW_LINES) ?: [];
        foreach ($lines as $index => $line) {
            if (trim($line) === '') {
                continue;
            }
            $decoded = json_decode($line, true);
            if (!is_array($decoded)) {
                $errors[] = "invalid JSON at {$events}:" . ($index + 1);
                continue;
            }
            try {
                aiSessionValidateEvent($decoded);
            } catch (Throwable $e) {
                $errors[] = "invalid event at {$events}:" . ($index + 1) . ' - ' . $e->getMessage();
            }
        }
    }

    if ($errors !== []) {
        foreach ($errors as $error) {
            fwrite(STDERR, "ERROR: {$error}\n");
        }
        exit(1);
    }

    fwrite(STDOUT, 'OK: session log validation passed' . PHP_EOL);
} catch (Throwable $e) {
    fwrite(STDERR, 'ERROR: ' . $e->getMessage() . PHP_EOL);
    exit(1);
}
