[CmdletBinding()]
param(
    [string]$CodexHome = $(if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $HOME '.codex' })
)

$ErrorActionPreference = 'Stop'
$required = @(
    'AGENTS.md',
    'config.toml',
    'agents\fast-reader.toml',
    'agents\explorer.toml',
    'agents\worker.toml',
    'agents\deep-reviewer.toml'
)
$errors = @()
foreach ($relative in $required) {
    $path = Join-Path $CodexHome $relative
    if (-not (Test-Path -LiteralPath $path)) { $errors += "Missing: $path" }
}

if ($errors.Count -eq 0) {
    $config = Get-Content -Raw -LiteralPath (Join-Path $CodexHome 'config.toml')
    foreach ($pattern in @(
        '(?m)^model\s*=\s*"gpt-5\.6-terra"\s*$',
        '(?m)^model_reasoning_effort\s*=\s*"high"\s*$',
        '(?m)^max_threads\s*=\s*4\s*$',
        '(?m)^max_depth\s*=\s*1\s*$'
    )) {
        if ($config -notmatch $pattern) { $errors += "Config pattern not found: $pattern" }
    }
}

if ($errors.Count -gt 0) {
    $errors | ForEach-Object { Write-Error $_ }
    exit 1
}

Write-Host "PASS: adaptive Codex routing files are installed under $CodexHome"
