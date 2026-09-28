[CmdletBinding()]
param(
    [Parameter()]
    [string]$ProjectRoot = (Get-Location).Path,
    [Parameter()]
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem

$projectRootFull = [IO.Path]::GetFullPath($ProjectRoot)
$projectRootPrefix = $projectRootFull.TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
$archives = @('storage-files (1).zip', 'storage-files.zip') | ForEach-Object {
    $path = Join-Path $projectRootFull $_
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Required archive is missing: $path"
    }
    $path
}

$result = [ordered]@{
    copied = [System.Collections.Generic.List[string]]::new()
    skipped_existing = [System.Collections.Generic.List[string]]::new()
    excluded = [System.Collections.Generic.List[string]]::new()
    rejected = [System.Collections.Generic.List[string]]::new()
    overwrite_attempts = 0
    dry_run = [bool]$DryRun
}

function Get-NormalizedArchivePath([string]$EntryPath) {
    $path = $EntryPath.Replace('\\', '/')
    if ($path.StartsWith('workspace/jjnds/')) { return $path.Substring('workspace/jjnds/'.Length) }
    if ($path.StartsWith('jjnds/')) { return $path.Substring('jjnds/'.Length) }
    return $null
}

foreach ($archivePath in $archives) {
    $archive = [IO.Compression.ZipFile]::OpenRead($archivePath)
    try {
        foreach ($entry in $archive.Entries) {
            if ($entry.FullName.EndsWith('/')) { continue }
            $relative = Get-NormalizedArchivePath $entry.FullName
            if ([string]::IsNullOrWhiteSpace($relative)) {
                $result.rejected.Add($entry.FullName)
                continue
            }
            if ($relative -eq 'git-lfs' -or $relative -eq 'godot' -or $relative.StartsWith('.godot/') -or $relative.EndsWith('.import')) {
                $result.excluded.Add($relative)
                continue
            }
            $segments = $relative.Split('/')
            if ($segments | Where-Object { $_ -eq '..' -or $_ -eq '' }) {
                $result.rejected.Add($relative)
                continue
            }
            $destination = [IO.Path]::GetFullPath((Join-Path $projectRootFull ($relative.Replace('/', [IO.Path]::DirectorySeparatorChar))))
            if (-not $destination.StartsWith($projectRootPrefix, [StringComparison]::OrdinalIgnoreCase)) {
                $result.rejected.Add($relative)
                continue
            }
            if (Test-Path -LiteralPath $destination) {
                $result.skipped_existing.Add($relative)
                continue
            }
            $result.copied.Add($relative)
            if (-not $DryRun) {
                [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($destination)) | Out-Null
                $input = $entry.Open()
                try {
                    $output = [IO.File]::Open($destination, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
                    try { $input.CopyTo($output) } finally { $output.Dispose() }
                } finally { $input.Dispose() }
            }
        }
    } finally {
        $archive.Dispose()
    }
}

$manifestPath = Join-Path $projectRootFull 'docs/integrations/2026-09-27-storage-files-manifest.json'
if (-not $DryRun) {
    [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($manifestPath)) | Out-Null
    $result | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $manifestPath -Encoding utf8
}

$result | ConvertTo-Json -Depth 4
