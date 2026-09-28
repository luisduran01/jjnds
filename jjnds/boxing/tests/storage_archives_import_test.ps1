$ErrorActionPreference = 'Stop'

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\\..')).Path
$importer = Join-Path $projectRoot 'tools\\integrate_storage_archives.ps1'
$result = & $importer -ProjectRoot $projectRoot -DryRun | ConvertFrom-Json

if ($result.overwrite_attempts -ne 0) {
    throw "Expected zero overwrite attempts, got $($result.overwrite_attempts)."
}
if (@($result.rejected | Where-Object { $_ -match '^workspace \(2\)/(git-lfs|godot)$' }).Count -ne 2) {
    throw 'Expected unexpected archive roots and their executables to be rejected.'
}
if (@($result.excluded | Where-Object { $_ -match '(^|/)\.godot/' -or $_ -match '\.import$' }).Count -eq 0) {
    throw 'Expected Godot cache and import metadata to be excluded.'
}
if (@($result.copied | Where-Object { $_ -match '(^|/)\.\.(/|$)' }).Count -ne 0) {
    throw 'Traversal path reached the copy list.'
}
if (@($result.copied | Where-Object { $_ -match '^jjnds/' -or $_ -match '^workspace/jjnds/' }).Count -ne 0) {
    throw 'Archive project roots were not normalized.'
}

Write-Output "PASS: storage archive dry-run policy ($($result.copied.Count) new entries)."
