[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$RunFolder
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $RunFolder)) {
    throw "detect-tests: run folder does not exist: $RunFolder"
}

$repoRoot = (& git rev-parse --show-toplevel 2>$null)
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($repoRoot)) {
    $repoRoot = (Get-Location).Path
} else {
    $repoRoot = $repoRoot.Trim()
}

function Test-RepoPath {
    param([string]$Relative)
    Test-Path -LiteralPath (Join-Path $repoRoot $Relative)
}

$playwrightCandidates = @(
    'playwright.config.ts',
    'playwright.config.js',
    'playwright.config.mjs',
    'playwright.config.cjs'
)
$playwrightFound = @($playwrightCandidates | Where-Object { Test-RepoPath $_ })

$detected = [ordered]@{
    repoRoot          = $repoRoot
    packageJson       = [bool](Test-RepoPath 'package.json')
    pnpmLock          = [bool](Test-RepoPath 'pnpm-lock.yaml')
    pytestIni         = [bool](Test-RepoPath 'pytest.ini')
    pyprojectToml     = [bool](Test-RepoPath 'pyproject.toml')
    testsFolder       = [bool](Test-RepoPath 'tests')
    playwrightConfigs = $playwrightFound
}

# JSON output
$jsonPath = Join-Path $RunFolder 'detected-tests.json'
($detected | ConvertTo-Json -Depth 4) | Out-File -FilePath $jsonPath -Encoding utf8

# Markdown output
$lines = @()
$lines += '# Detected Tests'
$lines += ''
$lines += "- repo root: $repoRoot"
$lines += "- package.json: $($detected.packageJson)"
$lines += "- pnpm-lock.yaml: $($detected.pnpmLock)"
$lines += "- pytest.ini: $($detected.pytestIni)"
$lines += "- pyproject.toml: $($detected.pyprojectToml)"
$lines += "- tests/ folder: $($detected.testsFolder)"
if ($playwrightFound.Count -gt 0) {
    $lines += "- Playwright config: $($playwrightFound -join ', ')"
} else {
    $lines += '- Playwright config: (none found)'
}
$lines += ''
$lines += '_Phase 1: no dependencies installed, no tests executed._'

$mdPath = Join-Path $RunFolder 'detected-tests.md'
($lines -join [Environment]::NewLine) | Out-File -FilePath $mdPath -Encoding utf8

Write-Host ("[detect-tests] pkg={0} pnpm={1} pytest={2} pyproject={3} tests={4} playwright={5}" -f `
    $detected.packageJson, $detected.pnpmLock, $detected.pytestIni, $detected.pyprojectToml, $detected.testsFolder, $playwrightFound.Count)
Write-Host "[detect-tests] artifacts written under $RunFolder"
