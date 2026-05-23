<?php

declare(strict_types=1);

$root = realpath(__DIR__ . '/..' . '/..');
if ($root === false) {
    fwrite(STDERR, "ERROR: repository root not found\n");
    exit(1);
}

// Prefer the canonical kit dictionary; fall back to the root-level index
// shipped to installed projects via the package-source-pack so that an
// installed target without the full templates/ tree can still validate.
$placeholdersDoc = $root . '/packages/ai-universal-rules/PLACEHOLDERS.md';
if (!is_file($placeholdersDoc)) {
    $rootIndex = $root . '/PLACEHOLDERS.md';
    if (is_file($rootIndex)) {
        fwrite(STDOUT, "INFO: using root PLACEHOLDERS.md as fallback dictionary (installed target).\n");
        $placeholdersDoc = $rootIndex;
    } else {
        fwrite(STDERR, "ERROR: missing PLACEHOLDERS.md\n");
        exit(1);
    }
}

$doc = (string) file_get_contents($placeholdersDoc);
$documented = [];
if (preg_match_all('/`(<[A-Z0-9_]+>)`/', $doc, $m) === 1 || (!empty($m[1]))) {
    $documented = array_values(array_unique($m[1]));
}

$templatePaths = [];
$templatesRoot = $root . '/packages/ai-universal-rules/templates';
if (is_dir($templatesRoot)) {
    $it = new RecursiveIteratorIterator(new RecursiveDirectoryIterator($templatesRoot, FilesystemIterator::SKIP_DOTS));
    foreach ($it as $file) {
        if (!$file->isFile() || strtolower($file->getExtension()) !== 'md') {
            continue;
        }
        $templatePaths[] = $file->getPathname();
    }
} else {
    // Installed target without templates/. Treat as success at the kit-level
    // check; placeholder enforcement at the project level lives in
    // verify-install-placeholders.php (run against the target directly).
    fwrite(STDOUT, "INFO: templates/ not present (installed target); skipping kit-level template scan.\n");
}

$used = [];
foreach ($templatePaths as $path) {
    $content = (string) file_get_contents($path);
    if (preg_match_all('/<[A-Z0-9_]+>/', $content, $m2) === 1 || (!empty($m2[0]))) {
        $used = array_merge($used, $m2[0]);
    }
}
$used = array_values(array_unique($used));

$missing = array_values(array_diff($used, $documented));

if ($missing !== []) {
    foreach ($missing as $token) {
        fwrite(STDERR, "ERROR: undocumented placeholder token {$token}\n");
    }
    exit(1);
}

fwrite(STDOUT, "OK: placeholder registry covers template tokens\n");
exit(0);
