$ErrorActionPreference = 'Stop'

$source = Get-Content 'boxing/characters/fighter.gd' -Raw
$attack = [regex]::Match($source, '(?s)func attack\(punch: String\) -> bool:.*?\nfunc plan_punch_step')
if (-not $attack.Success) {
    Write-Error 'Could not locate Fighter.attack.'
    exit 1
}
if ($attack.Value -notmatch 'parameters/UpperBody/blend_amount",\s*1\.0') {
    Write-Error 'Starting a punch does not blend the saved upper-body animation in.'
    exit 1
}

Write-Host 'Punches blend the saved upper-body animation in.'
