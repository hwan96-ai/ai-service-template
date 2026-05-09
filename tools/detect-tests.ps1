[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$RunFolder
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $RunFolder)) {
    throw "detect-tests: run folder does not exist: $RunFolder"
}

$repoRootRaw = (& git rev-parse --show-toplevel 2>$null)
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($repoRootRaw)) {
    $repoRoot = (Get-Location).Path
} else {
    $repoRoot = $repoRootRaw.Trim()
}

$detectedStacks = New-Object System.Collections.ArrayList
$testCommands   = New-Object System.Collections.ArrayList
$warnings       = New-Object System.Collections.ArrayList

function Add-Stack {
    param([string]$Name)
    if (-not $detectedStacks.Contains($Name)) {
        [void]$detectedStacks.Add($Name)
    }
}

function Add-Warning {
    param([string]$Message)
    [void]$warnings.Add($Message)
}

function Test-RepoSubPath {
    param([string]$Relative)
    return Test-Path -LiteralPath (Join-Path $repoRoot $Relative)
}

function Get-PackageJson {
    param([string]$AbsolutePath)
    if (-not (Test-Path -LiteralPath $AbsolutePath)) { return $null }
    try {
        $raw = Get-Content -LiteralPath $AbsolutePath -Raw -ErrorAction Stop
        if ([string]::IsNullOrWhiteSpace($raw)) { return $null }
        return ($raw | ConvertFrom-Json -ErrorAction Stop)
    } catch {
        Add-Warning ("Could not parse package.json at {0}: {1}" -f $AbsolutePath, $_.Exception.Message)
        return $null
    }
}

function Get-PlaywrightConfigsIn {
    param([string]$RelativeDir)
    $candidates = @(
        'playwright.config.ts',
        'playwright.config.js',
        'playwright.config.mjs',
        'playwright.config.cjs'
    )
    $found = @()
    foreach ($c in $candidates) {
        $rel = if ([string]::IsNullOrEmpty($RelativeDir)) { $c } else { (Join-Path $RelativeDir $c) }
        if (Test-RepoSubPath $rel) { $found += $rel }
    }
    return ,$found
}

function Add-Command {
    param(
        [string]$Id,
        [string]$Name,
        [string]$WorkingDirectory,
        [string]$Command,
        [string]$Level,
        [bool]$SafeByDefault,
        [string]$Reason
    )
    $obj = [ordered]@{
        id               = $Id
        name             = $Name
        workingDirectory = $WorkingDirectory
        command          = $Command
        level            = $Level
        safeByDefault    = $SafeByDefault
        reason           = $Reason
    }
    [void]$testCommands.Add($obj)
}

function Inspect-NodeProject {
    param(
        [string]$RelativeDir,   # '' for root
        [string]$Label          # 'root', 'frontend', 'backend'
    )
    $pkgRel = if ([string]::IsNullOrEmpty($RelativeDir)) { 'package.json' } else { (Join-Path $RelativeDir 'package.json') }
    $pkgAbs = Join-Path $repoRoot $pkgRel
    if (-not (Test-Path -LiteralPath $pkgAbs)) { return }

    $pkg = Get-PackageJson -AbsolutePath $pkgAbs
    if ($null -eq $pkg) { return }

    $usePnpm = $false
    $rootPnpmLock = Join-Path $repoRoot 'pnpm-lock.yaml'
    $localPnpmLock = if ([string]::IsNullOrEmpty($RelativeDir)) { $rootPnpmLock } else { Join-Path $repoRoot (Join-Path $RelativeDir 'pnpm-lock.yaml') }
    if ((Test-Path -LiteralPath $localPnpmLock) -or (Test-Path -LiteralPath $rootPnpmLock)) {
        $usePnpm = $true
    }

    $runner = if ($usePnpm) { 'pnpm' } else { 'npm' }
    $stackTag = if ($usePnpm) { 'node-pnpm' } else { 'node-npm' }
    Add-Stack ("{0}:{1}" -f $stackTag, $Label)

    $workDir = if ([string]::IsNullOrEmpty($RelativeDir)) { '.' } else { $RelativeDir }
    $idPrefix = if ([string]::IsNullOrEmpty($RelativeDir)) { 'root' } else { ($RelativeDir -replace '[\\/]', '-') }

    $scripts = $null
    if ($pkg.PSObject.Properties.Name -contains 'scripts' -and $null -ne $pkg.scripts) {
        $scripts = $pkg.scripts
    }
    if ($null -eq $scripts) {
        Add-Warning ("package.json at {0} has no scripts block" -f $pkgRel)
        return
    }

    $scriptNames = @($scripts.PSObject.Properties.Name)

    if ($scriptNames -contains 'typecheck') {
        $cmdText = if ($usePnpm) { 'pnpm run typecheck' } else { 'npm run typecheck' }
        Add-Command -Id ("{0}-typecheck" -f $idPrefix) -Name ("{0} typecheck" -f $Label) `
            -WorkingDirectory $workDir -Command $cmdText -Level 'typecheck' -SafeByDefault $true `
            -Reason 'package.json scripts.typecheck present'
    }
    if ($scriptNames -contains 'lint') {
        $cmdText = if ($usePnpm) { 'pnpm run lint' } else { 'npm run lint' }
        Add-Command -Id ("{0}-lint" -f $idPrefix) -Name ("{0} lint" -f $Label) `
            -WorkingDirectory $workDir -Command $cmdText -Level 'lint' -SafeByDefault $true `
            -Reason 'package.json scripts.lint present'
    }
    if ($scriptNames -contains 'test') {
        $cmdText = if ($usePnpm) { 'pnpm test' } else { 'npm test' }
        Add-Command -Id ("{0}-test" -f $idPrefix) -Name ("{0} unit tests" -f $Label) `
            -WorkingDirectory $workDir -Command $cmdText -Level 'unit' -SafeByDefault $true `
            -Reason 'package.json scripts.test present'
    }
    if ($scriptNames -contains 'build') {
        $cmdText = if ($usePnpm) { 'pnpm run build' } else { 'npm run build' }
        Add-Command -Id ("{0}-build" -f $idPrefix) -Name ("{0} build" -f $Label) `
            -WorkingDirectory $workDir -Command $cmdText -Level 'build' -SafeByDefault $false `
            -Reason 'package.json scripts.build present (only runs at TestLevel=all)'
    }
}

function Inspect-PythonProject {
    param(
        [string]$RelativeDir,
        [string]$Label
    )
    $pyproject = if ([string]::IsNullOrEmpty($RelativeDir)) { 'pyproject.toml' } else { (Join-Path $RelativeDir 'pyproject.toml') }
    $pytestIni = if ([string]::IsNullOrEmpty($RelativeDir)) { 'pytest.ini' }    else { (Join-Path $RelativeDir 'pytest.ini') }
    $reqsTxt   = if ([string]::IsNullOrEmpty($RelativeDir)) { 'requirements.txt' } else { (Join-Path $RelativeDir 'requirements.txt') }
    $testsDir  = if ([string]::IsNullOrEmpty($RelativeDir)) { 'tests' }         else { (Join-Path $RelativeDir 'tests') }

    $hasPyproject = Test-RepoSubPath $pyproject
    $hasPytestIni = Test-RepoSubPath $pytestIni
    $hasReqs      = Test-RepoSubPath $reqsTxt
    $hasTests     = Test-RepoSubPath $testsDir

    if (-not ($hasPyproject -or $hasPytestIni -or $hasReqs -or $hasTests)) { return }

    Add-Stack ("python:{0}" -f $Label)

    $workDir = if ([string]::IsNullOrEmpty($RelativeDir)) { '.' } else { $RelativeDir }
    $idPrefix = if ([string]::IsNullOrEmpty($RelativeDir)) { 'root' } else { ($RelativeDir -replace '[\\/]', '-') }

    if ($hasTests -or $hasPytestIni -or $hasPyproject) {
        $reasonParts = @()
        if ($hasPytestIni) { $reasonParts += 'pytest.ini' }
        if ($hasPyproject) { $reasonParts += 'pyproject.toml' }
        if ($hasTests)     { $reasonParts += 'tests/ folder' }
        $reason = ('Python indicators: {0}' -f ($reasonParts -join ', '))
        Add-Command -Id ("{0}-pytest" -f $idPrefix) -Name ("{0} pytest" -f $Label) `
            -WorkingDirectory $workDir -Command 'python -m pytest' -Level 'unit' -SafeByDefault $true `
            -Reason $reason
    } else {
        Add-Warning ("Python project detected at {0} but no tests folder or pytest config found" -f $workDir)
    }
}

function Inspect-PlaywrightProject {
    param(
        [string]$RelativeDir,
        [string]$Label
    )
    $configs = Get-PlaywrightConfigsIn -RelativeDir $RelativeDir
    if ($configs.Count -eq 0) { return }

    Add-Stack ("playwright:{0}" -f $Label)

    $workDir = if ([string]::IsNullOrEmpty($RelativeDir)) { '.' } else { $RelativeDir }
    $idPrefix = if ([string]::IsNullOrEmpty($RelativeDir)) { 'root' } else { ($RelativeDir -replace '[\\/]', '-') }

    # Prefer pnpm if pnpm-lock.yaml present anywhere relevant
    $rootPnpmLock = Join-Path $repoRoot 'pnpm-lock.yaml'
    $localPnpmLock = if ([string]::IsNullOrEmpty($RelativeDir)) { $rootPnpmLock } else { Join-Path $repoRoot (Join-Path $RelativeDir 'pnpm-lock.yaml') }
    $usePnpm = ((Test-Path -LiteralPath $localPnpmLock) -or (Test-Path -LiteralPath $rootPnpmLock))
    $cmdText = if ($usePnpm) { 'pnpm exec playwright test' } else { 'npx playwright test' }

    Add-Command -Id ("{0}-playwright-e2e" -f $idPrefix) -Name ("{0} Playwright E2E" -f $Label) `
        -WorkingDirectory $workDir -Command $cmdText -Level 'e2e' -SafeByDefault $false `
        -Reason ('Playwright config(s): {0}' -f ($configs -join ', '))
}

# -------- Run inspections --------
Inspect-NodeProject -RelativeDir ''         -Label 'root'
Inspect-NodeProject -RelativeDir 'frontend' -Label 'frontend'
Inspect-NodeProject -RelativeDir 'backend'  -Label 'backend'

Inspect-PythonProject -RelativeDir ''         -Label 'root'
Inspect-PythonProject -RelativeDir 'backend'  -Label 'backend'

Inspect-PlaywrightProject -RelativeDir ''         -Label 'root'
Inspect-PlaywrightProject -RelativeDir 'frontend' -Label 'frontend'
Inspect-PlaywrightProject -RelativeDir 'backend'  -Label 'backend'

# Note bare tests folders for split repos
foreach ($dir in @('frontend/tests','backend/tests')) {
    if ((Test-RepoSubPath $dir) -and (-not ($detectedStacks -match ($dir.Split('/')[0])))) {
        Add-Warning ("Found {0} but no recognised runner alongside it" -f $dir)
    }
}

$noTestsFound = ($testCommands.Count -eq 0)
if ($noTestsFound) {
    Add-Warning 'No test commands were detected. Automated verification is unavailable for this repository state.'
}

$result = [ordered]@{
    repoRoot       = $repoRoot
    detectedStacks = @($detectedStacks)
    testCommands   = @($testCommands)
    warnings       = @($warnings)
    noTestsFound   = $noTestsFound
}

$jsonPath = Join-Path $RunFolder 'detected-tests.json'
($result | ConvertTo-Json -Depth 6) | Out-File -FilePath $jsonPath -Encoding utf8

# Markdown summary
$lines = @()
$lines += '# Detected Tests'
$lines += ''
$lines += "- Repo root: $repoRoot"
$lines += ("- No tests found: {0}" -f $noTestsFound)
$lines += ''
$lines += '## Detected stacks'
$lines += ''
if ($detectedStacks.Count -gt 0) {
    foreach ($s in $detectedStacks) { $lines += "- $s" }
} else {
    $lines += '- (none)'
}
$lines += ''
$lines += '## Test commands'
$lines += ''
if ($testCommands.Count -gt 0) {
    foreach ($c in $testCommands) {
        # default-selected means eligible for default local selection, not side-effect-free.
        $safeMark = if ($c.safeByDefault) { 'default-selected' } else { 'opt-in' }
        $lines += ("- **{0}** ({1}, {2}) - `{3}` in `{4}` - {5}" -f $c.id, $c.level, $safeMark, $c.command, $c.workingDirectory, $c.reason)
    }
} else {
    $lines += '- (none detected)'
}
$lines += ''
$lines += '## Warnings'
$lines += ''
if ($warnings.Count -gt 0) {
    foreach ($w in $warnings) { $lines += "- $w" }
} else {
    $lines += '- (none)'
}
$lines += ''
$lines += '_Phase 2: detection only. This script does not install dependencies and does not execute tests._'

$mdPath = Join-Path $RunFolder 'detected-tests.md'
($lines -join [Environment]::NewLine) | Out-File -FilePath $mdPath -Encoding utf8

Write-Host ("[detect-tests] stacks={0} commands={1} warnings={2} noTestsFound={3}" -f `
    $detectedStacks.Count, $testCommands.Count, $warnings.Count, $noTestsFound)
Write-Host "[detect-tests] artifacts written under $RunFolder"
