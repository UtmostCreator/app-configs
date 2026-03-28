<?php

declare(strict_types=1);

require_once __DIR__ . '/ai_catalog_lib.php';

$root = aiRepoRoot();
$errors = [];
$warnings = [];
$manifest = aiLoadJson($root, 'AI-universal-rules/manifest.json');

foreach (aiValidateManifest($manifest, $root) as $error) {
    $errors[] = $error;
}

$yamlSummary = aiReadManifestYamlSummary($root);

foreach (['name', 'version', 'description'] as $key) {
    if (($yamlSummary[$key] ?? null) !== ($manifest[$key] ?? null)) {
        $errors[] = "manifest.yml and manifest.json disagree on {$key}";
    }
}

$catalog = aiLoadJson($root, 'AI-universal-rules/catalog.json');

foreach (['generated_by', 'repository', 'package', 'counts', 'resources', 'starter_profiles'] as $key) {
    if (!array_key_exists($key, $catalog)) {
        $errors[] = "catalog.json missing {$key}";
    }
}

foreach ($catalog['resources'] ?? [] as $resource) {
    if (!is_array($resource)) {
        $errors[] = 'catalog.json resources entries must be objects';
        continue;
    }

    foreach (['scope', 'type', 'name', 'path'] as $requiredKey) {
        if (!array_key_exists($requiredKey, $resource)) {
            $errors[] = "catalog.json resource missing {$requiredKey}";
        }
    }

    if (isset($resource['path']) && !file_exists(aiAbsolutePath($root, $resource['path']))) {
        $errors[] = "catalog.json references missing resource {$resource['path']}";
    }
}

foreach ($manifest['generated_outputs'] ?? [] as $path) {
    if (!file_exists(aiAbsolutePath($root, $path))) {
        $errors[] = "generated output missing {$path}";
    }
}

if (($catalog['package']['version'] ?? null) !== ($manifest['version'] ?? null)) {
    $errors[] = 'catalog.json package version does not match manifest.json';
}

if ($errors === [] && $warnings === []) {
    fwrite(STDOUT, "OK: AI catalog metadata validation passed\n");
}

foreach ($warnings as $warning) {
    fwrite(STDOUT, "WARN: {$warning}\n");
}

foreach ($errors as $error) {
    fwrite(STDERR, "ERROR: {$error}\n");
}

exit($errors === [] ? 0 : 1);
