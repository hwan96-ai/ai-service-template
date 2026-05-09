# Pester-style safety self-tests for the local AI harness.
# These tests do not install dependencies and do not invoke Codex CLI or Claude Code CLI.

Describe 'AI Service Template safety guardrails' {
    BeforeAll {
        . (Join-Path $PSScriptRoot 'AIServiceTemplate.Safety.TestHelpers.ps1')
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

    It 'keeps DryRun from invoking Codex or Claude even when run flags are present' -Skip:(-not (Get-Command git -ErrorAction SilentlyContinue)) {
        $repo = New-TemplateRuntimeRepo
        $autopilot = Join-Path $repo 'tools\ai-autopilot.ps1'
        Assert-True (Test-Path -LiteralPath $autopilot) "Expected copied autopilot script to exist at <$autopilot>."

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

        $dryRunExpectedOutput = @(
            'DryRun is ON',
            'DryRun suppressed -RunImplementer',
            'DryRun suppressed -RunReviewer'
        )
        $dryRunFailureContext = @(
            'DryRun child PowerShell process did not meet expectations.',
            "Repo: $repo",
            "Autopilot: $autopilot",
            "ExitCode: $($result.ExitCode)",
            ("Expected key strings: {0}" -f ($dryRunExpectedOutput -join ' | ')),
            'Output:',
            $result.Output
        ) -join [Environment]::NewLine

        Assert-Equal $result.ExitCode 0 $dryRunFailureContext
        foreach ($expectedOutput in $dryRunExpectedOutput) {
            Assert-Match $result.Output $expectedOutput ("Expected DryRun output to contain <$expectedOutput>.`n$dryRunFailureContext")
        }

        $runFolder = Get-LatestRunFolder -RepoPath $repo
        Assert-NotNullOrEmpty $runFolder ("Expected DryRun to create an ai-runs child folder.`n$dryRunFailureContext")

        $codexOutputPath = Join-Path $runFolder.FullName 'codex-output.md'
        $claudeOutputPath = Join-Path $runFolder.FullName 'claude-review.md'
        $handoffPath = Join-Path $runFolder.FullName 'AI_FINAL_HANDOFF.md'
        Assert-True (Test-Path -LiteralPath $codexOutputPath) ("Expected DryRun Codex placeholder artifact at <$codexOutputPath>.`n$dryRunFailureContext")
        Assert-True (Test-Path -LiteralPath $claudeOutputPath) ("Expected DryRun Claude placeholder artifact at <$claudeOutputPath>.`n$dryRunFailureContext")
        Assert-True (Test-Path -LiteralPath $handoffPath) ("Expected DryRun final handoff artifact at <$handoffPath>.`n$dryRunFailureContext")

        $codexOutput = Get-Content -LiteralPath $codexOutputPath -Raw
        $claudeOutput = Get-Content -LiteralPath $claudeOutputPath -Raw
        $handoff = Get-Content -LiteralPath $handoffPath -Raw

        Assert-Match $codexOutput 'not executed - DryRun' ("Expected Codex placeholder to prove DryRun suppression.`nPath: $codexOutputPath`nContent:`n$codexOutput")
        Assert-Match $codexOutput 'refused to invoke Codex CLI' ("Expected Codex placeholder to prove Codex CLI was not invoked.`nPath: $codexOutputPath`nContent:`n$codexOutput")
        Assert-Match $claudeOutput 'not executed - DryRun' ("Expected Claude placeholder to prove DryRun suppression.`nPath: $claudeOutputPath`nContent:`n$claudeOutput")
        Assert-Match $claudeOutput 'refused to invoke Claude CLI' ("Expected Claude placeholder to prove Claude CLI was not invoked.`nPath: $claudeOutputPath`nContent:`n$claudeOutput")
        Assert-Match $handoff 'Human review' ("Expected final handoff to preserve human-review gate.`nPath: $handoffPath`nContent:`n$handoff")
    }

    It 'redacts secret-like paths from git diff stat artifacts' -Skip:(-not (Get-Command git -ErrorAction SilentlyContinue)) {
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
        . (Join-Path $PSScriptRoot 'AIServiceTemplate.Safety.TestHelpers.ps1')
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
