<?php

declare(strict_types=1);

$root = realpath(__DIR__ . '/..' . '/..');
if ($root === false) {
    fwrite(STDERR, "ERROR: repository root not found\n");
    exit(1);
}

function hasBin(string $name): bool
{
    $output = [];
    $exit = 0;
    exec('command -v ' . escapeshellarg($name) . ' >/dev/null 2>&1', $output, $exit);
    return $exit === 0;
}

$scope = $argv[1] ?? '--all';

if (hasBin('gitleaks')) {
    $cmd = 'gitleaks detect --source ' . escapeshellarg($root) . ' --redact --no-banner';
    passthru($cmd, $exit);
    exit((int) $exit);
}

if (hasBin('trufflehog')) {
    $cmd = 'trufflehog git file://' . escapeshellarg($root) . ' --results=verified,unknown --fail';
    passthru($cmd, $exit);
    exit((int) $exit);
}

fwrite(STDOUT, "WARN: no secret scanner found (gitleaks/trufflehog). scope={$scope}\n");
exit(0);
