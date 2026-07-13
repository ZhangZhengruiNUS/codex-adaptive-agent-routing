[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$CodexHome = $(if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $HOME '.codex' }),
    [switch]$SkipConfig
)

$ErrorActionPreference = 'Stop'
$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$RepoRoot = Split-Path -Parent $PSScriptRoot
$CodexHome = [System.IO.Path]::GetFullPath($CodexHome)
$AgentHome = Join-Path $CodexHome 'agents'
$Timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$BackupRoot = Join-Path $CodexHome "backups\codex-adaptive-agent-routing-$Timestamp"

function Write-Utf8NoBom {
    param([string]$Path, [string]$Content)
    $parent = Split-Path -Parent $Path
    if ($parent) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
    [System.IO.File]::WriteAllText($Path, $Content, $Utf8NoBom)
}

function Set-TomlKey {
    param([string]$Text, [string]$Key, [string]$Value)
    $pattern = '(?m)^[ \t]*' + [regex]::Escape($Key) + '[ \t]*=.*$'
    $regex = [regex]::new($pattern)
    $replacement = "$Key = $Value"
    if ($regex.IsMatch($Text)) {
        return $regex.Replace($Text, $replacement, 1)
    }
    if ([string]::IsNullOrWhiteSpace($Text)) {
        return "$replacement`r`n"
    }
    return $Text.TrimEnd() + "`r`n$replacement`r`n"
}

function Merge-CodexConfig {
    param([string]$Existing)

    $firstSection = [regex]::Match($Existing, '(?m)^[ \t]*\[')
    if ($firstSection.Success) {
        $prefix = $Existing.Substring(0, $firstSection.Index)
        $suffix = $Existing.Substring($firstSection.Index)
    } else {
        $prefix = $Existing
        $suffix = ''
    }

    $prefix = Set-TomlKey $prefix 'model' '"gpt-5.6-terra"'
    $prefix = Set-TomlKey $prefix 'model_reasoning_effort' '"high"'
    if ($suffix) {
        $merged = $prefix.TrimEnd() + "`r`n`r`n" + $suffix.TrimStart()
    } else {
        $merged = $prefix
    }

    $agentsPattern = '(?ms)^[ \t]*\[agents\][ \t]*(?:\r?\n|$)(?<body>.*?)(?=^[ \t]*\[|\z)'
    $agentsMatch = [regex]::Match($merged, $agentsPattern)
    if ($agentsMatch.Success) {
        $body = $agentsMatch.Groups['body'].Value
        $body = Set-TomlKey $body 'max_threads' '4'
        $body = Set-TomlKey $body 'max_depth' '1'
        $newSection = "[agents]`r`n" + $body.Trim() + "`r`n`r`n"
        $merged = $merged.Substring(0, $agentsMatch.Index) + $newSection +
            $merged.Substring($agentsMatch.Index + $agentsMatch.Length)
    } else {
        $merged = $merged.TrimEnd() + "`r`n`r`n[agents]`r`nmax_threads = 4`r`nmax_depth = 1`r`n"
    }
    return $merged
}

$relativeTargets = @(
    'AGENTS.md',
    'agents\fast-reader.toml',
    'agents\explorer.toml',
    'agents\worker.toml',
    'agents\deep-reviewer.toml'
)
if (-not $SkipConfig) { $relativeTargets += 'config.toml' }

if (-not $PSCmdlet.ShouldProcess($CodexHome, 'Install adaptive Codex routing configuration')) {
    return
}

New-Item -ItemType Directory -Force -Path $CodexHome, $AgentHome, $BackupRoot | Out-Null
$manifest = foreach ($relative in $relativeTargets) {
    $target = Join-Path $CodexHome $relative
    $existed = Test-Path -LiteralPath $target
    if ($existed) {
        $backup = Join-Path $BackupRoot $relative
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $backup) | Out-Null
        Copy-Item -LiteralPath $target -Destination $backup -Force
    }
    [pscustomobject]@{ relative_path = $relative; existed = $existed }
}
Write-Utf8NoBom (Join-Path $BackupRoot 'manifest.json') ($manifest | ConvertTo-Json)

$startMarker = '<!-- codex-adaptive-agent-routing:start -->'
$endMarker = '<!-- codex-adaptive-agent-routing:end -->'
$routing = [System.IO.File]::ReadAllText((Join-Path $RepoRoot 'templates\AGENTS.md'))
$managedBlock = $startMarker + "`r`n" + $routing.Trim() + "`r`n" + $endMarker
$agentsMdPath = Join-Path $CodexHome 'AGENTS.md'
if (Test-Path -LiteralPath $agentsMdPath) {
    $existingAgentsMd = [System.IO.File]::ReadAllText($agentsMdPath)
    $start = $existingAgentsMd.IndexOf($startMarker)
    $end = $existingAgentsMd.IndexOf($endMarker)
    if ($start -ge 0 -and $end -ge $start) {
        $end += $endMarker.Length
        $newAgentsMd = $existingAgentsMd.Substring(0, $start) + $managedBlock + $existingAgentsMd.Substring($end)
    } else {
        $newAgentsMd = $existingAgentsMd.TrimEnd() + "`r`n`r`n" + $managedBlock + "`r`n"
    }
} else {
    $newAgentsMd = $managedBlock + "`r`n"
}
Write-Utf8NoBom $agentsMdPath $newAgentsMd

foreach ($name in @('fast-reader.toml', 'explorer.toml', 'worker.toml', 'deep-reviewer.toml')) {
    Copy-Item -LiteralPath (Join-Path $RepoRoot "agents\$name") -Destination (Join-Path $AgentHome $name) -Force
}

if (-not $SkipConfig) {
    $configPath = Join-Path $CodexHome 'config.toml'
    if (Test-Path -LiteralPath $configPath) {
        $config = [System.IO.File]::ReadAllText($configPath)
        $config = Merge-CodexConfig $config
    } else {
        $config = [System.IO.File]::ReadAllText((Join-Path $RepoRoot 'config.example.toml'))
    }
    Write-Utf8NoBom $configPath $config
}

Write-Host "Installed adaptive routing into: $CodexHome"
Write-Host "Backup and restore manifest: $BackupRoot"
Write-Host 'Restart Codex App and start a new task to load the configuration.'
