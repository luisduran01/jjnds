$ErrorActionPreference = 'Stop'

$source = Get-Content 'boxing/characters/fighter.gd' -Raw
if ($source -match 'Animations\.build') {
    Write-Error 'Fighter rebuilds animations instead of using the validated animation library in boxer_model.tscn.'
    exit 1
}
if ($source -notmatch 'visual\.get_node_or_null\("AnimationPlayer"\)') {
    Write-Error 'Fighter does not retrieve AnimationPlayer from boxer_model.tscn.'
    exit 1
}
if ($source -notmatch 'visual\.get_node_or_null\("AnimationTree"\)') {
    Write-Error 'Fighter does not retrieve AnimationTree from boxer_model.tscn.'
    exit 1
}

Write-Host 'Fighter uses the saved boxer animation library.'
