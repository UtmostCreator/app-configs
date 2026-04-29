<?php

declare(strict_types=1);

$root = realpath(__DIR__ . '/..' . '/..');
if ($root === false) {
    fwrite(STDERR, "ERROR: repository root not found\n");
    exit(1);
}

$required = [
    'docs/ai/catalog.md' => 'php tools/ai/generate-ai-catalog.php',
    'packages/ai-universal-rules/catalog.json' => 'php tools/ai/generate-ai-catalog.php',
    'packages/ai-universal-rules/docs/BROWSE.md' => 'php tools/ai/generate-ai-catalog.php',
    'llms.txt' => 'php tools/ai/generate-ai-catalog.php',
];

$errors = [];

foreach ($required as $path => $generator) {
    if (!is_file($root . '/' . $path)) {
        $errors[] = "missing generated artifact {$path} (generator: {$generator})";
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
