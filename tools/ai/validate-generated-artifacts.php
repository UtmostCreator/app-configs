<?php

declare(strict_types=1);

$root = realpath(__DIR__ . '/..' . '/..');
if ($root === false) {
    fwrite(STDERR, "ERROR: repository root not found\n");
    exit(1);
}

$required = [
    'docs/ai/catalog.md' => 'php tools/ai/generate-ai-catalog.php --check',
    'packages/ai-universal-rules/catalog.json' => 'php tools/ai/generate-ai-catalog.php --check',
    'packages/ai-universal-rules/docs/BROWSE.md' => 'php tools/ai/generate-ai-catalog.php --check',
    'llms.txt' => 'php tools/ai/generate-ai-catalog.php --check',
    'docs/ai/repo-required-tools.md' => 'bash scripts/ai/repo-tool-inventory.sh',
];

$errors = [];

foreach ($required as $path => $generator) {
    if (!is_file($root . '/' . $path)) {
        $errors[] = "missing generated artifact {$path} (generator: {$generator})";
    }
}

$runCheck = !in_array('--existence-only', $argv, true);

if ($runCheck) {
    $phpBin = defined('PHP_BINARY') ? (string) PHP_BINARY : 'php';
    $checkCmd = escapeshellarg($phpBin) . ' tools/ai/generate-ai-catalog.php --check';
    $output = [];
    $exit = 0;
    exec('cd ' . escapeshellarg($root) . ' && ' . $checkCmd . ' 2>&1', $output, $exit);
    if ($exit !== 0) {
        $errors[] = 'generated artifact drift detected by generate-ai-catalog --check';
        foreach ($output as $line) {
            fwrite(STDERR, "CHECK: {$line}\n");
        }
    }

    $toolsCheckCmd = 'bash scripts/ai/repo-tool-inventory.sh --check';
    $toolsOutput = [];
    $toolsExit = 0;
    exec('cd ' . escapeshellarg($root) . ' && ' . $toolsCheckCmd . ' 2>&1', $toolsOutput, $toolsExit);
    if ($toolsExit !== 0) {
        $errors[] = 'generated artifact drift detected by repo-tool-inventory --check';
        foreach ($toolsOutput as $line) {
            fwrite(STDERR, "CHECK: {$line}\n");
        }
    }
}

if ($errors !== []) {
    foreach ($errors as $error) {
        fwrite(STDERR, "ERROR: {$error}\n");
    }
    exit(1);
}

fwrite(STDOUT, "OK: generated artifact baseline present\n");
exit(0);
