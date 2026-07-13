[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $true)]
    [string]$BackupPath,
    [string]$CodexHome = $(if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $HOME '.codex' })
)

$ErrorActionPreference = 'Stop'
$BackupPath = [System.IO.Path]::GetFullPath($BackupPath)
$CodexHome = [System.IO.Path]::GetFullPath($CodexHome)
$manifestPath = Join-Path $BackupPath 'manifest.json'
if (-not (Test-Path -LiteralPath $manifestPath)) {
    throw "Restore manifest not found: $manifestPath"
}

$homePrefix = $CodexHome.TrimEnd('\') + '\'
$manifest = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json
if (-not $PSCmdlet.ShouldProcess($CodexHome, "Restore Codex files from $BackupPath")) {
    return
}

foreach ($entry in $manifest) {
    $target = [System.IO.Path]::GetFullPath((Join-Path $CodexHome $entry.relative_path))
    if (-not $target.StartsWith($homePrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Unsafe restore target outside Codex home: $target"
    }
    if ($entry.existed) {
        $source = Join-Path $BackupPath $entry.relative_path
        if (-not (Test-Path -LiteralPath $source)) { throw "Backup file missing: $source" }
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $target) | Out-Null
        Copy-Item -LiteralPath $source -Destination $target -Force
    } elseif (Test-Path -LiteralPath $target) {
        Remove-Item -LiteralPath $target -Force
    }
}

Write-Host "Restored Codex configuration from: $BackupPath"
Write-Host 'Restart Codex App and start a new task to reload the configuration.'
