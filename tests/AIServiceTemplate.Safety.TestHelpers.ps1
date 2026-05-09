function Get-SafetyRepoRoot {
    return (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).ProviderPath
}

function Initialize-SafetyTestContext {
    $script:RepoRoot = Get-SafetyRepoRoot
    $script:AutopilotPath = Join-Path $script:RepoRoot 'tools\ai-autopilot.ps1'
    $script:CollectContextPath = Join-Path $script:RepoRoot 'tools\collect-context.ps1'
    $script:CopyScriptPath = Join-Path $script:RepoRoot 'tools\copy-template-to-service.ps1'
    $script:ManifestPath = Join-Path $script:RepoRoot 'TEMPLATE_MANIFEST.json'
    $script:GitignorePath = Join-Path $script:RepoRoot '.gitignore'
    $script:PowerShellExe = (Get-Command powershell -ErrorAction Stop).Source
    $script:GitAvailable = $null -ne (Get-Command git -ErrorAction SilentlyContinue)

    if ([string]::IsNullOrWhiteSpace($script:TempRoot)) {
        $script:TempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("ai-service-template-safety-tests-{0}" -f ([System.Guid]::NewGuid().ToString('N')))
    }
}

function Assert-True {
    param(
        [Parameter(Mandatory)][bool]$Condition,
        [string]$Message = 'Expected condition to be true.'
    )

    if (-not $Condition) {
        throw $Message
    }
}

function Assert-False {
    param(
        [Parameter(Mandatory)][bool]$Condition,
        [string]$Message = 'Expected condition to be false.'
    )

    if ($Condition) {
        throw $Message
    }
}

function Assert-Equal {
    param(
        $Actual,
        $Expected,
        [string]$Message = "Expected <$Expected> but got <$Actual>."
    )

    if ($Actual -ne $Expected) {
        throw $Message
    }
}

function Assert-NotEqual {
    param(
        $Actual,
        $Expected,
        [string]$Message = "Expected value not to equal <$Expected>."
    )

    if ($Actual -eq $Expected) {
        throw $Message
    }
}

function Assert-Match {
    param(
        [AllowNull()]$Actual,
        [Parameter(Mandatory)][string]$Pattern,
        [string]$Message = "Expected text to match pattern <$Pattern>."
    )

    if (($Actual -as [string]) -notmatch $Pattern) {
        throw $Message
    }
}

function Assert-NotMatch {
    param(
        [AllowNull()]$Actual,
        [Parameter(Mandatory)][string]$Pattern,
        [string]$Message = "Expected text not to match pattern <$Pattern>."
    )

    if (($Actual -as [string]) -match $Pattern) {
        throw $Message
    }
}

function Assert-NotNullOrEmpty {
    param(
        [AllowNull()]$Actual,
        [string]$Message = 'Expected value not to be null or empty.'
    )

    if ($null -eq $Actual -or [string]::IsNullOrEmpty(($Actual -as [string]))) {
        throw $Message
    }
}

function Assert-DoesNotThrow {
    param([Parameter(Mandatory)][scriptblock]$ScriptBlock)

    try {
        & $ScriptBlock | Out-Null
    } catch {
        throw "Expected script block not to throw, but it threw: $($_.Exception.Message)"
    }
}

function New-SafetyTempDirectory {
    param([Parameter(Mandatory)][string]$Name)

    Initialize-SafetyTestContext

    $path = Join-Path $script:TempRoot ("{0}-{1}" -f $Name, [System.Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $path -Force | Out-Null
    return $path
}

function Invoke-ChildPowerShellScript {
    param(
        [Parameter(Mandatory)][string]$ScriptPath,
        [string[]]$Arguments = @(),
        [Parameter(Mandatory)][string]$WorkingDirectory
    )

    Initialize-SafetyTestContext

    Push-Location -LiteralPath $WorkingDirectory
    try {
        $output = & $script:PowerShellExe -NoProfile -ExecutionPolicy Bypass -File $ScriptPath @Arguments 2>&1
        $exitCode = $LASTEXITCODE
    } finally {
        Pop-Location
    }

    return [pscustomobject]@{
        ExitCode = $exitCode
        Output   = (($output | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine)
    }
}

function New-TemplateRuntimeRepo {
    Initialize-SafetyTestContext

    $target = New-SafetyTempDirectory -Name 'runtime-repo'

    Push-Location -LiteralPath $target
    try {
        & git init 2>&1 | Out-Null
    } finally {
        Pop-Location
    }

    $controlFiles = @(
        'AI_PRODUCT_SPEC.md',
        'AI_ACCEPTANCE_CRITERIA.md',
        'AI_TASK_QUEUE.md',
        'AI_WORKFLOW.md',
        'AGENTS.md',
        'CLAUDE.md'
    )

    foreach ($file in $controlFiles) {
        Copy-Item -LiteralPath (Join-Path $script:RepoRoot $file) -Destination (Join-Path $target $file)
    }

    $targetTools = Join-Path $target 'tools'
    New-Item -ItemType Directory -Path $targetTools -Force | Out-Null
    Get-ChildItem -LiteralPath (Join-Path $script:RepoRoot 'tools') -Filter '*.ps1' |
        ForEach-Object {
            Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $targetTools $_.Name)
        }

    return $target
}

function Get-LatestRunFolder {
    param([Parameter(Mandatory)][string]$RepoPath)

    Initialize-SafetyTestContext

    $runRoot = Join-Path $RepoPath 'ai-runs'
    Get-ChildItem -LiteralPath $runRoot -Directory |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
}
