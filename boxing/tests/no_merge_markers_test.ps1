$ErrorActionPreference = 'Stop'

$scripts = @(
    'boxing/characters/fighter.gd',
    'boxing/characters/animation_factory.gd',
    'boxing/tests/fight_e2e.tscn'
)

$markers = '^(<<<<<<<|=======|>>>>>>>)'
$failures = @()
foreach ($script in $scripts) {
    $matches = Select-String -Path $script -Pattern $markers
    if ($matches) {
        $failures += "$script contains unresolved merge markers."
    }
}

if ($failures) {
    $failures | ForEach-Object { Write-Error $_ }
    exit 1
}

Write-Host 'No unresolved merge markers in checked combat resources.'
