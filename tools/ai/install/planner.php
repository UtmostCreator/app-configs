<?php

declare(strict_types=1);

function aiInstallerBuildPlan(array $config, array $packRegistry, array $packs): array
{
    $plan = [];
    foreach ($packs as $packId) {
        foreach ($packRegistry[$packId] ?? [] as $item) {
            $target = $item['target'];
            $absTarget = $config['targetRoot'] . DIRECTORY_SEPARATOR . str_replace('/', DIRECTORY_SEPARATOR, $target);
            $exists = file_exists($absTarget);
            $action = 'CREATE';
            if ($exists && !$config['force']) {
                $action = 'SKIP_EXISTING_UNMANAGED';
            } elseif ($exists && $config['force']) {
                $action = 'OVERWRITE_MANAGED';
            }
            if ($exists && $config['force'] && (($item['core'] ?? false) === true) && !$config['allowCoreOverwrite']) {
                $action = 'SKIP_PROTECTED_CORE';
            }

            $plan[] = array_merge($item, [
                'pack' => $packId,
                'type' => $item['type'],
                'source' => $item['source'],
                'target' => $target,
                'action' => $action,
                'required' => (bool) ($item['required'] ?? true),
                'merge_strategy' => (string) ($item['merge_strategy'] ?? ($config['force'] ? 'replace' : 'skip-if-exists')),
                'reason' => $exists ? 'target exists' : 'target missing',
            ]);
        }
    }
    return $plan;
}
