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

function New-SafetyTempDirectory {
    param([Parameter(Mandatory)][string]$Name)

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

    $runRoot = Join-Path $RepoPath 'ai-runs'
    Get-ChildItem -LiteralPath $runRoot -Directory |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
}

Describe 'AI Service Template safety guardrails' {
    BeforeAll {
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

        $result.ExitCode | Should Not Be 0
        $result.Output | Should Match 'AutoCommit is not permitted'
        (Test-Path -LiteralPath (Join-Path $work 'ai-runs')) | Should Be $false
    }

    It 'refuses MaxIterations above the safety cap before creating run output' {
        $work = New-SafetyTempDirectory -Name 'maxiterations'

        $result = Invoke-ChildPowerShellScript `
            -ScriptPath $script:AutopilotPath `
            -WorkingDirectory $work `
            -Arguments @('-MaxIterations', '4', '-Goal', 'self-test max iteration refusal')

        $result.ExitCode | Should Not Be 0
        $result.Output | Should Match 'MaxIterations must be between\s+1\s+and\s+3'
        (Test-Path -LiteralPath (Join-Path $work 'ai-runs')) | Should Be $false
    }

    It 'refuses non-workspace-write CodexSandbox values before creating run output' {
        foreach ($sandbox in @('danger-full-access', 'read-only', 'bypass', 'yolo', 'full-auto', 'Workspace-write')) {
            $work = New-SafetyTempDirectory -Name 'codex-sandbox'

            $result = Invoke-ChildPowerShellScript `
                -ScriptPath $script:AutopilotPath `
                -WorkingDirectory $work `
                -Arguments @('-CodexSandbox', $sandbox, '-Goal', 'self-test codex sandbox refusal')

            $result.ExitCode | Should Not Be 0
            $result.Output | Should Match 'CodexSandbox is locked to\s+workspace-?\s*write'
            ($result.Output -replace '\s+', '') | Should Match ([regex]::Escape(($sandbox -replace '\s+', '')))
            (Test-Path -LiteralPath (Join-Path $work 'ai-runs')) | Should Be $false
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

        $result.ExitCode | Should Be 0
        $result.Output | Should Match 'DryRun is ON'
        $result.Output | Should Match 'DryRun suppressed -RunImplementer'
        $result.Output | Should Match 'DryRun suppressed -RunReviewer'

        $runFolder = Get-LatestRunFolder -RepoPath $repo
        $runFolder | Should Not BeNullOrEmpty

        $codexOutput = Get-Content -LiteralPath (Join-Path $runFolder.FullName 'codex-output.md') -Raw
        $claudeOutput = Get-Content -LiteralPath (Join-Path $runFolder.FullName 'claude-review.md') -Raw
        $handoff = Get-Content -LiteralPath (Join-Path $runFolder.FullName 'AI_FINAL_HANDOFF.md') -Raw

        $codexOutput | Should Match 'not executed - DryRun'
        $codexOutput | Should Match 'refused to invoke Codex CLI'
        $claudeOutput | Should Match 'not executed - DryRun'
        $claudeOutput | Should Match 'refused to invoke Claude CLI'
        $handoff | Should Match 'Human review'
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
            $artifactText | Should Match '\[redacted secret-like path\]'
            foreach ($fragment in @('.env.local', 'service.pem', 'api.key', 'service-secret.txt', 'token-cache.txt', 'credentials.json', 'service-credential.txt')) {
                $artifactText | Should Not Match ([regex]::Escape($fragment))
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

        $result.ExitCode | Should Be 0
        $result.Output | Should Match 'PREVIEW'
        $result.Output | Should Match 'no files were written'

        (Test-Path -LiteralPath (Join-Path $target 'AI_PRODUCT_SPEC.md')) | Should Be $false
        (Test-Path -LiteralPath (Join-Path $target 'tools')) | Should Be $false
        (Test-Path -LiteralPath (Join-Path $target 'ai-runs')) | Should Be $false
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
            $combinedText | Should Match ([regex]::Escape($term))
        }

        $manifest.autoCommit | Should Be $false
        $manifest.autoPush | Should Be $false
        $manifest.autoDeploy | Should Be $false
        $manifest.humanApprovalRequired | Should Be $true
    }

    It 'documents selected local checks as trusted-repository opt-in checks with script-internal limitations' {
        $combinedDocs = @(
            Get-Content -LiteralPath (Join-Path $script:RepoRoot 'README.md') -Raw
            Get-Content -LiteralPath (Join-Path $script:RepoRoot 'TEMPLATE_USAGE.md') -Raw
            Get-Content -LiteralPath (Join-Path $script:RepoRoot 'AI_WORKFLOW.md') -Raw
            Get-Content -LiteralPath (Join-Path $script:RepoRoot 'AI_ACCEPTANCE_CRITERIA.md') -Raw
            Get-Content -LiteralPath (Join-Path $script:RepoRoot 'SECURITY.md') -Raw
        ) -join [Environment]::NewLine

        $combinedDocs | Should Match 'selected opt-in local checks from trusted repositories'
        $combinedDocs | Should Match 'deny-lists wrapper command text'
        $combinedDocs | Should Match 'cannot guarantee'
        $combinedDocs | Should Match 'side effects'
        $combinedDocs | Should Not Match 'safe tests'
    }

    It 'keeps generated run artifacts and Claude local state out of source control intent' {
        $gitignoreText = Get-Content -LiteralPath $script:GitignorePath -Raw
        $manifest = Get-Content -LiteralPath $script:ManifestPath -Raw | ConvertFrom-Json
        $copyScriptText = Get-Content -LiteralPath $script:CopyScriptPath -Raw

        $gitignoreText | Should Match 'ai-runs/\*'
        $gitignoreText | Should Match '!ai-runs/\.gitkeep'
        $gitignoreText | Should Match '\.claude/'

        ($manifest.localArtifactPatterns -contains 'ai-runs/*') | Should Be $true
        ($manifest.localArtifactPatterns -contains '.claude/') | Should Be $true
        ($manifest.neverCopy -contains '.claude') | Should Be $true
        ($manifest.neverCopy -contains 'ai-runs/[0-9]*') | Should Be $true

        $copyScriptText | Should Match 'ai-runs/\.gitkeep'
        $copyScriptText | Should Match '\.claude'
    }
}

Describe 'Public release safety regressions' {
    BeforeAll {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).ProviderPath
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
            Test-Path -LiteralPath $promptPath | Should Be $true

            $prompt = Get-Content -LiteralPath $promptPath -Raw
            $prompt | Should Not Match 'SECRET_TOKEN_SHOULD_NOT_APPEAR'
            $prompt | Should Not Match 'fake-password'
            $prompt | Should Not Match 'connection string'
            $prompt | Should Match 'raw test output intentionally omitted/redacted for safety'
            $prompt | Should Match 'test-output\.txt is available only for local human review'
        } finally {
            if (Test-Path -LiteralPath $tempRun) {
                Remove-Item -LiteralPath $tempRun -Recurse -Force
            }
        }
    }

    It 'uses trusted local-check wording in release-facing artifacts' {
        $manifest = Get-Content -LiteralPath (Join-Path $script:RepoRoot 'TEMPLATE_MANIFEST.json') -Raw
        { $manifest | ConvertFrom-Json } | Should Not Throw
        $manifest | Should Not Match 'Run safe unit-level tests'
        $manifest | Should Match 'Run selected unit-level local checks from a trusted repository'

        $sampleHandoff = Get-Content -LiteralPath (Join-Path $script:RepoRoot 'examples\sample-AI_FINAL_HANDOFF.md') -Raw
        $sampleHandoff | Should Not Match 'Confirm detected test commands are safe and expected'
        $sampleHandoff | Should Match 'trusted, expected, and acceptable to run locally'

        $detectTests = Get-Content -LiteralPath (Join-Path $script:RepoRoot 'tools\detect-tests.ps1') -Raw
        $detectTests | Should Not Match 'safe-by-default'
        $detectTests | Should Match 'default-selected'

        $fixPrompt = Get-Content -LiteralPath (Join-Path $script:RepoRoot 'tools\write-codex-fix-prompt.ps1') -Raw
        $fixPrompt | Should Match 'token'
        $fixPrompt | Should Match 'credential'
        $fixPrompt | Should Match 'credentials\.json'
    }
}
