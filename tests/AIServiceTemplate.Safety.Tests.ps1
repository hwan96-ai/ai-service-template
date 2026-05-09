# Pester-style safety self-tests for the local AI harness.
# These tests do not install dependencies and do not invoke Codex CLI or Claude Code CLI.

$script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).ProviderPath
$script:AutopilotPath = Join-Path $script:RepoRoot 'tools\ai-autopilot.ps1'
$script:CollectContextPath = Join-Path $script:RepoRoot 'tools\collect-context.ps1'
$script:CopyScriptPath = Join-Path $script:RepoRoot 'tools\copy-template-to-service.ps1'
$script:ManifestPath = Join-Path $script:RepoRoot 'TEMPLATE_MANIFEST.json'
$script:GitignorePath = Join-Path $script:RepoRoot '.gitignore'
$script:PowerShellExe = (Get-Command powershell -ErrorAction Stop).Source
$script:GitAvailable = $null -ne (Get-Command git -ErrorAction SilentlyContinue)
$script:TempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("ai-service-template-safety-tests-{0}" -f ([System.Guid]::NewGuid().ToString('N')))

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

Describe 'AI Service Template safety guardrails' {
    BeforeAll {
        Initialize-SafetyTestContext
        New-Item -ItemType Directory -Path $script:TempRoot -Force | Out-Null
    }

    AfterAll {
        $candidate = Resolve-Path -LiteralPath $script:TempRoot -ErrorAction SilentlyContinue
        if ($candidate) {
            $candidatePath = [System.IO.Path]::GetFullPath($candidate.ProviderPath)
            $tempPath = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
            $leaf = Split-Path -Leaf $candidatePath

            if ($candidatePath.StartsWith($tempPath, [System.StringComparison]::OrdinalIgnoreCase) -and
                $leaf.StartsWith('ai-service-template-safety-tests-', [System.StringComparison]::OrdinalIgnoreCase)) {
                Remove-Item -LiteralPath $candidatePath -Recurse -Force
            }
        }
    }

    It 'refuses AutoCommit before creating run output' {
        $work = New-SafetyTempDirectory -Name 'autocommit'

        $result = Invoke-ChildPowerShellScript `
            -ScriptPath $script:AutopilotPath `
            -WorkingDirectory $work `
            -Arguments @('-AutoCommit', '-Goal', 'self-test autocommit refusal')

        Assert-NotEqual $result.ExitCode 0
        Assert-Match $result.Output 'AutoCommit is not permitted'
        Assert-False (Test-Path -LiteralPath (Join-Path $work 'ai-runs'))
    }

    It 'refuses MaxIterations above the safety cap before creating run output' {
        $work = New-SafetyTempDirectory -Name 'maxiterations'

        $result = Invoke-ChildPowerShellScript `
            -ScriptPath $script:AutopilotPath `
            -WorkingDirectory $work `
            -Arguments @('-MaxIterations', '4', '-Goal', 'self-test max iteration refusal')

        Assert-NotEqual $result.ExitCode 0
        Assert-Match $result.Output 'MaxIterations must be between\s+1\s+and\s+3'
        Assert-False (Test-Path -LiteralPath (Join-Path $work 'ai-runs'))
    }

    It 'refuses non-workspace-write CodexSandbox values before creating run output' {
        foreach ($sandbox in @('danger-full-access', 'read-only', 'bypass', 'yolo', 'full-auto', 'Workspace-write')) {
            $work = New-SafetyTempDirectory -Name 'codex-sandbox'

            $result = Invoke-ChildPowerShellScript `
                -ScriptPath $script:AutopilotPath `
                -WorkingDirectory $work `
                -Arguments @('-CodexSandbox', $sandbox, '-Goal', 'self-test codex sandbox refusal')

            Assert-NotEqual $result.ExitCode 0
            Assert-Match $result.Output 'CodexSandbox is locked to\s+workspace-?\s*write'
            Assert-Match ($result.Output -replace '\s+', '') ([regex]::Escape(($sandbox -replace '\s+', '')))
            Assert-False (Test-Path -LiteralPath (Join-Path $work 'ai-runs'))
        }
    }

    It 'keeps DryRun from invoking Codex or Claude even when run flags are present' -Skip:(-not $script:GitAvailable) {
        $repo = New-TemplateRuntimeRepo
        $autopilot = Join-Path $repo 'tools\ai-autopilot.ps1'

        $result = Invoke-ChildPowerShellScript `
            -ScriptPath $autopilot `
            -WorkingDirectory $repo `
            -Arguments @(
                '-DryRun',
                '-Implementer', 'codex',
                '-RunImplementer',
                '-Reviewer', 'claude',
                '-RunReviewer',
                '-Goal', 'self-test dry run suppression'
            )

        Assert-Equal $result.ExitCode 0
        Assert-Match $result.Output 'DryRun is ON'
        Assert-Match $result.Output 'DryRun suppressed -RunImplementer'
        Assert-Match $result.Output 'DryRun suppressed -RunReviewer'

        $runFolder = Get-LatestRunFolder -RepoPath $repo
        Assert-NotNullOrEmpty $runFolder

        $codexOutput = Get-Content -LiteralPath (Join-Path $runFolder.FullName 'codex-output.md') -Raw
        $claudeOutput = Get-Content -LiteralPath (Join-Path $runFolder.FullName 'claude-review.md') -Raw
        $handoff = Get-Content -LiteralPath (Join-Path $runFolder.FullName 'AI_FINAL_HANDOFF.md') -Raw

        Assert-Match $codexOutput 'not executed - DryRun'
        Assert-Match $codexOutput 'refused to invoke Codex CLI'
        Assert-Match $claudeOutput 'not executed - DryRun'
        Assert-Match $claudeOutput 'refused to invoke Claude CLI'
        Assert-Match $handoff 'Human review'
    }

    It 'redacts secret-like paths from git diff stat artifacts' -Skip:(-not $script:GitAvailable) {
        $repo = New-SafetyTempDirectory -Name 'redaction-repo'
        $runFolder = Join-Path $repo 'run-output'
        New-Item -ItemType Directory -Path $runFolder -Force | Out-Null

        $secretPaths = @(
            '.env.local',
            'keys/service.pem',
            'config/api.key',
            'config/service-secret.txt',
            'config/token-cache.txt',
            'config/credentials.json',
            'config/service-credential.txt'
        )

        Push-Location -LiteralPath $repo
        try {
            & git init 2>&1 | Out-Null
            & git config user.name 'Safety Test' 2>&1 | Out-Null
            & git config user.email 'safety@example.invalid' 2>&1 | Out-Null

            foreach ($relative in $secretPaths) {
                $path = Join-Path $repo $relative
                $parent = Split-Path -Parent $path
                if (-not [string]::IsNullOrWhiteSpace($parent)) {
                    New-Item -ItemType Directory -Path $parent -Force | Out-Null
                }
                Set-Content -LiteralPath $path -Value 'placeholder value' -Encoding utf8
            }

            & git add -f . 2>&1 | Out-Null
            & git commit -m 'baseline' 2>&1 | Out-Null

            foreach ($relative in $secretPaths) {
                Add-Content -LiteralPath (Join-Path $repo $relative) -Value 'changed value'
            }

            & $script:CollectContextPath -RunFolder $runFolder | Out-Null
        } finally {
            Pop-Location
        }

        $diffStat = Get-Content -LiteralPath (Join-Path $runFolder 'git-diff-stat.txt') -Raw
        $diffNames = Get-Content -LiteralPath (Join-Path $runFolder 'git-diff-names.txt') -Raw
        $status = Get-Content -LiteralPath (Join-Path $runFolder 'git-status.txt') -Raw

        foreach ($artifactText in @($diffStat, $diffNames, $status)) {
            Assert-Match $artifactText '\[redacted secret-like path\]'
            foreach ($fragment in @('.env.local', 'service.pem', 'api.key', 'service-secret.txt', 'token-cache.txt', 'credentials.json', 'service-credential.txt')) {
                Assert-NotMatch $artifactText ([regex]::Escape($fragment))
            }
        }
    }

    It 'keeps the copy script preview-only by default' {
        $target = New-SafetyTempDirectory -Name 'copy-target'
        New-Item -ItemType Directory -Path (Join-Path $target '.git') -Force | Out-Null

        $result = Invoke-ChildPowerShellScript `
            -ScriptPath $script:CopyScriptPath `
            -WorkingDirectory $script:RepoRoot `
            -Arguments @('-TargetRepo', $target)

        Assert-Equal $result.ExitCode 0
        Assert-Match $result.Output 'PREVIEW'
        Assert-Match $result.Output 'no files were written'

        Assert-False (Test-Path -LiteralPath (Join-Path $target 'AI_PRODUCT_SPEC.md'))
        Assert-False (Test-Path -LiteralPath (Join-Path $target 'tools'))
        Assert-False (Test-Path -LiteralPath (Join-Path $target 'ai-runs'))
    }

    It 'documents forbidden safety terms in the manifest and harness' {
        $manifest = Get-Content -LiteralPath $script:ManifestPath -Raw | ConvertFrom-Json
        $combinedText = @(
            Get-Content -LiteralPath $script:ManifestPath -Raw
            Get-Content -LiteralPath $script:AutopilotPath -Raw
        ) -join [Environment]::NewLine

        foreach ($term in @(
            'git commit',
            'git push',
            'deploy',
            'install',
            'danger-full-access',
            'bypass',
            'yolo',
            'full-auto'
        )) {
            Assert-Match $combinedText ([regex]::Escape($term))
        }

        Assert-False $manifest.autoCommit
        Assert-False $manifest.autoPush
        Assert-False $manifest.autoDeploy
        Assert-True $manifest.humanApprovalRequired
    }

    It 'documents selected local checks as trusted-repository opt-in checks with script-internal limitations' {
        $combinedDocs = @(
            Get-Content -LiteralPath (Join-Path $script:RepoRoot 'README.md') -Raw
            Get-Content -LiteralPath (Join-Path $script:RepoRoot 'TEMPLATE_USAGE.md') -Raw
            Get-Content -LiteralPath (Join-Path $script:RepoRoot 'AI_WORKFLOW.md') -Raw
            Get-Content -LiteralPath (Join-Path $script:RepoRoot 'AI_ACCEPTANCE_CRITERIA.md') -Raw
            Get-Content -LiteralPath (Join-Path $script:RepoRoot 'SECURITY.md') -Raw
        ) -join [Environment]::NewLine

        Assert-Match $combinedDocs 'selected opt-in local checks from trusted repositories'
        Assert-Match $combinedDocs 'deny-lists wrapper command text'
        Assert-Match $combinedDocs 'cannot guarantee'
        Assert-Match $combinedDocs 'side effects'
        Assert-NotMatch $combinedDocs 'safe tests'
    }

    It 'keeps generated run artifacts and Claude local state out of source control intent' {
        $gitignoreText = Get-Content -LiteralPath $script:GitignorePath -Raw
        $manifest = Get-Content -LiteralPath $script:ManifestPath -Raw | ConvertFrom-Json
        $copyScriptText = Get-Content -LiteralPath $script:CopyScriptPath -Raw

        Assert-Match $gitignoreText 'ai-runs/\*'
        Assert-Match $gitignoreText '!ai-runs/\.gitkeep'
        Assert-Match $gitignoreText '\.claude/'

        Assert-True ($manifest.localArtifactPatterns -contains 'ai-runs/*')
        Assert-True ($manifest.localArtifactPatterns -contains '.claude/')
        Assert-True ($manifest.neverCopy -contains '.claude')
        Assert-True ($manifest.neverCopy -contains 'ai-runs/[0-9]*')

        Assert-Match $copyScriptText 'ai-runs/\.gitkeep'
        Assert-Match $copyScriptText '\.claude'
    }
}

Describe 'Public release safety regressions' {
    BeforeAll {
        Initialize-SafetyTestContext
    }

    It 'omits raw local check output from Claude review prompts' {
        $scriptPath = Join-Path $script:RepoRoot 'tools\write-claude-review-prompt.ps1'
        $tempRun = Join-Path ([System.IO.Path]::GetTempPath()) ('ai-service-template-claude-review-' + [Guid]::NewGuid().ToString('N'))

        New-Item -ItemType Directory -Path $tempRun -Force | Out-Null

        try {
            Set-Content -Path (Join-Path $tempRun 'test-output.txt') -Encoding UTF8 -Value @(
                'SECRET_TOKEN_SHOULD_NOT_APPEAR',
                'fake-password',
                'connection string'
            )
            Set-Content -Path (Join-Path $tempRun 'test-summary.json') -Encoding UTF8 -Value '{"status":"failed","failed":1,"passed":0}'
            Set-Content -Path (Join-Path $tempRun 'git-status.txt') -Encoding UTF8 -Value ' M src/example.ps1'
            Set-Content -Path (Join-Path $tempRun 'git-diff-stat.txt') -Encoding UTF8 -Value ' src/example.ps1 | 2 +-'
            Set-Content -Path (Join-Path $tempRun 'git-diff-names.txt') -Encoding UTF8 -Value 'src/example.ps1'

            & $scriptPath -RunFolder $tempRun

            $promptPath = Join-Path $tempRun 'claude-review-prompt.md'
            Assert-True (Test-Path -LiteralPath $promptPath)

            $prompt = Get-Content -LiteralPath $promptPath -Raw
            Assert-NotMatch $prompt 'SECRET_TOKEN_SHOULD_NOT_APPEAR'
            Assert-NotMatch $prompt 'fake-password'
            Assert-NotMatch $prompt 'connection string'
            Assert-Match $prompt 'raw test output intentionally omitted/redacted for safety'
            Assert-Match $prompt 'test-output\.txt is available only for local human review'
        } finally {
            if (Test-Path -LiteralPath $tempRun) {
                Remove-Item -LiteralPath $tempRun -Recurse -Force
            }
        }
    }

    It 'uses trusted local-check wording in release-facing artifacts' {
        $manifest = Get-Content -LiteralPath (Join-Path $script:RepoRoot 'TEMPLATE_MANIFEST.json') -Raw
        Assert-DoesNotThrow { $manifest | ConvertFrom-Json }
        Assert-NotMatch $manifest 'Run safe unit-level tests'
        Assert-Match $manifest 'Run selected unit-level local checks from a trusted repository'
        Assert-True ((($manifest | ConvertFrom-Json).requiredFiles) -contains 'SECURITY.md')

        $sampleHandoff = Get-Content -LiteralPath (Join-Path $script:RepoRoot 'examples\sample-AI_FINAL_HANDOFF.md') -Raw
        Assert-NotMatch $sampleHandoff 'Confirm detected test commands are safe and expected'
        Assert-Match $sampleHandoff 'trusted, expected, and acceptable to run locally'

        $detectTests = Get-Content -LiteralPath (Join-Path $script:RepoRoot 'tools\detect-tests.ps1') -Raw
        Assert-NotMatch $detectTests 'safe-by-default'
        Assert-Match $detectTests 'default-selected'

        $fixPrompt = Get-Content -LiteralPath (Join-Path $script:RepoRoot 'tools\write-codex-fix-prompt.ps1') -Raw
        Assert-Match $fixPrompt 'token'
        Assert-Match $fixPrompt 'credential'
        Assert-Match $fixPrompt 'credentials\.json'
    }

    It 'keeps review and implementation prompt safety wording aligned' {
        $claudePromptScript = Get-Content -LiteralPath (Join-Path $script:RepoRoot 'tools\write-claude-review-prompt.ps1') -Raw
        $codexPromptScript = Get-Content -LiteralPath (Join-Path $script:RepoRoot 'tools\write-codex-implementation-prompt.ps1') -Raw

        Assert-Match $claudePromptScript '## Test Output Notice'
        Assert-NotMatch $claudePromptScript '## Test Output \(head\)'

        foreach ($pattern in @(
            '\.env',
            '\.env\.\*',
            '\*\.pem',
            '\*\.key',
            '\*secret\*',
            '\*token\*',
            '\*credential\*',
            'credentials\.json'
        )) {
            Assert-Match $codexPromptScript $pattern
        }
    }
}
